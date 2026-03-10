import Foundation

struct CanvasStatusResponse: Codable {
    var connected: Bool = false
    var status: String?
    var instanceUrl: String?
    var lastSyncAt: String?
}

struct CanvasConnectRequest: Codable {
    var accessToken: String
    var instanceUrl: String = "https://ulbra.instructure.com"
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

/// Request body for the canvas/ingest endpoint.
/// `scrapedJson` carries the raw JSON string produced by the in-page scraping script.
/// `nativeCookies` carries the session cookie string captured from the WKWebView cookie store,
/// used by the server for background sync without re-authentication.
struct CanvasIngestRequest: Encodable {
    var instanceUrl: String
    var scrapedJson: String
    var nativeCookies: String?
}

/// Response from canvas/ingest — mirrors CanvasSyncResponse shape.
struct CanvasIngestResponse: Codable {
    var success: Bool = false
    var courses: Int = 0
    var files: Int = 0
    var assignments: Int = 0
    var calendarEvents: Int = 0
    var errors: [String] = []
    var error: String?
}
