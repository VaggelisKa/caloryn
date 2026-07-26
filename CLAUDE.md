# Caloryn — agent instructions

SwiftUI + SwiftData iOS app, deployment target iOS 26.

## Tests

`xcodebuild test -project Caloryn.xcodeproj -scheme Caloryn -testPlan <plan> -destination "platform=iOS Simulator,name=iPhone 17" CODE_SIGNING_ALLOWED=NO`

Plans: `Caloryn-Unit` (639 tests, ~1.4s) · `Caloryn-UI` (9 journeys, ~88s) · `Caloryn-All`.

Use `set -o pipefail` when piping xcodebuild — otherwise a failed build reports `grep`'s
exit code and looks green.

## Rules

1. **Assert on behaviour, never structure.** No test may depend on view composition or
   on which type performed a write. Don't add ViewInspector: it breaks on exactly the
   refactoring it should protect.
2. **Characterize, don't fix.** A test that reveals a bug encodes current behaviour and
   reports it. Never fix the app inside a change whose value is being
   behaviour-preserving. Check `main` before calling anything a regression — several
   "new" bugs here predated the PR under review.
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
6. **Mutation testing reports, never gates.** Add new pure-logic models to its scope in
   `.github/workflows/mutation-audit.yml`.
7. **Measure, don't assume.** Already tried and dead: parallelising the UI target
   (141s vs 140s), and letting xcodebuild re-resolve packages (+112s). CI wall-clock is
   noisy — the same commit ran 137s/206s/268s, so never claim a CI speed-up from one
   sample.

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

`docs/testing/snapshot-testing.md` · `docs/testing/mutation-testing.md` · issue #90
(open defects the suite surfaced).
