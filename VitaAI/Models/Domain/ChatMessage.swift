import Foundation
import SwiftUI

struct ChatMessage: Identifiable, Codable {
    let id: String
    let role: String // "user" or "assistant"
    var content: String
    var timestamp: Date = Date()
    var feedback: Int = 0 // 0=none, 1=up, -1=down
    var isError: Bool = false

    // Image attachment (local only — not persisted via Codable)
    var imageData: Data?
    var imageMimeType: String?

    enum CodingKeys: String, CodingKey {
        case id, role, content, timestamp, feedback, isError
    }

    var hasImage: Bool { imageData != nil }

    var uiImage: Image? {
        guard let data = imageData,
              let ui = UIImage(data: data) else { return nil }
        return Image(uiImage: ui)
    }
}
