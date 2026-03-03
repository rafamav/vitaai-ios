import Foundation
import SwiftUI

// MARK: - Retention curve point

/// A single point on the Ebbinghaus forgetting curve.
struct RetentionPoint: Identifiable {
    let id = UUID()
    /// Days since initial learning: 0, 1, 7, 14, 30, 60, 90
    let day: Int
    /// Estimated retention percentage (0–100)
    let retention: Double
}

// MARK: - Daily study heatmap

/// One day's study session data for the heatmap calendar.
struct StudyDay: Identifiable {
    /// ISO8601 date string, e.g. "2025-01-15" — used as stable id and lookup key
    let id: String
    let date: Date
    let minutesStudied: Int
}

// MARK: - Card review forecast

/// Forecasted flashcard review count for one day.
struct ForecastDay: Identifiable {
    let date: Date
    let cardsCount: Int
    var id: String { date.formatted(.iso8601.day().month().year()) }
}

// MARK: - Card state distribution

/// One slice of the card distribution donut chart.
struct CardCategory: Identifiable {
    let id = UUID()
    let name: String
    let count: Int
    let color: Color
}
