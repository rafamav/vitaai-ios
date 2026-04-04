import Foundation

// MARK: - EstudosAPIService
// Wraps HTTPClient directly for Estudos-specific endpoints
// that are not yet in the main VitaAPI.swift file.
// Once VitaAPI.swift is updated, these can be moved there.

actor EstudosAPIService {
    private let client: HTTPClient

    init(client: HTTPClient) {
        self.client = client
    }

    // MARK: - Study Sessions (GET /api/study/sessions)

    func getStudySessions(limit: Int = 10) async throws -> StudySessionsResponse {
        try await client.get("study/sessions", queryItems: [
            URLQueryItem(name: "limit", value: String(limit)),
        ])
    }

    // MARK: - Documents (GET /api/documents)

    func getDocuments(limit: Int = 10) async throws -> DocumentsResponse {
        try await client.get("documents", queryItems: [
            URLQueryItem(name: "limit", value: String(limit)),
        ])
    }

    // MARK: - Studio Outputs (GET /api/studio/outputs)

    func getStudioOutputs(limit: Int = 10) async throws -> StudioOutputsResponse {
        try await client.get("studio/outputs", queryItems: [
            URLQueryItem(name: "limit", value: String(limit)),
        ])
    }

    // MARK: - Vita Memory / Recommendations (GET /api/vita/memory)

    func getVitaMemory() async throws -> VitaMemoryResponse {
        try await client.get("vita/memory")
    }

    // MARK: - Transcricoes List (GET /api/study/transcricao)

    func getTranscricoes() async throws -> [TranscricaoListEntry] {
        try await client.get("study/transcricao")
    }

    // MARK: - Notes (GET /api/notes)

    func getNotes(subjectId: String? = nil, limit: Int = 50) async throws -> [NoteListEntry] {
        var items: [URLQueryItem] = [
            URLQueryItem(name: "limit", value: String(limit)),
        ]
        if let subjectId { items.append(URLQueryItem(name: "subjectId", value: subjectId)) }
        return try await client.get("notes", queryItems: items)
    }
}
