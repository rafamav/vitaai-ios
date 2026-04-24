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

    @State private var scene: SCNScene?
    @State private var progress: Double = 0
    @State private var errorMessage: String?
    @State private var loadAttempt = 0
    @State private var lookup: [String: MeshInfo] = [:]
    @State private var selectedMesh: MeshInfo?
    @State private var resetTrigger = 0
    @State private var currentLayer: AtlasLayer = .arthrology
    @State private var cachedLayers: Set<AtlasLayer> = []
    @State private var hasTappedAnyMesh = false
    @State private var sceneMeshCount: Int = 0
    @State private var showSearch = false
    @State private var anglePreset: AtlasCameraAngle = .front
    @State private var angleTrigger = 0

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

                // First-time empty hint (only when scene is up + no mesh tapped yet)
                if scene != nil && !hasTappedAnyMesh {
                    VStack {
                        Spacer()
                        emptyHint
                            .padding(.bottom, 24)
                    }
                    .allowsHitTesting(false)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationBarHidden(true)
        // Immersive: hide VitaTopBar and tab bar so the 3D viewport owns the screen
        // (same pattern as PdfViewerScreen). Only our own toolbar + rails remain.
        .preference(key: ImmersivePreferenceKey.self, value: true)
        .task(id: "\(loadAttempt)-\(currentLayer.rawValue)") { await loadLayer() }
        .task { await loadLookupIfNeeded() }
        .onAppear { refreshCachedLayers() }
        .sheet(isPresented: $showSearch) {
            AtlasSearchSheet(
                lookup: lookup,
                currentLayer: currentLayer,
                onPick: { info in
                    showSearch = false
                    selectedMesh = info
                    hasTappedAnyMesh = true
                    VitaPostHogConfig.capture(event: "atlas_search_picked", properties: [
                        "layer": currentLayer.rawValue,
                        "structure": info.pt,
                    ])
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationBackground(.ultraThinMaterial)
        }
        .sheet(item: $selectedMesh) { info in
            MeshDetailSheet(
                info: info,
                onAskVita: {
                    VitaPostHogConfig.capture(event: "atlas_ask_vita", properties: [
                        "layer": currentLayer.rawValue,
                        "structure": info.pt,
                        "system": info.system,
                    ])
                    selectedMesh = nil
                    // Forward a richer prompt: name + system + EN fallback so the
                    // chat LLM can disambiguate (helpful for laterality and rare
                    // structures missing from anatomy-mesh-lookup.json).
                    let prompt = buildAskVitaPrompt(info)
                    onAskVita?(prompt)
                },
                onClose: { selectedMesh = nil }
            )
            .presentationDetents([.fraction(0.35), .medium])
            .presentationDragIndicator(.visible)
            .presentationBackground(.ultraThinMaterial)
        }
        .trackScreen("Atlas3D")
    }

    private func handleMeshTap(_ meshName: String) {
        let resolved = resolveMeshLookup(meshName)
        selectedMesh = resolved.info
        hasTappedAnyMesh = true
        VitaPostHogConfig.capture(event: "atlas_mesh_tapped", properties: [
            "layer": currentLayer.rawValue,
            "mesh_name": meshName,
            "has_lookup": resolved.hit,
            "lateralidade": resolved.lateralidade ?? "none",
            "pt_name": resolved.info.pt,
        ])
    }

    /// Mesh names from GLBs come polluted: `Radial artery_l`, `Femur.j.002`,
    /// `Carpal bones_03`. Strip those suffixes — first try the original key,
    /// then progressively cleaner variants — so we land on the lookup entry.
    /// Track the lateralidade so the sheet can append "(esquerda)/(direita)".
    private func resolveMeshLookup(_ meshName: String) -> (info: MeshInfo, hit: Bool, lateralidade: String?) {
        var lateralidade: String?

        // 1) Direct hit (rare but possible if the GLB matches the lookup key exactly)
        if let direct = lookup[meshName] {
            return (direct, true, nil)
        }

        // 2) Strip GLTFKit2 instance suffixes (.j.NNN, _NNN)
        var candidate = meshName
            .replacingOccurrences(of: #"\.j\.\d+$"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"_\d+$"#, with: "", options: .regularExpression)
        if let hit = lookup[candidate] { return (hit, true, nil) }

        // 3) Strip side markers (_l, _r, _left, _right, _sup, _inf, _med, _lat)
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
        for (pattern, label) in sideMatchers {
            if let range = candidate.range(of: pattern, options: [.regularExpression, .caseInsensitive]) {
                candidate.removeSubrange(range)
                lateralidade = label
                break
            }
        }
        if let hit = lookup[candidate] {
            let suffixed = lateralidade.map { "\(hit.pt) (\($0))" } ?? hit.pt
            let enrich = MeshInfo(
                id: hit.id,
                pt: suffixed,
                en: hit.en,
                system: hit.system,
                exam: hit.exam,
                description: hit.description,
                tip: hit.tip,
                curiosity: hit.curiosity
            )
            return (enrich, true, lateralidade)
        }

        // 4) Try title-cased variant (lookup keys are usually capitalized)
        let titleCased = candidate.split(separator: " ").enumerated().map { idx, word -> String in
            idx == 0 ? word.prefix(1).uppercased() + word.dropFirst() : String(word)
        }.joined(separator: " ")
        if let hit = lookup[titleCased] { return (hit, true, lateralidade) }

        // 5) Fallback: surface a clean label, no fake exam priority
        atlasLog.notice("[Atlas] tap mesh '\(meshName, privacy: .public)' → '\(candidate, privacy: .public)' no lookup hit")
        let fallback = MeshInfo(
            id: candidate,
            pt: prettify(candidate, lateralidade: lateralidade),
            en: candidate,
            system: currentLayer.rawValue,
            exam: "",   // empty = chip hidden
            description: nil,
            tip: nil,
            curiosity: nil
        )
        return (fallback, false, lateralidade)
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
        let active = (currentLayer == layer)
        let cached = cachedLayers.contains(layer)
        Button {
            guard !active else { return }
            UISelectionFeedbackGenerator().selectionChanged()
            VitaPostHogConfig.capture(event: "atlas_layer_selected", properties: [
                "from": currentLayer.rawValue,
                "to": layer.rawValue,
                "from_cached": cachedLayers.contains(currentLayer),
                "to_cached": cached,
            ])
            scene = nil
            progress = 0
            errorMessage = nil
            selectedMesh = nil
            currentLayer = layer
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
                    Image(systemName: layer.icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(active ? VitaColors.accent : VitaColors.textSecondary)
                    // Cache dot: bottom-right of the icon circle
                    if cached {
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
        .accessibilityHint(cached ? "Baixado, troca instantânea" : "Vai baixar ao selecionar")
        .accessibilityAddTraits(active ? [.isSelected] : [])
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
                        .transition(.opacity)
                }
            }

            Spacer()

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
                     ? "Baixando \(currentLayer.displayName) — \(Int(progress * 100))%"
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
            await MainActor.run { self.lookup = out }
            atlasLog.notice("[Atlas] lookup loaded: \(out.count) entries")
        } catch {
            atlasLog.error("[Atlas] lookup load failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Load pipeline

    private func loadLayer() async {
        let layerName = currentLayer.rawValue
        let layer = currentLayer
        do {
            let url = try await fetchOrCacheGLB(layer: layerName)
            let built = try await buildScene(from: url)
            await MainActor.run {
                self.scene = built
                self.cachedLayers.insert(layer)
                SentrySDK.reportFullyDisplayed()
            }
        } catch {
            atlasLog.error("[Atlas] load failed: \(error.localizedDescription, privacy: .public)")
            VitaPostHogConfig.capture(event: "atlas_load_failed", properties: [
                "layer": layerName,
                "error": "\(error)",
            ])
            await MainActor.run { self.errorMessage = error.localizedDescription }
        }
    }

    /// Subtitle shown under "Atlas 3D" — current system + structure count.
    private var headerSubtitle: String? {
        let system = currentLayer.displayName
        if scene != nil, sceneMeshCount > 0 {
            return "\(system) · \(sceneMeshCount) estruturas"
        }
        return system
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

    private func buildScene(from url: URL) async throws -> SCNScene {
        atlasLog.notice("[Atlas] buildScene start, url=\(url.path, privacy: .public)")
        let bytes = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0
        atlasLog.notice("[Atlas] glb file size: \(bytes) bytes")

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<SCNScene, Error>) in
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
                    Task { @MainActor in self.sceneMeshCount = meshCount }
                    atlasLog.notice("[Atlas] asset complete: scenes=\(asset.scenes.count) meshes=\(meshCount) materials=\(asset.materials.count)")

                    let source = GLTFSCNSceneSource(asset: asset)
                    guard let scene = source.defaultScene else {
                        atlasLog.error("[Atlas] GLTFSCNSceneSource.defaultScene is nil")
                        continuation.resume(throwing: AtlasError.noScene)
                        return
                    }
                    atlasLog.notice("[Atlas] scene built: rootChildren=\(scene.rootNode.childNodes.count)")

                    // 3-point studio-style rig — makes anatomical structures
                    // read cleanly against the dark starry background.
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

                    continuation.resume(returning: scene)
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

    var icon: String {
        switch self {
        case .arthrology:    return "figure.stand"
        case .myology:       return "figure.strengthtraining.traditional"
        case .neurology:     return "brain.head.profile"
        case .angiology:     return "heart.fill"
        case .splanchnology: return "lungs.fill"
        case .lymphoid:      return "drop.fill"
        case .joints:        return "link"
        }
    }
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

private struct MeshDetailSheet: View {
    let info: MeshInfo
    let onAskVita: () -> Void
    let onClose: () -> Void

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

                // Only show system chip — the per-mesh exam priority field is
                // unreliable in the legacy lookup, so we'd rather show nothing
                // than mislead a student about whether radial artery cai em prova.
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

                // When we have no rich content, nudge the user toward VITA — the
                // LLM already covers anatomy, exam frequency and clinical relevance.
                if (info.description ?? "").isEmpty
                    && (info.tip ?? "").isEmpty
                    && (info.curiosity ?? "").isEmpty {
                    Text("Toque abaixo pra VITA explicar essa estrutura, sua função, relação clínica e frequência em provas.")
                        .font(.system(size: 13))
                        .foregroundStyle(VitaColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Button(action: onAskVita) {
                    HStack(spacing: 10) {
                        Image(systemName: "bubble.left.and.bubble.right.fill")
                        Text("Perguntar pra VITA sobre \(info.pt)")
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(VitaColors.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(VitaColors.accent.opacity(0.15))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(VitaColors.accent.opacity(0.4), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(20)
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
    let currentLayer: AtlasLayer
    let onPick: (MeshInfo) -> Void

    @State private var query: String = ""
    @FocusState private var focused: Bool

    private var filtered: [MeshInfo] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard q.count >= 2 else { return [] }
        // Score: starts-with > contains; current-system entries float to top.
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
            if info.system == currentLayer.rawValue { score += 50 }
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
    let onMeshTap: (String) -> Void

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

        // Frame the whole scene (union of all geometry), not just first child.
        let (minV, maxV) = scene.rootNode.boundingBox
        let dx = maxV.x - minV.x, dy = maxV.y - minV.y, dz = maxV.z - minV.z
        let diagonal = sqrt(dx * dx + dy * dy + dz * dz)
        atlasLog.notice("[Atlas] scene bbox min=(\(minV.x),\(minV.y),\(minV.z)) max=(\(maxV.x),\(maxV.y),\(maxV.z)) diag=\(diagonal)")

        let camera = SCNCamera()
        camera.zNear = 0.01
        let safeDiag: Float = diagonal > 0.0001 ? diagonal : 2.0
        camera.zFar = Double(safeDiag) * 20
        let camNode = SCNNode()
        camNode.name = "AtlasCamera"
        camNode.camera = camera
        let cx = (minV.x + maxV.x) / 2
        let cy = (minV.y + maxV.y) / 2
        let cz = (minV.z + maxV.z) / 2
        let initialPosition = SCNVector3(cx, cy, cz + safeDiag * 1.6)
        camNode.position = initialPosition
        camNode.look(at: SCNVector3(cx, cy, cz))
        scene.rootNode.addChildNode(camNode)
        view.pointOfView = camNode

        // Remember framing so the "recenter" button can restore it.
        context.coordinator.initialCameraPosition = initialPosition
        context.coordinator.cameraTarget = SCNVector3(cx, cy, cz)

        // Find the GLB's root model node (skip the lights we just added so
        // rotation only spins the anatomy, not the lighting rig).
        if let modelRoot = scene.rootNode.childNodes.first(where: { node in
            node.light == nil && node.camera == nil
        }) {
            context.coordinator.modelContainer = modelRoot
        }

        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)

        return view
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
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
        coord.modelContainer?.eulerAngles.y = modelYaw
        SCNTransaction.commit()
    }

    final class Coordinator: NSObject {
        let onMeshTap: (String) -> Void
        var initialCameraPosition = SCNVector3Zero
        var cameraTarget = SCNVector3Zero
        var lastResetTrigger = 0
        var lastAngleTrigger = 0
        weak var modelContainer: SCNNode?
        private weak var lastSelected: SCNNode?
        private var lastSelectedOriginalMaterials: [SCNMaterial] = []

        init(onMeshTap: @escaping (String) -> Void) { self.onMeshTap = onMeshTap }

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
            // Climb to the first named ancestor (GLTFKit2 often leaves mesh names on parents).
            var node: SCNNode? = hit.node
            var name: String?
            while let n = node {
                if let nm = n.name, !nm.isEmpty, nm != "AtlasCamera" {
                    name = nm
                    break
                }
                node = n.parent
            }
            guard let picked = node, let pickedName = name else { return }

            // Tactile confirmation — feels like selecting a physical surface.
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            highlight(picked)
            onMeshTap(pickedName)
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
