import Foundation

struct WebalunoStatusResponse: Codable {
    var connected: Bool = false
    // New unified format
    var connections: [PortalConnectionInfo]?
    var totals: PortalTotals?
    // Legacy format (kept for backwards compat)
    var connection: WebalunoConnectionInfo?
    var counts: WebalunoCounts?
}

struct PortalConnectionInfo: Codable {
    var id: String?
    var instanceUrl: String?
    var portalName: String?
    var portalType: String?
    var status: String?
    var lastSyncAt: String?
    var counts: WebalunoCounts?
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

struct WebalunoConnectionInfo: Codable {
    var instanceUrl: String?
    var status: String?
    var lastSyncAt: String?
}

struct WebalunoCounts: Codable {
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

struct WebalunoConnectRequest: Codable {
    var cpf: String?
    var password: String?
    var sessionCookie: String?
    var instanceUrl: String = "https://ac3949.mannesoftprime.com.br"
}

struct WebalunoConnectResponse: Codable {
    var success: Bool = false
    var grades: Int = 0
    var schedule: Int = 0
    var syncErrors: [String]?
    var error: String?
}

struct WebalunoSyncResponse: Codable {
    var success: Bool = false
    var grades: Int = 0
    var schedule: Int = 0
    var error: String?
}

struct WebalunoGradesResponse: Codable {
    var grades: [WebalunoGrade] = []
    var summary: WebalunoGradesSummary?
    var lastSyncAt: String?
}

struct WebalunoGrade: Codable, Identifiable {
    var id: String = ""
    var subjectName: String = ""
    var subjectCode: String?
    var grade1: Double?
    var grade2: Double?
    var grade3: Double?
    var finalGrade: Double?
    var status: String?
    var attendance: Double?
    var semester: String?
}

struct WebalunoGradesSummary: Codable {
    var total: Int = 0
    var completed: Int = 0
    var inProgress: Int = 0
    var averageGrade: Double?
    var semesters: Int = 0
}

struct WebalunoScheduleResponse: Codable {
    var schedule: [WebalunoScheduleBlock] = []
    var summary: WebalunoScheduleSummary?
    var lastSyncAt: String?
}

struct WebalunoScheduleBlock: Codable {
    var subjectName: String = ""
    var dayOfWeek: Int = 0
    var startTime: String = ""
    var endTime: String = ""
    var room: String?
    var professor: String?
    var slots: Int = 1
}

struct WebalunoScheduleSummary: Codable {
    var totalClasses: Int = 0
    var subjects: Int = 0
    var daysWithClasses: Int = 0
}

// MARK: - Portal Extract (client-side HTML capture)

struct PortalExtractRequestPagesInner: Codable {
    var type: String?
    var html: String?
    var linkText: String?
}

struct PortalExtract200Response: Codable {
    var success: Bool?
    var grades: Int?
    var schedule: Int?
    var error: String?
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

// MARK: - Server-Driven UI

struct ScreenResponse: Codable {
    var screenId: String?
    var blocks: [ScreenBlock]?
}

struct ScreenBlock: Codable {
    var type: String?
    var data: [String: String]?
}

