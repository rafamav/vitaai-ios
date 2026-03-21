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

                    // Backend sends: data: {"type":"text_delta","content":"..."}\n\n
                    // No separate event: line — type is embedded in JSON payload.
                    // Accumulate data: lines, process on blank line (SSE spec).
                    var dataBuffer = ""

                    for try await line in bytes.lines {
                        if line.hasPrefix("data:") {
                            dataBuffer += String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                        } else if line.trimmingCharacters(in: .whitespaces).isEmpty, !dataBuffer.isEmpty {
                            if let event = Self.parseSSEData(dataBuffer) {
                                continuation.yield(event)
                                if case .messageStop = event {
                                    continuation.finish()
                                    return
                                }
                                if case .error = event {
                                    continuation.finish()
                                    return
                                }
                            }
                            dataBuffer = ""
                        }
                    }

                    // Handle remaining buffered data (stream closed without trailing blank line)
                    if !dataBuffer.isEmpty {
                        if let event = Self.parseSSEData(dataBuffer) {
                            continuation.yield(event)
                        }
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    /// Parse a JSON SSE data payload from the backend.
    /// Backend format: {"type":"text_delta","content":"..."}
    private static func parseSSEData(_ data: String) -> SSEEvent? {
        guard let jsonData = data.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let type = json["type"] as? String else {
            return nil
        }

        switch type {
        case "text_delta":
            let content = json["content"] as? String ?? ""
            return .textDelta(content)
        case "message_stop":
            let convId = json["conversationId"] as? String
            return .messageStop(conversationId: convId)
        case "error":
            let content = json["content"] as? String ?? "Unknown error"
            return .error(content)
        case "tool_use", "tool_result":
            // Tool events are informational — not surfaced to UI yet
            return nil
        default:
            return nil
        }
    }
}
