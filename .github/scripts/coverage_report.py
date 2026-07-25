#!/usr/bin/env python3
"""Turn an `xccov --report --json` payload into a readable per-file summary.

Writes a Markdown table for the job summary and the overall line-coverage
percentage used by the coverage ratchet.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path


def build_summary(report: dict) -> tuple[str, float]:
    covered_lines = 0
    executable_lines = 0
    rows: list[tuple[str, float, int]] = []

    for target in report.get("targets", []):
        # Test bundles inflate the number without saying anything about the
        # app's own coverage, so they are excluded.
        if target.get("name", "").endswith(".xctest"):
            continue

        for source_file in target.get("files", []):
            executable = source_file.get("executableLines", 0)
            covered = source_file.get("coveredLines", 0)
            if executable == 0:
                continue
            executable_lines += executable
            covered_lines += covered
            rows.append((source_file.get("name", "?"), 100.0 * covered / executable, executable))

    overall = (100.0 * covered_lines / executable_lines) if executable_lines else 0.0

    # Least-covered first: that is where the next test is most valuable.
    rows.sort(key=lambda row: (row[1], -row[2]))

    lines = [
        "## Code coverage",
        "",
        f"**Overall: {overall:.2f}%** ({covered_lines}/{executable_lines} executable lines)",
        "",
        "### Twenty least-covered files",
        "",
        "| File | Coverage | Executable lines |",
        "| --- | ---: | ---: |",
    ]
    for name, percent, executable in rows[:20]:
        lines.append(f"| {name} | {percent:.1f}% | {executable} |")

    return "\n".join(lines) + "\n", overall


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("report", type=Path, help="xccov JSON report")
    parser.add_argument("--output", type=Path, required=True, help="Markdown summary destination")
    parser.add_argument("--percent-file", type=Path, required=True, help="Overall percentage destination")
    args = parser.parse_args()

    report = json.loads(args.report.read_text(encoding="utf-8"))
    summary, overall = build_summary(report)

    args.output.write_text(summary, encoding="utf-8")
    args.percent_file.write_text(f"{overall:.2f}", encoding="utf-8")
    print(summary)


if __name__ == "__main__":
    main()
