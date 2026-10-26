-- Preserve returning buyers and invalid geographic values for data quality tests.
SELECT
    customer_id,
    customer_unique_id,
    customer_zip_code_prefix,
    customer_city,
    customer_state
FROM raw.customers
