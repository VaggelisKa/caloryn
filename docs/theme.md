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
