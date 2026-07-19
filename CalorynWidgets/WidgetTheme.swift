import SwiftUI
import UIKit

/// Widget-side mirror of the app's `CalorynTheme` palette.
///
/// The widget extension can't see the app target's theme, so the color
/// values are duplicated here. Keep in sync with `Caloryn/Theme/CalorynTheme.swift`.
enum WidgetTheme {
    static let sage = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.588, green: 0.671, blue: 0.514, alpha: 1)   // #96AB83
            : UIColor(red: 0.486, green: 0.557, blue: 0.420, alpha: 1)   // #7C8E6B
    })

    static let terracotta = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.831, green: 0.565, blue: 0.435, alpha: 1)   // #D4906F
            : UIColor(red: 0.757, green: 0.471, blue: 0.337, alpha: 1)   // #C17856
    })

    static let background = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.153, green: 0.149, blue: 0.141, alpha: 1)   // #272624 (surface)
            : UIColor(red: 0.980, green: 0.980, blue: 0.969, alpha: 1)   // #FAFAF7 (warmWhite)
    })

    static let ringTrack = Color.secondary.opacity(0.16)
}
