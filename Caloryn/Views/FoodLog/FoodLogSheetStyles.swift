import SwiftUI

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
