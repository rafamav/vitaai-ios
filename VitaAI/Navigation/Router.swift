import SwiftUI

@MainActor
@Observable
final class Router {
    var path = NavigationPath()
    var selectedTab: TabItem = .home
    var activeScreen: Route?
    var hideShell = false

    /// Mirror of `path` that keeps Route values accessible (NavigationPath is type-erased).
    private(set) var routeStack: [Route] = []
    var currentPath: [Route] { routeStack }

    func navigate(to route: Route) {
        path.append(route)
        routeStack.append(route)
    }

    func goBack() {
        guard !path.isEmpty else { return }
        path.removeLast()
        if !routeStack.isEmpty { routeStack.removeLast() }
    }

    func popToRoot() {
        path = NavigationPath()
        routeStack.removeAll()
    }
}
