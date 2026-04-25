import SwiftUI
import SceneKit
import GLTFKit2
import Sentry
import OSLog
import UIKit

// MARK: - Atlas 3D — Native SceneKit screen
//
// Replaces the old WKWebView approach that loaded /atlas-embed and stalled at
// 90% because of Clear-Site-Data poisoning + WebGL context loss. Now we:
//   1. Download the .glb from the backend on first open.
//   2. Cache it in Caches/ (survives reopens, evicted under pressure).
//   3. Parse with GLTFKit2 → SCNScene → SCNView with built-in cameraControl.
//
// Baseline ships the `arthrology` layer (skeleton, ~7MB). Other layers
// (myology, neurology, etc.) come in later commits.

private let atlasLog = Logger(subsystem: "com.bymav.vitaai", category: "Atlas3D")

struct AtlasSceneScreen: View {
    var onBack: () -> Void
    var onAskVita: ((String) -> Void)?

    @Environment(\.appContainer) private var container

    /// Single shared scene built once with lights + camera. Layers attach as
    /// child nodes (added/removed live), so toggling Ossos+Músculos keeps both
    /// in the same viewport without rebuilding anything.
    @State private var scene: SCNScene?
    @State private var progress: Double = 0
    @State private var errorMessage: String?
    @State private var loadAttempt = 0
    @State private var lookup: [String: MeshInfo] = [:]
    /// Lowercased-key mirror of `lookup` so we can match GLB mesh names that
    /// disagree with the catalogue on case (frequent — anatomy lookups Title
    /// Case, GLB exports often lowercase or all-caps).
    @State private var lookupCI: [String: MeshInfo] = [:]
    /// Index keyed by the bare base name (everything before the FIRST `.`),
    /// lowercased. Lets us resolve mesh names with arbitrary suffixes
    /// (`.o1.002`, `.e1l`, `_001`, etc.) when none of the strict strategies hit.
    @State private var lookupBase: [String: MeshInfo] = [:]
    @State private var selectedMesh: MeshInfo?
    /// All mesh-name candidates from the most recent tap (geometry + ancestors).
    /// Stored so "Esconder" hides every node that contributed to the selection.
    @State private var lastTappedCandidates: [String] = []
    @State private var resetTrigger = 0
    /// Layers currently in the scene. Tap a pill to add/remove. Default: ALL
    /// systems — user opens the body whole and dissects DOWN (toggling pills
    /// off) instead of building UP from one bone at a time.
    @State private var activeLayers: Set<AtlasLayer> = Set(AtlasLayer.allCases)
    /// Layers currently mid-download (network) — chip shows spinner overlay.
    @State private var loadingLayers: Set<AtlasLayer> = []
    /// In-memory cache of parsed model nodes per layer. Re-toggling a layer
    /// reattaches the same SCNNode without re-downloading or re-parsing.
    @State private var layerNodes: [AtlasLayer: SCNNode] = [:]
    /// Mesh count contributed by each loaded layer. Subtitle aggregates these.
    @State private var meshCountByLayer: [AtlasLayer: Int] = [:]
    @State private var cachedLayers: Set<AtlasLayer> = []
    @State private var hasTappedAnyMesh = false
    @State private var showSearch = false
    @State private var anglePreset: AtlasCameraAngle = .front
    @State private var angleTrigger = 0
    /// Bumped whenever a layer attaches/detaches so the scene wrapper can
    /// re-frame the camera around the new bounding box.
    @State private var bboxTrigger = 0
    /// Set when the user picks a structure from the search sheet — every
    /// other mesh is hidden and the camera zooms in. Tap the focus chip to
    /// exit and restore visibility.
    @State private var focusedMesh: MeshInfo?
    /// Mesh node names hidden by the user via the Esconder button.
    /// Persists across layer toggles (each mesh has a stable name).
    @State private var hiddenMeshes: Set<String> = []
    /// Global transparency applied across every active layer. 0 = opaque,
    /// 1 = fully invisible. Lets the user see organs hidden behind organs in
    /// the splanchnology layer (or skin/muscle in stacked combinations).
    @State private var transparency: Double = 0
    /// Dissect mode is OFF by default — the slider only appears after the
    /// user taps "Dissecar" in the angle rail. Keeps the bottom of the
    /// viewport clean for the 80% of users who never need transparency.
    @State private var dissectMode: Bool = false

    var body: some View {
        // No opaque base — the AppRouter's VitaAmbientBackground shows through.
        VStack(spacing: 0) {
            topBar

            ZStack {
                // Scene fills the viewport
                Group {
                    if let scene {
                        AnatomySceneView(
                            scene: scene,
                            resetTrigger: resetTrigger,
                            angleTrigger: angleTrigger,
                            anglePreset: anglePreset,
                            bboxTrigger: bboxTrigger,
                            hiddenMeshes: hiddenMeshes,
                            transparency: transparency,
                            focusedMeshId: focusedMesh?.id,
                            onMeshTap: { meshName in handleMeshTap(meshName) }
                        )
                        .transition(.opacity)
                    } else if let errorMessage {
                        errorView(errorMessage)
                    } else {
                        loadingView
                    }
                }

                // Vertical rail (left): all 7 systems visible at once
                HStack {
                    layerRail
                    Spacer()
                    angleRail
                }

                // Focus mode chip — floats top-center when the user isolates
                // a structure from search. Tap × to exit and restore visibility.
                if let focused = focusedMesh {
                    VStack {
                        focusChip(for: focused)
                            .padding(.top, 70) // below the topBar
                        Spacer()
                    }
                }

                // Bottom bar — only the tap hint by default. Transparency slider
                // appears below it ONLY when the user enabled "Dissecar" mode.
                if scene != nil && !activeLayers.isEmpty {
                    VStack {
                        Spacer()
                        if !hasTappedAnyMesh && !dissectMode {
                            emptyHint
                                .padding(.bottom, 6)
                                .allowsHitTesting(false)
                        }
                        if dissectMode {
                            transparencyBar
                                .padding(.horizontal, 14)
                                .padding(.bottom, 18)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationBarHidden(true)
        // Immersive: hide VitaTopBar and tab bar so the 3D viewport owns the screen
        // (same pattern as PdfViewerScreen). Only our own toolbar + rails remain.
        .preference(key: ImmersivePreferenceKey.self, value: true)
        .task(id: loadAttempt) { await ensureSceneAndInitialLayer() }
        .task { await loadLookupIfNeeded() }
        .onAppear { refreshCachedLayers() }
        .sheet(isPresented: $showSearch) {
            VitaSheet(detents: [.large]) {
                AtlasSearchSheet(
                    lookup: lookup,
                    activeLayerIds: Set(activeLayers.map { $0.rawValue }),
                    onPick: { info in
                        showSearch = false
                        // Focus mode: hide every other mesh and zoom into this
                        // one. The detail sheet still opens so the student
                        // immediately sees description/dica/curiosidade + can
                        // ask VITA inline. Exit via the floating focus chip.
                        focusedMesh = info
                        selectedMesh = info
                        hasTappedAnyMesh = true
                        VitaPostHogConfig.capture(event: "atlas_search_picked", properties: [
                            "layers": analyticsLayers,
                            "structure": info.pt,
                        ])
                        // Pair with atlas_focus_exit so we can measure the full
                        // funnel (search → focus enter → time spent → exit).
                        VitaPostHogConfig.capture(event: "atlas_focus_entered", properties: [
                            "structure": info.pt,
                            "system": info.system,
                            "layers_active": activeLayers.count,
                        ])
                    }
                )
            }
        }
        .sheet(item: $selectedMesh) { info in
            VitaSheet(detents: [.medium, .large]) {
                MeshDetailSheet(
                    info: info,
                    chatClient: container.chatClient,
                    onExpandToFullChat: { customPrompt in
                        VitaPostHogConfig.capture(event: "atlas_ask_vita_expand", properties: [
                            "layers": analyticsLayers,
                            "structure": info.pt,
                            "system": info.system,
                        ])
                        selectedMesh = nil
                        // Hand off to the full chat screen with the same seed.
                        onAskVita?(customPrompt)
                    },
                    onHide: {
                        // Exclude the "layer-<rawValue>" container nodes — those
                        // are bookkeeping wrappers from the multi-layer refactor;
                        // hiding one would nuke the entire system. Hide only the
                        // mesh itself + its immediate ancestors.
                        let toHide = Set(
                            lastTappedCandidates.filter { !$0.hasPrefix("layer-") }
                        )
                        hiddenMeshes.formUnion(toHide)
                        VitaPostHogConfig.capture(event: "atlas_mesh_hidden", properties: [
                            "layers": analyticsLayers,
                            "structure": info.pt,
                            "hidden_total": hiddenMeshes.count,
                        ])
                        selectedMesh = nil
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                    },
                    onClose: { selectedMesh = nil }
                )
            }
        }
        .trackScreen("Atlas3D")
    }

    private func handleMeshTap(_ candidates: [String]) {
        let resolved = resolveMeshLookup(candidates: candidates)
        selectedMesh = resolved.info
        lastTappedCandidates = candidates
        hasTappedAnyMesh = true
        VitaPostHogConfig.capture(event: "atlas_mesh_tapped", properties: [
            "layers": analyticsLayers,
            "mesh_name": candidates.first ?? "",
            "candidates_count": candidates.count,
            "matched_via": resolved.matchedVia,
            "has_lookup": resolved.hit,
            "lateralidade": resolved.lateralidade ?? "none",
            "pt_name": resolved.info.pt,
        ])
    }

    /// "+"-joined sorted rawValues for telemetry (e.g. "arthrology+myology").
    private var analyticsLayers: String {
        activeLayers.map { $0.rawValue }.sorted().joined(separator: "+")
    }

    /// Floating chip when focus mode is on. Shows the isolated structure name
    /// + a × to exit. Restoring visibility is just clearing focusedMesh —
    /// the AnatomySceneView observes the change and unhides the rest.
    private func focusChip(for info: MeshInfo) -> some View {
        Button {
            withAnimation(.easeOut(duration: 0.25)) {
                focusedMesh = nil
            }
            UISelectionFeedbackGenerator().selectionChanged()
            VitaPostHogConfig.capture(event: "atlas_focus_exit", properties: [
                "structure": info.pt,
            ])
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "scope")
                    .font(.system(size: 11, weight: .semibold))
                Text(info.pt)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(VitaColors.textSecondary)
            }
            .foregroundStyle(VitaColors.accent)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Capsule().stroke(VitaColors.accent.opacity(0.4), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Sair do modo foco em \(info.pt)")
        .transition(.opacity.combined(with: .scale))
    }

    /// Try every ancestor name and the geometry name, with progressive stripping
    /// (instance suffix → side marker → case-insensitive). Lateralidade is
    /// extracted from whichever candidate carried it, so the sheet shows
    /// "Fáscia antebraquial (esquerda)" even when the lookup key is bilateral.
    private func resolveMeshLookup(candidates: [String]) -> (info: MeshInfo, hit: Bool, lateralidade: String?, matchedVia: String) {
        let sideMatchers: [(pattern: String, label: String)] = [
            (#"[_\.\s]+(left|l)$"#,    "esquerda"),
            (#"[_\.\s]+(right|r)$"#,   "direita"),
            (#"[_\.\s]+(superior|sup)$"#,  "superior"),
            (#"[_\.\s]+(inferior|inf)$"#,  "inferior"),
            (#"[_\.\s]+(medial|med)$"#,    "medial"),
            (#"[_\.\s]+(lateral|lat)$"#,   "lateral"),
            (#"[_\.\s]+(anterior|ant)$"#,  "anterior"),
            (#"[_\.\s]+(posterior|post)$"#, "posterior"),
        ]

        // For each candidate, run strategies from most specific to most general.
        // First win across candidates breaks the loop.
        for raw in candidates {
            // Strategy 1: exact key (handles "Antebrachial fascia.l" already in lookup)
            if let hit = lookup[raw] {
                return (hit, true, nil, "exact")
            }
            if let hit = lookupCI[raw.lowercased()] {
                return (hit, true, nil, "exact-ci")
            }

            // Strategy 2: strip instance suffixes
            let stripped = raw
                .replacingOccurrences(of: #"\.[joJOgcGC]\.\d+$"#, with: "", options: .regularExpression)
                .replacingOccurrences(of: #"\.\d+$"#, with: "", options: .regularExpression)
                .replacingOccurrences(of: #"_\d+$"#, with: "", options: .regularExpression)
            if stripped != raw {
                if let hit = lookup[stripped] {
                    return (hit, true, nil, "stripped")
                }
                if let hit = lookupCI[stripped.lowercased()] {
                    return (hit, true, nil, "stripped-ci")
                }
            }

            // Strategy 3: also strip side, capture lateralidade
            var sideStripped = stripped
            var lateralidade: String?
            for (pattern, label) in sideMatchers {
                if let range = sideStripped.range(of: pattern, options: [.regularExpression, .caseInsensitive]) {
                    sideStripped.removeSubrange(range)
                    lateralidade = label
                    break
                }
            }
            if sideStripped != stripped {
                let baseHit = lookup[sideStripped] ?? lookupCI[sideStripped.lowercased()]
                if let hit = baseHit {
                    let label = lateralidade.map { "\(hit.pt) (\($0))" } ?? hit.pt
                    let enriched = MeshInfo(
                        id: hit.id, pt: label, en: hit.en, system: hit.system,
                        exam: hit.exam, description: hit.description,
                        tip: hit.tip, curiosity: hit.curiosity
                    )
                    return (enriched, true, lateralidade, "side-stripped")
                }
            }

            // Strategy 4: probe lookup with TA2 laterality suffixes.
            // Mesh "Piriformis muscle.o.001" strips to "Piriformis muscle"
            // but lookup is keyed `<name>.l/.r/.j/.i` — try them.
            let probeBase = stripped
            for (suffix, lat) in [(".l", "esquerda"), (".r", "direita"), (".j", nil as String?), (".i", nil as String?)] {
                let probed = probeBase + suffix
                if let hit = lookup[probed] ?? lookupCI[probed.lowercased()] {
                    let pt = lat.map { "\(hit.pt) (\($0))" } ?? hit.pt
                    let enriched = MeshInfo(
                        id: hit.id, pt: pt, en: hit.en, system: hit.system,
                        exam: hit.exam, description: hit.description,
                        tip: hit.tip, curiosity: hit.curiosity
                    )
                    return (enriched, true, lat, "suffix-probed")
                }
            }

            // Strategy 5: base-name lookup. Strip from FIRST `.` onward.
            // Catches `.o1.002`, `.e1l`, weird Blender duplicates.
            let dotIdx = raw.firstIndex(of: ".") ?? raw.endIndex
            let baseName = String(raw[..<dotIdx]).lowercased()
            if !baseName.isEmpty, let hit = lookupBase[baseName] {
                let lowerRaw = raw.lowercased()
                let lat: String? = (
                    lowerRaw.hasSuffix("l") || lowerRaw.hasSuffix(".l") || lowerRaw.contains("_left") ? "esquerda" :
                    lowerRaw.hasSuffix("r") || lowerRaw.hasSuffix(".r") || lowerRaw.contains("_right") ? "direita" :
                    nil
                )
                let pt = lat.map { "\(hit.pt) (\($0))" } ?? hit.pt
                let enriched = MeshInfo(
                    id: hit.id, pt: pt, en: hit.en, system: hit.system,
                    exam: hit.exam, description: hit.description,
                    tip: hit.tip, curiosity: hit.curiosity
                )
                return (enriched, true, lat, "base-lookup")
            }
        }

        // Last resort: prettify the most specific candidate name.
        let raw = candidates.first ?? ""
        let stripped = raw
            .replacingOccurrences(of: #"\.[joJOgcGC]\.\d+$"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\.\d+$"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"_\d+$"#, with: "", options: .regularExpression)
        var lateralidade: String?
        var sideStripped = stripped
        for (pattern, label) in sideMatchers {
            if let range = sideStripped.range(of: pattern, options: [.regularExpression, .caseInsensitive]) {
                sideStripped.removeSubrange(range)
                lateralidade = label
                break
            }
        }
        atlasLog.notice("[Atlas] mesh miss — tried \(candidates.count) candidates, first='\(raw, privacy: .public)' fallback='\(sideStripped, privacy: .public)'")
        let fallback = MeshInfo(
            id: sideStripped,
            pt: prettify(sideStripped, lateralidade: lateralidade),
            en: sideStripped,
            system: activeLayers.first?.rawValue ?? "",
            exam: "",
            description: nil,
            tip: nil,
            curiosity: nil
        )
        return (fallback, false, lateralidade, "fallback")
    }

    /// Compose a self-contained prompt the chat LLM can act on without needing
    /// to load the Atlas screen state. We keep it conversational; the chat side
    /// will run RAG / general knowledge over it.
    private func buildAskVitaPrompt(_ info: MeshInfo) -> String {
        let systemHint = info.system.isEmpty ? "" : " (sistema: \(info.system))"
        let enHint = (info.en != info.pt && !info.en.isEmpty) ? " — em inglês: \(info.en)" : ""
        return "Me explica sobre \(info.pt)\(systemHint)\(enHint). Quero saber: o que é, função, principais relações anatômicas, relevância clínica e se costuma cair em prova de medicina (ENADE, residência, OSCE)."
    }

    private func prettify(_ raw: String, lateralidade: String?) -> String {
        let cleaned = raw
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: ".", with: " ")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespaces)
        let cap = cleaned.prefix(1).uppercased() + cleaned.dropFirst()
        if let lateralidade { return "\(cap) (\(lateralidade))" }
        return String(cap)
    }

    // MARK: - Layer rail (vertical system switcher, all 7 visible)

    private var layerRail: some View {
        VStack(spacing: 8) {
            ForEach(AtlasLayer.allCases) { layer in
                layerPill(layer: layer)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(.ultraThinMaterial.opacity(0.7))
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
                )
        )
        .padding(.leading, 10)
        .padding(.top, 14)
    }

    @ViewBuilder
    private func layerPill(layer: AtlasLayer) -> some View {
        let active = activeLayers.contains(layer)
        let loading = loadingLayers.contains(layer)
        let cached = cachedLayers.contains(layer)
        Button {
            UISelectionFeedbackGenerator().selectionChanged()
            VitaPostHogConfig.capture(event: "atlas_layer_toggled", properties: [
                "layer": layer.rawValue,
                "to_active": !active,
                "active_count_before": activeLayers.count,
                "from_cached": cached,
            ])
            if active {
                detachLayer(layer)
            } else {
                Task { await attachLayer(layer) }
            }
        } label: {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(active ? VitaColors.accent.opacity(0.18) : Color.white.opacity(0.04))
                        .frame(width: 38, height: 38)
                        .overlay(
                            Circle()
                                .stroke(active ? VitaColors.accent.opacity(0.6) : Color.white.opacity(0.08),
                                        lineWidth: active ? 1.2 : 0.6)
                        )
                    if loading {
                        ProgressView()
                            .scaleEffect(0.6)
                            .tint(VitaColors.accent)
                    } else {
                        glyphView(layer.glyph, active: active)
                    }
                    // Cache dot: bottom-right of the icon circle
                    if cached && !loading {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(VitaColors.dataGreen)
                            .background(Circle().fill(Color.black))
                            .offset(x: 13, y: 13)
                    }
                }
                Text(layer.displayName)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(active ? VitaColors.accent : VitaColors.textSecondary.opacity(0.85))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .frame(width: 56)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Sistema \(layer.displayName)")
        .accessibilityHint(active
            ? "Tocar pra remover da cena"
            : (cached ? "Baixado, adiciona instantâneo" : "Tocar pra baixar e adicionar"))
        .accessibilityAddTraits(active ? [.isSelected] : [])
    }

    /// Renders an emoji-text or SF symbol for a layer pill, with the right
    /// tinting / sizing depending on whether the pill is active.
    @ViewBuilder
    private func glyphView(_ glyph: LayerGlyph, active: Bool) -> some View {
        switch glyph {
        case .sf(let symbol):
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(active ? VitaColors.accent : VitaColors.textSecondary)
        case .emoji(let char):
            Text(char)
                .font(.system(size: 18))
                .opacity(active ? 1.0 : 0.65)
        }
    }

    // MARK: - Camera angle rail (right)

    private var angleRail: some View {
        VStack(spacing: 6) {
            ForEach(AtlasCameraAngle.allCases) { angle in
                Button {
                    UISelectionFeedbackGenerator().selectionChanged()
                    anglePreset = angle
                    angleTrigger += 1
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: angle.icon)
                            .font(.system(size: 13, weight: .semibold))
                        Text(angle.displayName)
                            .font(.system(size: 8, weight: .semibold))
                    }
                    .foregroundStyle(anglePreset == angle ? VitaColors.accent : VitaColors.textSecondary)
                    .frame(width: 44, height: 38)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(anglePreset == angle
                                  ? VitaColors.accent.opacity(0.18)
                                  : Color.white.opacity(0.04))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(anglePreset == angle
                                    ? VitaColors.accent.opacity(0.5)
                                    : Color.white.opacity(0.06), lineWidth: 0.6)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Vista \(angle.displayName)")
            }

            // Thin separator between camera presets and the dissect toggle.
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 30, height: 0.5)
                .padding(.vertical, 2)

            // Dissecar — toggles the transparency slider at the bottom of the
            // viewport. Off by default; on when the user wants to peek through
            // outer layers (e.g. see ossos behind músculos).
            Button {
                UISelectionFeedbackGenerator().selectionChanged()
                withAnimation(.easeInOut(duration: 0.22)) {
                    dissectMode.toggle()
                    if !dissectMode { transparency = 0 }
                }
                VitaPostHogConfig.capture(event: "atlas_dissect_toggled", properties: [
                    "to_active": dissectMode,
                    "layers": analyticsLayers,
                ])
            } label: {
                VStack(spacing: 2) {
                    Image(systemName: dissectMode ? "rectangle.portrait.slash" : "scissors")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Dissecar")
                        .font(.system(size: 8, weight: .semibold))
                }
                .foregroundStyle(dissectMode ? VitaColors.accent : VitaColors.textSecondary)
                .frame(width: 44, height: 38)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(dissectMode
                              ? VitaColors.accent.opacity(0.18)
                              : Color.white.opacity(0.04))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(dissectMode
                                ? VitaColors.accent.opacity(0.5)
                                : Color.white.opacity(0.06), lineWidth: 0.6)
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Modo dissecar")
            .accessibilityHint(dissectMode
                ? "Toque pra desativar transparência"
                : "Toque pra ativar slider de transparência")
            .accessibilityAddTraits(dissectMode ? [.isSelected] : [])
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(.ultraThinMaterial.opacity(0.7))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
                )
        )
        .padding(.trailing, 10)
        .padding(.top, 14)
    }

    // MARK: - Empty state hint

    @ViewBuilder
    private var emptyHint: some View {
        HStack(spacing: 6) {
            Image(systemName: "hand.tap.fill")
                .font(.system(size: 11, weight: .semibold))
            Text("Toque numa estrutura pra explorar")
                .font(.system(size: 12, weight: .medium))
        }
        .foregroundStyle(VitaColors.textSecondary)
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(
            Capsule().fill(.ultraThinMaterial.opacity(0.85))
                .overlay(
                    Capsule().stroke(Color.white.opacity(0.06), lineWidth: 0.5)
                )
        )
    }

    /// Transparency slider — fades every active layer uniformly so the user
    /// can peek through outer organs/muscles to see structures behind. Reset
    /// button on the right snaps back to 0% (fully opaque).
    private var transparencyBar: some View {
        HStack(spacing: 12) {
            Image(systemName: transparency > 0.05 ? "eye.slash.fill" : "eye.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(transparency > 0.05 ? VitaColors.accent : VitaColors.textSecondary)
                .frame(width: 22)
                .contentTransition(.symbolEffect(.replace))

            Slider(value: $transparency, in: 0...0.85)
                .tint(VitaColors.accent)
                .accessibilityLabel("Transparência")
                .accessibilityValue("\(Int(transparency * 100)) por cento")

            Text("\(Int(transparency * 100))%")
                .font(.system(size: 11, weight: .semibold).monospacedDigit())
                .foregroundStyle(VitaColors.textSecondary)
                .frame(width: 32, alignment: .trailing)

            if transparency > 0.05 {
                Button {
                    withAnimation(.easeOut(duration: 0.2)) { transparency = 0 }
                    UISelectionFeedbackGenerator().selectionChanged()
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(VitaColors.accent)
                        .frame(width: 26, height: 26)
                        .background(Circle().fill(VitaColors.accent.opacity(0.15)))
                }
                .buttonStyle(.plain)
                .transition(.opacity.combined(with: .scale))
                .accessibilityLabel("Voltar opaco")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            Capsule().fill(.ultraThinMaterial.opacity(0.92))
                .overlay(
                    Capsule().stroke(Color.white.opacity(0.06), lineWidth: 0.5)
                )
        )
    }

    // MARK: - Top bar (shell-friendly)

    private var topBar: some View {
        HStack(spacing: 12) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(VitaColors.textPrimary)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(.ultraThinMaterial))
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 1) {
                Text("Atlas 3D")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(VitaColors.textPrimary)
                if let subtitle = headerSubtitle {
                    Text(subtitle)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(VitaColors.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .transition(.opacity)
                }
            }
            .layoutPriority(0) // can shrink so toolbar buttons never get crushed

            Spacer(minLength: 6)

            // "Mostrar tudo (N)" — only when the user has hidden meshes.
            // Compact: just the eye icon with a small count badge so it sits
            // next to the round toolbar icons without breaking the row.
            if !hiddenMeshes.isEmpty {
                Button {
                    hiddenMeshes.removeAll()
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    VitaPostHogConfig.capture(event: "atlas_show_all", properties: [
                        "layers": analyticsLayers,
                    ])
                } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "eye.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(VitaColors.accent)
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(.ultraThinMaterial))
                        Text("\(hiddenMeshes.count)")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(VitaColors.accent))
                            .offset(x: 4, y: -2)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Mostrar tudo, \(hiddenMeshes.count) escondidas")
                .transition(.opacity.combined(with: .scale))
            }

            // Search structures by PT-BR/EN name (4887 entries in the lookup).
            Button {
                showSearch = true
            } label: {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(VitaColors.textSecondary)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(.ultraThinMaterial))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Buscar estrutura")

            // Reset camera framing (useful after user zooms/rotates into the abyss).
            Button {
                resetTrigger += 1
            } label: {
                Image(systemName: "scope")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(VitaColors.textSecondary)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(.ultraThinMaterial))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Recentralizar câmera")

            Menu {
                Button {
                    scene = nil
                    errorMessage = nil
                    progress = 0
                    loadAttempt += 1
                } label: {
                    Label("Recarregar modelo", systemImage: "arrow.clockwise")
                }
                Button {
                    clearAtlasCaches()
                } label: {
                    Label("Limpar cache", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(VitaColors.textSecondary)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(.ultraThinMaterial))
            }
            .accessibilityLabel("Mais opções")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial.opacity(0.9))
    }

    private func clearAtlasCaches() {
        guard let cache = try? FileManager.default.url(
            for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: false
        ) else { return }
        for layer in AtlasLayer.allCases {
            let path = cache.appendingPathComponent("atlas-\(layer.rawValue).glb")
            try? FileManager.default.removeItem(at: path)
        }
        try? FileManager.default.removeItem(at: cache.appendingPathComponent("atlas-lookup.json"))
        // Drop in-memory caches AND detach all loaded layers — next ensure*
        // call will re-build the scene fresh with the user's active set.
        for (_, node) in layerNodes { node.removeFromParentNode() }
        layerNodes.removeAll()
        meshCountByLayer.removeAll()
        cachedLayers.removeAll()
        scene = nil
        progress = 0
        loadAttempt += 1
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    // MARK: - Loading & error

    private var loadingView: some View {
        VStack(spacing: 18) {
            // Pulsing anatomical silhouette in gold — feels like a heartbeat.
            AtlasLoadingSilhouette()

            VStack(spacing: 6) {
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                    .tint(VitaColors.accent)
                    .frame(width: 180)
                Text(progress > 0
                     ? "Baixando \(loadingLayers.first?.displayName ?? "modelo") — \(Int(progress * 100))%"
                     : "Carregando Atlas 3D…")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(VitaColors.textSecondary)
                    .monospacedDigit()
            }
        }
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(VitaColors.textSecondary)
            Text("Não foi possível carregar o Atlas")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(VitaColors.textPrimary)
            Text(message)
                .font(.system(size: 12))
                .foregroundStyle(VitaColors.textSecondary)
                .multilineTextAlignment(.center)
            Button {
                errorMessage = nil
                loadAttempt += 1
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                    Text("Tentar novamente")
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(VitaColors.accent)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(VitaColors.accent.opacity(0.3), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(32)
    }

    // MARK: - Lookup loader (mesh name → PT-BR info)

    private func loadLookupIfNeeded() async {
        guard lookup.isEmpty else { return }
        do {
            let cache = try FileManager.default.url(
                for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true
            )
            let cached = cache.appendingPathComponent("atlas-lookup.json")
            let data: Data
            if FileManager.default.fileExists(atPath: cached.path) {
                data = try Data(contentsOf: cached)
            } else if let remote = URL(string: AppConfig.authBaseURL + "/models/anatomy/anatomy-v2/lookup.json") {
                let (downloaded, _) = try await URLSession.shared.data(from: remote)
                try? downloaded.write(to: cached)
                data = downloaded
            } else {
                return
            }
            // Backend emits either `{pt, en, system, exam, id, desc?, tip?, curiosity?}`
            // or a raw string for the legacy format. Normalize to MeshInfo.
            let raw = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
            var out: [String: MeshInfo] = [:]
            out.reserveCapacity(raw.count)
            for (key, value) in raw {
                if let dict = value as? [String: Any] {
                    out[key] = MeshInfo(
                        id: (dict["id"] as? String) ?? key,
                        pt: (dict["pt"] as? String) ?? key,
                        en: (dict["en"] as? String) ?? key,
                        system: (dict["system"] as? String) ?? "",
                        exam: (dict["exam"] as? String) ?? "low",
                        description: dict["desc"] as? String,
                        tip: dict["tip"] as? String,
                        curiosity: dict["curiosity"] as? String
                    )
                } else if let str = value as? String {
                    out[key] = MeshInfo(id: key, pt: str, en: str, system: "", exam: "low",
                                        description: nil, tip: nil, curiosity: nil)
                }
            }
            // Build a case-insensitive index (key.lowercased() → MeshInfo) so
            // mesh names whose case drifted from the catalogue still resolve.
            var ciIndex: [String: MeshInfo] = [:]
            ciIndex.reserveCapacity(out.count)
            for (k, v) in out {
                ciIndex[k.lowercased()] = v
            }
            // Build base index: strip from FIRST `.` onward, prefer .l/.r/.j/.i
            // keys so the canonical TA2 entry wins on collisions.
            var baseIndex: [String: MeshInfo] = [:]
            let preferredOrder = [".l", ".r", ".j", ".i"]
            for (k, v) in out {
                guard preferredOrder.contains(where: { k.hasSuffix($0) }) else { continue }
                let dotIdx = k.firstIndex(of: ".") ?? k.endIndex
                let base = String(k[..<dotIdx]).lowercased()
                if baseIndex[base] == nil { baseIndex[base] = v }
            }
            for (k, v) in out {
                let dotIdx = k.firstIndex(of: ".") ?? k.endIndex
                let base = String(k[..<dotIdx]).lowercased()
                if baseIndex[base] == nil { baseIndex[base] = v }
            }
            await MainActor.run {
                self.lookup = out
                self.lookupCI = ciIndex
                self.lookupBase = baseIndex
            }
            atlasLog.notice("[Atlas] lookup loaded: \(out.count) entries (+\(ciIndex.count) CI, +\(baseIndex.count) base)")
        } catch {
            atlasLog.error("[Atlas] lookup load failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Load pipeline (multi-layer composable)

    /// First entry into the screen (or after a manual "Recarregar"). Builds the
    /// base scene with lights ONCE, then attaches every active layer in PARALLEL
    /// (TaskGroup) so the user gets the full body in roughly the time of the
    /// slowest GLB instead of summing across 7 systems sequentially.
    private func ensureSceneAndInitialLayer() async {
        if scene == nil {
            let base = buildBaseScene()
            await MainActor.run {
                self.scene = base
                SentrySDK.reportFullyDisplayed()
            }
        }
        let pending = activeLayers.subtracting(layerNodes.keys)
        guard !pending.isEmpty else { return }
        await withTaskGroup(of: Void.self) { group in
            for layer in pending {
                group.addTask { await attachLayer(layer) }
            }
        }
    }

    /// Adds a layer to the live scene. If the SCNNode is already cached
    /// in-memory (`layerNodes[layer]`), reattaches instantly. Otherwise
    /// fetches/parses the .glb (with disk cache) and parents the model root
    /// under a uniquely-named SCNNode so detach() can find it later.
    private func attachLayer(_ layer: AtlasLayer) async {
        await MainActor.run {
            self.activeLayers.insert(layer)
            self.errorMessage = nil
        }
        // Cache hit — instant reattach.
        if let cached = layerNodes[layer] {
            await MainActor.run {
                if let scene = self.scene, cached.parent == nil {
                    scene.rootNode.addChildNode(cached)
                }
                self.bboxTrigger += 1
            }
            return
        }
        // Cold path — download + parse.
        await MainActor.run { self.loadingLayers.insert(layer); self.progress = 0 }
        defer { Task { @MainActor in self.loadingLayers.remove(layer) } }
        do {
            let url = try await fetchOrCacheGLB(layer: layer.rawValue)
            let parsed = try await parseGLBToModelNode(url: url)
            let containerName = "layer-\(layer.rawValue)"
            parsed.node.name = containerName
            await MainActor.run {
                if let scene = self.scene {
                    scene.rootNode.addChildNode(parsed.node)
                }
                self.layerNodes[layer] = parsed.node
                self.meshCountByLayer[layer] = parsed.meshCount
                self.cachedLayers.insert(layer)
                self.bboxTrigger += 1
            }
        } catch {
            atlasLog.error("[Atlas] load failed (\(layer.rawValue)): \(error.localizedDescription, privacy: .public)")
            VitaPostHogConfig.capture(event: "atlas_load_failed", properties: [
                "layer": layer.rawValue,
                "error": "\(error)",
            ])
            await MainActor.run {
                self.activeLayers.remove(layer)
                // Show error only when nothing else is on screen.
                if self.activeLayers.isEmpty {
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    /// Detaches the SCNNode from the scene root. Keeps the parsed node in
    /// `layerNodes` so toggling back is instant. To purge entirely, use
    /// "Limpar cache" in the menu.
    private func detachLayer(_ layer: AtlasLayer) {
        if let node = layerNodes[layer] {
            node.removeFromParentNode()
        }
        activeLayers.remove(layer)
        bboxTrigger += 1
    }

    /// Subtitle shown under "Atlas 3D". Stays single-line: when only one layer
    /// is on we show its name + structure count; for 2+ layers we collapse to
    /// "N sistemas" so the toolbar buttons on the right never get pushed off.
    private var headerSubtitle: String? {
        if activeLayers.isEmpty { return "Toque num sistema pra começar" }
        let total = activeLayers
            .compactMap { meshCountByLayer[$0] }
            .reduce(0, +)
        let leading: String
        if activeLayers.count == 1, let only = activeLayers.first {
            leading = only.displayName
        } else {
            leading = "\(activeLayers.count) sistemas"
        }
        return total > 0 ? "\(leading) · \(total) estruturas" : leading
    }

    /// Scans Caches/ at view appear so chips already show a checkmark for
    /// layers downloaded in prior sessions (no cold-start false-negative).
    private func refreshCachedLayers() {
        guard let cache = try? FileManager.default.url(
            for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: false
        ) else { return }
        var found: Set<AtlasLayer> = []
        for layer in AtlasLayer.allCases {
            let path = cache.appendingPathComponent("atlas-\(layer.rawValue).glb").path
            if FileManager.default.fileExists(atPath: path) { found.insert(layer) }
        }
        cachedLayers = found
    }

    private func fetchOrCacheGLB(layer: String) async throws -> URL {
        let cache = try FileManager.default.url(
            for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        )
        let cached = cache.appendingPathComponent("atlas-\(layer).glb")
        if FileManager.default.fileExists(atPath: cached.path) {
            atlasLog.notice("[Atlas] using cached \(layer, privacy: .public).glb")
            return cached
        }

        // anatomy-v2 = Draco-decompressed variant (GLTFKit2 doesn't support
        // KHR_draco_mesh_compression natively). Larger on the wire, cached once.
        guard let remote = URL(string: AppConfig.authBaseURL + "/models/anatomy/anatomy-v2/\(layer).glb") else {
            throw AtlasError.invalidURL
        }
        atlasLog.notice("[Atlas] downloading \(remote.absoluteString, privacy: .public)")

        let delegate = DownloadProgressDelegate { [self] fraction in
            Task { @MainActor in self.progress = fraction }
        }
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 180
        let session = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
        defer { session.finishTasksAndInvalidate() }

        let start = Date()
        let (tmpURL, response) = try await session.download(from: remote)
        let elapsed = Date().timeIntervalSince(start)
        atlasLog.notice("[Atlas] download finished in \(elapsed, privacy: .public)s")

        guard let http = response as? HTTPURLResponse else {
            throw AtlasError.httpStatus(-1)
        }
        atlasLog.notice("[Atlas] download response: status=\(http.statusCode) contentLength=\(http.expectedContentLength)")
        guard http.statusCode == 200 else {
            throw AtlasError.httpStatus(http.statusCode)
        }

        try? FileManager.default.removeItem(at: cached)
        try FileManager.default.moveItem(at: tmpURL, to: cached)
        let size = (try? FileManager.default.attributesOfItem(atPath: cached.path)[.size] as? Int) ?? 0
        atlasLog.notice("[Atlas] cached at \(cached.path, privacy: .public) size=\(size)")
        await MainActor.run { self.progress = 1 }
        return cached
    }

    /// Builds a scene with the 3-point studio rig and nothing else — layers are
    /// added/removed live as user toggles them in the rail.
    private func buildBaseScene() -> SCNScene {
        let scene = SCNScene()
        // Ambient — neutral warm fill so geometry never reads pitch-black.
        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.intensity = 420
        ambient.light?.color = UIColor(red: 1.0, green: 0.96, blue: 0.90, alpha: 1.0)
        scene.rootNode.addChildNode(ambient)

        // Key — warm front-top-left
        let key = SCNNode()
        key.light = SCNLight()
        key.light?.type = .directional
        key.light?.intensity = 900
        key.light?.color = UIColor(red: 1.0, green: 0.94, blue: 0.82, alpha: 1.0)
        key.light?.castsShadow = false
        key.position = SCNVector3(5, 5, 5)
        key.eulerAngles = SCNVector3(-Float.pi / 4, Float.pi / 4, 0)
        scene.rootNode.addChildNode(key)

        // Fill — cool front-right, half intensity
        let fill = SCNNode()
        fill.light = SCNLight()
        fill.light?.type = .directional
        fill.light?.intensity = 450
        fill.light?.color = UIColor(red: 0.78, green: 0.84, blue: 1.0, alpha: 1.0)
        fill.position = SCNVector3(-5, 2, 5)
        fill.eulerAngles = SCNVector3(-Float.pi / 6, -Float.pi / 4, 0)
        scene.rootNode.addChildNode(fill)

        // Rim — warm amber from behind separates silhouette from bg
        let rim = SCNNode()
        rim.light = SCNLight()
        rim.light?.type = .directional
        rim.light?.intensity = 650
        rim.light?.color = UIColor(red: 1.0, green: 0.78, blue: 0.34, alpha: 1.0)
        rim.position = SCNVector3(0, 3, -6)
        rim.eulerAngles = SCNVector3(-Float.pi / 6, Float.pi, 0)
        scene.rootNode.addChildNode(rim)
        return scene
    }

    /// Loads a .glb and returns ONLY the model subtree (no lights, no camera)
    /// so it can be parented under our shared scene's rootNode without
    /// duplicating the lighting rig per layer.
    private func parseGLBToModelNode(url: URL) async throws -> (node: SCNNode, meshCount: Int) {
        atlasLog.notice("[Atlas] parseGLB start, url=\(url.path, privacy: .public)")
        let bytes = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0
        atlasLog.notice("[Atlas] glb file size: \(bytes) bytes")

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<(node: SCNNode, meshCount: Int), Error>) in
            var resumed = false
            GLTFAsset.load(with: url, options: [:]) { _, status, asset, error, _ in
                atlasLog.notice("[Atlas] GLTFAsset.load callback status=\(status.rawValue) hasAsset=\(asset != nil) hasError=\(error != nil)")
                guard !resumed else { return }
                if let error {
                    atlasLog.error("[Atlas] GLTFAsset.load error: \(error.localizedDescription, privacy: .public)")
                    resumed = true
                    continuation.resume(throwing: error)
                    return
                }
                if status == .complete, let asset {
                    resumed = true
                    let meshCount = asset.meshes.count
                    atlasLog.notice("[Atlas] asset complete: scenes=\(asset.scenes.count) meshes=\(meshCount) materials=\(asset.materials.count)")

                    let source = GLTFSCNSceneSource(asset: asset)
                    guard let scene = source.defaultScene else {
                        atlasLog.error("[Atlas] GLTFSCNSceneSource.defaultScene is nil")
                        continuation.resume(throwing: AtlasError.noScene)
                        return
                    }
                    // Strip lights/cameras the GLB might have authored — we own
                    // those at the shared scene level. Wrap remaining children
                    // under one SCNNode so detach is one-liner.
                    let container = SCNNode()
                    for child in scene.rootNode.childNodes {
                        if child.light != nil || child.camera != nil { continue }
                        child.removeFromParentNode()
                        container.addChildNode(child)
                    }
                    atlasLog.notice("[Atlas] model container assembled: meshes=\(meshCount) children=\(container.childNodes.count)")
                    continuation.resume(returning: (container, meshCount))
                }
            }
        }
    }

    private enum AtlasError: LocalizedError {
        case invalidURL
        case httpStatus(Int)
        case noScene
        var errorDescription: String? {
            switch self {
            case .invalidURL: return "URL do modelo inválida."
            case .httpStatus(let code): return "Servidor respondeu \(code) ao baixar o modelo."
            case .noScene: return "O arquivo .glb não tem cena padrão."
            }
        }
    }
}

// MARK: - Loading silhouette (pulsing anatomical figure)

private struct AtlasLoadingSilhouette: View {
    @State private var pulse = false

    var body: some View {
        Image(systemName: "figure.stand")
            .resizable()
            .scaledToFit()
            .frame(width: 64, height: 64)
            .symbolRenderingMode(.palette)
            .foregroundStyle(
                LinearGradient(
                    colors: [VitaColors.accent.opacity(0.95), VitaColors.accent.opacity(0.55)],
                    startPoint: .top, endPoint: .bottom
                )
            )
            .shadow(color: VitaColors.accent.opacity(pulse ? 0.55 : 0.2),
                    radius: pulse ? 22 : 10)
            .scaleEffect(pulse ? 1.04 : 0.96)
            .animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true), value: pulse)
            .onAppear { pulse = true }
    }
}

// MARK: - Camera angle presets

enum AtlasCameraAngle: String, CaseIterable, Identifiable {
    case front, side, back, top
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .front: return "Frente"
        case .side:  return "Lado"
        case .back:  return "Costas"
        case .top:   return "Topo"
        }
    }
    var icon: String {
        switch self {
        case .front: return "person.fill"
        case .side:  return "person.fill.turn.right"
        case .back:  return "person.fill.turn.down"
        case .top:   return "arrow.down.to.line"
        }
    }
}

// MARK: - Atlas layers (anatomical systems)

enum AtlasLayer: String, CaseIterable, Identifiable {
    case arthrology
    case myology
    case neurology
    case angiology
    case splanchnology
    case lymphoid
    case joints

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .arthrology:    return "Ossos"
        case .myology:       return "Músculos"
        case .neurology:     return "Nervos"
        case .angiology:     return "Vasos"
        case .splanchnology: return "Órgãos"
        case .lymphoid:      return "Linfático"
        case .joints:        return "Articulações"
        }
    }

    /// Anatomy systems don't map to clean SF Symbols (no skeleton glyph in
    /// Apple's set, no nerve glyph). We mix: emoji for the bones/blood/joints
    /// where SF fails the metaphor, SF Symbols where they actually fit.
    var glyph: LayerGlyph {
        switch self {
        case .arthrology:    return .emoji("🦴")
        case .myology:       return .emoji("💪")
        case .neurology:     return .emoji("🧠")
        case .angiology:     return .emoji("🩸")
        case .splanchnology: return .emoji("🫁")
        case .lymphoid:      return .emoji("💧")
        case .joints:        return .sf("circle.dotted.and.circle")
        }
    }
}

/// Tagged-union of icon source so the layer pill can render either an SF
/// Symbol or a plain emoji-as-text without the call site doing detection.
enum LayerGlyph {
    case sf(String)
    case emoji(String)
}

// MARK: - Mesh info + detail sheet

struct MeshInfo: Identifiable, Hashable {
    let id: String
    let pt: String
    let en: String
    let system: String
    let exam: String
    let description: String?
    let tip: String?
    let curiosity: String?
}

/// One bubble inside the inline anatomy chat. Kept local on purpose —
/// we don't need the heavy ChatMessage type from the main chat screen
/// (no images, no feedback, no markdown render yet — just text).
private struct AnatomyChatTurn: Identifiable {
    let id = UUID()
    let role: Role
    var text: String
    enum Role { case user, assistant }
}

private struct MeshDetailSheet: View {
    let info: MeshInfo
    /// Streams the chat reply directly into the sheet — we never leave the
    /// atlas viewport. Acts as actor since VitaChatClient is one.
    let chatClient: VitaChatClient
    /// Used by the "expand" button to escape into the full VitaChatScreen
    /// when the user wants more space / history / files. Optional.
    let onExpandToFullChat: (String) -> Void
    let onHide: () -> Void
    let onClose: () -> Void

    @State private var prompt: String = ""
    @FocusState private var promptFocused: Bool
    @State private var turns: [AnatomyChatTurn] = []
    @State private var isStreaming: Bool = false
    @State private var streamTask: Task<Void, Never>?
    @State private var streamError: String?
    @State private var conversationId: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(info.pt)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(VitaColors.textPrimary)
                    if info.en != info.pt {
                        Text(info.en)
                            .font(.system(size: 13))
                            .foregroundStyle(VitaColors.textSecondary)
                            .italic()
                    }
                }

                if !info.system.isEmpty {
                    Chip(label: systemLabel(info.system), color: VitaColors.accent.opacity(0.18))
                }

                if let desc = info.description, !desc.isEmpty {
                    sectionBlock("Descrição", content: desc)
                }
                if let tip = info.tip, !tip.isEmpty {
                    sectionBlock("Dica de prova", content: tip, icon: "lightbulb.fill")
                }
                if let curiosity = info.curiosity, !curiosity.isEmpty {
                    sectionBlock("Curiosidade", content: curiosity, icon: "sparkles")
                }

                // Inline chat: shows turns as they stream in. Composer always at
                // the bottom of the sheet — user tweaks question, mic dictates,
                // paperplane sends. We do NOT close the sheet; everything happens
                // here. "Expand" icon escapes to VitaChatScreen if more room is
                // wanted (history, attachments, etc.).
                if !turns.isEmpty || streamError != nil {
                    chatTranscript
                }
                askVitaComposer

                Button(action: onHide) {
                    HStack(spacing: 8) {
                        Image(systemName: "scissors")
                        Text("Esconder esta peça")
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(VitaColors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(VitaColors.textSecondary.opacity(0.3), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(20)
        }
        .onAppear {
            if prompt.isEmpty {
                prompt = "Me explica sobre \(info.pt)"
            }
        }
        .onDisappear {
            streamTask?.cancel()
        }
    }

    // MARK: - Composer

    private var askVitaComposer: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(VitaColors.accent)
                Text(turns.isEmpty ? "PERGUNTE À VITA" : "CONTINUE A CONVERSA")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(VitaColors.textSecondary)
                    .kerning(0.5)
                Spacer()
                if !turns.isEmpty {
                    Button {
                        // Hand off the conversation to the full chat screen,
                        // passing the latest user prompt as the seed (the full
                        // history is server-side under conversationId).
                        let lastUser = turns.last(where: { $0.role == .user })?.text
                            ?? "Me explica sobre \(info.pt)"
                        onExpandToFullChat(lastUser)
                    } label: {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(VitaColors.textSecondary)
                            .padding(6)
                            .background(Circle().fill(.ultraThinMaterial))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Abrir conversa completa com VITA")
                }
            }

            HStack(alignment: .center, spacing: 8) {
                VitaVoiceInput(
                    onTranscript: { text in
                        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !clean.isEmpty else { return }
                        prompt = clean
                        promptFocused = false
                    }
                )

                TextField(
                    "Me explica sobre \(info.pt)",
                    text: $prompt,
                    axis: .vertical
                )
                .font(.system(size: 14))
                .foregroundStyle(VitaColors.textPrimary)
                .lineLimit(1...4)
                .focused($promptFocused)
                .submitLabel(.send)
                .onSubmit { submit() }
                .disabled(isStreaming)

                Button(action: submit) {
                    Image(systemName: isStreaming ? "stop.fill" : "paperplane.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(canSendOrStop ? .white : VitaColors.textSecondary)
                        .frame(width: 36, height: 36)
                        .background(
                            Circle().fill(
                                canSendOrStop ? VitaColors.accent : VitaColors.glassBg
                            )
                        )
                }
                .buttonStyle(.plain)
                .disabled(!canSendOrStop)
                .accessibilityLabel(isStreaming ? "Parar resposta" : "Enviar pergunta")
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(VitaColors.accent.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(VitaColors.accent.opacity(0.3), lineWidth: 1)
                    )
            )
        }
    }

    // MARK: - Transcript

    private var chatTranscript: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(turns) { turn in
                HStack(alignment: .top, spacing: 8) {
                    if turn.role == .user {
                        Spacer(minLength: 32)
                        Text(turn.text)
                            .font(.system(size: 14))
                            .foregroundStyle(VitaColors.textPrimary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(VitaColors.accent.opacity(0.18))
                            )
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    } else {
                        // Avatar VITA real (mascote orb) — Rafael 2026-04-25:
                        // pediu várias vezes pra parar com sparkles. Estado
                        // muda conforme stream: thinking enquanto vazio, awake
                        // quando texto começa a chegar.
                        OrbMascot(
                            palette: .vita,
                            state: turn.text.isEmpty ? .thinking : .awake,
                            size: 26,
                            bounceEnabled: false
                        )
                        .padding(.top, 2)
                        Text(turn.text.isEmpty ? "…" : turn.text)
                            .font(.system(size: 14))
                            .foregroundStyle(VitaColors.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            if let err = streamError {
                Text("⚠︎ \(err)")
                    .font(.system(size: 12))
                    .foregroundStyle(VitaColors.dataRed)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Actions

    private var canSendOrStop: Bool {
        if isStreaming { return true }
        return !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func submit() {
        if isStreaming {
            // Stop button — cancel the in-flight stream.
            streamTask?.cancel()
            isStreaming = false
            UISelectionFeedbackGenerator().selectionChanged()
            return
        }
        let final = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !final.isEmpty else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        // Append turns optimistically so the UI feels instant.
        turns.append(AnatomyChatTurn(role: .user, text: final))
        let assistantId = AnatomyChatTurn(role: .assistant, text: "")
        turns.append(assistantId)
        let assistantIndex = turns.count - 1
        prompt = ""
        promptFocused = false
        streamError = nil
        isStreaming = true

        let convId = conversationId
        streamTask = Task { @MainActor in
            do {
                let stream = await chatClient.streamChat(
                    message: final,
                    conversationId: convId
                )
                for try await event in stream {
                    if Task.isCancelled { break }
                    switch event {
                    case .textDelta(let chunk):
                        if assistantIndex < turns.count {
                            turns[assistantIndex].text += chunk
                        }
                    case .messageStop(let cid):
                        if let cid { conversationId = cid }
                    case .toolProgress:
                        break
                    case .error(let msg):
                        streamError = msg
                    }
                }
            } catch is CancellationError {
                // user pressed stop — keep partial text as-is
            } catch {
                streamError = error.localizedDescription
            }
            isStreaming = false
        }
    }

    @ViewBuilder
    private func sectionBlock(_ title: String, content: String, icon: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(VitaColors.accent)
                }
                Text(title.uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(VitaColors.textSecondary)
                    .kerning(0.5)
            }
            Text(content)
                .font(.system(size: 14))
                .foregroundStyle(VitaColors.textPrimary.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func systemLabel(_ system: String) -> String {
        switch system {
        case "arthrology": return "Osteologia"
        case "myology": return "Miologia"
        case "neurology": return "Neurologia"
        case "angiology": return "Angiologia"
        case "splanchnology": return "Esplâncnologia"
        case "lymphoid": return "Linfático"
        case "joints": return "Articulações"
        default: return system.capitalized
        }
    }

    private struct Chip: View {
        let label: String
        let color: Color
        var body: some View {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(VitaColors.textPrimary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(color))
        }
    }
}

// MARK: - Search sheet

private struct AtlasSearchSheet: View {
    let lookup: [String: MeshInfo]
    let activeLayerIds: Set<String>
    let onPick: (MeshInfo) -> Void

    @State private var query: String = ""
    @FocusState private var focused: Bool

    private var filtered: [MeshInfo] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard q.count >= 2 else { return [] }
        // Score: starts-with > contains; entries from any active layer float up.
        var matches: [(MeshInfo, Int)] = []
        for info in lookup.values {
            let pt = info.pt.lowercased()
            let en = info.en.lowercased()
            var score = 0
            if pt.hasPrefix(q) { score = 100 }
            else if pt.contains(q) { score = 60 }
            else if en.hasPrefix(q) { score = 40 }
            else if en.contains(q) { score = 20 }
            if score == 0 { continue }
            if activeLayerIds.contains(info.system) { score += 50 }
            matches.append((info, score))
        }
        return matches
            .sorted { $0.1 > $1.1 || ($0.1 == $1.1 && $0.0.pt < $1.0.pt) }
            .prefix(40)
            .map { $0.0 }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search field
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(VitaColors.textSecondary)
                TextField("Buscar estrutura — fíbula, aorta, miocárdio…", text: $query)
                    .focused($focused)
                    .font(.system(size: 15))
                    .foregroundStyle(VitaColors.textPrimary)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                if !query.isEmpty {
                    Button { query = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(VitaColors.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.06))
            )
            .padding(.horizontal, 16)
            .padding(.top, 16)

            if query.count < 2 {
                placeholderState
            } else if filtered.isEmpty {
                noResultsState
            } else {
                List(filtered) { info in
                    Button { onPick(info) } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(info.pt)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(VitaColors.textPrimary)
                            HStack(spacing: 6) {
                                if !info.system.isEmpty {
                                    Text(systemLabel(info.system))
                                        .font(.system(size: 11))
                                        .foregroundStyle(VitaColors.textSecondary)
                                }
                                if info.en != info.pt {
                                    Text("· \(info.en)")
                                        .font(.system(size: 11))
                                        .foregroundStyle(VitaColors.textSecondary.opacity(0.7))
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }

            Spacer()
        }
        .onAppear { focused = true }
    }

    private var placeholderState: some View {
        VStack(spacing: 10) {
            Image(systemName: "books.vertical.fill")
                .font(.system(size: 38))
                .foregroundStyle(VitaColors.textSecondary.opacity(0.5))
            Text("\(lookup.count) estruturas no catálogo")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(VitaColors.textPrimary)
            Text("Digite ao menos 2 letras pra começar")
                .font(.system(size: 12))
                .foregroundStyle(VitaColors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var noResultsState: some View {
        VStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 38))
                .foregroundStyle(VitaColors.textSecondary.opacity(0.5))
            Text("Nenhuma estrutura corresponde a \"\(query)\"")
                .font(.system(size: 13))
                .foregroundStyle(VitaColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func systemLabel(_ system: String) -> String {
        switch system {
        case "arthrology": return "Osteologia"
        case "myology": return "Miologia"
        case "neurology": return "Neurologia"
        case "angiology": return "Angiologia"
        case "splanchnology": return "Esplâncnologia"
        case "lymphoid": return "Linfático"
        case "joints": return "Articulações"
        default: return system.capitalized
        }
    }
}

// MARK: - Download progress delegate

private final class DownloadProgressDelegate: NSObject, URLSessionDownloadDelegate {
    let onProgress: (Double) -> Void
    init(onProgress: @escaping (Double) -> Void) { self.onProgress = onProgress }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didWriteData bytesWritten: Int64, totalBytesWritten: Int64,
                    totalBytesExpectedToWrite: Int64) {
        guard totalBytesExpectedToWrite > 0 else { return }
        onProgress(Double(totalBytesWritten) / Double(totalBytesExpectedToWrite))
    }

    // Required by URLSessionDownloadDelegate protocol but handled by the async/await
    // download(from:) call in session, which returns the tmp URL directly.
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didFinishDownloadingTo location: URL) {}
}

// MARK: - Scene view (SwiftUI wrapper)

private struct AnatomySceneView: UIViewRepresentable {
    let scene: SCNScene
    let resetTrigger: Int
    let angleTrigger: Int
    let anglePreset: AtlasCameraAngle
    let bboxTrigger: Int
    let hiddenMeshes: Set<String>
    let transparency: Double
    /// When non-nil: hide every mesh whose name does not match (or share the
    /// stem with) this id. Camera animates to fit the focused node.
    let focusedMeshId: String?
    let onMeshTap: ([String]) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onMeshTap: onMeshTap) }

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView(frame: .zero)
        view.scene = scene
        view.backgroundColor = .clear
        view.allowsCameraControl = true     // rotate/pan/zoom built-in
        view.autoenablesDefaultLighting = false
        view.antialiasingMode = .multisampling2X
        view.preferredFramesPerSecond = 60
        view.isJitteringEnabled = true

        // Camera with safe defaults — actual framing happens in updateUIView
        // once at least one layer has attached (bboxTrigger fires).
        let camera = SCNCamera()
        camera.zNear = 0.01
        camera.zFar = 200
        let camNode = SCNNode()
        camNode.name = "AtlasCamera"
        camNode.camera = camera
        camNode.position = SCNVector3(0, 0, 4)
        scene.rootNode.addChildNode(camNode)
        view.pointOfView = camNode

        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)

        return view
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        // Re-frame when a layer joined/left the scene. Recalcs bbox over EVERY
        // non-light/non-camera child, fits the camera around it, and remembers
        // the framing so "recenter" + angle presets stay in sync.
        if bboxTrigger != context.coordinator.lastBboxTrigger {
            context.coordinator.lastBboxTrigger = bboxTrigger
            reframe(uiView, coord: context.coordinator)
        }
        // Reset camera when resetTrigger increments.
        if resetTrigger != context.coordinator.lastResetTrigger {
            context.coordinator.lastResetTrigger = resetTrigger
            if let cam = uiView.pointOfView {
                SCNTransaction.begin()
                SCNTransaction.animationDuration = 0.45
                cam.position = context.coordinator.initialCameraPosition
                cam.look(at: context.coordinator.cameraTarget)
                SCNTransaction.commit()
            }
        }
        // Snap camera to a preset angle when angleTrigger increments.
        if angleTrigger != context.coordinator.lastAngleTrigger {
            context.coordinator.lastAngleTrigger = angleTrigger
            applyAnglePreset(uiView, coord: context.coordinator)
        }
        // Apply hide/show. Only re-traverse when the set actually changed.
        // When focus mode is on, the focus pass below overrides hiddenMeshes.
        if focusedMeshId == nil &&
           hiddenMeshes != context.coordinator.lastHiddenMeshes {
            context.coordinator.lastHiddenMeshes = hiddenMeshes
            scene.rootNode.enumerateHierarchy { node, _ in
                guard let name = node.name else { return }
                if hiddenMeshes.contains(name) {
                    node.isHidden = true
                } else if node.isHidden {
                    node.isHidden = false
                }
            }
        }
        // Focus mode: hide everything that isn't the picked structure (or one
        // of its ancestors), then animate the camera to fit it. Clearing it
        // restores visibility honoring user-hidden meshes.
        if focusedMeshId != context.coordinator.lastFocusedMeshId {
            context.coordinator.lastFocusedMeshId = focusedMeshId
            applyFocus(uiView, coord: context.coordinator)
        }
        // Global transparency — has to fight depth-buffer write or the GPU
        // will discard pixels behind a translucent mesh BEFORE blending. We
        // set writesToDepthBuffer=false on every material when opacity<1 so
        // the inner skeleton stays visible through translucent muscle layers.
        // Reverts cleanly when opacity returns to 1 (depth write back on).
        if abs(transparency - context.coordinator.lastTransparency) > 0.001 {
            context.coordinator.lastTransparency = transparency
            let alpha = CGFloat(1.0 - transparency)
            let translucent = alpha < 0.999
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.18
            for layerNode in scene.rootNode.childNodes
                where (layerNode.name ?? "").hasPrefix("layer-") {
                layerNode.enumerateHierarchy { n, _ in
                    guard let geom = n.geometry else { return }
                    for material in geom.materials {
                        material.transparency = alpha
                        material.transparencyMode = .singleLayer
                        material.blendMode = .alpha
                        material.readsFromDepthBuffer = true
                        // Critical: when translucent, DON'T write depth — lets
                        // ossos behind músculos render through the muscle.
                        material.writesToDepthBuffer = !translucent
                    }
                }
            }
            SCNTransaction.commit()
        }
    }

    /// Recompute bbox across all attached layer containers (children whose name
    /// starts with "layer-"), refit the camera, and refresh the coordinator's
    /// remembered framing so reset/preset still work.
    private func reframe(_ uiView: SCNView, coord: Coordinator) {
        let layerContainers = scene.rootNode.childNodes.filter {
            ($0.name ?? "").hasPrefix("layer-") && $0.light == nil && $0.camera == nil
        }
        guard !layerContainers.isEmpty else { return }

        var hasBox = false
        var minV = SCNVector3Zero, maxV = SCNVector3Zero
        for node in layerContainers {
            let (lmin, lmax) = node.boundingBox
            // Convert to world space — layer containers may carry transforms.
            let wmin = node.convertPosition(lmin, to: scene.rootNode)
            let wmax = node.convertPosition(lmax, to: scene.rootNode)
            let lo = SCNVector3(min(wmin.x, wmax.x), min(wmin.y, wmax.y), min(wmin.z, wmax.z))
            let hi = SCNVector3(max(wmin.x, wmax.x), max(wmin.y, wmax.y), max(wmin.z, wmax.z))
            if !hasBox {
                minV = lo; maxV = hi; hasBox = true
            } else {
                minV = SCNVector3(min(minV.x, lo.x), min(minV.y, lo.y), min(minV.z, lo.z))
                maxV = SCNVector3(max(maxV.x, hi.x), max(maxV.y, hi.y), max(maxV.z, hi.z))
            }
        }
        guard hasBox else { return }

        let dx = maxV.x - minV.x, dy = maxV.y - minV.y, dz = maxV.z - minV.z
        let diagonal = sqrt(dx * dx + dy * dy + dz * dz)
        let safeDiag: Float = diagonal > 0.0001 ? diagonal : 2.0
        let cx = (minV.x + maxV.x) / 2
        let cy = (minV.y + maxV.y) / 2
        let cz = (minV.z + maxV.z) / 2
        let target = SCNVector3(cx, cy, cz)
        let initial = SCNVector3(cx, cy, cz + safeDiag * 1.6)
        atlasLog.notice("[Atlas] reframe layers=\(layerContainers.count) diag=\(diagonal)")

        // Update camera + remembered framing.
        if let cam = uiView.pointOfView {
            cam.camera?.zFar = Double(safeDiag) * 20
            // Only animate the FIRST framing (when coordinator is still at zero
            // origin). Subsequent re-frames after a layer toggle stay still
            // unless the user hits "recenter" — feels less jumpy when stacking.
            let firstTime = coord.initialCameraPosition.x == 0
                && coord.initialCameraPosition.y == 0
                && coord.initialCameraPosition.z == 0
            if firstTime {
                SCNTransaction.begin()
                SCNTransaction.animationDuration = 0.35
                cam.position = initial
                cam.look(at: target)
                SCNTransaction.commit()
            }
        }
        coord.initialCameraPosition = initial
        coord.cameraTarget = target
        // Anchor for angle-preset rotation: rotate ALL active layer containers
        // together (one yaw value applied per node so light rig stays put).
        coord.modelContainers = layerContainers
    }

    /// Focus mode: hide every mesh except the picked one (matched loosely on
    /// name + stem) and zoom the camera onto it. Clearing focus restores
    /// the previous hide state and re-frames to the full bbox.
    private func applyFocus(_ uiView: SCNView, coord: Coordinator) {
        guard let cam = uiView.pointOfView else { return }

        if let target = focusedMeshId {
            // Build candidate name set: exact id + lower-cased + base stem.
            // Mesh names in GLBs vary (".o.001" suffixes etc.), so we match
            // any node whose name SHARES the stem before the first dot.
            let lower = target.lowercased()
            let stem = lower.split(separator: ".").first.map(String.init) ?? lower

            var matchedNodes: [SCNNode] = []
            scene.rootNode.enumerateHierarchy { node, _ in
                guard node.geometry != nil || !node.childNodes.isEmpty else { return }
                guard let name = node.name?.lowercased() else { return }
                let nameStem = name.split(separator: ".").first.map(String.init) ?? name
                if name == lower || nameStem == stem {
                    matchedNodes.append(node)
                }
            }

            // Mark every "layer-*" node tree as hidden, then unhide ancestors
            // and self of every matched node so SceneKit still traverses them.
            scene.rootNode.enumerateHierarchy { node, _ in
                guard let nm = node.name else { return }
                if nm.hasPrefix("layer-") || node.geometry != nil {
                    node.isHidden = true
                }
            }
            var unhideSet: Set<ObjectIdentifier> = []
            for node in matchedNodes {
                var cursor: SCNNode? = node
                while let n = cursor {
                    unhideSet.insert(ObjectIdentifier(n))
                    n.isHidden = false
                    cursor = n.parent
                }
                node.enumerateChildNodes { child, _ in
                    child.isHidden = false
                    unhideSet.insert(ObjectIdentifier(child))
                }
            }

            // Frame camera around the union bbox of every matched node.
            guard let first = matchedNodes.first else { return }
            var (lo, hi) = first.boundingBox
            var minW = first.convertPosition(lo, to: scene.rootNode)
            var maxW = first.convertPosition(hi, to: scene.rootNode)
            for n in matchedNodes.dropFirst() {
                let (l, h) = n.boundingBox
                let wl = n.convertPosition(l, to: scene.rootNode)
                let wh = n.convertPosition(h, to: scene.rootNode)
                minW = SCNVector3(min(minW.x, wl.x, wh.x), min(minW.y, wl.y, wh.y), min(minW.z, wl.z, wh.z))
                maxW = SCNVector3(max(maxW.x, wl.x, wh.x), max(maxW.y, wl.y, wh.y), max(maxW.z, wl.z, wh.z))
            }
            let dx = maxW.x - minW.x, dy = maxW.y - minW.y, dz = maxW.z - minW.z
            let diag = sqrt(dx * dx + dy * dy + dz * dz)
            let safeDiag: Float = diag > 0.0001 ? diag : 0.5
            let cx = (minW.x + maxW.x) / 2
            let cy = (minW.y + maxW.y) / 2
            let cz = (minW.z + maxW.z) / 2
            let camPos = SCNVector3(cx, cy, cz + safeDiag * 2.4)
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.55
            SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            cam.position = camPos
            cam.look(at: SCNVector3(cx, cy, cz))
            SCNTransaction.commit()
            atlasLog.notice("[Atlas] focus → matched=\(matchedNodes.count) target=\(target, privacy: .public)")
        } else {
            // Restore: unhide everything not in user-driven hiddenMeshes,
            // then re-frame to the full active scene.
            scene.rootNode.enumerateHierarchy { node, _ in
                guard let name = node.name else { return }
                if hiddenMeshes.contains(name) {
                    node.isHidden = true
                } else if node.isHidden {
                    node.isHidden = false
                }
            }
            // Reuse reframe via initial camera framing.
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.45
            cam.position = coord.initialCameraPosition
            cam.look(at: coord.cameraTarget)
            SCNTransaction.commit()
            atlasLog.notice("[Atlas] focus cleared")
        }
    }

    private func applyAnglePreset(_ uiView: SCNView, coord: Coordinator) {
        guard let cam = uiView.pointOfView else { return }
        let target = coord.cameraTarget
        let initial = coord.initialCameraPosition
        let dx = initial.x - target.x, dy = initial.y - target.y, dz = initial.z - target.z
        let distance = sqrt(dx * dx + dy * dy + dz * dz)

        // Rotate the model itself for back/side views — keeps the rim+key+fill
        // lights doing their job and avoids the dark-back problem you'd get if
        // we just flipped the camera to a position with no light coverage.
        let modelYaw: Float
        let camPos: SCNVector3
        switch anglePreset {
        case .front:
            modelYaw = 0
            camPos = SCNVector3(target.x, target.y, target.z + distance)
        case .side:
            modelYaw = -.pi / 2
            camPos = SCNVector3(target.x, target.y, target.z + distance)
        case .back:
            modelYaw = .pi
            camPos = SCNVector3(target.x, target.y, target.z + distance)
        case .top:
            modelYaw = 0
            camPos = SCNVector3(target.x, target.y + distance, target.z + 0.001)
        }
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.5
        SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        cam.position = camPos
        cam.look(at: target)
        for node in coord.modelContainers {
            node.eulerAngles.y = modelYaw
        }
        SCNTransaction.commit()
    }

    final class Coordinator: NSObject {
        let onMeshTap: ([String]) -> Void
        var initialCameraPosition = SCNVector3Zero
        var cameraTarget = SCNVector3Zero
        var lastResetTrigger = 0
        var lastAngleTrigger = 0
        var lastBboxTrigger = 0
        var lastHiddenMeshes: Set<String> = []
        var lastTransparency: Double = 0
        var lastFocusedMeshId: String?
        var modelContainers: [SCNNode] = []
        private weak var lastSelected: SCNNode?
        private var lastSelectedOriginalMaterials: [SCNMaterial] = []

        init(onMeshTap: @escaping ([String]) -> Void) { self.onMeshTap = onMeshTap }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let view = gesture.view as? SCNView else { return }
            let point = gesture.location(in: view)
            let hits = view.hitTest(point, options: [
                SCNHitTestOption.boundingBoxOnly: false,
                SCNHitTestOption.ignoreHiddenNodes: true,
                SCNHitTestOption.searchMode: SCNHitTestSearchMode.closest.rawValue,
            ])
            guard let hit = hits.first else {
                clearHighlight()
                return
            }

            // GLTFKit2 stores names on the geometry, the leaf node, and the parent
            // chain — and which one carries the lookup key (e.g. "X.l") varies by
            // mesh. Collect ALL of them so the resolver can try the most specific
            // first. Order: geometry → self → climb to root.
            var candidates: [String] = []
            if let geomName = hit.node.geometry?.name, !geomName.isEmpty {
                candidates.append(geomName)
            }
            var cursor: SCNNode? = hit.node
            while let n = cursor {
                if let nm = n.name, !nm.isEmpty, nm != "AtlasCamera" {
                    candidates.append(nm)
                }
                cursor = n.parent
            }
            guard !candidates.isEmpty else {
                clearHighlight()
                return
            }

            // Tactile confirmation — feels like selecting a physical surface.
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            highlight(hit.node)
            onMeshTap(candidates)
        }

        private func highlight(_ node: SCNNode) {
            clearHighlight()
            guard let geom = node.geometry else { return }
            lastSelected = node
            lastSelectedOriginalMaterials = geom.materials
            let hl = SCNMaterial()
            hl.lightingModel = .physicallyBased
            hl.diffuse.contents = UIColor(red: 1.0, green: 0.78, blue: 0.32, alpha: 1.0)
            hl.emission.contents = UIColor(red: 0.55, green: 0.42, blue: 0.18, alpha: 1.0)
            hl.metalness.contents = 0.1
            hl.roughness.contents = 0.35
            geom.materials = [hl]
        }

        private func clearHighlight() {
            if let node = lastSelected, let geom = node.geometry, !lastSelectedOriginalMaterials.isEmpty {
                geom.materials = lastSelectedOriginalMaterials
            }
            lastSelected = nil
            lastSelectedOriginalMaterials = []
        }
    }
}
