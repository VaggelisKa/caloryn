import SwiftUI

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
    static var titleOutdent: CGFloat {
        if #available(iOS 26.0, *) {
            16
        } else {
            20
        }
    }
}
