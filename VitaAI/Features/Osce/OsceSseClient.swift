import Foundation

// MARK: - OsceSseClient
// Streams OSCE evaluations from the backend using Server-Sent Events.
// Mirrors VitaChatClient pattern.

actor OsceSseClient {
    private let tokenStore: TokenStore

    init(tokenStore: TokenStore) {
        self.tokenStore = tokenStore
    }

    enum OsceEvent: Sendable {
        case textDelta(String)
        case stepComplete(currentStep: Int, stepName: String, score: Int?)
        case done
        case error(String)
    }

    func streamRespond(attemptId: String, response: String) -> AsyncThrowingStream<OsceEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    guard let url = URL(string: AppConfig.apiBaseURL + "/ai/osce/\(attemptId)/respond") else {
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

                    let encoder = JSONEncoder()
                    encoder.keyEncodingStrategy = .convertToSnakeCase
                    request.httpBody = try encoder.encode(OsceRespondRequest(response: response))

                    let (bytes, urlResponse) = try await URLSession.shared.bytes(for: request)
                    guard let http = urlResponse as? HTTPURLResponse,
                          (200...299).contains(http.statusCode) else {
                        let code = (urlResponse as? HTTPURLResponse)?.statusCode ?? 0
                        continuation.finish(throwing: APIError.serverError(code))
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
                            case "step_complete":
                                if let data = eventData.data(using: .utf8),
                                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                                    let nextStep = json["current_step"] as? Int ?? 1
                                    let name = json["step_name"] as? String ?? ""
                                    let score = json["score"] as? Int
                                    continuation.yield(.stepComplete(currentStep: nextStep, stepName: name, score: score))
                                }
                            case "done":
                                continuation.yield(.done)
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
