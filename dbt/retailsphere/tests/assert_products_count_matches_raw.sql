WITH product_counts AS (
    SELECT
        (SELECT COUNT(*) FROM raw.products) AS raw_count,
        (SELECT COUNT(*) FROM {{ ref('products') }}) AS clean_count
)

SELECT raw_count, clean_count
FROM product_counts
WHERE raw_count <> clean_count
