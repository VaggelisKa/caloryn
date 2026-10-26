import SwiftUI

// The Plate / Market vocabulary for the three creation sheets — custom food, recipe and
// saved meal (`docs/design/plate-market.md`, "Everything else"). They share one look, so it
// is written once here rather than three times.
//
// The forms are stacks in a `ScrollView`, not `Form`s, and they follow the Portion sheet
// (`PlatePortion`): input wells sit straight on the white sheet under a bold title ("How
// much"), and lists of values are hairline rows on the sheet ("In this portion"). A well is
// already a surface, so it never goes inside another one. Only a list of plain rows (a
// recipe's ingredients, a meal's items) gets a group, `calorynGroupSurface()`: on the white
// sheet its hairline edge is what shows the group at all.

/// A titled section: a bold sentence-case title, an optional control beside it, the content
/// and an optional footnote.
struct CreationFormSection<Content: View, Trailing: View>: View {
    /// What the content sits on.
    enum Surface {
        /// Straight on the sheet: wells, and hairline rows that hold one well each.
        case sheet
        /// A white group with a hairline edge, for a list of plain rows.
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
            // The add chip beside the title while both fit; under it once they do not
            // (from AX1 "Ingredients" and "Add ingredient" need about 372pt of 362).
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

/// Type sizes the forms use that `CalorynTheme` has no name for, text-style-relative.
enum CreationFormTypography {
    /// A row's label, 16pt.
    static let rowLabel: Font = .system(.callout)
    /// An item row's name, 16pt medium.
    static let itemName: Font = .system(.callout, weight: .medium)
    /// Grams, units and footnotes, 13pt.
    static let detail: Font = .system(.footnote)
    /// The kcal on an item row, 16pt semibold tabular.
    static let itemKcal: Font = .system(.callout, weight: .semibold).monospacedDigit()
}

/// The 1pt rule between rows.
struct CreationFormDivider: View {
    var body: some View {
        Rectangle()
            .fill(CalorynTheme.hairline)
            .frame(height: CalorynTheme.hairlineWidth)
            .accessibilityHidden(true)
    }
}

/// A row straight on the sheet with a hairline above it, the way `PlatePortion` draws "In
/// this portion": every row, the first included, starts with a rule.
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

/// The form's running total: the kcal figure big and heavy in ink, its caption beside it,
/// and the macros under it as plain label-and-value pairs, told apart by label, not colour.
/// Straight on the sheet, as the Portion sheet draws its preview — not in a card.
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

/// An ingredient or meal item: name and grams on the left, its kcal right-aligned in a
/// fixed column over "kcal", and a remove control. Tapping the row edits the amount.
///
/// At accessibility sizes the kcal column and the remove control left the name about
/// 100pt ("Ho…" for "House Salad" at AX5). There the name and detail may wrap, the kcal
/// reads inline under them ("81 kcal"), and the remove control stays on the trailing edge,
/// as `LibraryRowLayout` does for the library rows.
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

/// The empty state inside an items group: a quiet line, not a full `ContentUnavailableView`,
/// so the group keeps its shape and the add control beside its title stays the way in.
struct CreationFormEmptyRow: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(CreationFormTypography.itemName)
                .foregroundStyle(CalorynTheme.textSecondary)
            // Secondary, not tertiary: this sentence is the instruction, and tertiary is
            // 3.1:1 on the sheet, for placeholders only.
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

/// The add control beside an items group's title ("Add ingredient", "Add item"): a hairline
/// chip with a functional plus, so it reads as an action without competing with Save.
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

/// The sheet's close glyph, in ink rather than the retired sage. Glass comes from the
/// toolbar on iOS 26.
///
/// These three are `Label`s rather than bare `Image`s: a toolbar draws a label as its
/// symbol alone, but keeps the title for the overflow menu iPhone Duo's vertical bar
/// spills into, and for VoiceOver. A custom view with no title cannot go vertical at all.
struct CreationFormCloseButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label("Close", systemImage: "xmark")
                .font(CalorynTheme.toolbarIcon)
                .foregroundStyle(CalorynTheme.textPrimary)
        }
        .accessibilityLabel("Close")
    }
}

/// The sheet's save glyph: an ink tick on the toolbar's own glass, like the close glyph
/// beside it, and `textTertiary` while the form cannot be saved (the spec's colour for a
/// disabled control). Drawn on the glass rather than as a prominent ink button: a toolbar
/// item keeps its regular glass whichever placement it takes, so a paper tick meant for an
/// ink capsule vanished into it in both appearances.
struct CreationFormSaveGlyph: View {
    let isEnabled: Bool
    var isSaving = false

    var body: some View {
        if isSaving {
            ProgressView()
                .tint(CalorynTheme.textPrimary)
        } else {
            Label("Save", systemImage: "checkmark")
                .font(CalorynTheme.toolbarIcon.weight(.semibold))
                .foregroundStyle(isEnabled ? CalorynTheme.textPrimary : CalorynTheme.textTertiary)
        }
    }
}

/// The favourite star on an existing food or recipe: filled ink when it is a favourite,
/// outlined ink when not.
struct CreationFormFavoriteGlyph: View {
    let isFavorite: Bool

    var body: some View {
        Label(
            isFavorite ? "Remove from Favorites" : "Add to Favorites",
            systemImage: isFavorite ? "star.fill" : "star"
        )
        .font(CalorynTheme.toolbarIcon)
        .foregroundStyle(CalorynTheme.textPrimary)
    }
}

/// Delete, at the foot of an edit form: a capsule with an ink label. Red now means lunch, so
/// the destructive weight is carried by the confirmation dialog it opens, whose button keeps
/// the system's destructive role.
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
                .foregroundStyle(CalorynTheme.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
    }
}

/// Delete's capsule before iOS 26, drawn here rather than by `.borderedProminent`. That style
/// fills with the tint and draws no edge, so any quiet fill vanished into the sheet (the
/// `surface` tint is the sheet's own colour in dark mode), and a destructive role can turn it
/// system red. A page-coloured capsule with the hairline edge `calorynGroupSurface()` uses
/// reads as a control in both appearances.
private struct CreationFormOutlinedCapsuleStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(Capsule().fill(CalorynTheme.pageBackground))
            .overlay {
                Capsule()
                    .strokeBorder(CalorynTheme.hairline, lineWidth: CalorynTheme.hairlineWidth)
                    .allowsHitTesting(false)
            }
            .contentShape(Capsule())
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}
