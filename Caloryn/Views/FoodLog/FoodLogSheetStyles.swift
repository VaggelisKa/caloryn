import SwiftUI

// The pieces the food-log sheets share — Portion, the multi-add portion editor and the
// ingredient amount picker — so the three read as one sheet in three uses
// (`docs/design/plate-market.md`, "Portion sheet"). Every colour comes from `CalorynTheme`.

/// A sheet's inline title in 17pt bold ink, for the toolbar's principal slot. The system
/// title draws in its own label colour, which is not the palette's ink.
struct FoodLogSheetTitle: View {
    let title: String

    var body: some View {
        Text(title)
            .font(CalorynTheme.sectionHeaderTitle)
            .foregroundStyle(CalorynTheme.textPrimary)
            .lineLimit(1)
            .accessibilityAddTraits(.isHeader)
    }
}

/// The food a sheet is about: its name 26pt heavy with the Nutri-Score badge beside it, and
/// the detail lines under it in the secondary text colour.
struct FoodLogSheetHeader: View {
    let name: String
    var nutriscoreGrade: String? = nil
    var lines: [String] = []

    @AppStorage("showNutriscore") private var showNutriscore = true
    @ScaledMetric(relativeTo: .title) private var nameSize: CGFloat = 26

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .center, spacing: 8) {
                Text(name)
                    .font(CalorynTypeface.fixed(size: nameSize, weight: .heavy))
                    .tracking(-nameSize * 0.005)
                    .foregroundStyle(CalorynTheme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                if showNutriscore, let grade = nutriscoreGrade {
                    NutriscoreBadge(grade: grade)
                }
            }

            ForEach(lines, id: \.self) { line in
                Text(line)
                    .font(CalorynTypeface.text(.subheadline))
                    .foregroundStyle(CalorynTheme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// The kcal preview: the figure 64pt heavy in `tint`, with "kcal" beside it over an
/// optional detail line.
///
/// The figure never wraps. Side by side while the two fit; at large text sizes "kcal" and
/// the detail drop under the figure instead, because squeezed into what the caption left
/// it, "100" broke into "10" over "0" and read as ten.
///
/// The figure is its own accessibility element carrying `identifier`, so its label is the
/// bare number a journey waits on.
struct FoodLogCaloriePreview: View {
    let calories: Int
    let tint: Color
    var detail: String? = nil
    let identifier: String

    @ScaledMetric(relativeTo: .largeTitle) private var figureSize: CGFloat = 64

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .lastTextBaseline, spacing: 10) {
                figure
                    .fixedSize()
                caption
            }

            VStack(alignment: .leading, spacing: 4) {
                figure
                    .minimumScaleFactor(0.5)
                caption
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var figure: some View {
        Text("\(calories)")
            .font(CalorynTheme.heroNumber(size: figureSize))
            .tracking(-figureSize * 0.01)
            .lineLimit(1)
            .foregroundStyle(tint)
            .contentTransition(.numericText())
            .animation(.smooth(duration: 0.3), value: calories)
            .accessibilityIdentifier(identifier)
    }

    private var caption: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("kcal")
                .font(CalorynTypeface.text(.subheadline, weight: .semibold))
                .foregroundStyle(tint)

            if let detail {
                Text(detail)
                    .font(CalorynTypeface.text(.footnote))
                    .foregroundStyle(CalorynTheme.textSecondary)
                    .contentTransition(.numericText())
                    .animation(.smooth(duration: 0.3), value: detail)
            }
        }
    }
}

/// "How much", "Which meal", "In this portion": 15pt bold ink.
struct FoodLogSectionTitle: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(CalorynTypeface.text(.subheadline, weight: .bold))
            .foregroundStyle(CalorynTheme.textPrimary)
            .accessibilityAddTraits(.isHeader)
    }
}

/// Label-and-value rows with a hairline over each, the way the board draws "In this
/// portion". Values are tabular and roll when they change.
struct FoodLogValueRows: View {
    struct Row: Identifiable, Equatable {
        let id: String
        let label: String
        let value: String
    }

    let rows: [Row]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(rows) { row in
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(CalorynTheme.separator)
                        .frame(height: CalorynTheme.hairlineWidth)
                        .accessibilityHidden(true)

                    HStack {
                        Text(row.label)
                            .foregroundStyle(CalorynTheme.textPrimary)

                        Spacer()

                        Text(row.value)
                            .monospacedDigit()
                            .foregroundStyle(CalorynTheme.textPrimary)
                            .contentTransition(.numericText())
                            .animation(.smooth(duration: 0.3), value: row.value)
                    }
                    .font(CalorynTypeface.text(.subheadline))
                    .padding(.vertical, 9)
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }
}

/// What a sheet's bottom action sits on: the sheet's own colour, clear at the top and
/// opaque under the button, so rows scroll out beneath it rather than under a bar.
struct FoodLogBottomFade: View {
    var body: some View {
        LinearGradient(
            stops: [
                .init(color: CalorynTheme.backgroundSecondary.opacity(0), location: 0),
                .init(color: CalorynTheme.backgroundSecondary, location: 0.3),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea(edges: .bottom)
    }
}

extension View {
    /// The Add Food search well: a hairline edge and ink while focused, as `calorynInputField`
    /// draws, as the board's capsule so it matches the round scanner button beside it. Filled
    /// with `backgroundInset`, not the form fields' `backgroundTertiary`, which read as grey on the white
    /// sheet. The form fields keep `calorynInputField`'s rectangle.
    func foodSearchWell(isFocused: Bool, height: CGFloat) -> some View {
        padding(.horizontal, 16)
            .frame(minHeight: height)
            .background(CalorynTheme.backgroundInset, in: Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(
                        isFocused ? CalorynTheme.accent : CalorynTheme.separator,
                        lineWidth: isFocused ? 1.2 : CalorynTheme.hairlineWidth
                    )
                    .allowsHitTesting(false)
            }
            .animation(.smooth(duration: 0.18), value: isFocused)
    }

    /// A sheet's primary action pinned to the bottom edge over `FoodLogBottomFade`.
    func foodLogBottomAction<Action: View>(@ViewBuilder _ action: () -> Action) -> some View {
        safeAreaInset(edge: .bottom) {
            action()
                .padding(.horizontal, CalorynTheme.pagePadding)
                .padding(.top, 12)
                .padding(.bottom, 8)
                .background {
                    FoodLogBottomFade()
                }
        }
    }
}
