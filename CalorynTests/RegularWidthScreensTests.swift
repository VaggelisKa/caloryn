import SwiftData
import SwiftUI
import UIKit
import XCTest
@testable import Caloryn

@MainActor
final class RegularWidthScreensTests: XCTestCase {
    private static let tallTablet = CGSize(width: 1032, height: 1376)
    private static let phone = CGSize(width: 402, height: 874)

    private var window: UIWindow?

    override func tearDown() {
        window?.isHidden = true
        window = nil
        super.tearDown()
    }

    func testMyFoodsOnATallTabletShowsTheFirstFavouriteBesideTheList() throws {
        let screen = try host(MyFoodsView(), fixture: .customFoods, size: Self.tallTablet, isRegular: true)

        XCTAssertEqual(screen.label(of: "myFoods.detail.name"), "Morning Smoothie")
        XCTAssertNotNil(screen.element("myFoods.detail.addToToday"))
        XCTAssertNotNil(screen.element("myFoods.food.House Salad"))
    }

    func testMyFoodsOnAPhoneKeepsTheListAlone() throws {
        let screen = try host(MyFoodsView(), fixture: .customFoods, size: Self.phone, isRegular: false)

        XCTAssertNotNil(screen.element("myFoods.food.Morning Smoothie"))
        XCTAssertNil(screen.element("myFoods.detail"))
    }

    func testSettingsOnATallTabletListsTheSectionsBesideTheChosenOne() throws {
        let screen = try host(SettingsView(), fixture: .loggedDay, size: Self.tallTablet, isRegular: true)

        XCTAssertEqual(screen.traits(of: "settings.section.goal")?.contains(.selected), true)
        XCTAssertNotNil(screen.element("settings.section.about"))
        XCTAssertNotNil(screen.element("settings.calorieTarget"))
        XCTAssertNil(screen.element("settings.editProfile"))
    }

    func testSettingsOnAPhoneKeepsOneList() throws {
        let screen = try host(SettingsView(), fixture: .loggedDay, size: Self.phone, isRegular: false)

        XCTAssertNotNil(screen.element("settings.calorieTarget"))
        XCTAssertNil(screen.element("settings.section.goal"))
    }

    func testHistoryOnATallTabletShowsTheCalorieTrendBesideThePage() throws {
        let router = AppRouter()
        router.selectedTab = .history
        let screen = try host(
            HistoryView().environment(router),
            fixture: .historyPattern,
            size: Self.tallTablet,
            isRegular: true
        )

        XCTAssertNotNil(screen.element("history.calorieTrend.card"))
        XCTAssertNotNil(screen.element("history.calorieTrend.details"))
    }

    func testHistoryOnAPhoneKeepsTheDetailForItsOwnPage() throws {
        let router = AppRouter()
        router.selectedTab = .history
        let screen = try host(
            HistoryView().environment(router),
            fixture: .historyPattern,
            size: Self.phone,
            isRegular: false
        )

        XCTAssertNotNil(screen.element("history.calorieTrend.card"))
        XCTAssertNil(screen.element("history.calorieTrend.details"))
    }

    private func host(
        _ view: some View,
        fixture: UITestConfiguration.Fixture,
        size: CGSize,
        isRegular: Bool
    ) throws -> HostedScreen {
        let container = try ModelContainer(
            for: Schema([
                UserProfile.self,
                FoodItem.self,
                FoodLogEntry.self,
                RecipeIngredient.self,
                DailyGoalSnapshot.self,
                MealTemplate.self,
                MealTemplateItem.self,
            ]),
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
        )
        try UITestSeeder.seed(fixture, into: container.mainContext)

        let controller = UIHostingController(rootView: view.modelContainer(container))
        controller.traitOverrides.horizontalSizeClass = isRegular ? .regular : .compact
        controller.traitOverrides.verticalSizeClass = .regular
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(origin: .zero, size: size)
        window.rootViewController = controller
        window.isHidden = false
        self.window = window
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 2))

        return HostedScreen(root: controller.view)
    }
}

@MainActor
private struct HostedScreen {
    let root: UIView

    func element(_ identifier: String) -> NSObject? {
        Self.find(identifier, in: root, depth: 0)
    }

    func label(of identifier: String) -> String? {
        element(identifier)?.accessibilityLabel
    }

    func traits(of identifier: String) -> UIAccessibilityTraits? {
        element(identifier)?.accessibilityTraits
    }

    private static func find(_ identifier: String, in object: NSObject, depth: Int) -> NSObject? {
        guard depth < 60 else { return nil }
        if object.responds(to: #selector(getter: UIAccessibilityIdentification.accessibilityIdentifier)),
           object.value(forKey: "accessibilityIdentifier") as? String == identifier {
            return object
        }
        for child in children(of: object) {
            if let match = find(identifier, in: child, depth: depth + 1) {
                return match
            }
        }
        return nil
    }

    private static func children(of object: NSObject) -> [NSObject] {
        var result: [NSObject] = []
        if let elements = object.accessibilityElements as? [NSObject] {
            result += elements
        } else {
            let count = object.accessibilityElementCount()
            if count != NSNotFound, count > 0 {
                result += (0 ..< count).compactMap { object.accessibilityElement(at: $0) as? NSObject }
            }
        }
        if let view = object as? UIView {
            result += view.subviews
        }
        return result
    }
}
