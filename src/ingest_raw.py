"""Validate and atomically replace configured RAW tables using Psycopg 3.

Input files must remain unchanged during validation and COPY. UTF-8 CSV text
is streamed unchanged (apart from an optional leading BOM) with newline="".
PostgreSQL CSV semantics apply: unquoted empty fields become NULL; quoted
empty fields remain empty strings. Whitespace, duplicates and source spelling
are preserved. Each dataset uses its own transaction, including in mode 'all'.
Importing this module never connects. No .env file is loaded and no DDL is run.
"""

import argparse
import csv
import os
from pathlib import Path

import psycopg
from psycopg import sql

if __package__:
    from .raw_datasets import DATASETS, RAW_DIRECTORY
else:  # Also support python src/ingest_raw.py.
    from raw_datasets import DATASETS, RAW_DIRECTORY


def connection_settings():
    """Read credentials from the environment without logging them."""
    return {
        "user": os.environ["PGUSER"],
        "dbname": os.environ["PGDATABASE"],
        "password": os.environ["PGPASSWORD"],
        "host": os.environ.get("PGHOST", "127.0.0.1"),
        "port": os.environ.get("PGPORT", "5432"),
    }


def validate_csv(file, expected_rows, columns):
    """Validate ordered headers, field widths and logical rows; then rewind."""
    if expected_rows < 0:
        raise ValueError("Expected row count cannot be negative.")
    reader = csv.reader(file, strict=True)
    if next(reader, None) != list(columns):
        raise ValueError("CSV header must match the ordered RAW columns.")
    count = 0
    for row in reader:
        if len(row) != len(columns):
            raise ValueError(f"CSV record {count + 1} must have {len(columns)} fields.")
        count += 1
    if count != expected_rows:
        raise ValueError(f"Expected {expected_rows} CSV rows; found {count}.")
    file.seek(0)


def ingest_dataset(dataset, file_path=None, expected_rows=None,
                   target_schema=None, target_table=None, *, settings_factory=None):
    """Replace one configured table; return the verified, committed row count.

    Overrides support synthetic CSVs and isolated test tables. settings_factory
    is resolved only after CSV validation, and keeps the RS-020 adapter's
    connection configuration patchable. SQL identifiers are always quoted.
    """
    expected_rows = dataset.expected_rows if expected_rows is None else expected_rows
    if expected_rows < 0:
        raise ValueError("Expected row count cannot be negative.")
    file_path = RAW_DIRECTORY / dataset.source_csv if file_path is None else file_path
    target = sql.Identifier(
        dataset.target_schema if target_schema is None else target_schema,
        dataset.target_table if target_table is None else target_table,
    )
    with open(file_path, encoding="utf-8-sig", newline="") as file:
        validate_csv(file, expected_rows, dataset.columns)
        settings = (settings_factory or connection_settings)()
        # Connection context commits on success, rolls back on any exception,
        # and closes. The exclusive lock lasts through commit/rollback.
        with psycopg.connect(**settings, autocommit=False) as connection:
            with connection.cursor() as cursor:
                cursor.execute(sql.SQL("LOCK TABLE {} IN ACCESS EXCLUSIVE MODE").format(target))
                cursor.execute(sql.SQL("SELECT * FROM {} LIMIT 0").format(target))
                if (tuple(column.name for column in cursor.description) != dataset.columns
                        or any(column.type_code != 25 for column in cursor.description)):
                    raise ValueError("Target must contain the configured ordered TEXT columns.")
                cursor.execute(sql.SQL("TRUNCATE TABLE {}").format(target))
                statement = sql.SQL(
                    "COPY {} ({}) FROM STDIN WITH (FORMAT CSV, HEADER MATCH)"
                ).format(target, sql.SQL(", ").join(map(sql.Identifier, dataset.columns)))
                with cursor.copy(statement) as copy:
                    while chunk := file.read(64 * 1024):
                        copy.write(chunk)
                cursor.execute(sql.SQL("SELECT count(*) FROM {}").format(target))
                actual_rows = cursor.fetchone()[0]
                if actual_rows != expected_rows:
                    raise ValueError(
                        f"Expected {expected_rows} loaded rows; found {actual_rows}."
                    )
    return actual_rows


def main(argv=None):
    parser = argparse.ArgumentParser(
        description="Ingest Olist CSVs into their configured raw.* tables. "
        "Connection: PGHOST/PGPORT/PGDATABASE/PGUSER/PGPASSWORD; no .env is loaded. "
        "Each dataset commits separately; 'all' stops on the first failure.",
    )
    parser.add_argument("dataset", choices=(*DATASETS, "all"))
    parser.add_argument("--source-dir", type=Path, default=RAW_DIRECTORY,
                        help="Directory containing original CSV filenames (default: data/raw)")
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--replace", action="store_true",
                      help="Authorize transactional TRUNCATE + COPY of each selected RAW table")
    mode.add_argument("--dry-run", action="store_true",
                      help="Validate CSVs and display targets without opening a database connection")
    args = parser.parse_args(argv)
    selected = DATASETS if args.dataset == "all" else {args.dataset: DATASETS[args.dataset]}
    action = "VALIDATE ONLY" if args.dry_run else "REPLACE (TRUNCATE + COPY)"
    for dataset in selected.values():
        print(f"{action}: {args.source_dir / dataset.source_csv} -> "
              f"{dataset.target_schema}.{dataset.target_table}; "
              f"expected rows: {dataset.expected_rows}", flush=True)
    try:
        for dataset in selected.values():
            path = args.source_dir / dataset.source_csv
            if args.dry_run:
                with open(path, encoding="utf-8-sig", newline="") as file:
                    validate_csv(file, dataset.expected_rows, dataset.columns)
                print(f"Validated {dataset.expected_rows} rows for "
                      f"{dataset.target_schema}.{dataset.target_table}.")
            else:
                count = ingest_dataset(dataset, path)
                print(f"Loaded {count} rows into "
                      f"{dataset.target_schema}.{dataset.target_table}; committed.", flush=True)
    except (OSError, ValueError, KeyError, csv.Error, psycopg.Error):
        # Driver errors can contain credentials or source values; never echo them.
        if args.dry_run:
            message = "CSV validation failed; no database connection was opened."
        else:
            message = ("Ingestion failed; the current dataset was not committed. "
                       "Earlier datasets may already be committed.")
        raise SystemExit(message) from None


if __name__ == "__main__":
    main()
