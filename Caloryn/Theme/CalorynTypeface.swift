import CoreText
import SwiftUI
import UIKit

/// Bricolage Grotesque, the app's typeface, bundled as fixed cuts of the variable font
/// (SIL Open Font License, `Fonts/BricolageGrotesque-OFL.txt`).
///
/// The variable font's default instance is its 96pt ExtraBold display cut, so it is not
/// bundled as is: body text would get display letterforms. Instead there is a text cut at
/// the 14pt optical size in five weights, family "Bricolage Grotesque", so `.fontWeight`
/// and `.bold()` resolve inside it, and a display cut at 36pt in bold and extra bold for
/// titles and the big numbers. Every text-style font is `relativeTo:` its style, so
/// Dynamic Type scales it; fixed sizes come from callers' `@ScaledMetric`.
///
/// SF Symbols keep the system font, since a symbol's weight and alignment come from it.
/// Inline navigation titles are not set through UIKit's title attributes, which are sized
/// once and would not follow a Dynamic Type change made while the app is open: they are a
/// SwiftUI `Text` in the principal slot instead (`calorynInlineTitle`). The one exception is
/// the title a large title collapses into on scroll: SwiftUI has no slot for it, so UIKit
/// draws it, from the attributes `styleCollapsedNavigationTitles()` sets.
enum CalorynTypeface {
    /// Registers the bundled cuts for this process. Call once, before the first view draws.
    /// Registration rather than `UIAppFonts`, so the fonts live entirely in this folder.
    static func register() {
        let urls = Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: nil) ?? []
        for url in urls where url.lastPathComponent.hasPrefix("BricolageGrotesque") {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }

    /// Sets the inline title a large title collapses into — History, Settings, My Foods — in
    /// 17pt bold ink, as `calorynInlineTitle` draws the others. A principal-slot `Text` cannot
    /// do it: it shows above the large title as well, not in its place once it scrolls away.
    /// The size is fixed, as UIKit's own inline title is: it does not scale with Dynamic Type.
    /// Call once, after `register()`, before the first navigation bar is made.
    static func styleCollapsedNavigationTitles() {
        guard let font = UIFont(name: postScriptName(size: 17, weight: .bold), size: 17) else { return }
        UINavigationBar.appearance().titleTextAttributes = [
            .font: font,
            .foregroundColor: UIColor(resource: .textPrimary),
        ]
    }

    /// The face for a text style, scaled with Dynamic Type. With no weight, the style's own:
    /// semibold for `.headline`, as the system draws it, regular for the rest.
    static func text(_ style: Font.TextStyle, weight: Font.Weight? = nil) -> Font {
        let size = baseSize(of: style)
        let weight = weight ?? (style == .headline ? .semibold : .regular)
        return .custom(postScriptName(size: size, weight: weight), size: size, relativeTo: style)
    }

    /// The face at a fixed point size, for callers that scale the size themselves.
    static func fixed(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom(postScriptName(size: size, weight: weight), fixedSize: size)
    }

    /// The display cut from 22pt up in bold and heavier, where its tighter spacing is
    /// meant to be seen; the text cut everywhere else.
    private static func postScriptName(size: CGFloat, weight: Font.Weight) -> String {
        let style: String
        switch weight {
        case .medium: style = "Medium"
        case .semibold: style = "SemiBold"
        case .bold: style = "Bold"
        case .heavy, .black: style = "ExtraBold"
        default: style = "Regular"
        }
        let usesDisplay = size >= 22 && (style == "Bold" || style == "ExtraBold")
        return (usesDisplay ? "BricolageGrotesqueDisplay-" : "BricolageGrotesque-") + style
    }

    /// The system's sizes for each style at the default content size.
    private static func baseSize(of style: Font.TextStyle) -> CGFloat {
        switch style {
        case .largeTitle: 34
        case .title: 28
        case .title2: 22
        case .title3: 20
        case .headline, .body: 17
        case .callout: 16
        case .subheadline: 15
        case .footnote: 13
        case .caption: 12
        case .caption2: 11
        default: 17
        }
    }
}
