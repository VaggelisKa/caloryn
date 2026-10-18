import SwiftUI

struct CreationFormSection<Content: View, Trailing: View>: View {
    enum Surface {
        case sheet
        case group
    }

    let title: String
    let footer: String?
    let surface: Surface
    @ViewBuilder let trailing: Trailing
    @ViewBuilder let content: Content

    init(
        _ title: String,
        footer: String? = nil,
        surface: Surface = .sheet,
        @ViewBuilder trailing: () -> Trailing = { EmptyView() },
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.footer = footer
        self.surface = surface
        self.trailing = trailing()
        self.content = content()
    }

    private var titleText: some View {
        Text(title)
            .font(CalorynTheme.sectionHeaderTitle)
            .foregroundStyle(CalorynTheme.textPrimary)
            .accessibilityAddTraits(.isHeader)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: 8) {
                    titleText
                    Spacer(minLength: 8)
                    trailing
                }

                VStack(alignment: .leading, spacing: 8) {
                    titleText
                    trailing
                }
            }

            switch surface {
            case .sheet:
                VStack(alignment: .leading, spacing: 0) {
                    content
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            case .group:
                VStack(alignment: .leading, spacing: 0) {
                    content
                }
                .padding(.horizontal, CalorynTheme.cardPadding)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .calorynGroupSurface()
            }

            if let footer {
                Text(footer)
                    .font(CreationFormTypography.detail)
                    .foregroundStyle(CalorynTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

enum CreationFormTypography {
    static let rowLabel: Font = CalorynTypeface.text(.callout)
    static let itemName: Font = CalorynTypeface.text(.callout, weight: .medium)
    static let detail: Font = CalorynTypeface.text(.footnote)
    static let itemKcal: Font = CalorynTypeface.text(.callout, weight: .semibold).monospacedDigit()
}

struct CreationFormDivider: View {
    var body: some View {
        Rectangle()
            .fill(CalorynTheme.separator)
            .frame(height: CalorynTheme.hairlineWidth)
            .accessibilityHidden(true)
    }
}

struct CreationFormSheetRow<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            CreationFormDivider()
            content
                .padding(.vertical, 8)
        }
    }
}

struct CreationFormTotal: View {
    let kcal: Int
    let caption: String
    var macros: [(label: String, value: String)] = []

    @ScaledMetric(relativeTo: .largeTitle) private var figureSize: CGFloat = 56

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(kcal.formatted())
                    .font(CalorynTheme.heroNumber(size: figureSize))
                    .tracking(-figureSize * 0.01)
                    .foregroundStyle(CalorynTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .contentTransition(.numericText(value: Double(kcal)))
                    .animation(.smooth(duration: 0.3), value: kcal)

                Text(caption)
                    .font(CalorynTheme.cardSubtitle.weight(.semibold))
                    .foregroundStyle(CalorynTheme.textSecondary)
            }
            .accessibilityElement(children: .combine)

            if !macros.isEmpty {
                HStack(alignment: .top, spacing: 0) {
                    ForEach(macros, id: \.label) { macro in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(macro.value)
                                .font(CalorynTheme.numericBody.weight(.semibold))
                                .foregroundStyle(CalorynTheme.textPrimary)
                            Text(macro.label)
                                .font(CreationFormTypography.detail)
                                .foregroundStyle(CalorynTheme.textSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct CreationFormItemRow: View {
    let name: String
    let detail: String
    let kcal: Int
    let onEdit: () -> Void
    let onDelete: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .callout) private var kcalColumn: CGFloat = 44

    var body: some View {
        if dynamicTypeSize.isAccessibilitySize {
            accessibilityLayout
        } else {
            standardLayout
        }
    }

    private var accessibilityLayout: some View {
        HStack(alignment: .top, spacing: 12) {
            Button(action: onEdit) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(name)
                        .font(CreationFormTypography.itemName)
                        .foregroundStyle(CalorynTheme.textPrimary)
                        .lineLimit(3)

                    Text(detail)
                        .font(CreationFormTypography.detail)
                        .foregroundStyle(CalorynTheme.textSecondary)
                        .lineLimit(3)

                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(kcal.formatted())
                            .font(CreationFormTypography.itemKcal)
                            .foregroundStyle(CalorynTheme.textPrimary)
                        Text("kcal")
                            .font(CreationFormTypography.detail)
                            .foregroundStyle(CalorynTheme.textSecondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            deleteButton
        }
        .padding(.vertical, 10)
    }

    private var deleteButton: some View {
        Button(role: .destructive, action: onDelete) {
            Image(systemName: "minus.circle")
                .font(CalorynTheme.inlineIcon)
                .foregroundStyle(CalorynTheme.textSecondary)
                .frame(minWidth: 28, minHeight: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Delete \(name)")
    }

    private var standardLayout: some View {
        HStack(spacing: 12) {
            Button(action: onEdit) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(name)
                            .font(CreationFormTypography.itemName)
                            .foregroundStyle(CalorynTheme.textPrimary)
                            .lineLimit(1)

                        Text(detail)
                            .font(CreationFormTypography.detail)
                            .foregroundStyle(CalorynTheme.textSecondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 8)

                    VStack(alignment: .trailing, spacing: 0) {
                        Text(kcal.formatted())
                            .font(CreationFormTypography.itemKcal)
                            .foregroundStyle(CalorynTheme.textPrimary)
                        Text("kcal")
                            .font(CreationFormTypography.detail)
                            .foregroundStyle(CalorynTheme.textSecondary)
                    }
                    .frame(minWidth: kcalColumn, alignment: .trailing)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            deleteButton
        }
        .padding(.vertical, 10)
    }
}

struct CreationFormEmptyRow: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(CreationFormTypography.itemName)
                .foregroundStyle(CalorynTheme.textSecondary)
            Text(detail)
                .font(CreationFormTypography.detail)
                .foregroundStyle(CalorynTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 14)
        .accessibilityElement(children: .combine)
    }
}

struct CreationFormAddButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: "plus")
                .labelStyle(.titleAndIcon)
                .calorynChip(isSelected: false)
        }
        .buttonStyle(.plain)
    }
}

struct CreationFormCloseButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(CalorynTheme.toolbarIcon)
                .foregroundStyle(CalorynTheme.accent)
        }
        .accessibilityLabel("Close")
    }
}

struct CreationFormSaveGlyph: View {
    let isEnabled: Bool
    var isSaving = false

    var body: some View {
        if isSaving {
            ProgressView()
                .tint(CalorynTheme.accent)
        } else {
            Image(systemName: "checkmark")
                .font(CalorynTheme.toolbarIcon.weight(.semibold))
                .foregroundStyle(isEnabled ? CalorynTheme.accent : CalorynTheme.textTertiary)
        }
    }
}

struct CreationFormFavoriteGlyph: View {
    let isFavorite: Bool

    var body: some View {
        Image(systemName: isFavorite ? "star.fill" : "star")
            .font(CalorynTheme.toolbarIcon)
            .foregroundStyle(CalorynTheme.accent)
    }
}

struct CreationFormDeleteButton: View {
    let title: String
    let action: () -> Void

    init(_ title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    var body: some View {
        if #available(iOS 26.0, *) {
            button
                .buttonStyle(.glass)
                .buttonBorderShape(.capsule)
        } else {
            button
                .buttonStyle(CreationFormOutlinedCapsuleStyle())
        }
    }

    private var button: some View {
        Button(role: .destructive, action: action) {
            Label(title, systemImage: "trash")
                .font(CalorynTheme.buttonLabel)
                .foregroundStyle(CalorynTheme.accent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
    }
}

private struct CreationFormOutlinedCapsuleStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(Capsule().fill(CalorynTheme.backgroundPrimary))
            .overlay {
                Capsule()
                    .strokeBorder(CalorynTheme.separator, lineWidth: CalorynTheme.hairlineWidth)
                    .allowsHitTesting(false)
            }
            .contentShape(Capsule())
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}
