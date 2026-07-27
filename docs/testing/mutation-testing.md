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

`--files-to-mutate` takes **one comma-separated argument**, not a list of
arguments. Space-separated paths make muter accept the first and reject the rest
with `unexpected arguments`:

```sh
muter run --files-to-mutate "Caloryn/Models/GoalEditDraft.swift,Caloryn/Models/PortionSelection.swift"
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

It runs weekly and on demand (`.github/workflows/mutation-audit.yml`), and **the
score** never fails the build. Three reasons:

1. It is far too slow for pull-request feedback.
2. Mutation scores are noisy — equivalent mutants can never be killed, so a
   perfect score is unreachable and chasing one wastes effort.
3. Gating on it encourages tests written to kill mutants rather than to describe
   behavior, which is the same failure mode as gating on a coverage percentage.

Treat it as a periodic audit that tells you where the assertions are thin.

A **missing report** is the one thing that does fail the job, and it is not the
same event as a low score: it means muter never ran, so nothing was measured.
That distinction was learned the hard way — see below.

## Status: the audit does not work yet

**No mutation score has ever been produced for this project.** Three problems
were found in sequence; two are fixed and the third is open.

### 1. The invocation was wrong, and the job went green anyway (fixed)

The first scheduled run (26 July 2026) passed each scoped path as a separate
argument, so muter took the first and rejected the rest:

```
Error: 11 unexpected arguments: 'Caloryn/Services/ActivityCalorieBudget.swift', ...
```

Because the step carries `continue-on-error: true` — so a low score can never
block anything — the job exited successfully. The summary said only that no
report was produced, and nobody was watching that line. The paths are now joined
into the single comma-separated argument muter expects, and a **missing report
now fails the job**, which is a different event from a low score.

### 2. The published muter predates Xcode 26 (fixed)

`brew install muter` gives you muter 16, released September 2023. It dies here:

```
Could not parse build request json at path: .../XCBuildData/<hash>.xcbuilddata/build-request.json
```

It also predates muter learning to recognise Swift Testing failures at all
(upstream #306, merged 21 July 2026). Most of this suite is `@Test` / `#expect`,
so that build would have scored our best-tested code as our weakest.

The source is maintained; only the release is stale. The workflow now builds a
**pinned commit** and caches it on that SHA, so the tool cannot shift underneath
a score comparison. Bump `MUTER_COMMIT` deliberately, and expect the number to
move when you do.

### 3. Muter does not observe our test failures (open)

With both fixes in place the run completes and reports:

> **Mutation score: 0%** — 0 of 279 mutants killed

That is not a measurement. Two pieces of evidence:

- **Direct.** Muter recorded the mutant at `GoalEditDraft.swift:104`
  (`&&` → `||` in `isInvalidTarget`) as `testSuiteOutcome: "passed"`. Applying
  that exact edit by hand and running `Caloryn-Unit` fails with **9 failing
  assertions**. The suite kills that mutant; muter did not notice.
- **Timing.** 279 mutants finished in 1h16m — **16.5 seconds each**. One real
  run of the unit plan takes 6–10 minutes in CI. Muter cannot have been running
  the suite at all.

`TestSuiteOutcome.from(testLog:terminationStatus:)` returns `.passed` only when
the log holds no failure text *and* the process exited 0, so the likely shape is
that the per-mutant `xcodebuild` invocation is exiting successfully without
running the tests. The mutated copy lives at `<project>_mutated`; a plausible
cause is that the copy lacks resolved Swift packages — this project gained a
test-only SPM dependency (swift-snapshot-testing) — but that has **not** been
confirmed.

Until this is understood, the workflow **rejects a 0-killed result** rather than
publishing it. A broken audit wearing a number is worse than no audit, because
the number invites the wrong conclusion about the suite.

`.github/scripts/mutation_summary.py` has now read one real report and its
assumptions held.

Muter is the only meaningful mutation-testing tool for Swift, and its maintenance
is thin. If it breaks against a future Xcode, dropping this workflow costs
nothing else in the test suite.
