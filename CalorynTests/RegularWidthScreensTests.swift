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

    // SwiftUI builds its accessibility tree only while accessibility automation is on. A
    // simulator that has run UI tests has it on; CI's fresh one does not, and every element
    // then reads as missing.
    override class func setUp() {
        super.setUp()
        guard let library = dlopen("/usr/lib/libAccessibility.dylib", RTLD_NOW),
              let setter = dlsym(library, "_AXSSetAutomationEnabled") else { return }
        typealias SetAutomationEnabled = @convention(c) (Int32) -> Void
        unsafeBitCast(setter, to: SetAutomationEnabled.self)(1)
    }

    override func tearDown() async throws {
        window?.isHidden = true
        window = nil
        try await super.tearDown()
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
            isRegular: true,
            readyWhen: "history.calorieTrend.card"
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
            isRegular: false,
            readyWhen: "history.calorieTrend.card"
        )

        XCTAssertNotNil(screen.element("history.calorieTrend.card"))
        XCTAssertNil(screen.element("history.calorieTrend.details"))
    }

    private func host(
        _ view: some View,
        fixture: UITestConfiguration.Fixture,
        size: CGSize,
        isRegular: Bool,
        readyWhen readyIdentifier: String? = nil
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

        let screen = HostedScreen(root: controller.view)
        if let readyIdentifier {
            let deadline = Date(timeIntervalSinceNow: 15)
            while screen.element(readyIdentifier) == nil, Date() < deadline {
                RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
            }
        }
        return screen
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
