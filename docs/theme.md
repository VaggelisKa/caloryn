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

This is a genuine hole in the abstraction and it has no automated guard: SwiftLint's
custom rules can ban a primitive but cannot detect a *missing* modifier. It is covered by
convention (CLAUDE.md rule 7) and by looking at screenshots, nothing stronger.

## Why the UIKit navigation tint survives

`HistoryDrillDownNavigationModifier` looks redundant now that `AccentColor` is set, and it
was deleted at one point. Measured on iOS 26, the drill-down back chevron is `#1B1914`
**with or without it** — identical pixels — because Liquid Glass renders the back button in
a glass container that ignores `navigationBar.tintColor`.

That is not sufficient reason to delete it. The app deploys to **iOS 18.6**, where the back
button is an ordinary chevron that *does* honour `tintColor`, and `ThemeScreenshotTests`
cannot run there: the UI test target's own deployment target is iOS 26.0. So the modifier
is proven inert on the SDK and unverifiable on the floor. It stays.

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

This is the same root cause as `HistoryDrillDownNavigationModifier` above, and it means the
`AccentColor` asset does *less* than it appears: it covers controls in content, not chrome.

A measurement note, since this cost a cycle: sampling "the darkest pixel in the button's
box" finds the glyph in light mode and the *container* in dark mode. Count pixels matching
the expected colour instead.

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
