import Foundation

enum SSEEvent {
    case textDelta(String)
    case toolProgress(String)
    case messageStop(conversationId: String?)
    case error(String)
}
