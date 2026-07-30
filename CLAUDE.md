# Caloryn — agent instructions

SwiftUI + SwiftData iOS app. Deployment target **iOS 18.6**, built against the iOS 26 SDK —
so `#available(iOS 26.0, *)` checks are live and their `else` branches ship. Do not delete
them as dead code.

## Tests

`xcodebuild test -project Caloryn.xcodeproj -scheme Caloryn -testPlan <plan> -destination "platform=iOS Simulator,name=iPhone 17" CODE_SIGNING_ALLOWED=NO`

Plans: `Caloryn-Unit` (~1.4s) · `Caloryn-UI` (15 journeys, ~170s) · `Caloryn-All`. Measure the
unit count yourself before quoting one — every wave moves it, so a number written here is
wrong by the next PR.

Use `set -o pipefail` when piping xcodebuild — otherwise a failed build reports `grep`'s
exit code and looks green.

## Rules

1. **Assert on behaviour, never structure.** No test may depend on view composition or
   on which type performed a write. Don't add ViewInspector: it breaks on exactly the
   refactoring it should protect.
2. **Fix small bugs, characterize big ones.** Small and local — a missing guard, an
   unvalidated parse, a wrong rounding — fix it, update the test that pinned the old
   behaviour, and put it in **its own commit**, never mixed into a behaviour-preserving
   change: "everything passed unchanged" is a refactor's whole warrant, and one fix
   spends it. Anything needing a new abstraction, a schema change or a redesign is not
   a small bug — stop, encode current behaviour in a passing test, report it, and open
   a ticket if asked. Duplication is the exception worth consolidating: the same defect
   in three parsers is one fix, not three. Check `main` before calling anything a
   regression — several "new" bugs here predated the PR under review.
3. **View logic goes in `Caloryn/Models/` as a plain struct, not a ViewModel layer.**
   See `GoalEditDraft`, `CustomFoodDraft`, `PortionSelection`. The view keeps
   `@State private var draft` and renders it. Take the *facts* a rule needs, not a model
   object (`PortionSelection.Shape` takes three values, not a `FoodItem`).
4. **Snapshots must be able to fail.** `precision` = fraction of pixels allowed to
   differ, keep at `1.0`; `perceptualPrecision` = per-pixel colour drift, `0.98`. At
   0.99 a changed digit passes — that happened. If you touch either, prove the test
   fails on a one-character change first. Only snapshot components with no clock, store
   or animation. Re-record by deleting the `.png` and running twice — then look at the
   image; it *is* the change under review.
5. **E2E journeys are the refactor net.** Seeded via `-uitest-reset` / `-uitest-seed`
   (DEBUG). Find elements by accessibility identifier, never by element type. One wait,
   not two — `isHittable` already implies existence, and each extra wait costs a full
   poll cycle. Adding `.accessibilityIdentifier(...)` is the only production change
   these tests may make.
6. **Theme comes from the asset catalog, never literals.** Colours: `CalorynTheme.*`,
   backed by Color Sets in `CalorynShared/SharedColors.xcassets` that declare light and
   dark together — never `Color.white`, `Color(.system*)` or `Color(red:)`. Lists:
   `calorynGroupedListStyle()` / `calorynPlainListStyle()`, never a bare `.listStyle(...)`
   — a `List` paints a system background *over* yours unless `scrollContentBackground` is
   hidden, which is why this drift is invisible in review. **Grouped-list rows need
   `.listRowBackground(CalorynTheme.cardBackground)` on each `Section` as well** — the
   list modifier cannot do it, rows paint their own `secondarySystemGroupedBackground`,
   and nothing lints this. `Form` needs `calorynFormStyle()` *and* the same row
   backgrounds. Screens: `calorynPageCanvas()` (page) or `calorynSheetCanvas()` (sheet)
   inside the `NavigationStack`, above `.navigationTitle` — **every** screen, including
   ones nested in a file whose outer view already has one. Pushed details also need
   `calorynDrillDownNavigation()`: a system back button ignores `AccentColor`, `.tint()`
   *and* a UIKit `tintColor` bridge, so it is replaced, not tinted. Same for toolbar
   buttons — `Button("Save")` has no label to colour, so use the explicit `label:` form
   with `.foregroundStyle`, and keep the disabled state in a ternary.
   `.swiftlint.yml` enforces the bans, but **a lint rule is a per-match regex and can
   never catch a *missing* modifier** — that is the whole class of bug here. Colour is
   only ever verified by looking: run `./scripts/theme-screenshots.sh`, which captures
   all 25 surfaces in both appearances and prints a per-screen colour census. When
   auditing for a missing modifier, scan **per struct, not per file** — a file-scoped
   grep hid three unthemed screens because their outer view in the same file was fine.
   And scan for screens the harness *cannot reach*: all seven onboarding steps were
   unthemed for as long as every capture had needed a seeded profile to get anywhere.
7. **Measure, don't assume.** Already tried and dead: parallelising the UI target
   (141s vs 140s), letting xcodebuild re-resolve packages (+112s), and mutation testing
   (muter cannot see this suite's failures — `docs/testing/mutation-testing.md`). CI
   wall-clock is noisy — the same commit ran 137s/206s/268s, so never claim a CI
   speed-up from one sample.

## CI

Simulator pinned to iPhone 17; the coverage-baseline cache key includes the model
because start-up coverage varies by device. Coverage is a **ratchet, not a target** —
fails only on a regression vs main, 0.5pp tolerance. UI plan retries 3×; a retry is a
bug, not noise.

## Gotchas

- SourceKit reports phantom `No such module 'Testing'` / `Cannot find type` errors from
  a stale index. **Trust the build.**
- New source files need no pbxproj edit (synchronized groups, objectVersion 77). Adding
  a package or target does.
- Keep `Package.resolved` tracked — it's under the gitignored `project.xcworkspace` and
  re-included by name. Snapshots compare pixels; a different dependency version renders
  differently.

## Further reading

`docs/testing/snapshot-testing.md` · `docs/testing/mutation-testing.md` · `docs/theme.md` · issue #90
(open defects the suite surfaced).
