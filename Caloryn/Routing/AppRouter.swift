import Foundation
import Observation

enum AppTab: Hashable {
    case today
    case myFoods
    case history
    case settings
}

@MainActor
@Observable
final class AppRouter {
    static let shared = AppRouter()

    var selectedTab: AppTab = .today
    private(set) var pendingRoute: AppRoute?

    func handle(_ url: URL) {
        guard let route = AppRoute(url: url) else { return }
        navigate(to: route)
    }

    func navigate(to route: AppRoute) {
        selectedTab = .today
        pendingRoute = route
    }

    func consumePendingRoute() -> AppRoute? {
        defer { pendingRoute = nil }
        return pendingRoute
    }
}
