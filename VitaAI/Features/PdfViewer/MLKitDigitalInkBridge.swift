import Foundation
import PencilKit
import OSLog

// MARK: - MLKitDigitalInkBridge
//
// Wrapper async/await ao redor do Google ML Kit Digital Ink Recognition.
// Substitui Apple VNRecognizeTextRequest (que era pra texto IMPRESSO em
// imagens, não handwriting digital cru).
//
// Modelos disponíveis (each ~5MB, on-device, lazy-downloaded):
//   - "pt-BR" → handwriting → texto digitado em português brasileiro
//   - "en-US" → handwriting inglês (fallback)
//   - "zxx-Zsym-x-shapes" → desenhos → shape identificado (circle, square,
//     triangle, arrow, etc) — alternativa/complemento ao $1 Recognizer
//
// Refs:
//   - https://developers.google.com/ml-kit/vision/digital-ink-recognition/ios
//   - https://developers.google.com/ml-kit/vision/digital-ink-recognition/base-models
//
// Rafael 2026-04-29: substitui Vision framework (que comia o texto sem
// converter) pra parar o sangramento. PT-BR é o foco — Rafael estuda em
// português.
//
// SIMULATOR STUB (2026-04-29 SWIFT): MLKit binary fat (MLKitCommon 7.0.0)
// só veio com slice arm64-iOS-device, não arm64-iOS-simulator. iOS 26.4 sim
// é arm64-only (sem Rosetta x86_64). Resultado: link error em sim arm64.
// Solução: gate o import e a impl real atrás de `#if !targetEnvironment(simulator)`.
// No sim, retorna nil (caller de PdfViewerViewModel já trata nil graciosamente).
// Em device real (arm64-ios), funciona normal.

#if !targetEnvironment(simulator)
import MLKitDigitalInkRecognition
#endif

enum MLKitDigitalInkBridge {

    private static let logger = Logger(subsystem: "com.bymav.vitaai", category: "mlkit-digital-ink")

    /// Modelos disponíveis. Cada um precisa download (lazy) de ~5MB on first use.
    enum Model: String {
        case textPtBR = "pt-BR"
        case textEnUS = "en-US"
        case shapes = "zxx-Zsym-x-shapes"
    }

    /// Resultado do reconhecimento.
    struct RecognitionResult {
        let text: String
        let score: Float
    }

    /// Reconhece handwriting. Retorna o texto candidato top + score 0..1, ou
    /// nil se falhou / score baixo.
    ///
    /// strokes: array de PKStroke do PencilKit. Cada PKStrokePoint vira
    /// MLKit StrokePoint (x, y, timestamp ms).
    static func recognize(
        strokes: [PKStroke],
        model: Model,
        minScore: Float = 0.5
    ) async -> RecognitionResult? {

        guard !strokes.isEmpty else { return nil }

#if targetEnvironment(simulator)
        // Simulator stub — MLKit não suporta arm64-ios-simulator (vide nota
        // no topo do arquivo). Loga e retorna nil; auto-convert no PDF viewer
        // simplesmente não roda no sim. Em device real, fluxo completo abaixo.
        logger.notice("[mlkit] simulator stub — recognize() retorna nil (model=\(model.rawValue, privacy: .public))")
        trackToolFailure(tool: "mlkit", stage: "recognize", reason: "simulator_stub", extraProps: ["model": model.rawValue])
        return nil
#else
        // 1. Garantir que o model está baixado
        guard let identifier = DigitalInkRecognitionModelIdentifier(forLanguageTag: model.rawValue) else {
            logger.error("[mlkit] model identifier inválido pra \(model.rawValue, privacy: .public)")
            trackToolFailure(tool: "mlkit", stage: "model_identifier", reason: "invalid_language_tag", extraProps: ["model": model.rawValue])
            return nil
        }
        let inkModel = DigitalInkRecognitionModel(modelIdentifier: identifier)
        let manager = ModelManager.modelManager()

        if !manager.isModelDownloaded(inkModel) {
            logger.notice("[mlkit] baixando model \(model.rawValue, privacy: .public) (~5MB)")
            let conditions = ModelDownloadConditions(allowsCellularAccess: true,
                                                     allowsBackgroundDownloading: true)
            // Download bloqueia até completar via Notification
            do {
                try await waitForDownload(model: inkModel, conditions: conditions, manager: manager)
            } catch {
                logger.error("[mlkit] download falhou: \(error.localizedDescription, privacy: .public)")
                trackToolFailure(tool: "mlkit", stage: "model_download", reason: "download_failed", extraProps: ["model": model.rawValue, "error": error.localizedDescription])
                return nil
            }
        }

        // 2. Construir Ink a partir dos PKStrokes
        let mlStrokes = strokes.compactMap { pkStroke -> Stroke? in
            var points: [StrokePoint] = []
            let path = pkStroke.path
            for idx in path.indices {
                let p = path[idx]
                points.append(StrokePoint(
                    x: Float(p.location.x),
                    y: Float(p.location.y),
                    t: Int(p.timeOffset * 1000) // segundos → ms
                ))
            }
            guard !points.isEmpty else { return nil }
            return Stroke(points: points)
        }
        guard !mlStrokes.isEmpty else { return nil }

        let ink = Ink(strokes: mlStrokes)

        // 3. Recognizer
        let options = DigitalInkRecognizerOptions(model: inkModel)
        let recognizer = DigitalInkRecognizer.digitalInkRecognizer(options: options)

        return await withCheckedContinuation { continuation in
            recognizer.recognize(ink: ink) { result, error in
                if let error {
                    Self.logger.error("[mlkit] recognize erro: \(error.localizedDescription, privacy: .public)")
                    trackToolFailure(tool: "mlkit", stage: "recognize_callback", reason: "sdk_error", extraProps: ["model": model.rawValue, "error": error.localizedDescription])
                    continuation.resume(returning: nil)
                    return
                }
                guard let result, !result.candidates.isEmpty else {
                    trackToolFailure(tool: "mlkit", stage: "recognize_result", reason: "no_candidates", extraProps: ["model": model.rawValue])
                    continuation.resume(returning: nil)
                    return
                }
                let top = result.candidates[0]
                // ML Kit Digital Ink retorna score como NSNumber? — inverso de
                // distance (lower = better). Convertemos pra similaridade 0..1.
                let scoreFloat: Float = top.score?.floatValue ?? 0.0
                Self.logger.notice("[mlkit] top='\(top.text, privacy: .public)' score=\(scoreFloat) candidates=\(result.candidates.count)")
                continuation.resume(returning: RecognitionResult(text: top.text, score: scoreFloat))
            }
        }
#endif
    }

#if !targetEnvironment(simulator)
    // MARK: - Helpers (device-only)

    private static func waitForDownload(
        model: DigitalInkRecognitionModel,
        conditions: ModelDownloadConditions,
        manager: ModelManager
    ) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            var resumed = false
            let lock = NSLock()
            let resume: (Result<Void, Error>) -> Void = { result in
                lock.lock(); defer { lock.unlock() }
                guard !resumed else { return }
                resumed = true
                switch result {
                case .success: continuation.resume(returning: ())
                case .failure(let e): continuation.resume(throwing: e)
                }
            }

            // Observers
            let didFinish = NotificationCenter.default.addObserver(
                forName: .mlkitModelDownloadDidSucceed,
                object: nil,
                queue: nil
            ) { note in
                if let m = note.userInfo?[ModelDownloadUserInfoKey.remoteModel.rawValue] as? DigitalInkRecognitionModel,
                   m.modelIdentifier.languageTag == model.modelIdentifier.languageTag {
                    resume(.success(()))
                }
            }
            let didFail = NotificationCenter.default.addObserver(
                forName: .mlkitModelDownloadDidFail,
                object: nil,
                queue: nil
            ) { note in
                if let m = note.userInfo?[ModelDownloadUserInfoKey.remoteModel.rawValue] as? DigitalInkRecognitionModel,
                   m.modelIdentifier.languageTag == model.modelIdentifier.languageTag {
                    let err = (note.userInfo?[ModelDownloadUserInfoKey.error.rawValue] as? Error)
                        ?? NSError(domain: "MLKit", code: -1, userInfo: nil)
                    resume(.failure(err))
                }
            }

            manager.download(model, conditions: conditions)

            // Cleanup notifications após resumo (best effort)
            Task {
                try? await Task.sleep(for: .seconds(120))
                NotificationCenter.default.removeObserver(didFinish)
                NotificationCenter.default.removeObserver(didFail)
            }
        }
    }
#endif
}
