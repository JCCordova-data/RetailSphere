-- RS-020: RAW orders table, documented here so a fresh clone can be reproduced end to end.
-- Run manually with psql -X -v ON_ERROR_STOP=1 BEFORE sql/021_create_raw_tables.sql.
-- Only for an empty database: do NOT run it where raw.orders already exists.
-- Intentionally fail if the table already exists: never mask schema drift.
-- No keys, indexes, defaults or constraints: preserve duplicate source rows.
-- Columns, order and TEXT type must match src/raw_datasets.py (ingestion checks this).
BEGIN;

CREATE SCHEMA IF NOT EXISTS raw;

CREATE TABLE raw.orders (
    order_id TEXT,
    customer_id TEXT,
    order_status TEXT,
    order_purchase_timestamp TEXT,
    order_approved_at TEXT,
    order_delivered_carrier_date TEXT,
    order_delivered_customer_date TEXT,
    order_estimated_delivery_date TEXT
);

COMMIT;