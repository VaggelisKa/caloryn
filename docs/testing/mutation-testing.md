# Mutation testing: why there isn't any

There was a weekly mutation audit here, using [muter][muter]. It was removed in
July 2026 without ever having produced a score. This note exists so the next
person to reach for muter knows what they are walking into.

## What mutation testing would have told us

Coverage says a line ran. Mutation testing asks whether anything would have
noticed if that line were wrong: it edits the source — flips a comparison,
removes a side effect — and checks whether the suite goes red. A mutant that
survives is a line that executes during tests without being verified.

That is the one question this suite cannot answer about itself, which is why it
was worth attempting.

## Why it was dropped

Three problems, found in sequence. The first two were fixed; the third was not.

**The invocation was wrong, and the job reported green.** `--files-to-mutate`
takes one comma-separated argument; the workflow passed eighteen separate ones,
so muter accepted the first and rejected the rest. The step carried
`continue-on-error: true` — correctly, since a low score should never block a
pull request — so the job went green anyway, for every run it ever made.

**The published release predates current Xcode.** `brew install muter` gives you
muter 16, released September 2023. It cannot parse Xcode 26's
`build-request.json`, and it predates muter recognising Swift Testing failures at
all (upstream #306, July 2026). Since most of this suite is `@Test` / `#expect`,
that build would have reported our best-tested code as our weakest. Building a
pinned commit of the maintained source got past both.

**Muter could not observe our test failures.** With the tooling fixed, a full run
completed and reported **0 of 279 mutants killed**. That was not a measurement:

- Muter recorded the mutant at `GoalEditDraft.swift:104` — `&&` → `||` in
  `isInvalidTarget` — as `passed`. Applying that exact edit by hand and running
  `Caloryn-Unit` fails with 9 assertions. The suite kills it; muter did not see.
- 279 mutants finished in 1h16m — 16.5 seconds each, against 6–10 minutes for
  one real run of the unit plan in CI. The suite cannot have been running.

`TestSuiteOutcome.from(testLog:terminationStatus:)` returns `.passed` only when
the log holds no failure text *and* the process exits 0, so the per-mutant
`xcodebuild` was likely exiting successfully without testing. An unconfirmed but
plausible cause: the mutated copy at `<project>_mutated` lacks resolved Swift
packages, and this project has a test-only SPM dependency.

## If you want to try again

The blocker is upstream, not here. Muter's last release is from September 2023
while its `master` is active, so any attempt means pinning an unreleased commit
and owning that choice.

Two things worth keeping from the last attempt:

1. **A tool that cannot measure must fail loudly.** A missing report and a low
   score are different events; so are "0% because the suite is weak" and "0%
   because nothing ran". The old workflow treated all of them as green.
2. **Check the wall clock.** 16.5 seconds per mutant was the tell, and it was
   visible in the report before any of the source-reading was necessary.

[muter]: https://github.com/muter-mutation-testing/muter
