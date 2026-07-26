# Mutation testing

## What it tells you that coverage does not

Code coverage says a line *ran*. It does not say anything was *checked*. A test
that calls a function and asserts nothing produces the same coverage number as a
test that verifies every branch.

Mutation testing closes that gap. Muter edits the source — flips `<` to `<=`,
removes a side effect, changes a boolean — rebuilds, and reruns the suite. If
the tests still pass, that mutant **survived**: the line runs during tests
without being verified.

This project has a concrete example. `HealthKitService.swift` shows about 300 of
433 lines covered, but it has no tests at all — those lines are executed
incidentally during app start-up. Coverage rates it well; mutation testing would
rate it at zero.

## Running it locally

Muter is not a project dependency and is not installed by the repo. Install it
yourself when you want to run an audit:

```sh
brew install muter-mutation-testing/formulae/muter
```

Then, from the repo root:

```sh
muter run --files-to-mutate "Caloryn/Services/NutritionCalculator.swift"
```

Mutation testing reruns the whole test suite **once per mutant**, so it is slow —
minutes for one file, hours for the whole domain core. Run it against one file at
a time while working on that file.

Configuration lives in `muter.conf.yml`. It pins the `Caloryn-Unit` test plan,
because the UI journey tests take over two minutes per run and would make an
audit take days.

## Reading the result

A report lists, per file, how many mutants were **killed** (a test failed — good)
and how many **survived** (no test noticed — a gap).

For each survivor, ask: *if this line were wrong in this way, would a user
notice?* If yes, the tests need a stronger assertion. If no — the mutation is in
logging, a debug path, or genuinely equivalent code — leave it. A 100% score is
not the goal; understanding the survivors is.

## Why it is scoped

The audit only mutates pure domain logic that already has real tests:

| Area | Files |
| --- | --- |
| Nutrition math | `NutritionCalculator`, `ActivityCalorieBudget` |
| History | `HistoryAnalytics`, `HistoryPatternDiscovery` |
| Logging | `FavoriteFoodLogging`, `DailyReminderPlanner` |
| App Intents | `CalorynIntentDomain` |
| Domain models | `ProduceVarietySummary`, `NutritionValues`, `DailyGoalSnapshot`, `GoalEditSeed`, `OnboardingProfileSave`, `SelectedDayRollover` |

Views are excluded: they are covered by journey tests, which are far too slow to
rerun per mutant. Files with no tests are excluded because the result is a
foregone conclusion — everything survives, which tells you nothing you did not
already know from the coverage report.

## Why it is not a CI gate

It runs weekly and on demand (`.github/workflows/mutation-audit.yml`), and it
never fails the build. Three reasons:

1. It is far too slow for pull-request feedback.
2. Mutation scores are noisy — equivalent mutants can never be killed, so a
   perfect score is unreachable and chasing one wastes effort.
3. Gating on it encourages tests written to kill mutants rather than to describe
   behavior, which is the same failure mode as gating on a coverage percentage.

Treat it as a periodic audit that tells you where the assertions are thin.

## Status

The configuration and workflow are in place but **have not yet been executed** —
muter was deliberately not installed on a developer machine as part of this
change. The first real run will happen on the next scheduled trigger or the
first manual `workflow_dispatch`. Expect to adjust `muter.conf.yml` once there is
real output; muter's report format has changed between releases, and
`.github/scripts/mutation_summary.py` reads it defensively for that reason.

Muter is the only meaningful mutation-testing tool for Swift, and its maintenance
is thin. If it breaks against a future Xcode, dropping this workflow costs
nothing else in the test suite.
