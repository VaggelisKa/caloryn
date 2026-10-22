# Coverage: what the two numbers mean

CI reports two coverage figures. They count differently, so they are not
comparable with each other, and neither is the number Xcode's coverage pane
shows for the whole app.

| Figure | Counts | Gate |
| --- | --- | --- |
| Unit plan (`coverage_report.py`) | xccov's report: a line once per function containing it | ratchet vs main, 0.5pp |
| Combined (`line_coverage.py`) | each source line once, covered when the unit plan *or* the UI journeys ran it | ≥ 70%, and ratchet vs main |

## Why the unit plan alone cannot answer "how much is tested"

SwiftUI views are most of the app's executable lines, and unit tests do not
reach them. That is by design. The suite asserts behaviour, never structure (no
ViewInspector), and snapshots cover only components with no clock, store or
animation (`snapshot-testing.md`). So view logic lives in plain structs under
`Caloryn/Models/`, where it is unit-tested, and the views themselves are
exercised by the E2E journeys.

A unit-plan-only figure therefore measures the logic layer diluted by thousands
of view lines it was never meant to reach. On 2026-10-18, before the logic
backfill, the logic layer was 79% covered by the unit plan, the whole app 32%.
Rendering every screen inside a unit test would raise that number, but those
tests would mostly prove a view rendered, not that it is right. This is the
"a line ran is not a line verified" trap from `mutation-testing.md`.

## Why the combined figure counts lines differently

`xccov view --report` sums per-function line counts. A SwiftUI body nests a
closure per container, so a view line is counted once for each closure that
contains it. `FoodSearchView.swift` has 849 executable lines, and the report
counts 1,910. Logic files have no such nesting and come out identical either
way.

Two such reports also cannot be unioned: a file at 40% in one plan and 60% in
the other could be anywhere from 60% to 100% combined. `line_coverage.py` reads
the per-line data instead (`xccov view --archive --json`), so the union is exact.
It is also the usual definition of line coverage (llvm-cov's).

The unit-plan ratchet stays as well. Without it, deleting unit tests whose
lines a journey also happens to run would not move the combined figure.

## Reproducing it locally

Run both plans with coverage on one simulator, one plan at a time, then combine:

```bash
python3 .github/scripts/line_coverage.py export Unit.xcresult --root . --output unit.json
python3 .github/scripts/line_coverage.py export UI.xcresult --root . --output ui.json
python3 .github/scripts/line_coverage.py combine --input unit=unit.json --input ui=ui.json \
  --output summary.md --percent-file percent.txt
```

`xcrun xcresulttool merge` looks like a shortcut but is not one: on the same two
bundles it reported less view coverage than the UI bundle alone.

## Not counted, or not countable

- The widget extension's views: the unit test bundle is hosted in the app and
  cannot import the extension, and the UI plan does not drive SpringBoard. The
  shared projection logic in `CalorynShared/` is covered.
