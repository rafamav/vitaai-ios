import Foundation

@MainActor
@Observable
final class LeaderboardViewModel {
    private let api: VitaAPI

    var entries: [LeaderboardEntry] = []
    var isLoading = true

    init(api: VitaAPI) {
        self.api = api
    }

    func load(period: String) async {
        isLoading = true
        do {
            entries = try await api.getLeaderboard(period: period)
        } catch {
            entries = []
        }
        isLoading = false
    }
}
