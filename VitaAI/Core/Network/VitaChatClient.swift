import Foundation

actor VitaChatClient {
    private let tokenStore: TokenStore

    init(tokenStore: TokenStore) {
        self.tokenStore = tokenStore
    }

    func streamChat(message: String, conversationId: String?, voiceMode: Bool = false) -> AsyncThrowingStream<SSEEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    guard let url = URL(string: AppConfig.apiBaseURL + "/ai/chat") else {
                        continuation.finish(throwing: APIError.invalidURL)
                        return
                    }

                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.setValue("text/event-stream", forHTTPHeaderField: "Accept")

                    if let token = await tokenStore.token {
                        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                    }

                    let body = ChatRequest(message: message, conversationId: conversationId, voiceMode: voiceMode ? true : nil)
                    request.httpBody = try JSONEncoder().encode(body)

                    let (bytes, response) = try await URLSession.shared.bytes(for: request)

                    guard let httpResponse = response as? HTTPURLResponse,
                          (200...299).contains(httpResponse.statusCode) else {
                        continuation.finish(throwing: APIError.serverError((response as? HTTPURLResponse)?.statusCode ?? 0))
                        return
                    }

                    var eventType = ""
                    var eventData = ""

                    for try await line in bytes.lines {
                        if line.hasPrefix("event:") {
                            eventType = String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces)
                        } else if line.hasPrefix("data:") {
                            eventData = String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)

                            switch eventType {
                            case "text_delta":
                                if let data = eventData.data(using: .utf8),
                                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                                   let text = json["text"] as? String {
                                    continuation.yield(.textDelta(text))
                                }
                            case "message_stop":
                                let convId = (try? JSONSerialization.jsonObject(with: eventData.data(using: .utf8) ?? Data()) as? [String: Any])?["conversationId"] as? String
                                continuation.yield(.messageStop(conversationId: convId))
                                continuation.finish()
                                return
                            case "error":
                                continuation.yield(.error(eventData))
                                continuation.finish()
                                return
                            default:
                                break
                            }

                            eventType = ""
                            eventData = ""
                        }
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}
