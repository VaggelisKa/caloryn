# Theme

CLAUDE.md rule 7 states the rules. This is why they exist.

## The failure mode

SwiftUI's defaults are wrong for a custom palette, and wrong in a way that looks right.

- A `List` or `Form` paints `systemGroupedBackground` **over** anything behind it. Setting
  `.background(CalorynTheme.pageBackground)` on it silently does nothing.
- `.listStyle(.plain)` paints `systemBackground` — white in light mode.
- A `Color` built from a `UIColor { traits in … }` closure falls back to whatever the
  `else` branch returns. Two of ours returned system greys, so dark mode quietly wasn't
  themed at all.

None of these fail. Nothing warns. The screen just renders slightly whiter than its
neighbours, which is exactly the kind of difference that survives code review. Every new
screen was a fresh opportunity to forget, and the adoption numbers showed it: at the point
this was fixed, `calorynPageCanvas()` was on 6 of 22 screens and `presentationBackground`
on 2 of 19 sheets.

The fix is not "remember the modifier". It is to make forgetting impossible or visible.

## Why an asset catalog

Colours live in `CalorynShared/SharedColors.xcassets` as Color Sets, each declaring its
light and dark appearance together, surfaced through Xcode's generated symbols
(`Color(.pageBackground)`).

The point is not tidiness. **A Color Set cannot omit a dark appearance without showing it
in Xcode's inspector, whereas a closure can omit one silently.** That asymmetry is the
whole argument. The previous `pageBackground` had been resolving to
`.systemGroupedBackground` in dark mode for as long as the theme had existed, and nobody
saw it, because nothing rendered it.

`CalorynShared` is a member of both the app and widget targets, so `WidgetTheme` reads the
same assets. It used to duplicate the values under a "keep in sync" comment. They had not
yet drifted — but the mechanism guaranteed they eventually would.

`CalorynTheme` is unchanged as an API. It was already a facade over 978 call sites; only
its backing moved. Renaming it would have been a 978-site rewrite for no benefit.

Two gotchas worth knowing:

- Xcode **strips a trailing `Color`** when generating symbols: an asset named `CarbColor`
  yields `.carb`. Ours are named `Carb` and `Fiber` so name and symbol agree.
- The generated symbols do not exist until the catalog compiles, so SourceKit reports
  `cannot be resolved without a contextual type` on a clean checkout. Trust the build.

## Why AccentColor matters more than it looks

`AccentColor.colorset` was an empty stub — it declared no colour. Every stock control that
was not hand-tinted therefore fell back to system blue.

The cost was not just the wrong colour. It was **48 hand-written `.tint(CalorynTheme.sage)`
call sites**, and a 40-line `UIViewControllerRepresentable` in the History drill-down whose
entire job was:

```swift
navigationController?.navigationBar.tintColor = UIColor(CalorynTheme.sage)
```

A careful engineer followed the theme correctly and still had to drop into UIKit, because
a one-line asset was missing. Populating the asset deleted that bridge and 37 of the tint
calls. The remaining ones are deliberate non-accent colours.

## Why the lint rules ban primitives

SwiftLint custom rules are per-match regexes with no whole-file logic, so the intuitive
rule — "this file uses `List` but not `calorynGroupedListStyle`" — is not expressible.

Banning `.listStyle(...)` outright is both expressible and stronger. Requiring the
abstraction leaves the unthemed state reachable; banning the primitive removes it. There is
nothing to assert once the wrong thing cannot be written.

One gap remains and is accepted: "every screen adopts `calorynPageCanvas()`" is not
enforceable this way. With the primitives banned the failure is mild — a screen that
forgets inherits its parent's background rather than painting a system colour over it.

## Row backgrounds, and the limit of the abstraction

`calorynGroupedListStyle()` hides the *scroll* background. It cannot set the *row*
background, and an inset-grouped row paints its own `secondarySystemGroupedBackground` —
pure white in light mode. So `cardBackground` never rendered in any grouped list, and the
symptom that started this work ("some screens are whiter") survived the first pass at
fixing it.

Two things were learned the hard way, both by measuring pixels rather than reasoning:

- `.listRowBackground` applied to the **List** does nothing. Applied to a **Section** it
  propagates to that section's rows. The first fix was the former and changed not a single
  pixel.
- Every `Section` in a grouped list therefore needs the modifier. Settings went from
  **28% of the screen being pure white to 0.2%**.

A `Form` behaves the same way and needs `calorynFormStyle()` plus the same row
backgrounds. This was found third, after the two list cases, on the multi-add review
sheet — 64% of that screen was `#F2F2F7`.

This is a genuine hole in the abstraction and it has no automated guard: SwiftLint's
custom rules can ban a primitive but cannot detect a *missing* modifier. It is covered by
convention (CLAUDE.md rule 7) and by looking at screenshots, nothing stronger.

### Audit per struct, not per file

Three unthemed screens — `GoalEditView`, `ProfileEditView`, `MissingFoodEntryView` — hid
from a file-scoped grep for "has a `navigationTitle` but no canvas", because each lives in
a file whose *outer* view (`SettingsView`, `TodayView`) is correctly themed. They were
found only by splitting each file into top-level `struct …: View` bodies first and asking
the question of each one separately. Any future sweep for a missing modifier must do the
same, and must drop `#if DEBUG` preview blocks, which otherwise produce false hits.

## Back buttons are replaced, not tinted

A pushed detail screen gets `calorynDrillDownNavigation()`, which hides the system back
button and supplies one the app owns.

Tinting was tried three ways at once. `HistoryDrillDownNavigationModifier` carried the
`AccentColor` asset, a `.tint(sage)`, **and** a UIKit `navigationBar.tintColor` bridge —
and the chevron still measured 0 sage pixels and 523 near-black ones. Liquid Glass renders
the back button in a container that ignores all three.

An earlier revision of this document argued the UIKit bridge should stay anyway, on the
grounds that the app deploys to iOS 18.6 where `tintColor` *does* apply, and the UI test
target (iOS 26.0) cannot verify that. That reasoning was sound but is now moot: a custom
back button works on both versions, so the bridge is gone.

The cost is real and worth knowing: hiding the system back button is the one place a
swipe-back regression could appear, and no test covers that gesture.

Screens that already build their own leading toolbar item — `PortionPickerView`,
`MyFoodsView` — must *not* also take this modifier, or they get two back buttons. Those two
are also the reason the bug was visible at all: their chevrons were correctly sage while
every other pushed screen's was black.

## Page canvas vs sheet canvas

`calorynPageCanvas()` paints `pageBackground`; `calorynSheetCanvas()` paints
`cardBackground`. Tab pages and pushed detail views use the first, modal sheets the
second, so a sheet reads as floating above the page rather than continuing it.

The list modifiers therefore paint no background of their own — the canvas supplies the
colour, so the same list is correct on a page and in a sheet. Rows still need
`.listRowBackground(...)`.

## Toolbar buttons need an explicit foreground style

iOS 26 renders navigation-bar and toolbar buttons inside a glass container that honours
**neither** the `AccentColor` asset **nor** `.tint()`. Both were measured: with `.tint()`
applied to the sheet canvas the close glyph still rendered `#000000`. Only
`.foregroundStyle(CalorynTheme.sage)` on the label itself works, which is why a couple of
buttons in the codebase already had it while their neighbours did not.

This is the same root cause as the back button above, and it means the `AccentColor` asset
does *less* than it appears: it covers controls in content, not chrome.

`Button("Save") { … }` is a special case with no fix available at the call site: the string
initializer builds its own label, so there is no view to attach `.foregroundStyle` to. Use
the explicit `label:` form. Where the button has a `.disabled(…)` condition, put that
condition in a ternary on the colour too — a flat sage silently throws the disabled
affordance away, which is a behaviour change smuggled inside a colour fix.

A measurement note, since this cost a cycle: sampling "the darkest pixel in the button's
box" finds the glyph in light mode and the *container* in dark mode. Count pixels matching
the expected colour instead.

## Looking at the app

```
./scripts/theme-screenshots.sh [output-dir]     # default /tmp/caloryn-theme-shots
```

Captures 25 surfaces in both appearances — all seven onboarding steps, Today, the food
search sheet, its results, those results *while the search is still running*, and the
portion picker, History with both drill-downs, Settings with both editors, My Foods,
multi-add review and its portion editor, the three creation sheets, and the ingredient
amount picker — then prints how much of each screen is `pageBackground`,
`cardBackground`, sage, and pure white.

Every extension of this harness so far has found a bug on the screen it was extended to
reach. That is the argument for adding a capture whenever a screen is touched.

### A screen the harness cannot reach is a screen nobody looks at

The onboarding captures came last and found the largest single gap: **none** of the seven
steps had a canvas, so the first screen a new user ever saw was system white — and in dark
mode near-black — while everything behind it was warm. Five of them also carried a system
back button, blue.

The reason it survived so long is structural rather than careless. Every capture in this
file launches with a fixture that seeds a `UserProfile`, and `ContentView` shows the main
tabs whenever a profile exists. Onboarding was not merely un-photographed; it was
*unreachable* by the only tool that looks at colour. The fix is one line — the `.empty`
fixture seeds no profile — but nothing pointed at the omission, because a harness reports
what it captured, never what it could not.

So when auditing, ask which screens the harness cannot get to at all, not just which of
its captures look wrong.

**A transient state is a surface too.** The search results list keeps a trailing spinner row
while more results are on the way, and that row painted its own white background for as long
as it existed: no capture could show it, because a real search settles in milliseconds and
every capture waits for it to settle. The `CALORYN_LOOKUP_FIXTURE=search-loading` fixture
(DEBUG) pins the search in flight so the row stays on screen. Note that the fixture also
needs a *local* match in the seed — with none, the view shows a full-screen spinner and
never builds the list at all, which is a different screen and photographs clean.

It prefers an already-booted simulator, so running it does not boot a second one alongside
whichever device you are testing on by hand.

Read the census before opening images: drift shows up as a number. Pure white above ~2% on
a screen without a keyboard means a `List` or `Form` row is painting its own background.
A dark capture whose page/card percentages are 0.0% means the appearance never switched —
that happened twice, and both times the images were silently light.

`ThemeScreenshotTests` asserts it reached every screen but nothing about colour, because no
XCTAssert reads a colour. The reaching is machine-checked; the looking is not.

## Why the snapshots were extended

The suite rendered only `traits: .reference` — light, `.large`. Every token the migration
changed was invisible to it: it passed unchanged through `cardBackground` going from pure
white to `#FAFAF7` and both dark backgrounds moving off system greys.

It now covers both appearances, the card surface (`solidCardSurface` is the only thing that
renders `cardBackground` and `cardSeparator`), the Nutri-Score badges in both modes — those
colours are appearance-independent by design, so asserting both makes that a checked
property — and one row at `accessibilityExtraExtraExtraLarge`.

The nine original light-mode tests were deliberately **not** re-recorded. Their images are
the evidence that light mode did not move during the migration.
