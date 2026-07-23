import SwiftData
import SwiftUI

struct MyFoodsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FoodItem.name) private var foodItems: [FoodItem]

    @State private var showingManualEntryForm = false
    @State private var showingRecipeForm = false
    @State private var editingManualEntry: FoodItem?
    @State private var editingRecipe: FoodItem?
    @State private var favoriteErrorMessage: String?

    private var manualEntries: [FoodItem] {
        foodItems.filter { $0.isCustom && !$0.isRecipe }
    }

    private var recipes: [FoodItem] {
        foodItems.filter(\.isRecipe)
    }

    var body: some View {
        NavigationStack {
            List {
                manualEntriesSection
                recipesSection
            }
            .calorynGroupedListStyle()
            .navigationTitle("My Foods")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    createMenu
                }
            }
            .sheet(isPresented: $showingManualEntryForm) {
                CustomFoodFormView(onSaved: { _ in
                    showingManualEntryForm = false
                })
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showingRecipeForm) {
                RecipeFormView(onSaved: { _ in
                    showingRecipeForm = false
                })
                .presentationDragIndicator(.visible)
            }
            .sheet(item: $editingManualEntry) { food in
                CustomFoodFormView(existingFood: food)
                    .presentationDragIndicator(.visible)
            }
            .sheet(item: $editingRecipe) { recipe in
                RecipeFormView(existingRecipe: recipe)
                    .presentationDragIndicator(.visible)
            }
            .alert("Couldn’t Update Pin", isPresented: favoriteErrorIsPresented) {
                Button("OK", role: .cancel) {
                    favoriteErrorMessage = nil
                }
            } message: {
                Text(favoriteErrorMessage ?? "Please try again.")
            }
        }
        .calorynPageCanvas()
    }

    private var createMenu: some View {
        Menu {
            Button {
                showingManualEntryForm = true
            } label: {
                Label("Create Manual Entry", systemImage: "plus")
            }

            Button {
                showingRecipeForm = true
            } label: {
                Label("Create Recipe", systemImage: "list.bullet.rectangle")
            }
        } label: {
            Image(systemName: "plus")
                .font(CalorynTheme.toolbarIcon)
                .foregroundStyle(CalorynTheme.sage)
        }
        .accessibilityLabel("Create Food")
    }

    private var manualEntriesSection: some View {
        Section {
            if manualEntries.isEmpty {
                EmptyFoodGroupRow(
                    title: "No Manual Entries",
                    message: "Create foods you enter yourself.",
                    systemImage: "pencil.and.list.clipboard"
                )
            } else {
                ForEach(manualEntries) { food in
                    Button {
                        editingManualEntry = food
                    } label: {
                        manualEntryRow(for: food)
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .leading) {
                        favoriteButton(for: food)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            delete(food)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        } header: {
            Text("Manual Entries")
                .font(CalorynTheme.caption)
                .foregroundStyle(CalorynTheme.textSecondary)
        }
    }

    private var recipesSection: some View {
        Section {
            if recipes.isEmpty {
                EmptyFoodGroupRow(
                    title: "No Recipes",
                    message: "Create recipes from reusable ingredients.",
                    systemImage: "list.bullet.rectangle"
                )
            } else {
                ForEach(recipes) { recipe in
                    Button {
                        editingRecipe = recipe
                    } label: {
                        RecipeLibraryRow(recipe: recipe)
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .leading) {
                        favoriteButton(for: recipe)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            delete(recipe)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        } header: {
            Text("Recipes")
                .font(CalorynTheme.caption)
                .foregroundStyle(CalorynTheme.textSecondary)
        }
    }

    private func manualEntryRow(for food: FoodItem) -> some View {
        FoodRowView(
            name: food.name,
            brand: food.brand,
            caloriesPer100g: food.caloriesPer100g,
            nutriscoreGrade: food.nutriscoreGrade,
            servingDescription: food.servingDescription,
            caloriesPerServing: food.calories(forGrams: food.defaultServingG ?? 100),
            isCustom: true,
            showsTypeBadge: false
        )
        .contentShape(Rectangle())
    }

    private func delete(_ food: FoodItem) {
        food.deletePreservingLogEntrySnapshots(from: modelContext)
        try? modelContext.save()
    }

    private func favoriteButton(for food: FoodItem) -> some View {
        Button {
            togglePinned(food)
        } label: {
            Label(food.isPinned ? "Unpin" : "Pin", systemImage: food.isPinned ? "pin.slash" : "pin")
        }
        .tint(food.isPinned ? CalorynTheme.textSecondary : CalorynTheme.terracotta)
    }

    private func togglePinned(_ food: FoodItem) {
        do {
            try PinnedFoodLogging.setPinned(
                !food.isPinned,
                for: food,
                modelContext: modelContext
            )
        } catch {
            favoriteErrorMessage = "Your pin couldn’t be updated. Please try again."
        }
    }

    private var favoriteErrorIsPresented: Binding<Bool> {
        Binding(
            get: { favoriteErrorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    favoriteErrorMessage = nil
                }
            }
        )
    }
}

private struct EmptyFoodGroupRow: View {
    let title: String
    let message: String
    let systemImage: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(CalorynTheme.inlineIcon)
                .foregroundStyle(CalorynTheme.textSecondary)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(CalorynTheme.itemTitle)
                    .foregroundStyle(CalorynTheme.textPrimary)

                Text(message)
                    .font(CalorynTheme.caption)
                    .foregroundStyle(CalorynTheme.textSecondary)
            }
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
    }
}

private struct RecipeLibraryRow: View {
    let recipe: FoodItem

    private var totalGrams: Double {
        recipe.defaultServingG ?? 0
    }

    private var ingredientCount: Int {
        recipe.recipeIngredients?.count ?? 0
    }

    private var calories: Double {
        recipe.calories(forGrams: totalGrams)
    }

    private var protein: Double {
        recipe.protein(forGrams: totalGrams)
    }

    private var carbs: Double {
        recipe.carbs(forGrams: totalGrams)
    }

    private var fat: Double {
        recipe.fat(forGrams: totalGrams)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(recipe.name)
                    .font(CalorynTheme.itemTitle)
                    .foregroundStyle(CalorynTheme.textPrimary)
                    .lineLimit(1)

                Text(recipeDetail)
                    .font(CalorynTheme.caption)
                    .foregroundStyle(CalorynTheme.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 12)

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(Int(calories.rounded()))")
                    .font(CalorynTheme.numericBody)
                    .foregroundStyle(CalorynTheme.textPrimary)

                Text("kcal total")
                    .font(CalorynTheme.numericMicroCaption)
                    .foregroundStyle(CalorynTheme.textSecondary)
            }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private var recipeDetail: String {
        let ingredientLabel = ingredientCount == 1 ? "1 ingredient" : "\(ingredientCount) ingredients"
        let macroLabel = "\(protein.macroFormatted) P · \(carbs.macroFormatted) C · \(fat.macroFormatted) F"

        guard totalGrams > 0 else {
            return "\(ingredientLabel) · \(macroLabel)"
        }

        return "\(ingredientLabel) · \(Int(totalGrams.rounded()))g · \(macroLabel)"
    }
}

#Preview {
    MyFoodsView()
        .modelContainer(for: [UserProfile.self, FoodItem.self, FoodLogEntry.self, RecipeIngredient.self], inMemory: true)
}
