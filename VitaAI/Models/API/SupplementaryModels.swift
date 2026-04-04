import Foundation

// MARK: - Subjects (GET /api/subjects)

struct SubjectsResponse: Decodable {
    let subjects: [AcademicSubject]
}

struct AcademicSubject: Decodable, Identifiable {
    let id: String
    let name: String
    let code: String?
    let difficulty: String?
    let vitaScore: Double?
    let flashcardCount: Int?
    let flashcardsDue: Int?
    let status: String?
}

// MARK: - Transcricao List (GET /api/study/transcricao)

struct TranscricaoListEntry: Decodable, Identifiable {
    let id: String
    let title: String
    let status: String?       // "processing", "completed", "failed"
    let duration: Int?        // seconds
    let createdAt: String?
}

// MARK: - Notes List (GET /api/notes)

struct NoteListEntry: Decodable, Identifiable {
    let id: String
    let title: String
    let content: String?
    let subjectId: String?
    let updatedAt: String?
}

// MARK: - Dashboard Data (GET /api/dashboard)

struct DashboardDataResponse: Decodable {
    let streakDays: Int?
    let flashcardsDue: Int?
    let todayStudyMinutes: Int?
    let recommendations: [DashboardRecommendationItem]?
}

struct DashboardRecommendationItem: Decodable, Identifiable {
    let id: String
    let deckId: String?
    let title: String
    let dueCount: Int
}

// MARK: - Portal Data (GET /api/portal/data)

struct PortalData200Response: Decodable {
    let enrollments: [PortalEnrollment]?
    let grades: [PortalGrade]?
    let evaluations: [PortalEvaluation]?
    let schedule: [PortalScheduleItem]?
    let calendar: [PortalCalendarItem]?
}

struct PortalEnrollment: Decodable, Identifiable {
    let id: String
    let courseName: String?
    let grade: Double?
    let attendance: Double?
}

struct PortalGrade: Decodable, Identifiable {
    var id: String?
    let subjectName: String?
    let label: String?
    let value: Double?
    // Rich grade fields (from webaluno sync)
    let grade1: String?
    let grade2: String?
    let grade3: String?
    let finalGrade: String?
    let attendance: String?
    let absences: String?
    let professor: String?
    let semester: String?
    let status: String?
}

struct PortalEvaluation: Decodable {
    let id: String?
    let title: String?
    let type: String?
    let date: String?
    let subjectName: String?
    let score: Double?
    let pointsPossible: Double?
    let grade: String?
    let status: String?
}

struct PortalScheduleItem: Decodable {
    let id: String?
    let subjectName: String?
    let professor: String?
    let room: String?
    let dayOfWeek: Int?
    let startTime: String?
    let endTime: String?
}

struct PortalCalendarItem: Decodable {
    let id: String?
    let title: String?
    let type: String?
    let startAt: Date?
    let subjectName: String?
}

// MARK: - Enrollments (GET /api/enrollments)

struct GetEnrollments200Response: Decodable {
    let enrollments: [PortalEnrollment]?
}

// MARK: - Student Context (GET /api/vita/student-context)

struct GetStudentContext200Response: Decodable {
    let context: String?
}

// MARK: - Sync Progress

struct SyncProgressResponse: Decodable {
    let syncId: String?
    let status: String?
    let progress: Int?
}

// MARK: - Remote Notes / MindMaps (for notes cloud sync)

struct RemoteNote: Decodable, Identifiable {
    let id: String
    let title: String
    let content: String?
    let subjectId: String?
    let updatedAt: String?
}

struct RemoteMindMap: Decodable, Identifiable {
    let id: String
    let title: String
    let subjectId: String?
    let updatedAt: String?
}
