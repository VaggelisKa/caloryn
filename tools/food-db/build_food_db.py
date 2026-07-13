#!/usr/bin/env python3
"""Build a compact, searchable SQLite snapshot from Open Food Facts' CSV export."""

from __future__ import annotations

import argparse
import contextlib
import csv
import datetime as dt
import email.utils
import gzip
import json
import math
import os
from pathlib import Path
import sqlite3
import sys
import time
from typing import BinaryIO, Iterator, TextIO
import urllib.error
import urllib.request


DEFAULT_SOURCE_URL = (
    "https://static.openfoodfacts.org/data/"
    "en.openfoodfacts.org.products.csv.gz"
)
SCHEMA_VERSION = "1"
TURSO_FROM_FILE_LIMIT_BYTES = 2_000_000_000
BATCH_SIZE = 5_000

NUTRIENT_FIELDS = (
    "energy-kcal_100g",
    "proteins_100g",
    "carbohydrates_100g",
    "fat_100g",
    "fiber_100g",
    "sugars_100g",
    "added-sugars_100g",
    "sucrose_100g",
    "glucose_100g",
    "fructose_100g",
    "lactose_100g",
    "maltose_100g",
    "maltodextrins_100g",
    "starch_100g",
    "polyols_100g",
    "saturated-fat_100g",
    "trans-fat_100g",
    "monounsaturated-fat_100g",
    "polyunsaturated-fat_100g",
    "omega-3-fat_100g",
    "omega-6-fat_100g",
    "omega-9-fat_100g",
    "salt_100g",
    "sodium_100g",
    "cholesterol_100g",
    "soluble-fiber_100g",
    "insoluble-fiber_100g",
    "casein_100g",
    "serum-proteins_100g",
    "alcohol_100g",
)

TEXT_FIELDS = (
    "code",
    "product_name",
    "brands",
    "quantity",
    "serving_size",
    "nutriscore_grade",
    "categories_tags",
    "countries_tags",
)

NUMERIC_FIELDS = (
    "serving_quantity",
    "product_quantity",
    *NUTRIENT_FIELDS,
)

REQUIRED_SOURCE_FIELDS = set(TEXT_FIELDS) | set(NUMERIC_FIELDS)


def sqlite_column(source_field: str) -> str:
    return source_field.replace("-", "_")


PRODUCT_COLUMNS = (
    *[sqlite_column(field) for field in TEXT_FIELDS],
    *[sqlite_column(field) for field in NUMERIC_FIELDS],
    "popularity",
)


CREATE_PRODUCTS_SQL = f"""
CREATE TABLE products (
    code TEXT PRIMARY KEY NOT NULL,
    product_name TEXT NOT NULL,
    brands TEXT,
    quantity TEXT,
    serving_size TEXT,
    nutriscore_grade TEXT,
    categories_tags TEXT,
    countries_tags TEXT,
    serving_quantity REAL,
    product_quantity REAL,
    {', '.join(f'{sqlite_column(field)} REAL' for field in NUTRIENT_FIELDS)},
    popularity INTEGER NOT NULL DEFAULT 0
)
"""


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--source",
        default=DEFAULT_SOURCE_URL,
        help="Official .csv.gz URL or a local .csv.gz file.",
    )
    parser.add_argument(
        "--cache",
        type=Path,
        help="Download a remote source here first. Recommended for a full build.",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=Path(".local-data/caloryn-foods.db"),
    )
    parser.add_argument(
        "--limit",
        type=positive_int,
        help="Stop after this many source rows. Useful for a quick local build.",
    )
    parser.add_argument(
        "--overwrite",
        action="store_true",
        help="Replace an existing output database.",
    )
    return parser.parse_args(argv)


def positive_int(raw: str) -> int:
    value = int(raw)
    if value <= 0:
        raise argparse.ArgumentTypeError("must be greater than zero")
    return value


def is_url(value: str) -> bool:
    return value.startswith("https://") or value.startswith("http://")


def download_snapshot(url: str, destination: Path, retries: int = 5) -> Path:
    destination.parent.mkdir(parents=True, exist_ok=True)
    partial = destination.with_suffix(destination.suffix + ".part")

    for attempt in range(1, retries + 1):
        existing = partial.stat().st_size if partial.exists() else 0
        request = urllib.request.Request(
            url,
            headers={
                "User-Agent": "CalorynFoodDBBuilder/1.0 (contact@caloryn.app)",
                **({"Range": f"bytes={existing}-"} if existing else {}),
            },
        )
        try:
            with urllib.request.urlopen(request, timeout=60) as response:
                status = getattr(response, "status", 200)
                last_modified = response.headers.get("Last-Modified")
                if existing and status != 206:
                    existing = 0
                    partial.unlink(missing_ok=True)
                mode = "ab" if existing and status == 206 else "wb"
                total = response.headers.get("Content-Length")
                expected = existing + int(total) if total else None
                copied = existing
                last_report = time.monotonic()
                with partial.open(mode) as output:
                    while chunk := response.read(1024 * 1024):
                        output.write(chunk)
                        copied += len(chunk)
                        if time.monotonic() - last_report >= 5:
                            suffix = f" / {format_bytes(expected)}" if expected else ""
                            print(
                                f"Downloaded {format_bytes(copied)}{suffix}",
                                file=sys.stderr,
                                flush=True,
                            )
                            last_report = time.monotonic()
            os.replace(partial, destination)
            if last_modified:
                modified = email.utils.parsedate_to_datetime(last_modified).timestamp()
                os.utime(destination, (modified, modified))
            return destination
        except (OSError, urllib.error.URLError) as error:
            if attempt == retries:
                raise RuntimeError(f"Snapshot download failed after {retries} attempts") from error
            delay = 2**attempt
            print(
                f"Download interrupted ({error}); resuming in {delay}s...",
                file=sys.stderr,
                flush=True,
            )
            time.sleep(delay)

    raise AssertionError("unreachable")


@contextlib.contextmanager
def open_source(source: str) -> Iterator[tuple[TextIO, str | None]]:
    binary: BinaryIO
    snapshot_modified: str | None = None

    if is_url(source):
        request = urllib.request.Request(
            source,
            headers={"User-Agent": "CalorynFoodDBBuilder/1.0 (contact@caloryn.app)"},
        )
        response = urllib.request.urlopen(request, timeout=60)
        binary = response
        snapshot_modified = response.headers.get("Last-Modified")
    else:
        path = Path(source)
        binary = path.open("rb")
        snapshot_modified = dt.datetime.fromtimestamp(
            path.stat().st_mtime, tz=dt.timezone.utc
        ).isoformat()

    try:
        with gzip.GzipFile(fileobj=binary) as compressed:
            with contextlib.closing(
                TextIOWrapperWithoutClosing(compressed)
            ) as text_stream:
                yield text_stream, snapshot_modified
    finally:
        binary.close()


class TextIOWrapperWithoutClosing:
    """Small proxy that decodes a binary stream without obscuring close ownership."""

    def __init__(self, stream: BinaryIO):
        import io

        self._wrapper = io.TextIOWrapper(
            stream, encoding="utf-8", errors="replace", newline=""
        )

    def __iter__(self):
        return iter(self._wrapper)

    def __getattr__(self, name: str):
        return getattr(self._wrapper, name)

    def close(self) -> None:
        self._wrapper.detach()


def finite_float(raw: str | None) -> float | None:
    if not raw:
        return None
    try:
        value = float(raw)
    except ValueError:
        return None
    return value if math.isfinite(value) else None


def integer(raw: str | None) -> int:
    value = finite_float(raw)
    return max(0, int(value)) if value is not None else 0


def normalize_text(raw: str | None) -> str | None:
    if raw is None:
        return None
    value = " ".join(raw.split())
    return value or None


def row_values(row: dict[str, str]) -> tuple[object, ...] | None:
    code = normalize_text(row.get("code"))
    name = normalize_text(row.get("product_name"))
    calories = finite_float(row.get("energy-kcal_100g"))
    if not code or len(code) > 64 or not name or calories is None:
        return None

    text_values = [normalize_text(row.get(field)) for field in TEXT_FIELDS]
    numeric_values = [finite_float(row.get(field)) for field in NUMERIC_FIELDS]
    return (*text_values, *numeric_values, integer(row.get("unique_scans_n")))


def create_schema(connection: sqlite3.Connection) -> None:
    connection.executescript(
        f"""
        PRAGMA page_size = 4096;
        PRAGMA auto_vacuum = NONE;
        PRAGMA encoding = 'UTF-8';
        PRAGMA journal_mode = OFF;
        PRAGMA synchronous = OFF;
        PRAGMA temp_store = MEMORY;
        PRAGMA locking_mode = EXCLUSIVE;

        CREATE TABLE _metadata (
            key TEXT PRIMARY KEY NOT NULL,
            value TEXT NOT NULL
        );

        {CREATE_PRODUCTS_SQL};
        """
    )


def import_rows(
    connection: sqlite3.Connection,
    stream: TextIO,
    limit: int | None,
) -> tuple[int, int]:
    csv.field_size_limit(sys.maxsize)
    reader = csv.DictReader(stream, delimiter="\t")
    source_fields = set(reader.fieldnames or [])
    missing = sorted(REQUIRED_SOURCE_FIELDS - source_fields)
    if missing:
        raise RuntimeError(f"Source snapshot is missing required columns: {', '.join(missing)}")

    placeholders = ", ".join("?" for _ in PRODUCT_COLUMNS)
    columns = ", ".join(PRODUCT_COLUMNS)
    insert_sql = f"INSERT OR REPLACE INTO products ({columns}) VALUES ({placeholders})"

    scanned = 0
    imported = 0
    batch: list[tuple[object, ...]] = []
    connection.execute("BEGIN")

    for row in reader:
        scanned += 1
        values = row_values(row)
        if values is not None:
            batch.append(values)
        if len(batch) >= BATCH_SIZE:
            connection.executemany(insert_sql, batch)
            imported += len(batch)
            batch.clear()
        if scanned % 100_000 == 0:
            print(
                f"Scanned {scanned:,}; accepted {imported + len(batch):,}",
                file=sys.stderr,
                flush=True,
            )
        if limit is not None and scanned >= limit:
            break

    if batch:
        connection.executemany(insert_sql, batch)
        imported += len(batch)
    connection.commit()
    return scanned, imported


def build_search_index(connection: sqlite3.Connection) -> None:
    connection.executescript(
        """
        CREATE VIRTUAL TABLE products_fts USING fts5(
            product_name,
            brands,
            content='products',
            content_rowid='rowid',
            tokenize='unicode61 remove_diacritics 2'
        );
        INSERT INTO products_fts(rowid, product_name, brands)
        SELECT rowid, product_name, coalesce(brands, '') FROM products;
        """
    )


def write_metadata(
    connection: sqlite3.Connection,
    source: str,
    snapshot_modified: str | None,
    scanned: int,
    imported: int,
) -> None:
    values = {
        "schema_version": SCHEMA_VERSION,
        "source": source,
        "source_snapshot_modified": snapshot_modified or "unknown",
        "built_at": dt.datetime.now(tz=dt.timezone.utc).isoformat(),
        "source_rows_scanned": str(scanned),
        "products_imported": str(imported),
        "license": "Open Database License (ODbL) 1.0",
        "attribution": "Contains information from Open Food Facts",
    }
    connection.executemany(
        "INSERT INTO _metadata(key, value) VALUES (?, ?)", values.items()
    )
    connection.commit()


def finalize_for_turso(connection: sqlite3.Connection) -> None:
    connection.execute("PRAGMA locking_mode = NORMAL")
    connection.execute("VACUUM")
    mode = connection.execute("PRAGMA journal_mode = WAL").fetchone()[0]
    if mode.lower() != "wal":
        raise RuntimeError(f"Could not enable WAL journal mode (got {mode})")
    connection.execute("PRAGMA wal_checkpoint(TRUNCATE)")


def verify_database(path: Path) -> dict[str, object]:
    connection = sqlite3.connect(path)
    try:
        integrity = connection.execute("PRAGMA integrity_check").fetchone()[0]
        page_size = connection.execute("PRAGMA page_size").fetchone()[0]
        auto_vacuum = connection.execute("PRAGMA auto_vacuum").fetchone()[0]
        journal_mode = connection.execute("PRAGMA journal_mode").fetchone()[0]
        product_count = connection.execute("SELECT count(*) FROM products").fetchone()[0]
        fts_count = connection.execute("SELECT count(*) FROM products_fts").fetchone()[0]
        sample = connection.execute(
            """
            SELECT p.code, p.product_name
            FROM products_fts AS f
            JOIN products AS p ON p.rowid = f.rowid
            WHERE products_fts MATCH 'milk* OR chocolate*'
            ORDER BY bm25(products_fts, 8.0, 3.0), p.popularity DESC
            LIMIT 1
            """
        ).fetchone()
    finally:
        connection.close()

    size = path.stat().st_size
    report = {
        "path": str(path),
        "size_bytes": size,
        "size": format_bytes(size),
        "under_turso_2gb_from_file_limit": size < TURSO_FROM_FILE_LIMIT_BYTES,
        "integrity_check": integrity,
        "page_size": page_size,
        "auto_vacuum": auto_vacuum,
        "journal_mode": journal_mode,
        "products": product_count,
        "fts_rows": fts_count,
        "sample_search_result": sample,
    }

    if integrity != "ok" or page_size != 4096 or auto_vacuum != 0:
        raise RuntimeError(f"Database compatibility validation failed: {report}")
    if journal_mode.lower() != "wal" or product_count != fts_count:
        raise RuntimeError(f"Database search validation failed: {report}")
    if product_count and sample is None:
        print(
            "Warning: sample contains no milk/chocolate search result.",
            file=sys.stderr,
        )
    return report


def format_bytes(value: int | None) -> str:
    if value is None:
        return "unknown"
    amount = float(value)
    for unit in ("B", "KB", "MB", "GB", "TB"):
        if amount < 1000 or unit == "TB":
            return f"{amount:.2f} {unit}"
        amount /= 1000
    raise AssertionError("unreachable")


def remove_sqlite_sidecars(path: Path) -> None:
    for suffix in ("-wal", "-shm"):
        Path(f"{path}{suffix}").unlink(missing_ok=True)


def build(args: argparse.Namespace) -> dict[str, object]:
    output = args.output.resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    if output.exists() and not args.overwrite:
        raise RuntimeError(f"Output already exists: {output}. Pass --overwrite to replace it.")

    source = args.source
    if args.cache:
        if not is_url(source):
            raise RuntimeError("--cache can only be used with a remote --source URL")
        cache = args.cache.resolve()
        if not cache.exists():
            print(f"Downloading snapshot to {cache}", file=sys.stderr, flush=True)
            download_snapshot(source, cache)
        else:
            print(f"Using cached snapshot {cache}", file=sys.stderr, flush=True)
        source = str(cache)

    temporary = output.with_suffix(output.suffix + ".building")
    temporary.unlink(missing_ok=True)
    remove_sqlite_sidecars(temporary)
    connection = sqlite3.connect(temporary)
    try:
        create_schema(connection)
        with open_source(source) as (stream, snapshot_modified):
            scanned, imported = import_rows(connection, stream, args.limit)
        print("Building FTS5 index...", file=sys.stderr, flush=True)
        build_search_index(connection)
        write_metadata(
            connection,
            args.source,
            snapshot_modified,
            scanned,
            imported,
        )
        finalize_for_turso(connection)
    except BaseException:
        connection.close()
        temporary.unlink(missing_ok=True)
        remove_sqlite_sidecars(temporary)
        raise
    else:
        connection.close()
        remove_sqlite_sidecars(temporary)

    if output.exists():
        output.unlink()
    remove_sqlite_sidecars(output)
    os.replace(temporary, output)
    report = verify_database(output)
    remove_sqlite_sidecars(output)
    return report


def main(argv: list[str] | None = None) -> int:
    try:
        report = build(parse_args(argv))
    except (OSError, RuntimeError, sqlite3.Error, urllib.error.URLError) as error:
        print(f"error: {error}", file=sys.stderr)
        return 1
    print(json.dumps(report, indent=2))
    if not report["under_turso_2gb_from_file_limit"]:
        print(
            "error: database exceeds Turso's 2 GB --from-file limit",
            file=sys.stderr,
        )
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
