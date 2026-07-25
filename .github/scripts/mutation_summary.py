#!/usr/bin/env python3
"""Summarize a muter JSON report for the CI job summary.

Muter's report shape has changed across releases, so this reads defensively
and says what it found rather than assuming a fixed structure.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path


def main() -> None:
    if len(sys.argv) < 2:
        sys.exit("usage: mutation_summary.py <report.json>")

    try:
        report = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        print(f"Could not read the mutation report: {error}")
        return

    score = report.get("globalMutationScore", report.get("mutationScore"))
    if score is not None:
        print(f"**Mutation score: {score}%**")
        print()
        print("A surviving mutant is a line that runs during tests without")
        print("being verified. Low scores point at weak assertions, not at")
        print("missing coverage.")
        print()

    files = report.get("fileReports") or report.get("files") or []
    if not files:
        print("No per-file results were present in the report.")
        return

    rows = []
    for entry in files:
        name = entry.get("fileName") or entry.get("path") or "?"
        file_score = entry.get("mutationScore")
        killed = entry.get("killedMutants")
        total = entry.get("appliedOperators") or entry.get("totalMutants")
        if isinstance(total, list):
            total = len(total)
        rows.append((file_score if file_score is not None else -1, name, killed, total))

    rows.sort()

    print("| File | Score | Killed | Mutants |")
    print("| --- | ---: | ---: | ---: |")
    for file_score, name, killed, total in rows:
        shown = "n/a" if file_score < 0 else f"{file_score}%"
        print(f"| {name} | {shown} | {killed if killed is not None else '?'} | {total or '?'} |")


if __name__ == "__main__":
    main()
