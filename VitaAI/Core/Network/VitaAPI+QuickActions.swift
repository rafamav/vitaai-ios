import Foundation

// MARK: - Quick Actions API
// GET /api/chat/quick-actions — returns suggestions, study tools, about-you,
// connectors, and attachment options for VitaPlusSheet.

extension VitaAPI {
    func getChatQuickActions() async throws -> QuickActionsResponse {
        try await client.get("chat/quick-actions")
    }
}
