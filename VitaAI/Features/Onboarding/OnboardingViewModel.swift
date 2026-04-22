import Foundation
import Observation

@MainActor
@Observable
final class OnboardingViewModel {
    private let tokenStore: TokenStore
    var api: VitaAPI?

    // MARK: - Navigation
    var isSaving = false
    var completionError: String?

    // MARK: - Welcome
    var nickname: String = ""
    var universityQuery: String = ""
    var selectedUniversity: University? = nil
    var selectedSemester: Int = 0
    var allUniversities: [University] = []

    // MARK: - Sync (shared between Connect → Syncing → Subjects → Done)
    var activeSyncId: String?
    var syncedSubjects: [SyncedSubject] = []
    var syncGrades: Int = 0
    var syncSchedule: Int = 0
    var syncCourses: Int = 0

    // MARK: - Subjects (difficulty selection — data from API)
    var subjectDifficulties: [String: String] = [:]  // subjectName → "fácil"|"medio"|"difícil"

    // MARK: - Derived

    var filteredUniversities: [University] {
        let query = universityQuery.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return [] }
        return allUniversities.filter { uni in
            uni.name.lowercased().contains(query) ||
            uni.shortName.lowercased().contains(query) ||
            uni.city.lowercased().contains(query)
        }
    }

    /// All distinct portal types derived from loaded universities (no hardcoded list)
    var allPortalTypes: [PortalTypeInfo] {
        var seen = Set<String>()
        var result: [PortalTypeInfo] = []
        for uni in allUniversities {
            if let portals = uni.portals {
                for p in portals where !p.portalType.isEmpty && !seen.contains(p.portalType) {
                    seen.insert(p.portalType)
                    result.append(PortalTypeInfo(type: p.portalType))
                }
            }
            // portals array from API is the source of truth
        }
        return result.sorted { $0.displayName < $1.displayName }
    }

    // MARK: - Init

    init(tokenStore: TokenStore, api: VitaAPI? = nil) {
        self.tokenStore = tokenStore
        self.api = api
        Task {
            if let name = await tokenStore.userName, !name.isEmpty {
                self.nickname = name.split(separator: " ").first.map(String.init) ?? name
            }
        }
    }

    func loadUniversities() async {
        guard let api else { return }
        do {
            let resp = try await api.getUniversities()
            allUniversities = resp.universities
        } catch {
            try? await Task.sleep(for: .seconds(2))
            if let resp = try? await api.getUniversities() {
                allUniversities = resp.universities
            }
        }
    }

    // MARK: - University

    func selectUniversity(_ university: University) {
        selectedUniversity = university
        universityQuery = university.shortName
    }

    func clearUniversity() {
        selectedUniversity = nil
        universityQuery = ""
    }

    func selectSemester(_ semester: Int) {
        selectedSemester = semester
    }

    // MARK: - Subjects

    func setDifficulty(_ subject: String, difficulty: String) {
        subjectDifficulties[subject] = difficulty
    }

    // MARK: - Sync results

    func setSyncId(_ syncId: String) {
        activeSyncId = syncId
    }

    /// Fetch subjects from API after sync (courses from Canvas or grades from WebAluno)
    func fetchSubjectsFromAPI() async {
        guard let api else { return }

        // Try Canvas courses first
        do {
            let coursesResp = try await api.getCourses()
            if !coursesResp.courses.isEmpty {
                syncedSubjects = coursesResp.courses.map { SyncedSubject(name: $0.name, source: "canvas") }
                syncCourses = coursesResp.courses.count
                return
            }
        } catch {
            print("[Onboarding] Canvas courses fetch failed: \(error)")
        }

        // Fallback: portal grades (subjects come from grade entries)
        do {
            let gradesResp = try await api.getGradesCurrent()
            let allSubjects = gradesResp.current + gradesResp.completed
            let uniqueSubjects = Set(allSubjects.map(\.subjectName).filter { !$0.isEmpty }).sorted()
            if !uniqueSubjects.isEmpty {
                syncedSubjects = uniqueSubjects.map { SyncedSubject(name: $0, source: "portal") }
                syncGrades = allSubjects.count
                return
            }
        } catch {
            print("[Onboarding] Portal grades fetch failed: \(error)")
        }

        // Fallback: agenda schedule
        do {
            let agenda = try await api.getAgenda()
            let uniqueSubjects = Set(agenda.schedule.map(\.subjectName).filter { !$0.isEmpty }).sorted()
            if !uniqueSubjects.isEmpty {
                syncedSubjects = uniqueSubjects.map { SyncedSubject(name: $0, source: "portal") }
            }
        } catch {
            print("[Onboarding] Agenda fetch failed: \(error)")
        }
    }

    // MARK: - Save

    /// Submits onboarding to backend FIRST. Only on 200 do we persist local state
    /// and emit the analytics event. If backend rejects, throws — the view stays on
    /// the onboarding screen so the user can retry. Never declare completion client-side
    /// ahead of server-acknowledged persistence (incident 2026-04-22 onboarding loop).
    func complete() async throws {
        isSaving = true
        completionError = nil
        defer { isSaving = false }

        let subjects = syncedSubjects.map(\.name)
        let data = OnboardingData(
            nickname: nickname.trimmingCharacters(in: .whitespaces),
            universityName: selectedUniversity?.shortName ?? "",
            universityState: selectedUniversity?.state ?? "",
            semester: selectedSemester,
            subjects: subjects,
            subjectDifficulties: subjectDifficulties
        )

        try await postOnboardingToBackend(data: data)

        // Backend acknowledged — safe to commit local + analytics.
        await tokenStore.saveOnboardingData(data)
        VitaPostHogConfig.capture(event: "onboarding_completed", properties: [
            "university_name": data.universityName,
            "semester": data.semester,
            "disciplines_count": subjects.count,
            "portal_connected": !syncedSubjects.isEmpty,
        ])
    }

    // MARK: - Backend Sync

    private func postOnboardingToBackend(data: OnboardingData) async throws {
        guard let api else {
            throw OnboardingCompletionError.apiUnavailable
        }

        let lms = selectedUniversity?.primaryPortal?.portalType
        let universityName: String? = {
            let name = data.universityName.trimmingCharacters(in: .whitespaces)
            return name.isEmpty ? nil : name
        }()

        let body = OnboardingPostRequest(
            moment: "graduacao",
            studyGoal: "graduacao",
            year: data.semester > 0 ? data.semester : nil,
            semester: data.semester > 0 ? data.semester : nil,
            highSchoolYear: nil,
            examBoard: nil,
            selectedSubjects: data.subjects.isEmpty ? nil : data.subjects,
            subjectDifficulties: data.subjectDifficulties.isEmpty ? nil : data.subjectDifficulties,
            university: universityName,
            universityLms: lms
        )

        // HTTPClient already retries 3x with exponential backoff for 5xx/network
        // errors and handles 401 with token refresh. Any error here means the
        // backend actually rejected (e.g. validation) — propagate so the caller
        // leaves the user on the onboarding screen instead of marking complete.
        try await api.postOnboarding(body)
    }
}

enum OnboardingCompletionError: LocalizedError {
    case apiUnavailable

    var errorDescription: String? {
        switch self {
        case .apiUnavailable:
            return "Não foi possível contatar o servidor. Tente novamente."
        }
    }
}

// MARK: - Synced Subject (from API)

struct SyncedSubject: Identifiable {
    var id: String { name }
    let name: String
    let source: String  // "canvas" | "webaluno"
}
