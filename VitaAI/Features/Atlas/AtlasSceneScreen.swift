import SwiftUI
import SceneKit
import GLTFKit2
import Sentry
import OSLog

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

    var body: some View {
        // No opaque base — the AppRouter's VitaAmbientBackground shows through.
        VStack(spacing: 0) {
            topBar
            layerBar

            ZStack {
                if let scene {
                    AnatomySceneView(
                        scene: scene,
                        resetTrigger: resetTrigger,
                        onMeshTap: { meshName in handleMeshTap(meshName) }
                    )
                    .transition(.opacity)
                } else if let errorMessage {
                    errorView(errorMessage)
                } else {
                    loadingView
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationBarHidden(true)
        .task(id: "\(loadAttempt)-\(currentLayer.rawValue)") { await loadLayer() }
        .task { await loadLookupIfNeeded() }
        .sheet(item: $selectedMesh) { info in
            MeshDetailSheet(
                info: info,
                onAskVita: {
                    selectedMesh = nil
                    onAskVita?(info.pt)
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
        // Try exact match, then strip GLTFKit2's ".j.N" suffix, then try the
        // parent node's name (many arthrology meshes are grouped).
        if let info = lookup[meshName] {
            selectedMesh = info
            return
        }
        let stripped = meshName.replacingOccurrences(of: #"\.j\.\d+$"#, with: "", options: .regularExpression)
        if let info = lookup[stripped] {
            selectedMesh = info
            return
        }
        atlasLog.notice("[Atlas] tap mesh '\(meshName, privacy: .public)' no lookup hit")
    }

    // MARK: - Layer bar (system switcher)

    private var layerBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(AtlasLayer.allCases) { layer in
                    Button {
                        guard layer != currentLayer else { return }
                        scene = nil
                        progress = 0
                        errorMessage = nil
                        currentLayer = layer
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: layer.icon)
                                .font(.system(size: 11, weight: .semibold))
                            Text(layer.displayName)
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundStyle(currentLayer == layer ? VitaColors.accent : VitaColors.textSecondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(
                            Capsule()
                                .fill(currentLayer == layer
                                      ? VitaColors.accent.opacity(0.15)
                                      : Color.white.opacity(0.04))
                        )
                        .overlay(
                            Capsule()
                                .stroke(currentLayer == layer
                                        ? VitaColors.accent.opacity(0.4)
                                        : Color.white.opacity(0.06),
                                        lineWidth: 0.8)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .background(.ultraThinMaterial.opacity(0.65))
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

            Text("Atlas 3D")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(VitaColors.textPrimary)

            Spacer()

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

            Button {
                scene = nil
                errorMessage = nil
                progress = 0
                loadAttempt += 1
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(VitaColors.textSecondary)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(.ultraThinMaterial))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Recarregar modelo")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial.opacity(0.9))
    }

    // MARK: - Loading & error

    private var loadingView: some View {
        VStack(spacing: 14) {
            ProgressView(value: progress)
                .progressViewStyle(.linear)
                .tint(VitaColors.accent)
                .frame(width: 180)
            Text(progress > 0 ? "Baixando modelo — \(Int(progress * 100))%" : "Carregando Atlas 3D…")
                .font(.system(size: 13))
                .foregroundStyle(VitaColors.textSecondary)
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
        do {
            let url = try await fetchOrCacheGLB(layer: layerName)
            let built = try await buildScene(from: url)
            await MainActor.run {
                self.scene = built
                SentrySDK.reportFullyDisplayed()
            }
        } catch {
            atlasLog.error("[Atlas] load failed: \(error.localizedDescription, privacy: .public)")
            await MainActor.run { self.errorMessage = error.localizedDescription }
        }
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
                    atlasLog.notice("[Atlas] asset complete: scenes=\(asset.scenes.count) meshes=\(asset.meshes.count) materials=\(asset.materials.count)")

                    let source = GLTFSCNSceneSource(asset: asset)
                    guard let scene = source.defaultScene else {
                        atlasLog.error("[Atlas] GLTFSCNSceneSource.defaultScene is nil")
                        continuation.resume(throwing: AtlasError.noScene)
                        return
                    }
                    atlasLog.notice("[Atlas] scene built: rootChildren=\(scene.rootNode.childNodes.count)")

                    // Ambient + directional so the mesh isn't flat black.
                    let ambient = SCNNode()
                    ambient.light = SCNLight()
                    ambient.light?.type = .ambient
                    ambient.light?.intensity = 550
                    scene.rootNode.addChildNode(ambient)

                    let key = SCNNode()
                    key.light = SCNLight()
                    key.light?.type = .directional
                    key.light?.intensity = 900
                    key.position = SCNVector3(5, 5, 5)
                    key.eulerAngles = SCNVector3(-Float.pi / 4, Float.pi / 4, 0)
                    scene.rootNode.addChildNode(key)

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

                HStack(spacing: 8) {
                    if !info.system.isEmpty {
                        Chip(label: systemLabel(info.system), color: VitaColors.accent.opacity(0.18))
                    }
                    Chip(label: "Prova: \(examLabel(info.exam))", color: examColor(info.exam).opacity(0.18))
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

    private func examLabel(_ exam: String) -> String {
        switch exam {
        case "high": return "alta"
        case "med", "medium": return "média"
        case "low": return "baixa"
        default: return exam
        }
    }

    private func examColor(_ exam: String) -> Color {
        switch exam {
        case "high": return VitaColors.dataRed
        case "med", "medium": return VitaColors.dataAmber
        default: return VitaColors.dataGreen
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
    }

    final class Coordinator: NSObject {
        let onMeshTap: (String) -> Void
        var initialCameraPosition = SCNVector3Zero
        var cameraTarget = SCNVector3Zero
        var lastResetTrigger = 0
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
