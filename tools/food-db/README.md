# Caloryn food database builder

This tool creates a compact SQLite search database from the official Open Food
Facts daily CSV export. It only imports products with a code, product name, and
calories per 100 g, and only stores fields already consumed by Caloryn.

The output contains:

- `products`: barcode, display fields, serving information, and nutrition per 100 g
- `products_fts`: an FTS5 index over product name and brand
- `_metadata`: snapshot provenance, schema version, attribution, and row counts

## Quick verification build

This streams only the beginning of the remote snapshot and produces a small
database without keeping the source file:

```sh
python3 tools/food-db/build_food_db.py \
  --limit 10000 \
  --output .local-data/caloryn-foods-sample.db \
  --overwrite
```

## Full one-time snapshot

Cache the approximately 1.3 GB compressed source so an interrupted database
build does not require another download:

```sh
python3 tools/food-db/build_food_db.py \
  --cache .local-data/openfoodfacts-products.csv.gz \
  --output .local-data/caloryn-foods.db \
  --overwrite
```

The download can resume from its `.part` file. The builder prints progress,
checks SQLite integrity and FTS search, verifies Turso's file requirements, and
exits with status 2 if the finished file exceeds the 2 GB `--from-file` limit.

Import the resulting file with:

```sh
turso db import .local-data/caloryn-foods.db
```

Open Food Facts data is available under the Open Database License (ODbL). The
database records the required attribution in `_metadata`; the API should also
expose attribution in its documentation or status response.

## Search query shape

The future service can query name and brand with:

```sql
SELECT p.*
FROM products_fts AS f
JOIN products AS p ON p.rowid = f.rowid
WHERE products_fts MATCH ?
ORDER BY bm25(products_fts, 8.0, 3.0), p.popularity DESC
LIMIT ?;
```

Convert user input into safely quoted FTS prefix terms in the service rather
than interpolating raw input into SQL.

## Tests

```sh
python3 -m unittest tools/food-db/test_build_food_db.py
```
