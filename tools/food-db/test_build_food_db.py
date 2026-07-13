import csv
import gzip
import importlib.util
from pathlib import Path
import sqlite3
import tempfile
import unittest


SCRIPT = Path(__file__).with_name("build_food_db.py")
SPEC = importlib.util.spec_from_file_location("build_food_db", SCRIPT)
assert SPEC and SPEC.loader
builder = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(builder)


class FoodDatabaseBuilderTests(unittest.TestCase):
    def test_builds_searchable_turso_compatible_database(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "source.csv.gz"
            output = root / "foods.db"
            fields = sorted(builder.REQUIRED_SOURCE_FIELDS | {"unique_scans_n"})
            rows = [
                self.row(fields, code="123", name="Chocolate Milk", calories="82", brand="Test Dairy"),
                self.row(fields, code="456", name="Incomplete", calories="", brand="No Calories"),
            ]
            with gzip.open(source, "wt", encoding="utf-8", newline="") as stream:
                writer = csv.DictWriter(stream, fieldnames=fields, delimiter="\t")
                writer.writeheader()
                writer.writerows(rows)

            exit_code = builder.main(
                ["--source", str(source), "--output", str(output), "--overwrite"]
            )

            self.assertEqual(exit_code, 0)
            connection = sqlite3.connect(output)
            try:
                self.assertEqual(
                    connection.execute("SELECT count(*) FROM products").fetchone()[0], 1
                )
                result = connection.execute(
                    """
                    SELECT p.code, p.product_name
                    FROM products_fts AS f
                    JOIN products AS p ON p.rowid = f.rowid
                    WHERE products_fts MATCH 'choc*'
                    """
                ).fetchone()
                self.assertEqual(result, ("123", "Chocolate Milk"))
                self.assertEqual(connection.execute("PRAGMA page_size").fetchone()[0], 4096)
                self.assertEqual(connection.execute("PRAGMA journal_mode").fetchone()[0], "wal")
            finally:
                connection.close()

    @staticmethod
    def row(fields, code, name, calories, brand):
        row = {field: "" for field in fields}
        row.update(
            {
                "code": code,
                "product_name": name,
                "brands": brand,
                "energy-kcal_100g": calories,
                "unique_scans_n": "42",
            }
        )
        return row


if __name__ == "__main__":
    unittest.main()
