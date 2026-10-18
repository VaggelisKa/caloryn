#!/usr/bin/env python3
"""Line coverage that can be combined across test plans.

`xccov view --report` counts a line once for every function that contains it.
A SwiftUI body nests a closure per container, so view files are counted two to
three times over, and two such reports cannot be unioned: there is no way to
tell which of the counted lines each plan reached.

This counts each source line once, as covered when any test in any plan
executed it. The unit plan and the UI journeys then combine into one figure.
See docs/testing/coverage.md.

    export   one .xcresult -> a compact, repo-relative JSON of line numbers
    combine  several exports -> a Markdown summary and the overall percentage
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
from collections import defaultdict
from pathlib import Path

# Test sources are not what coverage is measuring. The test plans already
# leave them out; this keeps that true if a plan's coverage targets change.
TEST_DIRECTORIES = ("CalorynTests/", "CalorynUITests/")


def export(xcresult: Path, root: Path, output: Path) -> None:
    raw = subprocess.run(
        ["xcrun", "xccov", "view", "--archive", "--json", str(xcresult)],
        check=True,
        capture_output=True,
        text=True,
    ).stdout

    files: dict[str, dict[str, list[int]]] = {}
    for path, lines in json.loads(raw).items():
        relative = os.path.relpath(path, root)
        if relative.startswith("..") or relative.startswith(TEST_DIRECTORIES):
            continue
        executable = [line["line"] for line in lines if line.get("isExecutable")]
        if not executable:
            continue
        covered = [
            line["line"]
            for line in lines
            if line.get("isExecutable") and line.get("executionCount", 0) > 0
        ]
        files[relative] = {"executable": executable, "covered": covered}

    output.write_text(json.dumps({"files": files}, sort_keys=True), encoding="utf-8")
    print(f"Exported {len(files)} files from {xcresult}")


def area(path: str) -> str:
    """`Caloryn/Views/Today/X.swift` -> `Caloryn/Views`; `CalorynShared/X.swift` -> `CalorynShared`."""
    parts = path.split("/")
    if parts[0] == "Caloryn" and len(parts) > 2:
        return "/".join(parts[:2])
    return parts[0] if len(parts) > 1 else path


def percent(covered: int, executable: int) -> float:
    return 100.0 * covered / executable if executable else 0.0


def combine(inputs: list[tuple[str, Path]]) -> tuple[str, float]:
    plans = {name: json.loads(path.read_text(encoding="utf-8"))["files"] for name, path in inputs}

    # A line is executable if any plan saw it as executable. The plans build the
    # same app, so in practice the sets agree; the union keeps a file that one
    # plan never loaded from silently dropping out of the denominator.
    executable: dict[str, set[int]] = defaultdict(set)
    covered_by: dict[str, dict[str, set[int]]] = {name: defaultdict(set) for name in plans}
    for name, files in plans.items():
        for path, lines in files.items():
            executable[path].update(lines["executable"])
            covered_by[name][path].update(lines["covered"])

    def covered_in(path: str, names: list[str]) -> int:
        lines: set[int] = set()
        for name in names:
            lines |= covered_by[name].get(path, set())
        return len(lines & executable[path])

    names = list(plans)
    total = sum(len(lines) for lines in executable.values())
    combined = sum(covered_in(path, names) for path in executable)
    overall = percent(combined, total)

    out = [
        "## Combined line coverage",
        "",
        f"**Overall: {overall:.2f}%** ({combined}/{total} executable lines, each counted once,"
        " covered when any plan ran it)",
        "",
        "| Plan | Coverage |",
        "| --- | ---: |",
    ]
    for name in names:
        alone = sum(covered_in(path, [name]) for path in executable)
        out.append(f"| {name} alone | {percent(alone, total):.1f}% |")
    out.append(f"| **combined** | **{overall:.1f}%** |")

    by_area: dict[str, list[int]] = defaultdict(lambda: [0, 0])
    for path, lines in executable.items():
        by_area[area(path)][0] += covered_in(path, names)
        by_area[area(path)][1] += len(lines)

    out += ["", "### By area", "", "| Area | Coverage | Executable lines |", "| --- | ---: | ---: |"]
    for name, (covered, lines) in sorted(by_area.items(), key=lambda item: -item[1][1]):
        out.append(f"| {name} | {percent(covered, lines):.1f}% | {lines} |")

    # Least-covered first: that is where the next test is most valuable.
    rows = sorted(
        ((path, percent(covered_in(path, names), len(lines)), len(lines)) for path, lines in executable.items()),
        key=lambda row: (row[1], -row[2]),
    )
    out += [
        "",
        "### Twenty least-covered files",
        "",
        "| File | Coverage | Executable lines |",
        "| --- | ---: | ---: |",
    ]
    for path, file_percent, lines in rows[:20]:
        out.append(f"| {path} | {file_percent:.1f}% | {lines} |")

    return "\n".join(out) + "\n", overall


def parse_input(value: str) -> tuple[str, Path]:
    name, separator, path = value.partition("=")
    if not separator or not name or not path:
        raise argparse.ArgumentTypeError(f"expected NAME=PATH, got {value!r}")
    return name, Path(path)


def main() -> None:
    parser = argparse.ArgumentParser()
    commands = parser.add_subparsers(dest="command", required=True)

    export_parser = commands.add_parser("export", help="xcresult -> line coverage JSON")
    export_parser.add_argument("xcresult", type=Path)
    export_parser.add_argument("--root", type=Path, required=True, help="Repository root")
    export_parser.add_argument("--output", type=Path, required=True)

    combine_parser = commands.add_parser("combine", help="line coverage JSONs -> summary")
    combine_parser.add_argument("--input", type=parse_input, action="append", required=True, metavar="NAME=PATH")
    combine_parser.add_argument("--output", type=Path, required=True, help="Markdown summary destination")
    combine_parser.add_argument("--percent-file", type=Path, required=True, help="Overall percentage destination")

    args = parser.parse_args()
    if args.command == "export":
        export(args.xcresult, args.root.resolve(), args.output)
        return

    summary, overall = combine(args.input)
    args.output.write_text(summary, encoding="utf-8")
    args.percent_file.write_text(f"{overall:.2f}", encoding="utf-8")
    print(summary)


if __name__ == "__main__":
    main()
