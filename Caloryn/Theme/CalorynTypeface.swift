import CoreText
import SwiftUI
import UIKit

/// The variable font's default instance is its 96pt ExtraBold display cut, so it is not
/// bundled as is: body text would get display letterforms. Instead there is a text cut at
/// the 14pt optical size in five weights, family "Bricolage Grotesque", so `.fontWeight`
/// and `.bold()` resolve inside it, and a display cut at 36pt in bold and extra bold for
/// titles and the big numbers. Every text-style font is `relativeTo:` its style, so
/// Dynamic Type scales it; fixed sizes come from callers' `@ScaledMetric`.
enum CalorynTypeface {
    static func register() {
        let urls = Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: nil) ?? []
        for url in urls where url.lastPathComponent.hasPrefix("BricolageGrotesque") {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }

    static func styleCollapsedNavigationTitles() {
        guard let font = UIFont(name: postScriptName(size: 17, weight: .bold), size: 17) else { return }
        UINavigationBar.appearance().titleTextAttributes = [
            .font: font,
            .foregroundColor: UIColor(resource: .textPrimary),
        ]
    }

    static func text(_ style: Font.TextStyle, weight: Font.Weight? = nil) -> Font {
        let size = baseSize(of: style)
        let weight = weight ?? (style == .headline ? .semibold : .regular)
        return .custom(postScriptName(size: size, weight: weight), size: size, relativeTo: style)
    }

    static func fixed(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom(postScriptName(size: size, weight: weight), fixedSize: size)
    }

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
