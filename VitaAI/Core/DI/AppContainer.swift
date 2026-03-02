import Foundation

@MainActor
final class AppContainer: ObservableObject {
    let tokenStore: TokenStore
    let httpClient: HTTPClient
    let api: VitaAPI
    let chatClient: VitaChatClient
    let authManager: AuthManager
    let notebookStore: NotebookStore

    init() {
        let tokenStore = TokenStore()
        let httpClient = HTTPClient(tokenStore: tokenStore)
        let api = VitaAPI(client: httpClient)
        let chatClient = VitaChatClient(tokenStore: tokenStore)
        let authManager = AuthManager(tokenStore: tokenStore)

        self.tokenStore = tokenStore
        self.httpClient = httpClient
        self.api = api
        self.chatClient = chatClient
        self.authManager = authManager
        self.notebookStore = NotebookStore()
    }
}
