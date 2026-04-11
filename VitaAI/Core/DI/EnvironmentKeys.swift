import SwiftUI

private struct AppContainerKey: EnvironmentKey {
    @MainActor static let defaultValue: AppContainer = AppContainer()
}

private struct AppDataManagerKey: EnvironmentKey {
    @MainActor static let defaultValue: AppDataManager = AppDataManager(api: VitaAPI(client: HTTPClient(tokenStore: TokenStore())))
}

extension EnvironmentValues {
    var appContainer: AppContainer {
        get { self[AppContainerKey.self] }
        set { self[AppContainerKey.self] = newValue }
    }

    var appData: AppDataManager {
        get { self[AppDataManagerKey.self] }
        set { self[AppDataManagerKey.self] = newValue }
    }
}
