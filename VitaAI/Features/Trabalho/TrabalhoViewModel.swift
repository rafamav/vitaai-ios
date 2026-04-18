import Foundation
import SwiftUI

// MARK: - TrabalhoViewModel

@MainActor
@Observable
final class TrabalhoViewModel {
    private let api: VitaAPI

    var pending: [TrabalhoItem] = []
    var completed: [TrabalhoItem] = []
    var overdue: [TrabalhoItem] = []
    var grades: [GradeEntry] = []
    var total: Int = 0
    var selectedSegment: Int = 0
    var isLoading: Bool = true

    init(api: VitaAPI) {
        self.api = api
    }

    // MARK: - Load

    func load() async {
        isLoading = true

        async let trabalhosTask: Void = fetchTrabalhos()
        async let gradesTask: Void = fetchGrades()
        _ = await (trabalhosTask, gradesTask)

        isLoading = false
    }

    private func fetchTrabalhos() async {
        do {
            let response = try await api.getTrabalhos()
            pending = response.pending
            completed = response.completed
            overdue = response.overdue
            total = response.total
        } catch {
            print("[TrabalhoViewModel] trabalhos error: \(error)")
        }
    }

    private func fetchGrades() async {
        do {
            let allSubjects = try await api.getSubjects().subjects
            if !allSubjects.isEmpty {
                grades = allSubjects.compactMap { gs -> GradeEntry? in
                    let value: Double
                    if let final_ = gs.finalGrade {
                        value = final_
                    } else {
                        let available = [gs.grade1, gs.grade2, gs.grade3].compactMap { $0 }
                        guard !available.isEmpty else { return nil }
                        value = available.reduce(0, +) / Double(available.count)
                    }
                    return GradeEntry(
                        id: UUID().uuidString,
                        userId: "",
                        subjectId: gs.displayName,
                        label: gs.displayName,
                        value: value,
                        maxValue: 10.0,
                        notes: gs.status ?? "",
                        date: nil
                    )
                }
                return
            }
        } catch {
            print("[TrabalhoViewModel] subjects fallback: \(error)")
        }

        do {
            let entries = try await api.getGrades(limit: 30)
            if !entries.isEmpty { grades = entries }
        } catch {
            print("[TrabalhoViewModel] grades fallback: \(error)")
        }
    }

    // MARK: - Dismiss (archive)

    func dismiss(_ item: TrabalhoItem) {
        withAnimation {
            pending.removeAll { $0.id == item.id }
            overdue.removeAll { $0.id == item.id }
            completed.removeAll { $0.id == item.id }
        }
        // Fire-and-forget backend call
        Task {
            try? await api.dismissTrabalho(id: item.id)
        }
    }

    var sortedGrades: [GradeEntry] {
        grades.sorted {
            let lhs = $0.date ?? ""
            let rhs = $1.date ?? ""
            return lhs > rhs
        }
    }
}
