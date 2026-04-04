import Foundation

// MARK: - Study Sessions (GET /api/study/sessions)

struct StudySessionsResponse: Decodable {
    let sessions: [StudySessionEntry]
}

struct StudySessionEntry: Decodable, Identifiable {
    let id: String
    let type: String           // "flashcard", "qbank", "simulado", "pdf", "transcricao"
    let title: String
    let duration: Int?         // seconds
    let accuracy: Double?      // 0.0 - 1.0
    let discipline: String?
    let createdAt: String
}

// MARK: - Documents (GET /api/documents)

struct DocumentsResponse: Decodable {
    let documents: [DocumentItem]
}

struct DocumentItem: Decodable, Identifiable {
    let id: String
    let title: String
    let fileName: String?
    let fileUrl: String?
    let subjectId: String?
    let totalPages: Int?
    let currentPage: Int?
    let readProgress: Double?  // 0.0 - 1.0
    let createdAt: String?

    var progressPercent: Int {
        guard let progress = readProgress else { return 0 }
        return Int(progress * 100)
    }
}

// MARK: - Studio Outputs (GET /api/studio/outputs)

struct StudioOutputsResponse: Decodable {
    let outputs: [StudioOutputItem]
}

struct StudioOutputItem: Decodable, Identifiable {
    let id: String
    let outputType: String     // "summary", "flashcards", "mindmap", "quiz"
    let title: String
    let sourceName: String?
    let createdAt: String?
}

// MARK: - Vita Memory / Recommendations (GET /api/vita/memory)

struct VitaMemoryResponse: Decodable {
    let recommendations: [VitaRecommendation]
}

struct VitaRecommendation: Decodable, Identifiable {
    let id: String
    let discipline: String
    let reason: String
    let suggestedAction: String
    let priority: Int?          // 1 = highest
}

// MARK: - QBank Progress (already exists, re-exported here for clarity)
// Uses QBankProgressResponse from QBankModels.swift

// MARK: - Simulado Diagnostics (already exists)
// Uses SimuladoDiagnosticsResponse from SimuladoModels.swift

// MARK: - Continue Where You Left Off (composite type built from multiple sources)

struct ContinueItem: Identifiable {
    let id: String
    let type: ContinueItemType
    let title: String
    let subtitle: String?
    let progress: Double?      // 0.0 - 1.0
    let icon: String           // SF Symbol name

    enum ContinueItemType: String {
        case pdf
        case simulado
        case flashcard
        case transcricao
    }
}

// MARK: - Tool Card (static definition for the tools grid)

struct ToolDefinition: Identifiable {
    let id: String
    let name: String
    let icon: String           // SF Symbol
    let accentColor: ToolColor
    let route: Route

    enum ToolColor {
        case gold
        case blue
        case purple
        case teal
        case amber
        case green
    }

    static let allTools: [ToolDefinition] = [
        ToolDefinition(
            id: "qbank",
            name: String(localized: "QBank"),
            icon: "checkmark.square.fill",
            accentColor: .blue,
            route: .qbank
        ),
        ToolDefinition(
            id: "flashcards",
            name: String(localized: "Flashcards"),
            icon: "rectangle.on.rectangle.angled",
            accentColor: .purple,
            route: .flashcardStats
        ),
        ToolDefinition(
            id: "simulados",
            name: String(localized: "Simulados"),
            icon: "text.badge.checkmark",
            accentColor: .teal,
            route: .simuladoHome
        ),
        ToolDefinition(
            id: "pdfs",
            name: String(localized: "PDFs"),
            icon: "doc.text.fill",
            accentColor: .gold,
            route: .notebookList
        ),
        ToolDefinition(
            id: "transcricao",
            name: String(localized: "Transcricao"),
            icon: "waveform",
            accentColor: .teal,
            route: .transcricao
        ),
        ToolDefinition(
            id: "casos",
            name: String(localized: "Casos Clinicos"),
            icon: "stethoscope",
            accentColor: .amber,
            route: .osce
        ),
        ToolDefinition(
            id: "voz",
            name: String(localized: "Voz"),
            icon: "mic.fill",
            accentColor: .green,
            route: .vitaChat()
        ),
        ToolDefinition(
            id: "studio",
            name: String(localized: "Studio"),
            icon: "wand.and.stars",
            accentColor: .gold,
            route: .mindMapList
        ),
    ]
}

// MARK: - Recent Material (composite from documents + studio outputs + transcricoes + notes)

struct RecentMaterial: Identifiable {
    let id: String
    let type: MaterialType
    let title: String
    let subtitle: String?
    let createdAt: String?

    enum MaterialType: String {
        case document
        case studioOutput
        case transcricao
        case note
    }

    var icon: String {
        switch type {
        case .document:     return "doc.text"
        case .studioOutput: return "wand.and.stars"
        case .transcricao:  return "waveform"
        case .note:         return "note.text"
        }
    }

    var typeLabel: String {
        switch type {
        case .document:     return String(localized: "Documento")
        case .studioOutput: return String(localized: "Studio")
        case .transcricao:  return String(localized: "Transcricao")
        case .note:         return String(localized: "Nota")
        }
    }
}
