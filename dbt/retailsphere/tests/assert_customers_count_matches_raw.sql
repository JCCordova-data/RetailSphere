WITH customer_counts AS (
    SELECT
        (SELECT COUNT(*) FROM raw.customers) AS raw_count,
        (SELECT COUNT(*) FROM {{ ref('customers') }}) AS clean_count
)

SELECT raw_count, clean_count
FROM customer_counts
WHERE raw_count <> clean_count
