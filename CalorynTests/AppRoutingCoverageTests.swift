import Foundation
import Testing
@testable import Caloryn

/// Deep-link parsing and building for `AppRoute`, beyond the round trips in
/// `AppRouteTests`: every host, every malformed or unknown shape the system
/// could hand the app, and the meal labels the widget shows.
struct AppRouteParsingCoverageTests {
    private static func route(_ string: String) throws -> AppRoute? {
        AppRoute(url: try #require(URL(string: string)))
    }

    @Test("Each route builds the exact URL the widget links to", arguments: [
        (AppRoute.today, "caloryn://today"),
        (AppRoute.nutritionDetails, "caloryn://nutrition-details"),
        (AppRoute.addFood(meal: .dinner), "caloryn://add-food?meal=dinner"),
        (AppRoute.scanFood(meal: .snack), "caloryn://scan-food?meal=snack"),
        (AppRoute.addFood(meal: .breakfast), "caloryn://add-food?meal=breakfast"),
        (AppRoute.scanFood(meal: .lunch), "caloryn://scan-food?meal=lunch"),
    ])
    func routeBuildsItsURL(route: AppRoute, expected: String) throws {
        #expect(route.url.absoluteString == expected)
        #expect(try Self.route(expected) == route)
    }

    @Test("Well-formed links parse to their route", arguments: [
        ("caloryn://nutrition-details", AppRoute.nutritionDetails),
        ("CALORYN://TODAY", AppRoute.today),
        ("Caloryn://Nutrition-Details", AppRoute.nutritionDetails),
        ("caloryn://ADD-FOOD?meal=lunch", AppRoute.addFood(meal: .lunch)),
        ("caloryn://today?meal=lunch", AppRoute.today),
        ("caloryn://add-food?source=widget&meal=snack", AppRoute.addFood(meal: .snack)),
        ("caloryn://scan-food?meal=dinner&meal=lunch", AppRoute.scanFood(meal: .dinner)),
        ("caloryn://scan-food/extra/path?meal=breakfast", AppRoute.scanFood(meal: .breakfast)),
    ])
    func wellFormedLinkParses(link: String, expected: AppRoute) throws {
        #expect(try Self.route(link) == expected)
    }

    @Test("Malformed, unknown and foreign links are rejected", arguments: [
        "https://today",
        "calorynx://today",
        "calory://today",
        "caloryn://settings",
        "caloryn://history",
        "caloryn:today",
        "caloryn:///today",
        "caloryn://",
        "caloryn://scan-food",
        "caloryn://scan-food?meal=brunch",
        "caloryn://scan-food?meal=",
        "caloryn://add-food?meal=",
        "caloryn://add-food?dish=lunch",
        "caloryn://add-food?meal=Lunch",
        "caloryn://add-food?meal=%20lunch",
        "caloryn://add-food-now?meal=lunch",
    ])
    func malformedLinkIsRejected(link: String) throws {
        #expect(try Self.route(link) == nil)
    }

    @Test("Widget meals carry the label and symbol the widget draws", arguments: [
        (WidgetMeal.breakfast, "Breakfast", "sunrise.fill"),
        (WidgetMeal.lunch, "Lunch", "sun.max.fill"),
        (WidgetMeal.dinner, "Dinner", "moon.fill"),
        (WidgetMeal.snack, "Snack", "leaf.fill"),
    ])
    func widgetMealPresentation(meal: WidgetMeal, name: String, symbol: String) {
        #expect(meal.displayName == name)
        #expect(meal.systemImage == symbol)
        #expect(meal.id == meal.rawValue)
    }

    @Test("Widget meal identifiers are distinct so a list can key on them")
    func widgetMealIdentifiersAreDistinct() {
        #expect(Set(WidgetMeal.allCases.map(\.id)).count == WidgetMeal.allCases.count)
    }
}

/// `AppRouter` state transitions. Each test owns a fresh router — never the
/// shared one the hosted app is observing.
@MainActor
struct AppRouterStateCoverageTests {
    @Test("A fresh router starts on Today with nothing pending")
    func freshRouterHasNoPendingRoute() {
        let router = AppRouter()

        #expect(router.selectedTab == .today)
        #expect(router.pendingRoute == nil)
        #expect(router.consumePendingRoute() == nil)
    }

    @Test("Handling a valid link switches to Today and queues its route")
    func handlingValidLinkQueuesRoute() throws {
        let router = AppRouter()
        router.selectedTab = .settings

        router.handle(try #require(URL(string: "caloryn://scan-food?meal=lunch")))

        #expect(router.selectedTab == .today)
        #expect(router.pendingRoute == .scanFood(meal: .lunch))
    }

    @Test("Handling an invalid link leaves the tab and any pending route untouched")
    func handlingInvalidLinkChangesNothing() throws {
        let router = AppRouter()
        router.navigate(to: .addFood(meal: .dinner))
        router.selectedTab = .history

        router.handle(try #require(URL(string: "caloryn://add-food?meal=brunch")))
        router.handle(try #require(URL(string: "https://example.com/today")))

        #expect(router.selectedTab == .history)
        #expect(router.pendingRoute == .addFood(meal: .dinner))
    }

    @Test("A pending route is consumed exactly once")
    func pendingRouteIsConsumedOnce() {
        let router = AppRouter()
        router.navigate(to: .nutritionDetails)

        #expect(router.consumePendingRoute() == .nutritionDetails)
        #expect(router.pendingRoute == nil)
        #expect(router.consumePendingRoute() == nil)
    }

    @Test("A newer navigation replaces one that was never consumed")
    func latestNavigationWins() {
        let router = AppRouter()
        router.navigate(to: .addFood(meal: .breakfast))
        router.selectedTab = .myFoods
        router.navigate(to: .today)

        #expect(router.selectedTab == .today)
        #expect(router.consumePendingRoute() == .today)
    }
}
