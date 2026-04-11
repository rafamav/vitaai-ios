import Foundation

// MIGRATION: Partial migration to OpenAPI generated types.
// SyncProgressResponse -> SyncProgress (generated) with extension for computed isDone/isError
// FilterFilesResponse -> PortalFilterFiles200Response (generated)
// Canvas API client types (CanvasAPIUser, etc.) are for direct Canvas REST, not in OpenAPI spec.
// CanvasStatusResponse, CanvasConnectRequest/Response, CoursesResponse, etc. kept manual --
// generated Portal* types have different field shapes.

typealias SyncProgressResponse = SyncProgress
typealias FilterFilesResponse = PortalFilterFiles200Response

extension SyncProgress {
    var isDone: Bool { (phase == "done") || (percent ?? 0) >= 100 }
    var isError: Bool { phase == "error" }
}

// MARK: - Backend Status / Connect / Disconnect responses

/// Response from GET /api/portal/status -- all portal connections + counts
struct CanvasStatusResponse: Codable {
    var connected: Bool = false
    var connections: [PortalConnectionDetail]?
    var totals: PortalTotals?

    struct PortalConnectionDetail: Codable {
        var id: String?
        var instanceUrl: String?
        var portalName: String?
        var portalType: String?
        var status: String?
        var lastSyncAt: String?
        var lastPingAt: String?
        var counts: PortalCounts?
    }

    struct PortalCounts: Codable {
        var subjects: Int = 0
        var evaluations: Int = 0
        var schedule: Int = 0
        var documents: Int = 0
        var semesters: Int = 0
    }

    struct PortalTotals: Codable {
        var subjects: Int = 0
        var evaluations: Int = 0
        var schedule: Int = 0
        var documents: Int = 0
        var semesters: Int = 0
    }

    /// Convenience: find the canvas connection
    var canvasConnection: PortalConnectionDetail? {
        connections?.first { $0.portalType == "canvas" }
    }
}

struct CanvasConnectRequest: Codable {
    var accessToken: String
    var instanceUrl: String = ""
}

struct CanvasConnectResponse: Codable {
    var success: Bool = false
    var connectionId: String?
    var updated: Bool = false
    var error: String?
}

struct CanvasSyncResponse: Codable {
    var courses: Int = 0
    var files: Int = 0
    var assignments: Int = 0
    var calendarEvents: Int = 0
    var pdfExtracted: Int = 0
    var studyEvents: Int = 0
    var errors: [String] = []
}

struct CoursesResponse: Codable {
    var connected: Bool = false
    var courses: [Course] = []
}

struct Course: Codable, Identifiable {
    var id: String
    var name: String
    var code: String = ""
    var term: String = ""
    var filesCount: Int = 0
    var assignmentsCount: Int = 0
    var pdfsCount: Int = 0
}

struct FilesResponse: Codable {
    var files: [CanvasFile] = []
}

struct CanvasFile: Codable, Identifiable {
    var id: String
    var displayName: String
    var contentType: String?
    var size: Int64 = 0
    var hasText: Bool = false
    var totalPages: Int?
    var courseName: String?
    var courseId: String?
    var moduleName: String?
    var modulePosition: Int?
    var itemPosition: Int?
    var updatedAt: String?
}

struct AssignmentsResponse: Codable {
    var assignments: [Assignment] = []
}

struct Assignment: Codable, Identifiable {
    var id: String
    var name: String
    var description: String?
    var dueAt: String?
    var pointsPossible: Double?
    var courseName: String = ""
    var courseId: String = ""
}

// MARK: - Vita Crawl (universal portal extraction via Vita LLM)

struct VitaCrawlResponse: Codable {
    var syncId: String?
    var status: String?
    var error: String?
}

// MARK: - Sync Progress Items (granular progress from Vita crawl)

struct SyncProgressItem: Codable, Identifiable {
    var id: String { "\(type)-\(name)" }
    var type: String = ""
    var name: String = ""
    var status: String = "pending"
    var detail: String?
}

// MARK: - Canvas REST API Response Models (decoded from Canvas directly on device)

/// User from /api/v1/users/self
struct CanvasAPIUser: Decodable {
    let id: Int
    let name: String
    let shortName: String?
    let loginId: String?
    let avatarUrl: String?

    enum CodingKeys: String, CodingKey {
        case id, name
        case shortName = "short_name"
        case loginId = "login_id"
        case avatarUrl = "avatar_url"
    }
}

/// Course from /api/v1/courses?include[]=total_scores&include[]=teachers&include[]=term
struct CanvasAPICourse: Decodable {
    let id: Int
    let name: String
    let courseCode: String?
    let enrollments: [CanvasAPIEnrollment]?
    let teachers: [CanvasAPITeacher]?
    let term: CanvasAPITerm?

    enum CodingKeys: String, CodingKey {
        case id, name, enrollments, teachers, term
        case courseCode = "course_code"
    }
}

struct CanvasAPIEnrollment: Decodable {
    let type: String?
    let enrollmentState: String?
    let computedCurrentScore: Double?
    let computedFinalScore: Double?
    let computedCurrentGrade: String?
    let computedFinalGrade: String?

    enum CodingKeys: String, CodingKey {
        case type
        case enrollmentState = "enrollment_state"
        case computedCurrentScore = "computed_current_score"
        case computedFinalScore = "computed_final_score"
        case computedCurrentGrade = "computed_current_grade"
        case computedFinalGrade = "computed_final_grade"
    }
}

struct CanvasAPITeacher: Decodable {
    let id: Int?
    let displayName: String?

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
    }
}

struct CanvasAPITerm: Decodable {
    let id: Int?
    let name: String?
}

/// File from /api/v1/courses/:id/files
struct CanvasAPIFile: Decodable {
    let id: Int
    let displayName: String
    let contentType: String?
    let size: Int
    let url: String? // direct download URL (authenticated)

    enum CodingKeys: String, CodingKey {
        case id, size, url
        case displayName = "display_name"
        case contentType = "content-type"
    }
}

/// Assignment from /api/v1/courses/:id/assignments?include[]=submission
struct CanvasAPIAssignment: Decodable {
    let id: Int
    let name: String
    let description: String?
    let dueAt: String?
    let pointsPossible: Double?
    let submission: CanvasAPISubmission?

    enum CodingKeys: String, CodingKey {
        case id, name, description, submission
        case dueAt = "due_at"
        case pointsPossible = "points_possible"
    }
}

struct CanvasAPISubmission: Decodable {
    let score: Double?
    let grade: String?
    let submittedAt: String?

    enum CodingKeys: String, CodingKey {
        case score, grade
        case submittedAt = "submitted_at"
    }
}

/// Calendar event from /api/v1/calendar_events
struct CanvasAPICalendarEvent: Decodable {
    let id: Int
    let title: String?
    let startAt: String?
    let endAt: String?
    let contextType: String?

    enum CodingKeys: String, CodingKey {
        case id, title
        case startAt = "start_at"
        case endAt = "end_at"
        case contextType = "context_type"
    }
}

// MARK: - Ingest Payload (sent to POST /api/portal/ingest, matches openapi.yaml CanvasIngestPayload)
// Uses [String: Any] arrays + JSONSerialization because the data comes from Canvas REST API
// in dynamic shapes. The generated CanvasIngestPayload uses typed arrays which don't match.

struct CanvasIngestPayload {
    let instanceUrl: String
    let user: [String: Any]?
    let courses: [[String: Any]]
    let assignments: [[String: Any]]
    let files: [[String: Any]]
    let calendarEvents: [[String: Any]]
    let errors: [[String: Any]]
    let pdfContents: [[String: Any]]
    let sessionCookies: String?

    func toJSONData() throws -> Data {
        var dict: [String: Any] = [
            "instanceUrl": instanceUrl,
            "courses": courses,
            "assignments": assignments,
            "files": files,
            "calendarEvents": calendarEvents,
            "errors": errors,
            "pdfContents": pdfContents,
        ]
        if let user { dict["user"] = user }
        if let sessionCookies { dict["sessionCookies"] = sessionCookies }
        return try JSONSerialization.data(withJSONObject: dict)
    }
}

// MARK: - Ingest Response

struct CanvasIngestResponse: Decodable {
    let ok: Bool?
    let success: Bool?
    let traceId: String?
    let courses: Int?
    let assignments: Int?
    let files: Int?
    let calendarEvents: Int?
    let pdfExtracted: Int?
    let errors: [String]?
}
