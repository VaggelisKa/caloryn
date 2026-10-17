import SwiftUI

/// The rows of `FoodSearchView`'s two lists.
///
/// Pure rendering, split out of `FoodSearchView.swift` for size. Every row is
/// a `Button` wrapping a `selectionRow`, which reserves space for the
/// multi-selection tick only while selection mode is active. Nothing here
/// decides anything: what to show and what a tap does are answered by the
/// models and handlers the main file owns.
extension FoodSearchView {

    /// One saved meal, in either list.
    ///
    /// Both lists had their own copy of this and only the resting one carried
    /// the identifier, so a journey could tick a meal from Recent but not from
    /// search results. One builder is what keeps that from drifting apart
    /// again.
    func mealRow(for meal: MealTemplate) -> some View {
        Button {
            handleMealSelection(meal)
        } label: {
            selectionRow(isSelected: isSelected(.meal(meal.id))) {
                savedMealRow(meal)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityValue(selectionAccessibilityValue(for: .meal(meal.id)))
        .accessibilityIdentifier("meal.select.\(meal.id.uuidString)")
    }

    func personalFoodRow(for food: FoodItem) -> some View {
        Button {
            handleFoodItemSelection(food)
        } label: {
            selectionRow(isSelected: isSelected(.food(food.id))) {
                FoodRowView(
                    name: food.name,
                    brand: food.brand,
                    caloriesPer100g: food.caloriesPer100g,
                    nutriscoreGrade: food.nutriscoreGrade,
                    servingDescription: food.servingDescription,
                    servingGrams: food.defaultServingG,
                    isCustom: true,
                    showsTypeBadge: false
                )
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityValue(selectionAccessibilityValue(for: .food(food.id)))
        .accessibilityIdentifier("foodSearch.result.\(food.name)")
    }

    func recipeRow(for food: FoodItem) -> some View {
        Button {
            handleFoodItemSelection(food)
        } label: {
            selectionRow(isSelected: isSelected(.food(food.id))) {
                FoodRowView(
                    name: food.name,
                    brand: food.brand,
                    caloriesPer100g: food.caloriesPer100g,
                    caloriesPerServing: food.calories(forGrams: food.defaultServingG ?? 100),
                    isRecipe: true,
                    showsTypeBadge: false
                )
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityValue(selectionAccessibilityValue(for: .food(food.id)))
        .accessibilityIdentifier("foodSearch.result.\(food.name)")
    }

    func savedFoodRow(for food: FoodItem) -> some View {
        Button {
            handleFoodItemSelection(food)
        } label: {
            selectionRow(isSelected: isSelected(.food(food.id))) {
                FoodRowView(
                    name: food.name,
                    brand: food.brand,
                    caloriesPer100g: food.caloriesPer100g,
                    nutriscoreGrade: food.nutriscoreGrade,
                    servingDescription: food.servingDescription,
                    servingGrams: food.defaultServingG
                )
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityValue(selectionAccessibilityValue(for: .food(food.id)))
        .accessibilityIdentifier("foodSearch.result.\(food.name)")
    }

    func remoteProductRow(_ result: FoodSearchResult) -> some View {
        let product = result.product
        let productName = product.productName ?? "Unknown"
        // The serving the product is saved with, so the row prices what the Portion sheet
        // opens on. A serving size with no weight anywhere is still shown, unpriced.
        let serving = product.effectiveServingInfo

        return Button {
            handleProductSelection(result)
        } label: {
            selectionRow(
                isSelected: isSelected(.remoteProduct(product.id))
            ) {
                FoodRowView(
                    name: productName,
                    brand: product.brands,
                    caloriesPer100g: product.nutriments?.energyKcal100g ?? 0,
                    nutriscoreGrade: product.nutritionGrades.flatMap { grade in
                        ["a", "b", "c", "d", "e"].contains(grade.lowercased())
                            ? grade.lowercased()
                            : nil
                    },
                    servingDescription: serving.servingDescription ?? product.formattedServingDescription,
                    servingGrams: serving.defaultServingG
                )
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityValue(
            selectionAccessibilityValue(for: .remoteProduct(product.id))
        )
        .accessibilityIdentifier("foodSearch.result.\(productName)")
    }

    func contextualSuggestionRow(
        food: FoodItem,
        suggestion: ContextualFoodSuggestion
    ) -> some View {
        Button {
            if isSelectingMultiple {
                toggleFoodSelection(food)
            } else {
                // A single tap goes where every other single tap goes — the
                // portion picker, seeded with the suggested amount. The review
                // sheet is for a batch, and reading as one for a single food
                // was the confusion.
                selectedFoodItem = PortionDestination(
                    food: food,
                    suggestedPortionGrams: suggestion.resolvedPortionGrams
                )
            }
        } label: {
            selectionRow(
                isSelected: isSelected(.food(food.id)),
                spacing: 12
            ) {
                FoodRowView(
                    name: food.name,
                    brand: food.brand,
                    caloriesPer100g: food.caloriesPer100g,
                    nutriscoreGrade: food.nutriscoreGrade,
                    isCustom: food.isManualEntry,
                    isRecipe: food.isRecipe,
                    portionGrams: suggestion.resolvedPortionGrams,
                    portionCalories: food.calories(forGrams: suggestion.resolvedPortionGrams)
                )
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            "\(food.name), suggested \(suggestion.resolvedPortionGrams.rounded().truncatedSafely) grams"
        )
        .accessibilityValue(selectionAccessibilityValue(for: .food(food.id)))
        .accessibilityHint(
            isSelectingMultiple
                ? "Double tap to \(isSelected(.food(food.id)) ? "remove" : "select") this item"
                : "Double tap to adjust its portion"
        )
        .accessibilityIdentifier("contextualSuggestions.food.\(food.id.uuidString)")
    }

    func selectionRow<Content: View>(
        isSelected: Bool,
        spacing: CGFloat = 10,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(spacing: 0) {
            selectionIndicator(isSelected: isSelected)
                .frame(
                    width: selectionIndicatorWidth,
                    alignment: .leading
                )
                .opacity(isSelectingMultiple ? 1 : 0)
                .scaleEffect(
                    isSelectingMultiple ? 1 : 0.82,
                    anchor: .leading
                )
                .frame(
                    width: isSelectingMultiple
                        ? selectionIndicatorWidth + spacing
                        : 0,
                    alignment: .leading
                )
                .clipped()

            content()
        }
        // Every hairline runs from the row's leading margin. Left to itself the separator
        // starts under the first text, which in selection mode is the name after the tick,
        // and only the rows laid out after the mode changed moved over.
        .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
        .animation(selectionModeAnimation, value: isSelectingMultiple)
    }

    private func selectionIndicator(isSelected: Bool) -> some View {
        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
            .font(CalorynTheme.inlineIcon)
            .foregroundStyle(
                isSelected ? CalorynTheme.textPrimary : CalorynTheme.textSecondary
            )
            .contentTransition(.symbolEffect(.replace))
            .scaleEffect(isSelected ? 1 : 0.94)
            .animation(selectionChangeAnimation, value: isSelected)
            .accessibilityHidden(true)
    }

    /// A saved meal as a food row: its name, "Saved meal, 3 items", and what logging the
    /// whole meal adds.
    private func savedMealRow(_ meal: MealTemplate) -> some View {
        let snapshots = (try? MealTemplateCommands.snapshots(for: meal)) ?? []

        return FoodRowView(
            name: meal.name,
            brand: nil,
            caloriesPer100g: 0,
            detail: FoodLogSheetCopy.savedMealDetail(itemCount: snapshots.count),
            portionCalories: snapshots.reduce(0) { $0 + $1.nutrition.calories }
        )
    }
}
