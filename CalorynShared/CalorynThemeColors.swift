import SwiftUI

/// The app's colours, named by the role they play rather than the screen or component that
/// first needed them, so a re-skin is a change to `SharedColors.xcassets` and nothing else.
///
/// Every token resolves to a Color Set of the same name (bar `separator`, see there) that
/// declares its light and dark appearance together — never a literal or a
/// `UIColor { traits in … }` closure, which can omit a dark variant silently. One Color Set
/// per role, even where two roles share a value
/// today (`accent` and `textPrimary` are both ink): sharing a value is a design decision a
/// re-skin may undo, so it lives in the catalog, not in a Swift alias. The convention and the
/// value table are in `docs/theme.md`; CLAUDE.md rule 6 has the rules.
///
/// This file is in `CalorynShared`, a member of both the app and the widget target, so the
/// widget speaks the same vocabulary. Fonts, spacing and the meal and Nutri-Score lookups
/// are app-only and live in `Caloryn/Theme/CalorynTheme.swift`.
enum CalorynTheme {
    // MARK: - Backgrounds

    // What content sits on, in three steps of elevation, plus the inset well.

    /// The canvas a page sits on: every tab page and pushed screen, a widget's container.
    static let backgroundPrimary = Color(.backgroundPrimary)
    /// A raised surface on the canvas: a sheet, a grouped list row, a group surface, the face
    /// of a control raised off a well (a stepper's round buttons).
    static let backgroundSecondary = Color(.backgroundSecondary)
    /// A recessed well or panel inside a raised surface: an input field, a stepper pill, a
    /// notice panel.
    static let backgroundTertiary = Color(.backgroundTertiary)
    /// A well that sinks to the page: page paper in light, `backgroundTertiary` in dark. The
    /// Add Food search well and its scanner circle, where `backgroundTertiary` read as grey on
    /// the white sheet.
    static let backgroundInset = Color(.backgroundInset)

    // MARK: - Text

    // Text and the glyphs that read as content, in three steps of emphasis.

    static let textPrimary = Color(.textPrimary)
    static let textSecondary = Color(.textSecondary)
    /// The quietest text: the legend's "not yet", a disabled chevron. Below 4.5:1 on the
    /// page (2.8:1 light), so only for a placeholder whose meaning is also carried some other
    /// way — never for a figure or anything the reader must be able to make out.
    static let textTertiary = Color(.textTertiary)
    /// A label or glyph drawn on `accent`: the primary button's label, a selected chip's text,
    /// the check on a selected radio.
    static let textOnAccent = Color(.textOnAccent)

    // MARK: - Accent

    /// What the reader can act on: the primary button and a selected chip or segment, slider
    /// and spinner tints, a focused field's edge, a selection ring, a button's own label or
    /// glyph. Also the app-wide tint: the build's global accent colour is this Color Set.
    static let accent = Color(.accent)
    /// The accent where a stock control draws white on it: a switch's track under its white
    /// knob, the selected day of a graphical date picker. Ink in light; in dark, where ink is
    /// near-white, a mid grey the white knob still shows on (3:1, and 3.8:1 against the
    /// system's off track). `ContentView` applies it to every `Toggle`.
    static let accentControl = Color(.accentControl)

    // MARK: - Lines

    /// Row separators, surface borders, chip and field outlines. Carries its own alpha in the
    /// Color Set, so it reads the same on paper and on a white surface. The one set not named
    /// like its token: UIKit owns `UIColor.separator`, so an asset called `Separator` makes
    /// `Color(.separator)` ambiguous with the system colour and Xcode warns on every build.
    static let separator = Color(.separatorLine)
    /// A soft shadow under a control raised off a well.
    static let shadow = Color(.shadow)

    // MARK: - Fills

    // Shapes that are neither a surface, text nor data.

    /// The unfilled part of a track: a donut's or progress bar's remainder, the wash behind a
    /// status word, a day with nothing logged.
    static let fillTrack = Color(.fillTrack)
    /// The background of a badge: the "Recipe" / "Yours" type badge, drawn with
    /// `textSecondary` on it (4.7:1 light, 5.7:1 dark on the page). Alpha is baked in.
    static let fillBadge = Color(.fillBadge)
    /// A loading placeholder, and the band that sweeps over it, so the two add up at its
    /// peak: ink at two light weights, so a placeholder reads as part of the page.
    static let fillLoading = Color(.fillLoading)
    static let fillLoadingHighlight = Color(.fillLoadingHighlight)
    /// A neutral action background under the system's white label and glyph: swipe actions.
    /// Dark in both appearances (6.6:1 light, 8:1 dark).
    static let fillAction = Color(.fillAction)

    // MARK: - Data

    // Marks that carry a quantity and are not meal-coloured, in three steps of weight, so
    // History's over, on-track and under days read as ink, mid and light rather than as hues.

    /// The heaviest data mark: an overshoot, an over-goal ring or bar, a progress bar's fill.
    static let dataPrimary = Color(.dataPrimary)
    /// The neutral mid weight: an on-track day, eaten calories not attributed to a meal.
    static let dataSecondary = Color(.dataSecondary)
    /// The light weight: an under-goal day.
    static let dataTertiary = Color(.dataTertiary)
    /// A reference line on a chart: the daily target rule.
    static let dataReference = Color(.dataReference)

    // MARK: - Meal palette

    // Categorical, so named for the meal. `fill` is for shapes, `ink` for text in the meal's
    // colour, `onFill` for a label drawn on the fill. Asset names omit a `Color` suffix: Xcode
    // strips it when generating symbols, so `MealLunchColor` would yield `.mealLunch` anyway.
    static let mealBreakfast = Color(.mealBreakfast)
    static let mealBreakfastInk = Color(.mealBreakfastInk)
    static let mealLunch = Color(.mealLunch)
    static let mealLunchInk = Color(.mealLunchInk)
    static let mealDinner = Color(.mealDinner)
    static let mealDinnerInk = Color(.mealDinnerInk)
    static let mealSnack = Color(.mealSnack)
    static let mealSnackInk = Color(.mealSnackInk)
    static let mealBreakfastOnFill = Color(.mealBreakfastOnFill)
    static let mealLunchOnFill = Color(.mealLunchOnFill)
    static let mealDinnerOnFill = Color(.mealDinnerOnFill)
    static let mealSnackOnFill = Color(.mealSnackOnFill)

    // MARK: - Nutri-Score

    // The official Nutri-Score colours (A = best, E = worst), and the white the letter is drawn
    // in. Appearance-independent by design: they must not shift with the interface style.
    static let nutriscoreA = Color(.nutriscoreA)
    static let nutriscoreB = Color(.nutriscoreB)
    static let nutriscoreC = Color(.nutriscoreC)
    static let nutriscoreD = Color(.nutriscoreD)
    static let nutriscoreE = Color(.nutriscoreE)
    static let nutriscoreOnFill = Color(.nutriscoreOnFill)
}
