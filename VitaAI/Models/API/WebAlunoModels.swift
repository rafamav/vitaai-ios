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

// MARK: - Grades Current (consolidated per subject)

struct GradesCurrentResponse: Codable {
    var current: [GradeSubject] = []
    var completed: [GradeSubject] = []
    var summary: GradesSummary = GradesSummary()
}

struct GradeSubject: Codable, Identifiable {
    var id: String { subjectName }
    var subjectName: String = ""
    var grade1: Double?
    var grade2: Double?
    var grade3: Double?
    var finalGrade: Double?
    var status: String = "cursando"
    var attendance: Int?
    var absences: Int?
    var workload: Int?

    private enum CodingKeys: String, CodingKey {
        case subjectName, grade1, grade2, grade3, finalGrade, status, attendance, absences, workload
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        subjectName = (try? c.decode(String.self, forKey: .subjectName)) ?? ""
        grade1 = Self.flexDouble(c, .grade1)
        grade2 = Self.flexDouble(c, .grade2)
        grade3 = Self.flexDouble(c, .grade3)
        finalGrade = Self.flexDouble(c, .finalGrade)
        status = (try? c.decode(String.self, forKey: .status)) ?? "cursando"
        attendance = (try? c.decode(Int.self, forKey: .attendance))
        absences = (try? c.decode(Int.self, forKey: .absences))
        workload = (try? c.decode(Int.self, forKey: .workload))
    }

    private static func flexDouble(_ c: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) -> Double? {
        if let d = try? c.decode(Double.self, forKey: key) { return d }
        if let i = try? c.decode(Int.self, forKey: key) { return Double(i) }
        return nil
    }
}

struct GradesSummary: Codable {
    var subjectsCount: Int = 0
    var averageAttendance: Double?
    var totalAbsences: Int = 0
    var averageGrade: Double?
    var totalWorkload: Int = 0

    init(subjectsCount: Int = 0, averageAttendance: Double? = nil, totalAbsences: Int = 0, averageGrade: Double? = nil, totalWorkload: Int = 0) {
        self.subjectsCount = subjectsCount
        self.averageAttendance = averageAttendance
        self.totalAbsences = totalAbsences
        self.averageGrade = averageGrade
        self.totalWorkload = totalWorkload
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        subjectsCount = (try? c.decode(Int.self, forKey: .subjectsCount)) ?? 0
        // averageAttendance can be Int or Double from API
        if let d = try? c.decode(Double.self, forKey: .averageAttendance) {
            averageAttendance = d
        } else if let i = try? c.decode(Int.self, forKey: .averageAttendance) {
            averageAttendance = Double(i)
        } else {
            averageAttendance = nil
        }
        totalAbsences = (try? c.decode(Int.self, forKey: .totalAbsences)) ?? 0
        if let d = try? c.decode(Double.self, forKey: .averageGrade) {
            averageGrade = d
        } else if let i = try? c.decode(Int.self, forKey: .averageGrade) {
            averageGrade = Double(i)
        } else {
            averageGrade = nil
        }
        totalWorkload = (try? c.decode(Int.self, forKey: .totalWorkload)) ?? 0
    }
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
