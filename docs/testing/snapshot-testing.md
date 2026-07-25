# Snapshot testing

Pixel snapshots of the app's reusable presentational components, using
[swift-snapshot-testing][lib]. They run in the unit test plan and take about a
tenth of a second in total.

## What they are for

A snapshot catches the visual regressions that assertions do not: a row that
starts wrapping instead of truncating, a badge that loses its background, a
colour token that stops resolving. Nothing else in the suite looks at what the
app draws.

## Why they arrived last

They were deliberately held back until the view-logic refactor had landed. A
snapshot fails on any visual change at all, so recording them against a
structure still being moved would have produced a stream of re-recordings
rather than reviews — and a team that gets used to re-recording without looking
has a suite that cannot fail.

## What is eligible

Only components whose entire output is determined by their inputs.

Excluded, and why:

- anything reading the clock — a snapshot that changes on its own trains people
  to ignore it
- anything reading the store, which brings in ordering and migration state
- anything mid-animation, including `CalorieRingView`, whose ring animates up
  from zero on appear

`FoodRowView` reads `@AppStorage("showNutriscore")`, which would otherwise make
it depend on whatever the machine happened to have stored. The test pins that
default rather than trusting it.

## The two precision knobs

These are easy to get backwards, and getting them backwards makes the suite
decorative:

| Knob | Means | Set to |
|---|---|---|
| `precision` | Fraction of pixels allowed to differ | `1.0` — none |
| `perceptualPrecision` | How far each pixel may drift in colour | `0.98` |

The first version of these tests used `precision: 0.99`. A changed digit is
roughly 0.1% of the image, so **380 kcal becoming 381 passed**. Antialiasing
tolerance belongs in `perceptualPrecision`, which is per-pixel; `precision` is a
budget for how much of the image may be wrong, and that budget should be zero.

If you loosen either knob, verify the suite still fails on a one-character
change before you commit.

## Reproducibility

Snapshots compare pixels, so anything that differs between a laptop and CI
shows up as an unexplained image diff. Three things are pinned:

- **Device and runtime** — iPhone 17 / iOS 26.5, chosen by
  `.github/actions/select-simulator`, which CI and local runs share.
- **Layout** — a fixed width and height rather than a device profile, so the
  images do not depend on the simulator's screen at all.
- **Dependency versions** — `Package.resolved` is tracked. It sits under
  `project.xcworkspace`, which `.gitignore` excludes, so that path is
  re-included by name; without it CI could resolve a different version of the
  rendering library than you did.

Interface style is passed as a `UITraitCollection`, not through SwiftUI's
`colorScheme`. The theme's colours are dynamic `UIColor`s and resolve from the
trait collection, so that is the only place pinning it has any effect.

## Working with them

Add a case by writing the test and running it once: the first run records the
reference and fails, telling you to re-run. **Look at the recorded image before
you commit it** — a wrong reference is worse than no test, because it locks the
bug in.

References live in `CalorynTests/Snapshots/__Snapshots__/`.

When a snapshot fails, the diff is attached to the test result bundle, which CI
uploads as the `unit-test-results` artifact. Open it in Xcode to see reference,
actual, and difference side by side.

To re-record after an intended visual change, delete the affected `.png` and run
the test twice — once to record, once to assert. Review the new image in the
diff of your pull request; that image *is* the change under review.

[lib]: https://github.com/pointfreeco/swift-snapshot-testing
