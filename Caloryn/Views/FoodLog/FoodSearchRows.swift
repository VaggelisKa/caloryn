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
                MealTemplateLibraryRow(template: meal, showsIcon: false)
            }
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
                    servingDescription: food.servingDescription
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
                    servingDescription: product.formattedServingDescription,
                    caloriesPerServing: product.caloriesPerServing
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
                Text(food.name)
                    .font(CalorynTheme.itemTitle)
                    .foregroundStyle(CalorynTheme.textPrimary)

                Spacer(minLength: 8)

                Text("\(suggestion.resolvedPortionGrams.rounded().truncatedSafely)g")
                    .font(CalorynTheme.numericBody)
                    .foregroundStyle(CalorynTheme.textPrimary)
            }
            .padding(.vertical, 4)
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
        .animation(selectionModeAnimation, value: isSelectingMultiple)
    }

    private func selectionIndicator(isSelected: Bool) -> some View {
        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
            .font(CalorynTheme.inlineIcon)
            .foregroundStyle(
                isSelected ? CalorynTheme.sage : CalorynTheme.textSecondary
            )
            .contentTransition(.symbolEffect(.replace))
            .scaleEffect(isSelected ? 1 : 0.94)
            .animation(selectionChangeAnimation, value: isSelected)
            .accessibilityHidden(true)
    }
}
