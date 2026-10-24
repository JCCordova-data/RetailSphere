"""Replace RAW orders atomically using Psycopg 3 (PostgreSQL 18).

Assumptions: UTF-8 CSV, exact ordered header, eight TEXT target columns,
no concurrent changes to the input file. PostgreSQL CSV rules apply: unquoted
empty fields become NULL; quoted empty fields remain empty strings. Values,
whitespace and duplicate records are preserved. No .env file is loaded.

Running this module explicitly replaces raw.orders; importing it does nothing.
TRUNCATE takes an exclusive lock until commit. Requires TRUNCATE/INSERT/SELECT
privileges. Transactional rollback protects existing rows on any load failure.
"""

import csv
import os
from pathlib import Path

import psycopg
from psycopg import sql


COLUMNS = (
    "order_id", "customer_id", "order_status", "order_purchase_timestamp",
    "order_approved_at", "order_delivered_carrier_date",
    "order_delivered_customer_date", "order_estimated_delivery_date",
)
CSV_PATH = Path(__file__).resolve().parents[1] / "data/raw/olist_orders_dataset.csv"
EXPECTED_ROWS = 99_441


def connection_settings():
    """Read credentials without logging them; default to the local server."""
    return {
        "user": os.environ["PGUSER"],
        "dbname": os.environ["PGDATABASE"],
        "password": os.environ["PGPASSWORD"],
        "host": os.environ.get("PGHOST", "127.0.0.1"),
        "port": os.environ.get("PGPORT", "5432"),
    }


def validate_csv(file, expected_rows):
    """Validate logical records, including quoted multiline fields."""
    reader = csv.reader(file, strict=True)
    if next(reader, None) != list(COLUMNS):
        raise ValueError("CSV header must match the ordered RAW columns.")
    count = 0
    for row in reader:
        if len(row) != len(COLUMNS):
            raise ValueError(f"CSV record {count + 1} must have eight fields.")
        count += 1
    if count != expected_rows:
        raise ValueError(f"Expected {expected_rows} CSV rows; found {count}.")
    file.seek(0)


def ingest_orders(file_path=CSV_PATH, expected_rows=EXPECTED_ROWS,
                  target_schema="raw", target_table="orders"):
    """Validate, replace and verify; commit only when every step succeeds."""
    if expected_rows < 0:
        raise ValueError("Expected row count cannot be negative.")
    target = sql.Identifier(target_schema, target_table)
    with open(file_path, encoding="utf-8-sig", newline="") as file:
        validate_csv(file, expected_rows)
        # Psycopg's connection context commits on success, rolls back on error,
        # and closes the connection. Autocommit is disabled explicitly.
        with psycopg.connect(**connection_settings(), autocommit=False) as connection:
            with connection.cursor() as cursor:
                cursor.execute(sql.SQL("LOCK TABLE {} IN ACCESS EXCLUSIVE MODE").format(target))
                cursor.execute(sql.SQL("SELECT * FROM {} LIMIT 0").format(target))
                if (tuple(column.name for column in cursor.description) != COLUMNS
                        or any(column.type_code != 25 for column in cursor.description)):
                    raise ValueError("Target must contain the eight ordered TEXT columns.")
                cursor.execute(sql.SQL("TRUNCATE TABLE {}").format(target))
                statement = sql.SQL(
                    "COPY {} ({}) FROM STDIN WITH (FORMAT CSV, HEADER MATCH)"
                ).format(target, sql.SQL(", ").join(map(sql.Identifier, COLUMNS)))
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


def main():
    try:
        count = ingest_orders()
    except (OSError, ValueError, KeyError, csv.Error, psycopg.Error):
        # Database errors can include connection details or input values.
        raise SystemExit("Ingestion failed; transaction was not committed.") from None
    print(f"Loaded {count} RAW orders.")


if __name__ == "__main__":
    main()
