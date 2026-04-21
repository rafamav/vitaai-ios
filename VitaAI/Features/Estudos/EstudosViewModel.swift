import Foundation
import SwiftUI

// MARK: - EstudosTab

enum EstudosTab: Int, CaseIterable {
    case disciplinas = 0
    case notebooks   = 1
    case mindMaps    = 2
    case flashcards  = 3
    case pdfs        = 4

    var title: String {
        switch self {
        case .disciplinas: return "Disciplinas"
        case .notebooks:   return "Notebooks"
        case .mindMaps:    return "Mapas"
        case .flashcards:  return "Flashcards"
        case .pdfs:        return "PDFs"
        }
    }
}

// MARK: - CourseSortOption

enum CourseSortOption: String, CaseIterable {
    case favoritesFirst = "favoritesFirst"
    case nameAZ         = "nameAZ"
    case nameZA         = "nameZA"
    case mostFiles      = "mostFiles"

    var label: String {
        switch self {
        case .favoritesFirst: return "Favoritos primeiro"
        case .nameAZ:         return "Nome (A-Z)"
        case .nameZA:         return "Nome (Z-A)"
        case .mostFiles:      return "Mais arquivos"
        }
    }

    var iconName: String {
        switch self {
        case .favoritesFirst: return "star.fill"
        case .nameAZ, .nameZA: return "textformat.abc"
        case .mostFiles:       return "doc.on.doc.fill"
        }
    }
}

// MARK: - Folder Colors

enum FolderPalette {
    static let colors: [Color] = [
        Color(hex: 0x4FC3F7), Color(hex: 0x66BB6A), Color(hex: 0xEF5350),
        Color(hex: 0xFDD835), Color(hex: 0xAB47BC), Color(hex: 0x26A69A),
    ]
    static func color(forIndex i: Int) -> Color { colors[i % colors.count] }
}

// MARK: - EstudosViewModel

@MainActor
@Observable
final class EstudosViewModel {
    private let api: VitaAPI
    var selectedTab: EstudosTab = .disciplinas
    var canvasConnected: Bool = true
    var subjects: [AcademicSubject] = []
    var dashboardSubjects: [DashboardSubject] = []
    var files: [CanvasFile] = []
    var downloadingFileId: String? = nil
    var downloadedFilePaths: [String: URL] = [:]
    var flashcardsDue: Int = 0
    var streakDays: Int = 0
    var avgAccuracy: Double = 0
    var simulados: [SimuladoEntry] = []
    var documents: [DocumentEntry] = []
    var notes: [NoteEntry] = []
    var studyRecommendations: [DashboardRecommendation] = []
    var recentActivity: [ActivityFeedItem] = []
    var trabalhosPending: [TrabalhoItem] = []
    var trabalhosOverdue: [TrabalhoItem] = []
    var isLoading = true
    var error: String? = nil
    var selectedCourseId: String? = nil
    var sortOption: CourseSortOption = .favoritesFirst
    var favoriteCourseIds: Set<String> = []

    var sortedSubjects: [AcademicSubject] {
        switch sortOption {
        case .favoritesFirst:
            return subjects.sorted { a, b in
                let aFav = favoriteCourseIds.contains(a.id)
                let bFav = favoriteCourseIds.contains(b.id)
                if aFav != bFav { return aFav }
                return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
            }
        case .nameAZ: return subjects.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .nameZA: return subjects.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedDescending }
        case .mostFiles: return subjects.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
    }

    func isFavorite(_ courseId: String) -> Bool { favoriteCourseIds.contains(courseId) }

    func toggleFavorite(_ courseId: String) {
        if favoriteCourseIds.contains(courseId) { favoriteCourseIds.remove(courseId) }
        else { favoriteCourseIds.insert(courseId) }
        saveFavorites()
    }

    private let userScopedFavoritesKey: String

    private func loadFavorites() {
        favoriteCourseIds = Set(UserDefaults.standard.stringArray(forKey: userScopedFavoritesKey) ?? [])
    }

    private func saveFavorites() {
        UserDefaults.standard.set(Array(favoriteCourseIds), forKey: userScopedFavoritesKey)
    }

    init(api: VitaAPI, userEmail: String? = nil) {
        self.api = api
        let scope = userEmail ?? "default"
        self.userScopedFavoritesKey = "estudos_favorite_course_ids_\(scope)"
        loadFavorites()
    }

    // MARK: - Load

    func load() async {
        isLoading = true; error = nil
        do {
            async let progressTask  = api.getProgress()
            async let subjectsTask  = api.getSubjects()
            async let filesTask     = api.getFiles(courseId: selectedCourseId)
            async let activityTask  = api.getActivityFeed(limit: 5)
            async let dashboardTask = api.getDashboard()
            let (progressResp, subjectsResp, filesResp) =
                try await (progressTask, subjectsTask, filesTask)
            if let r = try? await activityTask { recentActivity = r }
            if let dash = try? await dashboardTask { applyDashboard(dash) }
            flashcardsDue = progressResp.flashcardsDue
            streakDays    = progressResp.streakDays
            avgAccuracy   = progressResp.avgAccuracy
            if !subjectsResp.subjects.isEmpty { subjects = subjectsResp.subjects; canvasConnected = true }
            if !filesResp.files.isEmpty { files = filesResp.files }
            // rawDecks fetch removed 2026-04-21 — it was paired with
            // flashcardDisplayDecks (dead state, no View reads it) and the
            // 5.6MB payload was duplicated with FlashcardsListScreen's own
            // call. Local recommendations now fall back to the flashcardsDue
            // counter from progress.
            if studyRecommendations.isEmpty {
                buildLocalRecommendations(flashcardsDue: progressResp.flashcardsDue, decks: [])
            }
        } catch {
            print("[EstudosViewModel] API error: \(error)")
            self.error = error.localizedDescription
        }
        if let t = try? await api.getTrabalhos() {
            trabalhosPending = t.pending; trabalhosOverdue = t.overdue
        }
        isLoading = false
    }

    // MARK: - Dashboard integration

    private func applyDashboard(_ dash: Dashboard) {
        if let subs = dash.subjects, !subs.isEmpty {
            // vitaScore is computed server-side in /api/dashboard — just consume.
            dashboardSubjects = subs.sorted { ($0.vitaScore ?? 0) > ($1.vitaScore ?? 0) }
        }
        if let hero = dash.hero, !hero.isEmpty {
            studyRecommendations = hero.sorted { $0.urgency > $1.urgency }.prefix(6).map { card in
                DashboardRecommendation(
                    id: card.id, title: card.title, subtitle: card.subtitle,
                    dueCount: 0, deckId: card.action.id ?? "",
                    type: card.type.rawValue, urgency: card.urgency,
                    ctaText: card.cta.text, labelTone: card.labelTone.rawValue,
                    subjectName: card.pills.first?.text ?? ""
                )
            }
            return
        }
        if let subs = dash.subjects, !subs.isEmpty {
            studyRecommendations = buildSubjectRecommendations(
                subjects: subs, flashcardsDue: dash.flashcardsDueTotal ?? 0)
        }
    }

    private func buildSubjectRecommendations(subjects: [DashboardSubject], flashcardsDue: Int) -> [DashboardRecommendation] {
        var recs: [DashboardRecommendation] = []
        if flashcardsDue > 0 {
            recs.append(DashboardRecommendation(
                id: "flashcards-due", title: "Revisar Flashcards",
                subtitle: "\(flashcardsDue) cards pendentes de revisao",
                dueCount: flashcardsDue, deckId: "", type: "revision",
                urgency: 80, ctaText: "Revisar agora", labelTone: "warning", subjectName: "Flashcards"
            ))
        }
        for sub in subjects.filter({ $0.vitaScore != nil }).sorted(by: { ($0.vitaScore ?? 100) < ($1.vitaScore ?? 100) }).prefix(3) {
            let score = Int(sub.vitaScore ?? 50)
            let name = sub.name ?? sub.shortName ?? "Disciplina"
            let tone = score < 40 ? "danger" : score < 60 ? "warning" : "info"
            recs.append(DashboardRecommendation(
                id: "subject-\(name)", title: "Estudar \(name)",
                subtitle: score < 50 ? "VitaScore baixo — prioridade alta" : "Revisar conceitos",
                dueCount: 0, deckId: "", type: "revision",
                urgency: 100 - score, ctaText: "Estudar agora", labelTone: tone, subjectName: name
            ))
        }
        return recs
    }

    private func buildLocalRecommendations(flashcardsDue: Int, decks: [FlashcardDeckEntry]) {
        var recs: [DashboardRecommendation] = []
        for deck in decks.sorted(by: { $0.cards.count > $1.cards.count }).prefix(3) {
            let pending = deck.cards.filter { $0.repetitions == 0 }.count
            guard pending > 0 else { continue }
            recs.append(DashboardRecommendation(
                id: deck.id, title: deck.title,
                subtitle: "\(pending) cards para revisar",
                dueCount: pending, deckId: deck.id, type: "revision",
                urgency: 60, ctaText: "Revisar agora", labelTone: "info", subjectName: ""
            ))
        }
        if recs.isEmpty && flashcardsDue > 0 {
            recs.append(DashboardRecommendation(
                id: "flashcards-pending", title: "Revisar Flashcards",
                subtitle: "\(flashcardsDue) cards pendentes de revisao",
                dueCount: flashcardsDue, deckId: "", type: "revision",
                urgency: 70, ctaText: "Revisar agora", labelTone: "warning", subjectName: "Flashcards"
            ))
        }
        studyRecommendations = recs
    }

    func selectTab(_ tab: EstudosTab) { selectedTab = tab }

    func selectCourse(_ courseId: String?) {
        selectedCourseId = courseId; selectedTab = .pdfs
        Task { await reloadFiles() }
    }

    func clearCourseFilter() { selectedCourseId = nil; Task { await reloadFiles() } }

    private func reloadFiles() async {
        isLoading = true
        do { let r = try await api.getFiles(courseId: selectedCourseId); files = r.files }
        catch { print("[EstudosViewModel] Files reload: \(error)") }
        isLoading = false
    }

    func downloadFile(fileId: String, fileName: String) async -> URL? {
        guard downloadingFileId == nil else { return nil }
        downloadingFileId = fileId; defer { downloadingFileId = nil }
        if let cached = downloadedFilePaths[fileId] { return cached }
        do {
            let data = try await api.downloadFileData(fileId: fileId)
            let dir = FileManager.default.temporaryDirectory.appendingPathComponent("pdfs", isDirectory: true)
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let dest = dir.appendingPathComponent(fileName)
            try data.write(to: dest); downloadedFilePaths[fileId] = dest; return dest
        } catch {
            print("[EstudosViewModel] Download failed: \(error)")
            return nil
        }
    }

}

struct SimuladoEntry: Identifiable {
    var id: String; var title: String; var totalQ: Int; var correctQ: Int; var finishedAt: String?
    var scorePercent: Int {
        guard totalQ > 0 else { return 0 }
        return Int((Double(correctQ) / Double(totalQ)) * 100)
    }
}

struct DocumentEntry: Identifiable {
    var id: String; var title: String; var fileName: String
    var readProgress: Int; var totalPages: Int; var currentPage: Int
}

struct NoteEntry: Identifiable {
    var id: String; var title: String; var content: String; var updatedAt: String
}
