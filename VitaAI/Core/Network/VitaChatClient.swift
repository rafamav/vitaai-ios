import Foundation

actor VitaChatClient {
    private let tokenStore: TokenStore
    private let session: URLSession
    private let tokenRefresher: TokenRefresher
    private var onUnauthorized: (@Sendable @MainActor () -> Void)?

    private static let maxRetries = 3

    init(tokenStore: TokenStore, tokenRefresher: TokenRefresher? = nil, session: URLSession? = nil) {
        self.tokenStore = tokenStore
        if let session {
            self.session = session
        } else {
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 30
            config.timeoutIntervalForResource = 300
            self.session = URLSession(configuration: config)
        }
        self.tokenRefresher = tokenRefresher ?? TokenRefresher(tokenStore: tokenStore)
    }

    func setOnUnauthorized(_ handler: @escaping @Sendable @MainActor () -> Void) {
        self.onUnauthorized = handler
    }

    func streamChat(
        message: String,
        conversationId: String?,
        voiceMode: Bool = false,
        imageBase64: String? = nil,
        imageType: String? = nil
    ) -> AsyncThrowingStream<SSEEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    guard let url = URL(string: AppConfig.apiBaseURL + "/ai/coach") else {
                        continuation.finish(throwing: APIError.invalidURL)
                        return
                    }

                    var requestDict: [String: Any] = [
                        "message": message,
                        "voiceMode": voiceMode
                    ]
                    if let conversationId {
                        requestDict["conversationId"] = conversationId
                    }
                    if let imageBase64, let imageType {
                        requestDict["image"] = imageBase64
                        requestDict["imageType"] = imageType
                    }
                    let encodedBody = try JSONSerialization.data(withJSONObject: requestDict)

                    var didAttemptRefresh = false
                    var lastError: Error = APIError.unknown

                    for attempt in 0..<Self.maxRetries {
                        if attempt > 0 {
                            let delay = UInt64(pow(2.0, Double(attempt - 1)) * 1_000_000_000)
                            try await Task.sleep(nanoseconds: delay)
                        }

                        var request = URLRequest(url: url)
                        request.httpMethod = "POST"
                        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
                        request.httpBody = encodedBody

                        if let token = await self.tokenStore.token {
                            request.setValue("\(AppConfig.sessionCookieName)=\(token)", forHTTPHeaderField: "Cookie")
                        } else {
                            NSLog("[VitaChatClient] WARNING: No token available")
                        }

                        let bytes: URLSession.AsyncBytes
                        let response: URLResponse
                        do {
                            (bytes, response) = try await self.session.bytes(for: request)
                        } catch {
                            NSLog("[VitaChatClient] Network error: %@", "\(error)")
                            lastError = APIError.networkError(error)
                            continue
                        }

                        guard let httpResponse = response as? HTTPURLResponse else {
                            lastError = APIError.unknown
                            continue
                        }

                        NSLog("[VitaChatClient] HTTP %d", httpResponse.statusCode)

                        if httpResponse.statusCode == 401 {
                            if !didAttemptRefresh {
                                didAttemptRefresh = true
                                if await self.tokenRefresher.refreshSession() {
                                    continue
                                }
                            }
                            if let handler = self.onUnauthorized { await handler() }
                            continuation.finish(throwing: APIError.unauthorized)
                            return
                        }

                        guard (200...299).contains(httpResponse.statusCode) else {
                            if httpResponse.statusCode == 403 {
                                NSLog("[VitaChatClient] 403 Forbidden — user may lack Pro subscription")
                                continuation.finish(throwing: APIError.forbidden)
                                return
                            }
                            if (500...599).contains(httpResponse.statusCode) {
                                lastError = APIError.serverError(httpResponse.statusCode)
                                continue
                            }
                            continuation.finish(throwing: APIError.serverError(httpResponse.statusCode))
                            return
                        }

                        // Connected — stream events (no retry mid-stream)
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
                        return
                    }

                    // All retries exhausted
                    continuation.finish(throwing: lastError)
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}
