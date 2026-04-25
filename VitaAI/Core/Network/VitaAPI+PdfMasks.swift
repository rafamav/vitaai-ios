import Foundation
import CoreGraphics

// MARK: - VitaAPI+PdfMasks
//
// Endpoint pra tracking cross-device de tentativas no Study Mode do PDF Viewer.
// UserDefaults continua sendo fonte primária local (offline-first); este endpoint
// apenas adiciona persistência server-side. Falhas são silenciosas.
//
// Backend: vita-web — POST /api/pdf/masks/attempt (route.ts).
// Tabela: vita.pdf_mask_attempts (migration 0072).

extension VitaAPI {
    struct MaskAttemptRequest: Encodable {
        let documentId: String
        let maskId: String
        let pageIndex: Int
        let bbox: BoundingBox
        let correct: Bool

        struct BoundingBox: Encodable {
            let x: Double
            let y: Double
            let width: Double
            let height: Double
        }
    }

    struct MaskAttemptResponse: Decodable {
        let ok: Bool
        let row: MaskAttemptRow?
    }

    struct MaskAttemptRow: Decodable {
        let id: String?
        let attempts: Int?
        let correct: Int?
        let lastAttemptAt: String?
    }

    /// Registra uma tentativa no backend. Fire-and-forget — caller não deve
    /// aguardar nem mostrar erro pro user (UserDefaults é fonte primária).
    @discardableResult
    func recordMaskAttempt(
        documentId: String,
        maskId: String,
        pageIndex: Int,
        bbox: CGRect,
        correct: Bool
    ) async throws -> MaskAttemptResponse {
        let body = MaskAttemptRequest(
            documentId: documentId,
            maskId: maskId,
            pageIndex: pageIndex,
            bbox: .init(
                x: Double(bbox.origin.x),
                y: Double(bbox.origin.y),
                width: Double(bbox.size.width),
                height: Double(bbox.size.height)
            ),
            correct: correct
        )
        return try await client.post("pdf/masks/attempt", body: body)
    }
}
