import SwiftUI

// The Plate vocabulary for the Settings screens' `List`/`Form` groups
// (`docs/design/plate-market.md`): a bold ink title outside each white group, rows whose
// label is ink and whose value is the quieter secondary, and a two-line label for a toggle
// that needs to say what it does. Every colour is a `CalorynTheme` token; the system's own
// `.secondary` and `LabeledContent` value styles are grey-blue, not the warm palette.

/// A group's title, outside the white group: 17pt bold ink, sentence case as written.
///
/// Pulled out to the group's own edge rather than indented to its rows, so the titles line
/// up with the page's large title the way the board draws them.
struct SettingsSectionTitle: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(CalorynTheme.sectionHeaderTitle)
            .foregroundStyle(CalorynTheme.textPrimary)
            .textCase(nil)
            .padding(.leading, -SettingsGroupMetrics.titleOutdent)
            .accessibilityAddTraits(.isHeader)
    }
}

/// A group footer in the theme's secondary text, in place of the system footer grey.
struct SettingsSectionFooter: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(CalorynTheme.caption)
            .foregroundStyle(CalorynTheme.textSecondary)
    }
}

/// A read-only "label … value" row, its value in the secondary text as the board draws every
/// Settings value (the goal's macros too). Pass `valueIsInk` for a figure an edit screen exists
/// to show (Edit goal's target, Edit profile's measurements).
///
/// At accessibility sizes the value goes under the title and may wrap, as `LabeledContent`
/// lays itself out there: side by side, "Moderately Active" truncated from AX3.
struct SettingsValueRow: View {
    let title: String
    let value: String
    var valueIsInk = false
    var valueAccessibilityLabel: String?

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 2) {
                    titleText
                    valueText
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    titleText

                    Spacer(minLength: 12)

                    valueText
                        .multilineTextAlignment(.trailing)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var titleText: some View {
        Text(title)
            .font(CalorynTheme.bodyText)
            .foregroundStyle(CalorynTheme.textPrimary)
    }

    private var valueText: some View {
        Text(value)
            .font(CalorynTheme.bodyText.monospacedDigit())
            .foregroundStyle(valueIsInk ? CalorynTheme.textPrimary : CalorynTheme.textSecondary)
            .accessibilityLabel(valueAccessibilityLabel ?? value)
    }
}

/// A row that opens a detail screen, with the board's chevron in `textSecondary`.
///
/// A `NavigationLink` in a `List` draws its own disclosure chevron in a cool system grey
/// (197,197,199 on white, about 1.7:1) that no tint reaches. These rows are buttons that set
/// a `navigationDestination(isPresented:)` on the list instead, and draw the chevron here.
struct SettingsDisclosureLabel<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(spacing: 12) {
            content()
                .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "chevron.right")
                .font(CalorynTheme.compactIcon)
                .foregroundStyle(CalorynTheme.textSecondary)
                .accessibilityHidden(true)
        }
        .contentShape(Rectangle())
    }
}

/// A toggle's label: the setting in ink, and an optional line under it in the secondary text.
struct SettingsToggleLabel: View {
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(CalorynTheme.bodyText)
                .foregroundStyle(CalorynTheme.textPrimary)

            if let subtitle {
                Text(subtitle)
                    .font(CalorynTheme.cardSubtitle)
                    .foregroundStyle(CalorynTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// A warning line inside a group: ink, with a functional warning glyph so it does not rely on
/// colour. The retired terracotta used to carry it, and the meal palette owns red now.
struct SettingsWarningText: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Label {
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: "exclamationmark.circle.fill")
                .accessibilityHidden(true)
        }
        .font(CalorynTheme.caption)
        .foregroundStyle(CalorynTheme.textPrimary)
    }
}

enum SettingsGroupMetrics {
    /// How far a group title sits outside the rows' text, so it lands on the group's edge as
    /// the board puts it: an inset-grouped row indents its content 16pt from that edge on
    /// iOS 26 and 20pt before it.
    static var titleOutdent: CGFloat {
        if #available(iOS 26.0, *) {
            16
        } else {
            20
        }
    }
}
