import Foundation

// MIGRATION: Partial migration to OpenAPI generated types.
// PortalExtractRequestPagesInner -> generated (identical fields)
// PortalExtract200Response -> generated (superset of manual fields)

// PortalTotals, PortalCounts: custom init(from:) for safe defaults. Kept manual.
// ScreenResponse/ScreenBlock: generated uses different field names (sections vs blocks). Kept manual.

struct PortalStatusResponse: Codable {
    var connected: Bool = false
    // New unified format
    var connections: [PortalConnectionInfo]?
    var totals: PortalTotals?
    // Legacy format (kept for backwards compat)
    var connection: PortalConnectionLegacyInfo?
    var counts: PortalCounts?
}

struct PortalConnectionInfo: Codable {
    var id: String?
    var instanceUrl: String?
    var portalName: String?
    var portalType: String?
    var status: String?
    var lastSyncAt: String?
    var counts: PortalCounts?
}

struct PortalTotals: Codable {
    var grades: Int
    var subjects: Int
    var schedule: Int
    var documents: Int
    var semesters: Int

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        grades = (try? c.decode(Int.self, forKey: .grades)) ?? 0
        subjects = (try? c.decode(Int.self, forKey: .subjects)) ?? 0
        schedule = (try? c.decode(Int.self, forKey: .schedule)) ?? 0
        documents = (try? c.decode(Int.self, forKey: .documents)) ?? 0
        semesters = (try? c.decode(Int.self, forKey: .semesters)) ?? 0
    }

    init(grades: Int = 0, subjects: Int = 0, schedule: Int = 0, documents: Int = 0, semesters: Int = 0) {
        self.grades = grades; self.subjects = subjects; self.schedule = schedule; self.documents = documents; self.semesters = semesters
    }
}

struct PortalConnectionLegacyInfo: Codable {
    var instanceUrl: String?
    var status: String?
    var lastSyncAt: String?
}

struct PortalCounts: Codable {
    var grades: Int
    var subjects: Int
    var schedule: Int
    var semesters: Int
    var completed: Int
    var documents: Int

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        grades = (try? c.decode(Int.self, forKey: .grades)) ?? 0
        subjects = (try? c.decode(Int.self, forKey: .subjects)) ?? 0
        schedule = (try? c.decode(Int.self, forKey: .schedule)) ?? 0
        semesters = (try? c.decode(Int.self, forKey: .semesters)) ?? 0
        completed = (try? c.decode(Int.self, forKey: .completed)) ?? 0
        documents = (try? c.decode(Int.self, forKey: .documents)) ?? 0
    }

    init(grades: Int = 0, subjects: Int = 0, schedule: Int = 0, semesters: Int = 0, completed: Int = 0, documents: Int = 0) {
        self.grades = grades; self.subjects = subjects; self.schedule = schedule; self.semesters = semesters
        self.completed = completed; self.documents = documents
    }
}

// MARK: - Agenda (unified calendar)

struct AgendaResponse: Codable {
    var schedule: [AgendaClassBlock] = []
    var evaluations: [AgendaEvaluation] = []
    var summary: AgendaSummary = AgendaSummary()
}

struct AgendaClassBlock: Codable, Identifiable {
    var id: String { "\(dayOfWeek)-\(subjectName)-\(startTime)" }
    var subjectName: String = ""
    var dayOfWeek: Int = 0
    var startTime: String = ""
    var endTime: String = ""
    var room: String?
    var professor: String?
    var slots: Int = 1
}

struct AgendaEvaluation: Codable, Identifiable {
    var id: String = ""
    var title: String = ""
    var type: String = ""
    var date: String?
    var status: String = ""
    var score: Double?
    var subjectName: String?
}

struct AgendaSummary: Codable {
    var totalClasses: Int = 0
    var subjects: Int = 0
    var daysWithClasses: Int = 0
    var upcomingEvaluations: Int = 0
}

// MARK: - Subjects

struct SubjectsResponse: Codable {
    var subjects: [AcademicSubject]
}

struct AcademicSubject: Codable, Identifiable {
    var id: String
    var name: String
    var status: String?
    var source: String?
    var difficulty: String?
    /// Canonical discipline slug from vita.disciplines (96-row catalog).
    /// Nullable while the normalizer hasn't mapped this subject yet.
    var disciplineSlug: String?
    /// Canonical name from vita.disciplines, joined on disciplineSlug.
    var canonicalName: String?
    var professor: String?
    var semester: String?
    var workload: Int?
    /// Catalog area (basica, clinica, cirurgica, etc.) joined from vita.disciplines.
    var area: String?
    /// Icon slug from vita.disciplines, used for row rendering.
    var icon: String?
    /// True when the LLM normalizer couldn't place this subject in the catalog.
    var needsReview: Bool?
    /// Total QBank questions available for this discipline slug, computed
    /// server-side from qbank_topics. Replaces the need to cross-reference
    /// /api/qbank/filters.disciplines[] (deprecated).
    var questionCount: Int?
    /// Attendance percent (0-100), copied from academic_subjects.attendancePercent.
    /// Lets enrollment-aware screens stop cross-referencing /api/grades/current.
    var attendance: Double?
    /// Absence count, copied from academic_subjects.absences.
    var absences: Int?
    /// AP1/P1/N1 score derived server-side from academic_evaluations.
    var grade1: Double?
    /// AP2/P2/N2 score derived server-side from academic_evaluations.
    var grade2: Double?
    /// AP3/P3/N3 score derived server-side from academic_evaluations.
    var grade3: Double?
    /// Final/Média/Exame score derived server-side from academic_evaluations.
    var finalGrade: Double?

    /// Prefer the canonical catalog name when present, fall back to the
    /// portal-sourced subject name.
    var displayName: String { canonicalName ?? name }
}

// MARK: - Server-Driven UI (manual — generated uses different field names)

struct ScreenResponse: Codable {
    var screenId: String?
    var blocks: [ScreenBlock]?
}

struct ScreenBlock: Codable {
    var type: String?
    var data: [String: String]?
}
