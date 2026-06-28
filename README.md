# Caloryn

Caloryn is a native iOS nutrition tracker built with SwiftUI and SwiftData. It combines fast daily meal logging, profile-based calorie and nutrient goals, reusable custom foods and recipes, Open Food Facts search and barcode lookup, optional Apple Health-powered calorie auto-adjustments, history, CSV export, and local-first storage with optional iCloud sync.

## Stack

- SwiftUI for the app UI and navigation
- SwiftData for local persistence
- CloudKit-backed SwiftData sync when iCloud sync is enabled
- Open Food Facts for product search, nutrition data, and barcode lookup
- Xcode project-based setup with no external package dependencies

## Features

- Onboarding for profile setup, activity level, calorie goal, macro ratio selection, and tracked nutrient selection
- Automatic BMR, daily calorie burn, calorie target, macro target, and editable nutrient goal calculation
- Day-based meal logging for breakfast, lunch, dinner, and multiple snack groups
- Open Food Facts product search, barcode lookup, serving-size fallback logic, Nutri-Score grades, and fruit/vegetable category inference
- Manual foods with calories, macros, optional nutrient fields, serving sizes, and fruit/vegetable variety tracking
- Recipe foods assembled from reusable ingredients with calculated calories, macros, fiber, and serving weight
- Daily calorie ring, macro progress, nutrient details, fruit/veg variety summary, optional Nutri-Score summary, and copy-yesterday flow
- Optional calorie auto-adjust mode, off by default, that learns from Apple Health Active Energy history on device
- History pattern discovery for 7-day, 14-day, 30-day, and 90-day ranges
- CSV export of logged food entries, theme preference, and optional iCloud sync toggle

## Project Structure

```text
Caloryn/
  Models/        SwiftData models and domain types
  Services/      Nutrition logic, food search, HealthKit integration, CSV export
  Views/         Onboarding, today, history, food log, settings
  Theme/         App theme, glass styles, appearance helpers
  Extensions/    Date and formatting helpers
  Assets.xcassets/
Caloryn.xcodeproj/
```

## Data Model

The app persists three main SwiftData models:

- `UserProfile`: user demographics, activity level, calorie target, and macro targets
- `FoodItem`: reusable food definitions, including barcode, serving info, nutrition per 100g, custom-food flags, recipe flags, Nutri-Score, and produce classification
- `FoodLogEntry`: logged portions for a specific date and meal slot, with nutrition values denormalized at write time

Recipes add a related `RecipeIngredient` model so recipe nutrition is stored from ingredient snapshots and can be logged like any other food.

## How It Works

- App entry starts in [`Caloryn/CalorynApp.swift`](Caloryn/CalorynApp.swift), where the SwiftData `ModelContainer` is configured with optional CloudKit sync.
- On first launch, users complete onboarding; afterwards the app opens into the main tab flow in [`Caloryn/ContentView.swift`](Caloryn/ContentView.swift).
- Daily logging lives in [`Caloryn/Views/Today/TodayView.swift`](Caloryn/Views/Today/TodayView.swift), with detailed nutrition totals in [`Caloryn/Views/Today/NutritionDetailsView.swift`](Caloryn/Views/Today/NutritionDetailsView.swift).
- Reusable manual foods and recipes live in [`Caloryn/Views/MyFoods/MyFoodsView.swift`](Caloryn/Views/MyFoods/MyFoodsView.swift).
- Food lookup is handled by [`Caloryn/Services/FoodSearchService.swift`](Caloryn/Services/FoodSearchService.swift), which queries Open Food Facts search and barcode endpoints.
- Goal calculation is centralized in [`Caloryn/Services/NutritionCalculator.swift`](Caloryn/Services/NutritionCalculator.swift), with activity budget adjustment logic in [`Caloryn/Services/ActivityCalorieBudget.swift`](Caloryn/Services/ActivityCalorieBudget.swift).

## Running The App

1. Open `Caloryn.xcodeproj` in Xcode.
2. Select the `Caloryn` scheme.
3. Run on an iOS Simulator or device.

Current project settings in the checked-in Xcode project:

- iOS deployment target: `26.0`
- Swift version: `5.0`
- App version: `1.9`
- Bundle identifier: `www.caloryn`

## Notes

- The app uses network calls to Open Food Facts, so search and barcode lookup require connectivity.
- SwiftData sync is configured to use CloudKit when the `iCloudSyncEnabled` preference is on.
- Calorie auto-adjust is opt-in, reads Apple Health Active Energy only, recalculates the activity baseline on device, and does not store Health samples in SwiftData.
- CSV export writes a temporary file and presents the native iOS share sheet.
