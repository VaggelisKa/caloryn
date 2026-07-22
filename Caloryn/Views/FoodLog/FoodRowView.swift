import SwiftUI

struct FoodRowView: View {
    let name: String
    let brand: String?
    let caloriesPer100g: Double
    var nutriscoreGrade: String? = nil
    var servingDescription: String? = nil
    var caloriesPerServing: Double? = nil
    var isCustom: Bool = false
    var isRecipe: Bool = false
    var showsTypeBadge: Bool = true
    var provenance: FoodProvenance? = nil

    @AppStorage("showNutriscore") private var showNutriscore = true

    private var subtitle: String? {
        guard !isRecipe else { return nil }

        var parts: [String] = []
        if let brand, !brand.isEmpty {
            parts.append(brand)
        }
        if let srv = servingDescription, !srv.isEmpty {
            parts.append(srv)
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(name)
                        .font(CalorynTheme.itemTitle)
                        .foregroundStyle(CalorynTheme.textPrimary)
                        .lineLimit(1)

                    if showsTypeBadge && (isCustom || isRecipe) {
                        Text(isRecipe ? "RECIPE" : "CUSTOM")
                            .font(CalorynTheme.badgeText)
                            .foregroundStyle(CalorynTheme.sage)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(CalorynTheme.sage.opacity(0.15), in: .capsule)
                    }

                    if showNutriscore, let grade = nutriscoreGrade {
                        NutriscoreBadge(grade: grade)
                    }
                }

                if let subtitle {
                    Text(subtitle)
                        .font(CalorynTheme.caption)
                        .foregroundStyle(CalorynTheme.textSecondary)
                        .lineLimit(1)
                }

                if let provenance, provenance.source != .userEntered {
                    HStack(spacing: 6) {
                        Label(provenance.source.shortLabel, systemImage: "checkmark.seal")

                        if provenance.recoveredByFallback {
                            Text("Recovered")
                        }

                        if let warning = provenance.completeness.warningLabel {
                            Label(warning, systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(CalorynTheme.terracotta)
                        }
                    }
                    .font(CalorynTheme.numericMicroCaption)
                    .foregroundStyle(CalorynTheme.textSecondary)
                    .lineLimit(1)
                }
            }

            Spacer()

            if let srvCal = caloriesPerServing {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(Int(srvCal.rounded()))")
                        .font(CalorynTheme.numericBody)
                        .foregroundStyle(CalorynTheme.textPrimary)
                    Text(isRecipe ? "kcal total" : "kcal/srv")
                        .font(CalorynTheme.numericMicroCaption)
                        .foregroundStyle(CalorynTheme.textSecondary)
                }
            } else {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(Int(caloriesPer100g.rounded()))")
                        .font(CalorynTheme.numericBody)
                        .foregroundStyle(CalorynTheme.textPrimary)
                    Text("kcal/100g")
                        .font(CalorynTheme.numericMicroCaption)
                        .foregroundStyle(CalorynTheme.textSecondary)
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    List {
        FoodRowView(name: "Rugbroed", brand: "Schulstad", caloriesPer100g: 210, servingDescription: "1 slice (45g)", caloriesPerServing: 94)
        FoodRowView(name: "Skyr", brand: "Arla", caloriesPer100g: 63, servingDescription: "170g")
        FoodRowView(name: "Chicken Breast", brand: nil, caloriesPer100g: 165)
        FoodRowView(name: "Nick's Pizza", brand: "Homemade", caloriesPer100g: 267, isCustom: true)
        FoodRowView(name: "Greek Salad", brand: nil, caloriesPer100g: 72, isRecipe: true)
    }
}
