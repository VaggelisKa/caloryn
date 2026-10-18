# Direction A "Plate", Market palette — build spec

The UI uplift agreed on 2026-10-17. Mockups live on the design canvas
(https://claude.ai/artifact/95xiztSKJ5fXrQQSdkq5sb); rendered PNGs and the HTML
boards are handed to builders out of band. This file is the contract: what changes,
what must not, and how each change is verified.

## Scope

A skin change. Nothing else moves:

- Data model, services, routing, flows and sheet structure stay exactly as they are.
- Every `accessibilityIdentifier` in the app survives, on an element that still does
  the same thing. The UI journeys (`Caloryn-UI`) are the refactor net and must pass.
- Liquid Glass chrome stays: system navigation bars, the tab bar, sheet presentation
  (`presentationBackground(.regularMaterial)` where it is used today), glass buttons
  (`adaptiveGlassProminentButton`, `adaptiveGlassButtonStyle`), the themed drill-down
  back button. Glass is the chrome; the content underneath is what changes.
- Deployment target iOS 18.6 built against the iOS 26 SDK. Every `#available(iOS 26.0, *)`
  branch keeps its `else`. Swift Charts `SectorMark` is iOS 17+, so it is fine on both.
- Typeface is Bricolage Grotesque (SIL OFL), bundled as fixed cuts of the variable font in
  `Caloryn/Theme/Fonts` and registered at launch by `CalorynTypeface`: a text cut at the
  14pt optical size in five weights, and a display cut at 36pt in bold and extra bold that
  takes over from 22pt up. Every token is `relativeTo:` its text style, so Dynamic Type
  still scales it. Weight carries the feel: heavy for display numbers and screen titles,
  bold for section titles, tabular digits on every number. Tracking is close to zero,
  because the display cut is already tight. SF Symbols, inline navigation titles, the tab
  bar and other system chrome keep the system font.

## Tokens

All colours are Color Sets in `CalorynShared/SharedColors.xcassets`, light and dark
declared together (CLAUDE.md rule 6). Never a literal.

| Asset | Light | Dark | Role |
|---|---|---|---|
| `PageBackground` | `#FEFDFA` | `#141614` | every page canvas |
| `CardBackground` | `#FFFFFF` | `#262A26` | sheet canvas, the few grouped surfaces |
| `Surface` | `#F6F5F1` | `#262A26` | input wells inside a sheet (stepper pill, search well) |
| `TextPrimary` | `#1E231F` | `#ECEBE8` | ink: text, controls, primary buttons |
| `TextSecondary` | `#566057` | `#A6ACA6` | captions, units, inactive tab labels |
| `TextTertiary` *(new)* | `#8E948C` | `#6F756F` | "not yet", a disabled chevron; 2.8:1 in light, so placeholders only |
| `Hairline` *(new)* | `#1E231F` α 0.10 | `#ECEBE8` α 0.12 | row separators, surface borders |
| `MealBreakfast` *(new)* | `#F2B705` | `#F7C94A` | breakfast fill |
| `MealBreakfastInk` *(new)* | `#7A5A00` | `#F7C94A` | breakfast text |
| `MealLunch` *(new)* | `#D44026` | `#F0705A` | lunch fill |
| `MealLunchInk` *(new)* | `#8F2A17` | `#F0705A` | lunch text |
| `MealDinner` *(new)* | `#5B3758` | `#B98BB5` | dinner fill |
| `MealDinnerInk` *(new)* | `#6A3D66` | `#B98BB5` | dinner text |
| `MealSnack` *(new)* | `#7E8B2E` | `#B5C457` | snack fill |
| `MealSnackInk` *(new)* | `#4F5918` | `#B5C457` | snack text |
| `MealBreakfastOnFill` *(new)* | `#1E231F` | `#262A26` | label or glyph on the breakfast fill |
| `MealLunchOnFill` *(new)* | `#FFFFFF` | `#262A26` | label or glyph on the lunch fill |
| `MealDinnerOnFill` *(new)* | `#FFFFFF` | `#262A26` | label or glyph on the dinner fill |
| `MealSnackOnFill` *(new)* | `#1E231F` | `#262A26` | label or glyph on the snack fill |
| `HistoryEaten` *(new)* | `#5C615D` | `#8E968F` | neutral "eaten" fill in History day plates and bars |
| `HistoryEatenLight` *(new)* | `#959A96` | `#555B56` | an under-goal day in History, a step lighter than `HistoryEaten` |
| `TypeBadgeFill` *(new)* | `#566057` α 0.18 | `#A6ACA6` α 0.18 | the "Recipe" / "Yours" badge background |
| `TypeBadgeText` *(new)* | `#566057` | `#A6ACA6` | the "Recipe" / "Yours" badge text |
| `ControlTint` *(new)* | `#1E231F` | `#8E968F` | a switch's on track and a graphical date picker's selected day: what the system draws white on |
| `SwipeActionTint` *(new)* | `#566057` | `#4A504B` | a swipe action's background under its white label |
| `AccentColor` (app catalog) | `#1E231F` | `#ECEBE8` | stock controls: pickers, links |

Fill is for shapes (sectors, chips, the header add button's wash); ink is for text in that
meal's colour, dark enough for 4.5:1 on the page. In dark mode fill and ink are the same
value. On-fill is what is drawn *on* a fill (a selected meal chip's label, "Log to
<meal>"). The boards draw white there, but white on the yellow breakfast fill is 1.8:1 and
on the snack olive 3.7:1, so those two take ink. The light lunch fill was darkened from
the board's `#D9452B` (white on it 4.3:1) to `#D44026` (4.6:1), so white 13pt chip text on
it clears 4.5:1. Dinner's light ink was lifted from the board's `#4A2C47`, which sat 1.3:1
from `TextPrimary` and read as black, to `#6A3D66` in the same hue: 7.8:1 on the page and
8.5:1 on white, so still well past 4.5:1, and the only ink lighter than its own fill.

Existing `Stone` and `Terracotta` assets stay in the catalog (a few unchanged screens
read them) but the app stops using them for meaning. The `Sage`, `Carb`, `Fiber`,
`HistoryUnder` and `WarmWhite` sets lost their last reader and were removed:

- `proteinColor`, `carbColor`, `fatColor`, `fiberColor` resolve to `TextPrimary`. Macros
  are told apart by their label, never by colour, because the meal palette now owns
  colour and the two systems would collide (sage was both "protein" and "lunch").
- `HistoryTheme`: `under` → `HistoryEatenLight`, `onTrack` → `HistoryEaten`, `over` →
  `TextPrimary`, `notLogged` → `Hairline`. Red no longer means "over"; it means lunch.
  (The first draft had `under` → `TextSecondary`, which is 1.04:1 against `HistoryEaten`
  in light: the existing strip and bars could not tell an under day from an on-track one.)
  Weekly consistency reuses the day steps: a week two-thirds on track or better takes the
  on-track colour, a third or better the under colour, anything less the over colour.
- Nutri-Score badge colours are fixed by the standard and do not change.

`CalorynTheme` gains: `hairline`, `mealFill(_ meal: MealType)`, `mealInk(_ meal: MealType)`,
`mealOnFill(_ meal: MealType)`, `textTertiary`, `historyEaten`, `historyEatenLight`,
`typeBadgeFill`, `typeBadgeText`. Keep the existing names (`sage`, `terracotta`, …) so unchanged call sites
compile; retire them from new code.

## Vocabulary

- **Pages**: `calorynPageCanvas()`, content directly on the page, no cards. Lists use
  `calorynPlainListStyle()` with `.listRowBackground(Color.clear)` and the separator
  tinted `CalorynTheme.hairline` (`.listRowSeparatorTint`). Scroll views draw their own
  1pt hairline between rows.
- **Grouped surfaces** exist only where rows are controls (Settings) or a single callout
  (History insight). Built as a stack (the insight), they are `calorynGroupSurface()`:
  `CardBackground`, 22pt continuous radius, 1pt `Hairline` border, no shadow. Built as a
  `List` or `Form` (Settings, the forms), they are `calorynGroupedListStyle()` /
  `calorynFormStyle()` plus `.listRowBackground(CalorynTheme.cardBackground)` on each
  Section, as today, and **keep the system inset-grouped shape: its own corner radius and no
  border**. A row cannot draw a border round its whole section, so the board's 22pt bordered
  Settings groups are not reproduced in a `List`; the white group on paper is the surface.
- **Sheets**: `calorynSheetCanvas()` (white), glass close/back buttons as today but
  glyphs in `TextPrimary`, not sage (`calorynDrillDownNavigation()` already is). Input wells
  use `Surface`: `calorynInputField()` draws a `Surface` well with a `Hairline` edge and an
  ink edge when focused.
- **Section header** (`CalorynMealSectionHeader`): meal name in its ink, 17pt bold, total
  in `TextSecondary` tabular ("nothing yet" in `TextSecondary` too), add button
  30pt circle in the meal fill at 16% (`mealWash`) with the plus in the meal's ink, the same
  treatment for all four meals. Non-meal sections: 17pt
  bold ink.
- **Row**: name 16pt medium, optional `NutriscoreBadge` or type badge, grams in
  `TextSecondary` 13pt, kcal 16pt semibold tabular right-aligned in a fixed 44pt column.
  A row that shows an amount prices it: "152" over "kcal" for 40 g of a 380 kcal food, the
  line under the name "Quaker, 40 g · per 100 g: 380 kcal" (`FoodRowSummary`). A row with
  no weighable amount says "kcal per 100 g"; a recipe, "kcal total".
- **Type badge** ("Recipe", "Yours"): 10pt bold, meal-independent neutral tint:
  `TextSecondary` at 18% with `TextSecondary` text in both appearances —
  `TypeBadgeFill` / `TypeBadgeText`. `FoodRowView` already draws it.
- **Primary button**: 54pt capsule, `TextPrimary` background, `PageBackground` label,
  17pt bold: `calorynPrimaryButton()`, which keeps glass on iOS 26. The only non-ink
  primary is the Portion sheet's "Log to <meal>", `calorynPrimaryButton(meal:)`, in the
  target meal's fill with its on-fill label. Any other prominent button goes through
  `adaptiveGlassProminentButton()`, which also draws a paper label: the system styles'
  own white label disappears on the near-white ink of dark mode.
- **Chips**: 32–34pt capsules; selected = ink fill with page-coloured text, unselected =
  1pt `Hairline` border. Meal chips in the Portion sheet: selected = that meal's fill
  with its on-fill text, unselected = `Hairline` border with the meal's ink text.
- **Toggles** are ink in light. A `Toggle` ignores `AccentColor`, and its knob is always
  white while ink is near-white in dark mode, so switches take `ControlTint`
  (`CalorynToggleStyle`, applied app-wide in `ContentView`): ink in light, a mid grey in
  dark. **Stepper** on the Portion sheet: a `Surface` capsule with round white minus/plus
  buttons at the ends and the grams field centred. Counts (servings, age, a snack slot) use
  the same pill without the typed field, `CalorynStepperPill`, never a stock `Stepper` or
  a wheel, whose fills are a system grey.
- **No decorative glyphs.** The meal name carries its colour; there are no wedge or dot
  icons on headers, chips or titles. The only keys are the legend beside the donut.
  SF Symbols stay where they are *functional* (tab bar, scanner, chevrons, search).
- Copy: sentence case, no middle-dot joins ("Arla, 1 pot 150 g"), no uppercase eyebrows.

## The donut (Today hero)

Swift Charts, so it animates and respects Dynamic Type for free:

```swift
Chart(sectors) { sector in
    SectorMark(angle: .value("kcal", sector.kcal),
               innerRadius: .ratio(0.70),
               angularInset: 1.5)
        .foregroundStyle(sector.color)
}
```

- 168pt, left of the number column. The hole is **empty**; the number sits beside the
  ring, never inside it.
- Sectors in `MealType.sortOrder` (breakfast, lunch, dinner, snack), each in its meal
  fill. Remaining budget is one sector in `Hairline`.
- Over budget: the ring's whole is everything eaten, and the amount past the budget is its
  own final sector in `TextPrimary`, sized as its share of the day. The meals share the
  rest — the budget — in proportion to what each contributed, so every logged meal stays
  on the ring. (The `PlateOver` board instead draws meals at full size and cuts the
  overshoot out of the last one; that only works in its dinner-last order, and in
  `sortOrder` would erase a small snack. The ink slice is the same size either way; the
  meal slices are about 15% smaller than the board's.) The ink sector takes a wider
  `angularInset` (3 against 1.5) so a page-coloured gap parts it from the dark dinner
  purple. The legend gains an "Over" row keyed by a 2pt ink ring, the mark History uses
  for an over-goal day: `CalorieDonutSummary.legend` ends with a `.over` entry. No arcs or
  markers outside the ring.
- Right column: the number 56pt heavy (`remaining`, or `over` when over) with a tight
  tracking, caption "kcal left of 2.000" / "kcal over", a line "963 of 2.000 eaten",
  then the legend: 12pt circle key in the meal fill, meal name in `TextSecondary`, kcal
  tabular; an unlogged meal shows a hollow key and "not yet". The dynamic-target cues
  (`CalorieRingSummary.cue`: updating / increase / reduction) render under the caption
  exactly as they do in the ring today.
- The whole hero keeps `today.calorieRing`, the same accessibility label/value/hint and
  the tap + long-press that open Nutrition Details.
- The logic is a plain struct in `Caloryn/Models/` (`CalorieDonutSummary` or similar):
  per-meal totals + budget in, sectors / remaining / over out. Unit-test it. The view
  only renders.
- Mini versions (History day plates, Settings goal row, onboarding goal) are the same
  chart at 36–44pt with `angularInset: 1` and no legend: `CalorieMiniDonutView`. On a white
  surface (the Settings goal row) pass `plateColor: CalorynTheme.pageBackground` and
  `fillsPlate: true`, as the board draws it.

## Screens

Boards are named by their mock file. Where a screen has no board, apply the vocabulary.

- **Today** (`Plate`, `PlateOver`, `PlateDark`): date row = "Friday 17 October" 22pt
  heavy left, two 36pt glass circle chevrons right (ids `today.previousDay`/`nextDay`).
  Hero as above. Nutri-Score day summary, when shown, becomes a "Nutri-Score" label (17pt
  bold ink) over a row of grade chips with
  counts directly under the hero (no card). Meal sections as in Vocabulary; the header's
  macro line goes (macros live in Nutrition Details), the total stays. Empty meal row
  reads "Add dinner, or copy yesterday's." and the copy-yesterday control keeps
  `today.copyYesterday`.
- **History** (`PlateHistory`): range picker becomes ink chips (keeps
  `history.rangePicker`, still a `Picker` under the hood is fine if styled, or four
  buttons with the identifier on the container). Headline number "1.953 kcal a day",
  support line. The daily consistency strip becomes a row of mini donuts, one per day,
  `HistoryEaten` fill, over days outlined in ink, today dashed; a 3-key legend under it.
  The recurring-pattern insight is the one surface (white, bordered). "On track" and
  "Macros" as sections with ink bars. The calorie-trend card and its chart keep their
  identifiers and drill-downs; bars use `HistoryEaten` with over days in `TextPrimary`.
- **My Foods** (`PlateMyFoods`): title, glass + button (keeps `myFoods.createMenu`),
  sections Favourites / Meals / Recipes / Your own entries as hairline lists. No search
  field (not in scope). Saved meals show their item names as the subtitle.
- **Settings** (`PlateSettings`): bold section titles outside white bordered groups. Goal
  group leads with a mini donut and "2.000 kcal a day". Toggles ink. Every existing row
  stays (calorie estimate, reminder, data, about), only restyled.
- **Add Food sheet** (`PlateAddFood`): title "Add to Lunch" with the meal word in its
  ink; search well in `Surface`; sections "Usually at lunch" (the contextual
  suggestions, when any) then "Recent"; rows per Vocabulary. Search results, multi-select
  and barcode states keep their structure, restyled.
- **Portion sheet** (`PlatePortion`): food name 26pt heavy + badge, brand/serving line;
  kcal preview 64pt heavy in the target meal's ink (`portionPicker.calories`); stepper
  pill (`gramsField` ids unchanged, minus/plus step 10 g); quick-portion chips; meal
  chips; "In this portion" rows; CTA "Log to lunch" in the meal fill. Edit mode keeps
  the delete action and identifiers.
- **Nutrition details** (`PlateDetails`): big number, "Against your targets" ink bars,
  fruit and veg chips with a dashed "n more for variety", Nutri-Score counts, remaining
  nutrients as hairline rows, the data-quality note. Ids `nutritionDetails.*` stay.
- **Onboarding** (`PlateWelcome`, `PlateGoal`): welcome = the four-sector ring with a
  bite out of it (a 200pt donut with a page-coloured circle over the top-left), the name,
  the existing two-line tagline, ink CTA, the existing footnote. Goal step = "Your daily
  plate", empty donut inside a dotted "what you burn" ring, slider labelled gain / keep /
  lose, "Where the number comes from" rows, "Set a number yourself instead" link. Other
  steps: same vocabulary (hairline rows, chips for choices, ink CTA). All
  `onboarding.*` ids stay.
- **Everything else** (recipe, custom food and meal forms, multi-add review and editor,
  ingredient amount, scanner, history drill-downs, goal and profile edit): restyle to the
  vocabulary. Forms keep `calorynFormStyle()` with white group surfaces. No new features.

## App icon and widgets

Finished after the merge of the redesign (the first cut shipped the sage icon and widgets).

- **Icon**: the welcome screen's mark — the four-meal ring with the bite out of its
  top-left, no glyph — on the light page, filling 76% of the icon (Apple's icon-grid
  circle). The dark variant draws the dark fills on a transparent background, so the
  system's dark backdrop shows through the hole and the bite; the tinted variant is the
  same ring in four greys, brightest for breakfast and darkest for dinner, so the sectors
  stay tellable apart once the system tints them. `scripts/render-app-icon.swift` draws all
  three from the Color Sets; re-run it after a palette change rather than editing the PNGs.
- **Widgets**: paper and ink, no cards. The Today widget draws the day as the same plate —
  Swift Charts, empty hole, meals in their fill, the rest in `Hairline`, the overshoot in
  ink — with the number beside the ring and the "x of y eaten" line under it; the large
  family adds the legend. Quick log is a hairline row per meal, the name in the meal's ink
  and the meal header's wash-and-plus at the end, no meal glyphs. The widget snapshot
  carries each meal's kcal (`WidgetCalorieSummary.meals`; a snapshot from before decodes
  to an empty list and draws its total in `HistoryEaten`). `WidgetPlateSummary` in
  `CalorynShared` restates `CalorieDonutSummary`'s sector rule for the widget target. The
  whole plate is `widgetAccentable()`, so in the tinted rendering mode the meals take the
  accent and the track keeps the hairline's alpha.

## Where the build differs from the boards, on purpose

The boards are the reference except here. Each is either the scope above winning over a
mock, or a decision this change does not make.

- **Add Food keeps its saved-meals section** ("Meals") between the suggestions and Recent,
  as on `main`; `PlateAddFood` folds "Office lunch" into "Usually at lunch". Sheet
  structure stays (Scope).
- **Add Food's scanner circle stays glass**, tinted `Surface` with a `Hairline` edge, where
  the board draws a flat `Surface` circle: chrome stays glass (Scope).
- **No step-progress capsules in onboarding.** `PlateGoal` draws six above the goal step;
  the flow has never had them, and adding one is a feature, not a skin.
- **Inactive tab items stay in the system's label colour, not `TextSecondary`.** On the
  iOS 26 Liquid Glass tab bar the selected item takes `.tint` and every other item is drawn
  in the vibrant label colour, which on this page reads as ink. Checked against the iOS 27
  SDK on iOS 26.5 and 27.0 simulators (2026-10-18): `UITabBar.appearance()
  .unselectedItemTintColor`, a `UITabBarAppearance` with `normal.iconColor` and
  `titleTextAttributes` on every layout, `UITabBarItem.appearance()
  .setTitleTextAttributes(_:for: .normal)` and a `.foregroundStyle` on the `Tab` label all
  leave the inactive items exactly as they were; `.tint` recolours only the selected one.
  Nothing in the iOS 27 SDK adds a public knob (`UITabBarController` gains a prominent tab
  and batch updates, SwiftUI nothing tab-colour-related). The chrome is the system's, so
  the system look stays.
- **The edited product catalog keeps the system navigation-bar search field** rather than
  a `Surface` well: it is navigation chrome, like the bar it drops from.

## Verification, per lane and at integration

- Build with `set -o pipefail` and an explicit simulator **id** (two iPhone 17s exist;
  a name is ambiguous): `xcodebuild build -project Caloryn.xcodeproj -scheme Caloryn
  -destination "id=<UDID>" CODE_SIGNING_ALLOWED=NO`.
- Unit plan: `-testPlan Caloryn-Unit` on an **iPhone 17 / iOS 26.5** simulator, which is
  what the snapshot references are pinned to. A component whose pixels change
  (FoodRowView, NutriscoreBadge, NutriscoreDaySummary, the card surface) gets its `.png`
  deleted, the test run twice, and the new image opened and described in the commit
  message. `precision` stays 1.0 and `perceptualPrecision` 0.98.
- Run the app and look: install the built `.app`, launch with
  `-uitest-reset -uitest-seed loggedDay` (or `customFoods`, `history`,
  `historyPattern`, `empty` for onboarding), `xcrun simctl io <UDID> screenshot`, then
  switch `xcrun simctl ui <UDID> appearance dark` and capture again. Put the capture next
  to the mock PNG and list the differences before deciding they are acceptable.
- UI plan: `-testPlan Caloryn-UI` must pass; a retry is a bug.
- Integration: `./scripts/theme-screenshots.sh` for all 25 surfaces in both appearances;
  the pure-white census is expected to rise on light mode because `CardBackground` is
  now white on purpose — read the images, not just the numbers. Audit per struct, not per
  file, for a missing canvas (`docs/theme.md`).
- Never run two test plans on one simulator at once. One lane, one simulator, created
  with `xcrun simctl create`, erased once after creation so appearance switching works.
