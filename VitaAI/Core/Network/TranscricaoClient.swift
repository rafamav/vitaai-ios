import Foundation

// MARK: - Domain Types

struct TranscriptionFlashcard: Identifiable, Sendable {
    let id: String
    let front: String
    let back: String
}

enum TranscricaoSSEEvent: Sendable {
    case progress(stage: String, percent: Int)
    case complete(transcript: String, summary: String, flashcards: [TranscriptionFlashcard])
    case error(message: String)
}

// MARK: - TranscricaoClient
//
// Actor-based SSE client for audio upload + streaming transcription pipeline.
// Mirrors Android's TranscricaoSseClient pattern: multipart/form-data POST → SSE response.
//
// Endpoint: POST /ai/transcribe
// Events:  { type: "progress", stage, percent }
//          { type: "complete", transcript, summary, flashcards }
//          { type: "error", message }

actor TranscricaoClient {
    private let tokenStore: TokenStore

    init(tokenStore: TokenStore) {
        self.tokenStore = tokenStore
    }

    // MARK: - Upload + Stream

    /// Uploads audio file and returns an SSE stream with progress/completion events.
    func uploadAndStream(fileURL: URL) -> AsyncThrowingStream<TranscricaoSSEEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    guard let fileData = try? Data(contentsOf: fileURL) else {
                        continuation.finish(throwing: APIError.noData)
                        return
                    }

                    let boundary = "VitaBoundary-\(UUID().uuidString.replacingOccurrences(of: "-", with: ""))"
                    var body = Data()
                    body.append(formPart(boundary: boundary, name: "audio", filename: "audio.m4a",
                                         contentType: "audio/m4a", data: fileData))
                    body.append("--\(boundary)--\r\n".utf8Data)

                    guard let url = URL(string: AppConfig.apiBaseURL + "/ai/transcribe") else {
                        continuation.finish(throwing: APIError.invalidURL)
                        return
                    }

                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
                    request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
                    request.httpBody = body
                    request.timeoutInterval = 180

                    if let token = await tokenStore.token {
                        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                    }

                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    guard let httpResponse = response as? HTTPURLResponse else {
                        continuation.finish(throwing: APIError.unknown)
                        return
                    }
                    guard (200...299).contains(httpResponse.statusCode) else {
                        if httpResponse.statusCode == 401 {
                            continuation.finish(throwing: APIError.unauthorized)
                        } else {
                            continuation.finish(throwing: APIError.serverError(httpResponse.statusCode))
                        }
                        return
                    }

                    var eventType = ""
                    var dataLines: [String] = []

                    for try await line in bytes.lines {
                        if line.hasPrefix("event:") {
                            eventType = String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces)
                        } else if line.hasPrefix("data:") {
                            let content = String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                            dataLines.append(content)
                        } else if line.isEmpty, !dataLines.isEmpty {
                            let rawJSON = dataLines.joined(separator: "\n")
                            dataLines = []
                            if let event = Self.parse(type: eventType, data: rawJSON) {
                                continuation.yield(event)
                                switch event {
                                case .complete, .error:
                                    continuation.finish()
                                    return
                                default:
                                    break
                                }
                            }
                            eventType = ""
                        }
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - Multipart Builder

    private func formPart(boundary: String, name: String, filename: String,
                          contentType: String, data: Data) -> Data {
        var part = Data()
        part.append("--\(boundary)\r\n".utf8Data)
        part.append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n".utf8Data)
        part.append("Content-Type: \(contentType)\r\n\r\n".utf8Data)
        part.append(data)
        part.append("\r\n".utf8Data)
        return part
    }

    // MARK: - SSE Parser

    private static func parse(type: String, data: String) -> TranscricaoSSEEvent? {
        guard let jsonData = data.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
        else { return nil }

        switch type {
        case "progress":
            return .progress(
                stage: json["stage"] as? String ?? "",
                percent: json["percent"] as? Int ?? 0
            )
        case "complete":
            let transcript = json["transcript"] as? String ?? ""
            let summary = json["summary"] as? String ?? ""
            let rawCards = json["flashcards"] as? [[String: String]] ?? []
            let cards = rawCards.enumerated().map { idx, card in
                TranscriptionFlashcard(
                    id: card["id"] ?? "\(idx)",
                    front: card["front"] ?? "",
                    back: card["back"] ?? ""
                )
            }
            return .complete(transcript: transcript, summary: summary, flashcards: cards)
        case "error":
            return .error(message: json["message"] as? String ?? "Erro desconhecido")
        default:
            return nil
        }
    }
}

// MARK: - Helper

private extension String {
    var utf8Data: Data { data(using: .utf8) ?? Data() }
}
