import Foundation
import Observation

@MainActor
@Observable
final class AgendaViewModel {
    let appData: AppDataManager

    var studyItems: [LocalStudyItem] = []
    var selectedDayIndex: Int = {
        // Sunday=1...Saturday=7 in Calendar; map to 0-based index matching Portuguese days array
        let raw = Calendar.current.component(.weekday, from: Date())
        return raw - 1
    }()
    var showCreateModal = false

    // Create modal state
    var newTitle = ""
    var newSubject = ""
    var newTime = "09:00"
    var newDuration = 60
    var isSaving = false

    // Convenience accessors for shared data
    var studyEvents: [StudyEventEntry] { appData.studyEvents }
    var classSchedule: [AgendaClassBlock] { appData.classSchedule }
    var academicEvaluations: [AgendaEvaluation] { appData.academicEvaluations }
    var gradesResponse: GradesCurrentResponse? { appData.gradesResponse }
    var isLoading: Bool { appData.isLoading }

    init(appData: AppDataManager) {
        self.appData = appData
    }

    func toggleItem(_ item: LocalStudyItem) {
        guard let idx = studyItems.firstIndex(where: { $0.id == item.id }) else { return }
        studyItems[idx].completed.toggle()
    }

    func createItem() {
        guard !newTitle.isEmpty else { return }
        let item = LocalStudyItem(
            id: UUID().uuidString,
            title: newTitle,
            subject: newSubject.isEmpty ? nil : newSubject,
            time: newTime,
            duration: newDuration,
            dayIndex: selectedDayIndex,
            completed: false
        )
        studyItems.append(item)
        newTitle = ""
        newSubject = ""
        newTime = "09:00"
        newDuration = 60
        showCreateModal = false
    }

    // MARK: - Computed filtered collections

    var selectedDayStudyItems: [LocalStudyItem] {
        studyItems
            .filter { $0.dayIndex == selectedDayIndex }
            .sorted { $0.time < $1.time }
    }

    var selectedDayEvents: [StudyEventEntry] {
        let calendar = Calendar.current
        let today = Date()
        let weekday = calendar.component(.weekday, from: today)
        let weekStart = calendar.date(byAdding: .day, value: -(weekday - 1), to: today) ?? today
        guard let selectedDate = calendar.date(byAdding: .day, value: selectedDayIndex, to: weekStart) else { return [] }

        let fmt = ISO8601DateFormatter()
        return studyEvents.filter { event in
            guard let date = fmt.date(from: event.startAt) else { return false }
            return calendar.isDate(date, inSameDayAs: selectedDate)
        }
    }

    var selectedDayClasses: [AgendaClassBlock] {
        classSchedule
            .filter { $0.dayOfWeek == selectedDayIndex }
            .sorted { $0.startTime < $1.startTime }
    }

    // Total planned minutes for the selected day (study items + classes)
    var selectedDayTotalMinutes: Int {
        let studyMins = selectedDayStudyItems.reduce(0) { $0 + $1.duration }
        let classMins = selectedDayClasses.reduce(0) { acc, cls in
            acc + minutesBetween(start: cls.startTime, end: cls.endTime)
        }
        return studyMins + classMins
    }

    var selectedDayClassCount: Int {
        selectedDayClasses.count + selectedDayEvents.filter { $0.eventType == "CLASS" }.count
    }

    var selectedDaySummary: String {
        let classes = selectedDayClassCount
        let minutes = selectedDayTotalMinutes
        var parts: [String] = []
        if classes > 0 {
            parts.append("\(classes) \(classes == 1 ? "aula" : "aulas")")
        }
        if minutes > 0 {
            parts.append("\(formatMinutes(minutes)) planejadas")
        }
        return parts.joined(separator: " · ")
    }

    // MARK: - Private helpers

    private func minutesBetween(start: String, end: String) -> Int {
        let parts = { (s: String) -> (Int, Int)? in
            let comps = s.split(separator: ":").compactMap { Int($0) }
            guard comps.count >= 2 else { return nil }
            return (comps[0], comps[1])
        }
        guard let s = parts(start), let e = parts(end) else { return 0 }
        return max(0, (e.0 * 60 + e.1) - (s.0 * 60 + s.1))
    }

    private func formatMinutes(_ total: Int) -> String {
        let h = total / 60
        let m = total % 60
        if h > 0 && m > 0 { return "\(h)h \(m)min" }
        if h > 0 { return "\(h)h" }
        return "\(m)min"
    }
}

// MARK: - Local model types

struct LocalStudyItem: Identifiable {
    var id: String
    var title: String
    var subject: String?
    var time: String
    var duration: Int
    var dayIndex: Int
    var completed: Bool

    var durationLabel: String {
        if duration >= 60 {
            let h = duration / 60
            let m = duration % 60
            return m > 0 ? "\(h)h \(m)min" : "\(h)h"
        }
        return "\(duration) min"
    }
}

