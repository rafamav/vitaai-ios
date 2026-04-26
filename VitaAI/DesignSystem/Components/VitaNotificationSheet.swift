import Foundation

// MARK: - VitaNotification Model

struct VitaNotification: Identifiable, Decodable {
    let id: String
    let type: String
    let title: String
    let description: String
    let time: String?
    let read: Bool
    var createdAt: String? = nil
    var route: String? = nil
    var group: String? = nil
    var priority: String? = nil

    var icon: String {
        switch type {
        case "gradePosted": return "\u{1F4CA}"
        case "examAlert", "exam": return "\u{1F4DD}"
        case "assignment": return "\u{1F4CB}"
        case "seminar": return "\u{1F399}\u{FE0F}"
        case "attendanceAlert": return "\u{26A0}\u{FE0F}"
        case "newMaterial": return "\u{1F4DA}"
        case "badge": return "\u{1F3C6}"
        case "streak": return "\u{1F525}"
        case "flashcard", "flashcardDue": return "\u{1F0CF}"
        case "reminder", "studyPlan": return "\u{23F0}"
        case "deadline": return "\u{23F3}"
        case "vitaInsight": return "\u{1F4A1}"
        case "transcriptionReady": return "\u{1F3A7}"
        case "transcriptionFailed", "uploadFailed": return "\u{26A0}\u{FE0F}"
        case "portalCookieExpired": return "\u{1F510}"
        case "quotaWarning": return "\u{1F4E6}"
        default: return "\u{1F514}"
        }
    }

    /// SF Symbol matching `type` — used by VitaNotifPopout pra render gold-tinted
    /// icons em vez de emoji (alinha com paleta monocromática gold do app).
    var sfSymbol: String {
        switch type {
        case "gradePosted": return "chart.bar.fill"
        case "examAlert", "exam": return "doc.text.fill"
        case "assignment": return "list.clipboard.fill"
        case "seminar": return "mic.fill"
        case "attendanceAlert": return "exclamationmark.triangle.fill"
        case "newMaterial": return "books.vertical.fill"
        case "badge": return "trophy.fill"
        case "streak": return "flame.fill"
        case "flashcard", "flashcardDue": return "rectangle.stack.fill"
        case "reminder", "studyPlan": return "alarm.fill"
        case "deadline": return "hourglass"
        case "vitaInsight": return "lightbulb.fill"
        case "transcriptionReady": return "waveform.circle.fill"
        case "transcriptionFailed", "uploadFailed": return "exclamationmark.circle.fill"
        case "portalCookieExpired": return "lock.rotation"
        case "quotaWarning": return "externaldrive.badge.exclamationmark"
        default: return "bell.fill"
        }
    }

    var relativeTime: String {
        guard let createdAt, let date = Self.parseDate(createdAt) else {
            return time ?? ""
        }
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60 { return "Agora" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes) min" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours) h" }
        let days = hours / 24
        return "\(days) d"
    }

    private static func parseDate(_ str: String) -> Date? {
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = fmt.date(from: str) { return d }
        fmt.formatOptions = [.withInternetDateTime]
        return fmt.date(from: str)
    }
}
