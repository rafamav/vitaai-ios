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
        case .nameAZ:         return "textformat.abc"
        case .nameZA:         return "textformat.abc"
        case .mostFiles:      return "doc.on.doc.fill"
        }
    }
}

// MARK: - Folder Colors

enum FolderPalette {
    static let colors: [Color] = [
        Color(hex: 0x4FC3F7), // Light Blue
        Color(hex: 0x66BB6A), // Green
        Color(hex: 0xEF5350), // Red/Pink
        Color(hex: 0xFDD835), // Yellow
        Color(hex: 0xAB47BC), // Purple
        Color(hex: 0x26A69A), // Teal
    ]

    static func color(forIndex index: Int) -> Color {
        colors[index % colors.count]
    }
}

// MARK: - FlashcardDeckDisplayEntry
// Mirrors Android FlashcardDeck: id, name, cardCount, masteredCount, courseName

struct FlashcardDeckDisplayEntry: Identifiable {
    var id: String
    var name: String
    var cardCount: Int
    var masteredCount: Int
    var courseName: String

    var progress: Double {
        guard cardCount > 0 else { return 0 }
        return Double(masteredCount) / Double(cardCount)
    }
}

// MARK: - EstudosViewModel

@MainActor
@Observable
final class EstudosViewModel {
    private let api: VitaAPI

    // Tabs
    var selectedTab: EstudosTab = .disciplinas

    // Canvas connection state
    var canvasConnected: Bool = true

    // Disciplinas (raw from API/mock)
    var courses: [Course] = []

    // Flashcards tab — display entries (include progress)
    var flashcardDisplayDecks: [FlashcardDeckDisplayEntry] = []

    // PDFs
    var files: [CanvasFile] = []
    var downloadingFileId: String? = nil
    var downloadedFilePaths: [String: URL] = [:] // fileId -> local URL

    // Stats (retained from iOS-specific view)
    var flashcardsDue: Int = 0
    var streakDays: Int = 0
    var avgAccuracy: Double = 0

    // Simulados (iOS-specific)
    var simulados: [SimuladoEntry] = []

    // Documents (iOS-specific — PDF read progress)
    var documents: [DocumentEntry] = []

    // Notes (iOS-specific)
    var notes: [NoteEntry] = []

    // Study recommendations from dashboard API (Vita Sugere)
    var studyRecommendations: [DashboardRecommendation] = []

    // Recent activity feed (Sessoes Recentes)
    var recentActivity: [ActivityFeedItem] = []

    // Trabalhos pendentes (from /api/study/trabalhos)
    var trabalhosPending: [TrabalhoItem] = []
    var trabalhosOverdue: [TrabalhoItem] = []

    // State
    var isLoading = true
    var error: String? = nil

    // Selected course filter for PDFs tab
    var selectedCourseId: String? = nil

    // MARK: - Disciplinas Sort & Favorites

    var sortOption: CourseSortOption = .favoritesFirst
    var favoriteCourseIds: Set<String> = []

    /// Sorted courses based on current sort option, with favorites support.
    var sortedCourses: [Course] {
        let sorted: [Course]
        switch sortOption {
        case .favoritesFirst:
            sorted = courses.sorted { a, b in
                let aFav = favoriteCourseIds.contains(a.id)
                let bFav = favoriteCourseIds.contains(b.id)
                if aFav != bFav { return aFav }
                return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
            }
        case .nameAZ:
            sorted = courses.sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        case .nameZA:
            sorted = courses.sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedDescending
            }
        case .mostFiles:
            sorted = courses.sorted { $0.filesCount > $1.filesCount }
        }
        return sorted
    }

    func isFavorite(_ courseId: String) -> Bool {
        favoriteCourseIds.contains(courseId)
    }

    func toggleFavorite(_ courseId: String) {
        if favoriteCourseIds.contains(courseId) {
            favoriteCourseIds.remove(courseId)
        } else {
            favoriteCourseIds.insert(courseId)
        }
        saveFavorites()
    }

    // MARK: - Favorites Persistence (UserDefaults, scoped to user)

    private let userScopedFavoritesKey: String

    private func loadFavorites() {
        let stored = UserDefaults.standard.stringArray(forKey: userScopedFavoritesKey) ?? []
        favoriteCourseIds = Set(stored)
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
        isLoading = true
        error = nil

        do {
            async let progressTask  = api.getProgress()
            async let coursesTask   = api.getCourses()
            async let filesTask     = api.getFiles(courseId: selectedCourseId)
            async let decksTask     = api.getFlashcardDecks(dueOnly: false)
            async let dashboardTask = api.getDashboard()
            async let activityTask  = api.getActivityFeed(limit: 5)

            let (progressResp, coursesResp, filesResp, rawDecks) =
                try await (progressTask, coursesTask, filesTask, decksTask)

            // Dashboard recommendations (best-effort, don't fail main load)
            if let dashResp = try? await dashboardTask {
                // studyRecommendations removed — not in generated Dashboard type
            }
            if let activityResp = try? await activityTask {
                recentActivity = activityResp
            }


            flashcardsDue = progressResp.flashcardsDue
            streakDays    = progressResp.streakDays
            avgAccuracy   = progressResp.avgAccuracy

            canvasConnected = coursesResp.connected

            if !coursesResp.courses.isEmpty {
                courses = coursesResp.courses
            }

            if !filesResp.files.isEmpty {
                files = filesResp.files
            }

            if !rawDecks.isEmpty {
                flashcardDisplayDecks = rawDecks.map { deck in
                    FlashcardDeckDisplayEntry(
                        id: deck.id,
                        name: deck.title,
                        cardCount: deck.cards.count,
                        masteredCount: deck.cards.filter { $0.repetitions > 0 }.count,
                        courseName: courses.first(where: { $0.id == deck.subjectId })?.name ?? ""
                    )
                }
            }
        } catch {
            print("[EstudosViewModel] API error: \(error)")
            self.error = error.localizedDescription
        }

        // Trabalhos — independent of main load (best-effort)
        if let trabResp = try? await api.getTrabalhos() {
            trabalhosPending = trabResp.pending
            trabalhosOverdue = trabResp.overdue
        }

        isLoading = false
    }

    func selectTab(_ tab: EstudosTab) {
        selectedTab = tab
    }

    func selectCourse(_ courseId: String?) {
        selectedCourseId = courseId
        selectedTab = .pdfs
        Task { await reloadFiles() }
    }

    func clearCourseFilter() {
        selectedCourseId = nil
        Task { await reloadFiles() }
    }

    private func reloadFiles() async {
        isLoading = true
        do {
            let resp = try await api.getFiles(courseId: selectedCourseId)
            files = resp.files
        } catch {
            print("[EstudosViewModel] Files reload failed: \(error)")
        }
        isLoading = false
    }

    // MARK: - PDF Download

    func downloadFile(fileId: String, fileName: String) async -> URL? {
        guard downloadingFileId == nil else { return nil }
        downloadingFileId = fileId
        defer { downloadingFileId = nil }

        // Return cached path if already downloaded
        if let cached = downloadedFilePaths[fileId] {
            return cached
        }

        do {
            let data = try await api.downloadFileData(fileId: fileId)
            let dir = FileManager.default.temporaryDirectory.appendingPathComponent("pdfs", isDirectory: true)
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let dest = dir.appendingPathComponent(fileName)
            try data.write(to: dest)
            downloadedFilePaths[fileId] = dest
            return dest
        } catch {
            print("[EstudosViewModel] Download failed: \(error)")
            return nil
        }
    }

}

// MARK: - Local Models (Estudos-specific)

struct SimuladoEntry: Identifiable {
    var id: String
    var title: String
    var totalQ: Int
    var correctQ: Int
    var finishedAt: String?

    var scorePercent: Int {
        guard totalQ > 0 else { return 0 }
        return Int((Double(correctQ) / Double(totalQ)) * 100)
    }
}

struct DocumentEntry: Identifiable {
    var id: String
    var title: String
    var fileName: String
    var readProgress: Int
    var totalPages: Int
    var currentPage: Int
}

struct NoteEntry: Identifiable {
    var id: String
    var title: String
    var content: String
    var updatedAt: String
}
