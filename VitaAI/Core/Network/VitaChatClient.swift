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
                    guard let url = URL(string: AppConfig.apiBaseURL + "/ai/coach") else {
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

                    for try await line in bytes.lines {
                        guard line.hasPrefix("data:") else { continue }

                        let eventData = String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)

                        guard let rawData = eventData.data(using: .utf8),
                              let json = try? JSONSerialization.jsonObject(with: rawData) as? [String: Any],
                              let type = json["type"] as? String else {
                            continue
                        }

                        switch type {
                        case "text_delta":
                            if let content = json["content"] as? String {
                                continuation.yield(.textDelta(content))
                            }
                        case "tool_progress":
                            if let content = json["content"] as? String {
                                continuation.yield(.toolProgress(content))
                            }
                        case "message_stop":
                            let convId = json["conversationId"] as? String
                            continuation.yield(.messageStop(conversationId: convId))
                            continuation.finish()
                            return
                        case "error":
                            let content = json["content"] as? String ?? "Unknown error"
                            continuation.yield(.error(content))
                            continuation.finish()
                            return
                        default:
                            break
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
