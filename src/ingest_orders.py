"""RS-020 compatible adapter for the shared RAW ingestion engine.

Running this module explicitly replaces raw.orders, as before. For explicit
replacement authorization or offline validation use ingest_raw's CLI instead.
Importing this module does nothing; credentials come only from PG* variables.
"""

import csv
import psycopg

if __package__:
    from .ingest_raw import connection_settings, ingest_dataset
    from .ingest_raw import validate_csv as _validate_csv
    from .raw_datasets import DATASETS, RAW_DIRECTORY
else:  # Preserve python src/ingest_orders.py as well as module invocation.
    from ingest_raw import connection_settings, ingest_dataset
    from ingest_raw import validate_csv as _validate_csv
    from raw_datasets import DATASETS, RAW_DIRECTORY


COLUMNS = DATASETS["orders"].columns
CSV_PATH = RAW_DIRECTORY / DATASETS["orders"].source_csv
EXPECTED_ROWS = DATASETS["orders"].expected_rows


def validate_csv(file, expected_rows):
    """Preserve the original two-argument RS-020 validator."""
    return _validate_csv(file, expected_rows, COLUMNS)


def ingest_orders(file_path=CSV_PATH, expected_rows=EXPECTED_ROWS,
                  target_schema="raw", target_table="orders"):
    """Preserve the RS-020 signature and configurable isolated test target."""
    return ingest_dataset(
        DATASETS["orders"], file_path, expected_rows, target_schema, target_table,
        settings_factory=connection_settings,
    )


def main():
    try:
        count = ingest_orders()
    except (OSError, ValueError, KeyError, csv.Error, psycopg.Error):
        # Database errors can include connection details or input values.
        raise SystemExit("Ingestion failed; transaction was not committed.") from None
    print(f"Loaded {count} RAW orders.")


if __name__ == "__main__":
    main()
