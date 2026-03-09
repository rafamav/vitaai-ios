import Foundation

// MARK: - Google Calendar

struct GoogleCalendarStatusResponse: Codable {
    var connected: Bool = false
    var status: String?
    var googleEmail: String?
    var lastSyncAt: String?
    var counts: GoogleCalendarCounts?
}

struct GoogleCalendarCounts: Codable {
    var events: Int = 0
}

struct GoogleCalendarSyncResponse: Codable {
    var synced: Int = 0
    var events: Int = 0
}

// MARK: - Google Drive

struct GoogleDriveStatusResponse: Codable {
    var connected: Bool = false
    var status: String?
    var googleEmail: String?
    var lastSyncAt: String?
    var counts: GoogleDriveCounts?
}

struct GoogleDriveCounts: Codable {
    var files: Int = 0
}

struct GoogleDriveSyncResponse: Codable {
    var synced: Int = 0
    var files: Int = 0
}
