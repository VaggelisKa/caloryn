# Caloryn

Caloryn is a native iOS nutrition tracker built with SwiftUI and SwiftData. It combines fast daily meal logging, profile-based calorie and nutrient goals, reusable custom foods and recipes, Open Food Facts search and barcode lookup, optional Apple Health-powered calorie auto-adjustments, history pattern discovery, home screen widgets, daily reminders, CSV export, and local-first storage with optional iCloud sync.

## Stack

- SwiftUI for the app UI and navigation, WidgetKit for the home screen widgets, App Intents for the daily reminder and Siri/Shortcuts actions
- SwiftData for local persistence, with CloudKit-backed sync when iCloud sync is enabled
- Bounded Caloryn API → Open Food Facts failover for product search and barcode lookup
- Xcode project-based setup (synchronized groups, no `project.pbxproj` edits needed for new source files); one Swift Package dependency, [swift-snapshot-testing](https://github.com/pointfreeco/swift-snapshot-testing), used only by the test targets

## Features

- Onboarding for profile setup, activity level, calorie goal, macro ratio selection, and tracked nutrient selection
- Automatic BMR, daily calorie burn, calorie target, macro target, and editable nutrient goal calculation
- Day-based meal logging for breakfast, lunch, dinner, and multiple snack groups, plus reusable meal templates
- Open Food Facts product search, barcode lookup, serving-size fallback logic, Nutri-Score grades, and fruit/vegetable category inference
- Manual foods with calories, macros, optional nutrient fields, serving sizes, and fruit/vegetable variety tracking
- Recipe foods assembled from reusable ingredients with calculated calories, macros, fiber, and serving weight
- Daily calorie ring, macro progress, nutrient details, fruit/veg variety summary, optional Nutri-Score summary, and copy-yesterday flow
- Optional calorie auto-adjust mode, off by default, that learns from Apple Health Active Energy history on device
- History pattern discovery for 7-day, 14-day, 30-day, and 90-day ranges: calorie trend, goal consistency, weekly consistency, and macro patterns
- Home screen widgets (Daily Progress, Quick Log) backed by an App Group snapshot, kept in sync with the main app's data
- Configurable daily logging reminder, skipped automatically once enough calories are already logged
- CSV export of logged food entries, theme preference, and optional iCloud sync toggle

## Project Structure

```text
Caloryn/            Main app target
  Models/            SwiftData models and plain-struct view state (drafts, selections, summaries)
  Services/          Nutrition logic, food search, HealthKit integration, widget sync, reminders, CSV export
  Views/             Onboarding, today, history, food log, my foods, settings
  Routing/           App-wide navigation router
  AppIntents/        Siri/Shortcuts and widget-triggered intents
  Theme/             App theme, glass styles, appearance helpers
  Extensions/        Date and formatting helpers
  Debug/             DEBUG-only UI test seeding and fixtures
  Assets.xcassets/
CalorynShared/       Code and Color Sets shared between the app and the widget extension (App Group model, theme colors)
CalorynWidgets/      WidgetKit extension (Daily Progress, Quick Log)
CalorynTests/        Unit test target (Swift Testing)
CalorynUITests/      End-to-end journey tests (XCTest)
docs/                ADRs, theming, and testing strategy notes
scripts/             Developer tooling (e.g. theme screenshot audit)
Caloryn.xcodeproj/
```

## Data Model

The app persists SwiftData models including:

- `UserProfile`: user demographics, activity level, calorie target, and macro targets
- `FoodItem`: reusable food definitions, including barcode, serving info, nutrition per 100g, provenance/completeness, custom-food flags, recipe flags, Nutri-Score, and produce classification
- `FoodLogEntry`: logged portions for a specific date and meal slot, with nutrition values and provenance denormalized at write time
- `MealTemplate` / `MealTemplateItem`: reusable groups of foods that can be logged together
- `DailyGoalSnapshot`: per-day snapshot of the active calorie/macro goals, used so History stays accurate after goals change

Recipes add a related `RecipeIngredient` model so recipe nutrition is stored from ingredient snapshots and can be logged like any other food.

## How It Works

- App entry starts in [`Caloryn/CalorynApp.swift`](Caloryn/CalorynApp.swift), where the SwiftData `ModelContainer` is configured with optional CloudKit sync.
- On first launch, users complete onboarding; afterwards the app opens into the main tab flow in [`Caloryn/ContentView.swift`](Caloryn/ContentView.swift).
- Daily logging lives in [`Caloryn/Views/Today/TodayView.swift`](Caloryn/Views/Today/TodayView.swift), with detailed nutrition totals in [`Caloryn/Views/Today/NutritionDetailsView.swift`](Caloryn/Views/Today/NutritionDetailsView.swift).
- Reusable manual foods and recipes live in [`Caloryn/Views/MyFoods/MyFoodsView.swift`](Caloryn/Views/MyFoods/MyFoodsView.swift).
- Food lookup is handled by [`Caloryn/Services/FoodSearchService.swift`](Caloryn/Services/FoodSearchService.swift), which applies the bounded provider policy documented in [`docs/adr/0002-food-provider-failover.md`](docs/adr/0002-food-provider-failover.md).
- Goal calculation is centralized in [`Caloryn/Services/NutritionCalculator.swift`](Caloryn/Services/NutritionCalculator.swift), with activity budget adjustment logic in [`Caloryn/Services/ActivityCalorieBudget.swift`](Caloryn/Services/ActivityCalorieBudget.swift).
- History pattern discovery is a pure Swift analytics layer in [`Caloryn/Services/HistoryAnalytics.swift`](Caloryn/Services/HistoryAnalytics.swift) and [`Caloryn/Services/HistoryPatternDiscovery.swift`](Caloryn/Services/HistoryPatternDiscovery.swift); see [`docs/adr/0001-history-pattern-discovery.md`](docs/adr/0001-history-pattern-discovery.md) for the design rationale.
- Widgets read a projected snapshot written by [`Caloryn/Services/DailyWidgetSnapshotProjector.swift`](Caloryn/Services/DailyWidgetSnapshotProjector.swift) into the shared App Group container defined in `CalorynShared/`.

## Running The App

1. Open `Caloryn.xcodeproj` in Xcode.
2. Select the `Caloryn` scheme.
3. Run on an iOS Simulator or device.

Current project settings in the checked-in Xcode project:

- Deployment target: **iOS 18.6**, built against the iOS 26 SDK — `#available(iOS 26.0, *)` checks are live in the codebase
- Swift version: `5.0`
- App version: `1.15`
- Bundle identifier: `www.caloryn`

## Contributing

Start with [`CLAUDE.md`](CLAUDE.md) — it's the source of truth for test commands, testing rules (behavior over structure, small-bug-fix vs. characterization-test policy), theming rules, and CI notes, and applies to any contributor, human or agent. [`CONTEXT.md`](CONTEXT.md) documents the product's domain language (naming to use and avoid) for the History feature. Design decisions with lasting rationale live in [`docs/adr/`](docs/adr).

Quick pointers:

- Run tests with `xcodebuild test`, see [`CLAUDE.md`](CLAUDE.md) for the exact invocation and available test plans (`Caloryn-Unit`, `Caloryn-UI`, `Caloryn-All`).
- View-facing logic belongs in a plain struct under `Caloryn/Models/` (see `GoalEditDraft`, `CustomFoodDraft`, `PortionSelection`), not a ViewModel layer.
- Colors and list/form backgrounds must come from `CalorynTheme` and the shared style helpers — see [`docs/theme.md`](docs/theme.md) and rule 6 in `CLAUDE.md`.
- UI tests find elements by accessibility identifier; adding an identifier is the only production change those tests may make.

## Notes

- The app uses network calls to the Caloryn API and Open Food Facts, so search and barcode lookup require connectivity.
- SwiftData sync is configured to use CloudKit when the `iCloudSyncEnabled` preference is on.
- Calorie auto-adjust is opt-in, reads Apple Health Active Energy only, recalculates the activity baseline on device, and does not store Health samples in SwiftData.
- Widgets and the daily reminder read from an App Group snapshot rather than opening the main SwiftData store directly.
- CSV export writes a temporary file and presents the native iOS share sheet.

## License

Apache License 2.0 — see [`LICENSE`](LICENSE).
