import SwiftUI

struct LibraryFoodDetailPane: View {
    let summary: LibraryFoodDetailSummary
    let onToggleFavorite: () -> Void
    let onAddToToday: () -> Void
    let onEdit: () -> Void

    @AppStorage("showNutriscore") private var showNutriscore = true
    @ScaledMetric(relativeTo: .title) private var nameSize: CGFloat = 26

    private static let figureShape = RoundedRectangle(cornerRadius: CalorynTheme.smallCornerRadius, style: .continuous)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                figures

                VStack(alignment: .leading, spacing: 6) {
                    FoodLogSectionTitle("Per 100 g")

                    FoodLogValueRows(
                        rows: summary.per100gLines.map { line in
                            FoodLogValueRows.Row(id: line.id, label: line.label, value: line.value)
                        }
                    )
                }

                actions
            }
            .padding(24)
            .calorynGroupSurface()
            .padding(.horizontal, CalorynTheme.pagePadding)
            .padding(.top, 8)
            .padding(.bottom, 24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollBounceBehavior(.basedOnSize)
        .accessibilityIdentifier("myFoods.detail")
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .center, spacing: 8) {
                    Text(summary.name)
                        .font(CalorynTypeface.fixed(size: nameSize, weight: .heavy))
                        .tracking(-nameSize * 0.005)
                        .foregroundStyle(CalorynTheme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityIdentifier("myFoods.detail.name")

                    LibraryTypeBadge(text: summary.typeBadge)

                    if showNutriscore, let grade = summary.nutriscoreGrade {
                        NutriscoreBadge(grade: grade)
                    }
                }

                Text(summary.portionLine)
                    .font(CalorynTypeface.text(.subheadline))
                    .foregroundStyle(CalorynTheme.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: onToggleFavorite) {
                Label(summary.favoriteActionLabel, systemImage: summary.isFavorite ? "star.fill" : "star")
                    .labelStyle(.iconOnly)
                    .font(CalorynTheme.inlineIcon)
                    .foregroundStyle(CalorynTheme.accent)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(summary.favoriteActionLabel)
            .accessibilityIdentifier("myFoods.detail.favorite")
        }
    }

    private var figures: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 110), spacing: 10)],
            alignment: .leading,
            spacing: 10
        ) {
            ForEach(summary.figures) { figure in
                VStack(alignment: .leading, spacing: 2) {
                    Text(figure.value)
                        .font(CalorynTheme.compactNumber)
                        .foregroundStyle(CalorynTheme.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Text(figure.label)
                        .font(CalorynTypeface.text(.footnote))
                        .foregroundStyle(CalorynTheme.textSecondary)
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(CalorynTheme.backgroundTertiary, in: Self.figureShape)
                .overlay {
                    Self.figureShape
                        .strokeBorder(CalorynTheme.separator, lineWidth: CalorynTheme.hairlineWidth)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    private var actions: some View {
        HStack(spacing: 10) {
            Button(action: onAddToToday) {
                Text("Add to Today")
            }
            .calorynPrimaryButton()
            .accessibilityIdentifier("myFoods.detail.addToToday")

            Button(action: onEdit) {
                Text("Edit")
                    .font(CalorynTheme.primaryButtonLabel)
                    .foregroundStyle(CalorynTheme.accent)
                    .frame(maxWidth: .infinity, minHeight: CalorynPrimaryButtonMetrics.height)
                    .overlay {
                        Capsule()
                            .strokeBorder(CalorynTheme.separator, lineWidth: CalorynTheme.hairlineWidth)
                    }
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("myFoods.detail.edit")
        }
    }
}

struct LibraryDetailPlaceholder: View {
    var body: some View {
        ContentUnavailableView {
            Label("Nothing selected", systemImage: "fork.knife")
        } description: {
            Text("Pick a food or recipe to see its nutrition here.")
                .foregroundStyle(CalorynTheme.textSecondary)
        }
        .foregroundStyle(CalorynTheme.textSecondary, CalorynTheme.textSecondary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("myFoods.detail.placeholder")
    }
}

struct LibraryRowBackground: View {
    let isSelected: Bool

    var body: some View {
        if isSelected {
            let shape = RoundedRectangle(cornerRadius: CalorynTheme.smallCornerRadius, style: .continuous)
            shape
                .fill(CalorynTheme.backgroundSecondary)
                .overlay {
                    shape.strokeBorder(CalorynTheme.accent.opacity(0.22), lineWidth: CalorynTheme.hairlineWidth)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
        } else {
            Color.clear
        }
    }
}
