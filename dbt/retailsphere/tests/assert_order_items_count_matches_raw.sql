WITH item_counts AS (
    SELECT
        (SELECT COUNT(*) FROM raw.order_items) AS raw_count,
        (SELECT COUNT(*) FROM {{ ref('order_items') }}) AS clean_count
)

SELECT raw_count, clean_count
FROM item_counts
WHERE raw_count <> clean_count
