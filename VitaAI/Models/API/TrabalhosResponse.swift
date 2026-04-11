import Foundation

// MARK: - /api/study/trabalhos response

struct TrabalhosResponse: Codable {
    var pending: [TrabalhoItem] = []
    var completed: [TrabalhoItem] = []
    var overdue: [TrabalhoItem] = []
    var total: Int = 0
}

struct TrabalhoItem: Codable, Identifiable {
    var id: String
    var title: String
    var subjectName: String = ""
    var type: String = "assignment"
    var status: String = "pending"
    var submitted: Bool = false
    var submittedAt: String?
    var date: String?
    var daysUntil: Int?
    var pointsPossible: Double?
    var score: Double?
    var grade: String?
    var description: String?
    var descriptionHtml: String?
    var submissionTypes: [String] = []
    var canvasAssignmentId: String?
    var canGenerate: Bool = false

    // Computed

    var dueDate: Date? {
        guard let date else { return nil }
        return ISO8601DateFormatter().date(from: date)
    }

    var submissionDate: Date? {
        guard let submittedAt else { return nil }
        return ISO8601DateFormatter().date(from: submittedAt)
    }

    var submissionTypeLabel: String {
        if submissionTypes.contains("online_text_entry") { return "Texto online" }
        if submissionTypes.contains("online_upload") { return "Upload de arquivo" }
        if submissionTypes.contains("external_tool") { return "Ferramenta externa" }
        if submissionTypes.contains("online_url") { return "Link" }
        return submissionTypes.first ?? "Entrega"
    }

    var urgencyColor: String {
        guard let daysUntil else { return "tertiary" }
        if daysUntil < 0 { return "red" }
        if daysUntil <= 1 { return "red" }
        if daysUntil <= 3 { return "amber" }
        if daysUntil <= 7 { return "accent" }
        return "green"
    }
}
