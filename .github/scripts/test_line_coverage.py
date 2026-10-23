#!/usr/bin/env python3

from __future__ import annotations

import json
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest import mock

import line_coverage


def archive_line(number: int, count: int | None) -> dict:
    if count is None:
        return {"line": number, "isExecutable": False}
    return {"line": number, "isExecutable": True, "executionCount": count}


class ExportTests(unittest.TestCase):
    def export(self, archive: dict) -> dict:
        completed = subprocess.CompletedProcess(args=[], returncode=0, stdout=json.dumps(archive))
        with tempfile.TemporaryDirectory() as directory, mock.patch.object(
            line_coverage.subprocess, "run", return_value=completed
        ):
            output = Path(directory) / "out.json"
            line_coverage.export(Path("ignored.xcresult"), Path("/repo"), output)
            return json.loads(output.read_text())["files"]

    def test_keeps_executable_lines_and_those_that_ran(self):
        files = self.export({
            "/repo/Caloryn/A.swift": [
                archive_line(1, None),
                archive_line(2, 3),
                archive_line(3, 0),
                archive_line(4, 1),
            ]
        })
        self.assertEqual(files, {"Caloryn/A.swift": {"executable": [2, 3, 4], "covered": [2, 4]}})

    def test_drops_tests_files_outside_the_root_and_files_with_nothing_executable(self):
        files = self.export({
            "/repo/CalorynTests/T.swift": [archive_line(1, 1)],
            "/repo/CalorynUITests/U.swift": [archive_line(1, 1)],
            "/elsewhere/Package.swift": [archive_line(1, 1)],
            "/repo/Caloryn/Empty.swift": [archive_line(1, None)],
            "/repo/CalorynShared/S.swift": [archive_line(5, 0)],
        })
        self.assertEqual(files, {"CalorynShared/S.swift": {"executable": [5], "covered": []}})


class CombineTests(unittest.TestCase):
    def combine(self, **plans: dict) -> tuple[str, float]:
        with tempfile.TemporaryDirectory() as directory:
            inputs = []
            for name, files in plans.items():
                path = Path(directory) / f"{name}.json"
                path.write_text(json.dumps({"files": files}))
                inputs.append((name, path))
            return line_coverage.combine(inputs)

    def test_overlapping_lines_count_once(self):
        summary, overall = self.combine(
            unit={"Caloryn/A.swift": {"executable": [1, 2, 3, 4], "covered": [1, 2]}},
            ui={"Caloryn/A.swift": {"executable": [1, 2, 3, 4], "covered": [2, 3]}},
        )
        self.assertEqual(overall, 75.0)
        self.assertIn("(3/4 executable lines", summary)
        self.assertIn("| unit alone | 50.0% |", summary)
        self.assertIn("| ui alone | 50.0% |", summary)

    def test_disjoint_lines_add_up(self):
        _, overall = self.combine(
            unit={"Caloryn/A.swift": {"executable": [1, 2, 3, 4], "covered": [1]}},
            ui={"Caloryn/A.swift": {"executable": [1, 2, 3, 4], "covered": [4]}},
        )
        self.assertEqual(overall, 50.0)

    def test_a_file_only_one_plan_saw_stays_in_the_denominator(self):
        summary, overall = self.combine(
            unit={
                "Caloryn/A.swift": {"executable": [1, 2], "covered": [1, 2]},
                "CalorynWidgets/W.swift": {"executable": [1, 2], "covered": []},
            },
            ui={"Caloryn/A.swift": {"executable": [1, 2], "covered": [1]}},
        )
        self.assertEqual(overall, 50.0)
        self.assertIn("| CalorynWidgets | 0.0% | 2 |", summary)

    def test_inputs_sharing_a_name_merge_into_one_plan(self):
        with tempfile.TemporaryDirectory() as directory:
            shards = {
                "unit": {"Caloryn/A.swift": {"executable": [1, 2, 3, 4], "covered": [1]}},
                "ui-1": {"Caloryn/A.swift": {"executable": [1, 2, 3, 4], "covered": [4]}},
                "ui-2": {"Caloryn/A.swift": {"executable": [1, 2, 3, 4], "covered": [2, 3]}},
            }
            paths = {}
            for shard, files in shards.items():
                paths[shard] = Path(directory) / f"{shard}.json"
                paths[shard].write_text(json.dumps({"files": files}))
            summary, overall = line_coverage.combine(
                [("unit", paths["unit"]), ("ui", paths["ui-1"]), ("ui", paths["ui-2"])]
            )
        self.assertEqual(overall, 100.0)
        self.assertIn("| ui alone | 75.0% |", summary)
        self.assertEqual(summary.count(" alone |"), 2)

    def test_a_covered_line_that_is_not_executable_is_ignored(self):
        _, overall = self.combine(
            unit={"Caloryn/A.swift": {"executable": [1, 2], "covered": [1, 9]}},
        )
        self.assertEqual(overall, 50.0)

    def test_areas_group_by_the_second_level_under_caloryn(self):
        self.assertEqual(line_coverage.area("Caloryn/Views/Today/X.swift"), "Caloryn/Views")
        self.assertEqual(line_coverage.area("Caloryn/ContentView.swift"), "Caloryn")
        self.assertEqual(line_coverage.area("CalorynShared/X.swift"), "CalorynShared")


if __name__ == "__main__":
    unittest.main()
