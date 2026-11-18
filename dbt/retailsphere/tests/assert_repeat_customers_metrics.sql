WITH source_buyers AS (
    -- RAW baseline also detects unexpected changes in CLEAN identity mapping.
    SELECT customers.customer_unique_id, COUNT(DISTINCT orders.order_id) AS purchases
    FROM raw.orders AS orders
    JOIN raw.customers AS customers ON orders.customer_id = customers.customer_id
    WHERE orders.order_status = 'delivered'
      AND NULLIF(BTRIM(orders.order_id), '') IS NOT NULL
      AND NULLIF(BTRIM(orders.customer_id), '') IS NOT NULL
      AND NULLIF(BTRIM(customers.customer_unique_id), '') IS NOT NULL
    GROUP BY customers.customer_unique_id
),

expected AS (
    SELECT
        COUNT(*) AS buyers,
        COUNT(*) FILTER (WHERE purchases = 1) AS one_time_buyers,
        COUNT(*) FILTER (WHERE purchases >= 2) AS repeat_buyers,
        COALESCE(SUM(purchases), 0) AS purchases
    FROM source_buyers
),

actual AS (
    SELECT
        COUNT(*) AS buyers,
        COUNT(*) FILTER (WHERE NOT is_repeat_customer) AS one_time_buyers,
        COUNT(*) FILTER (WHERE is_repeat_customer) AS repeat_buyers,
        COALESCE(SUM(completed_purchases), 0) AS purchases
    FROM {{ ref('repeat_customers') }}
)

SELECT actual.*, expected.buyers AS expected_buyers
FROM actual
CROSS JOIN expected
WHERE actual.buyers IS DISTINCT FROM expected.buyers
   OR actual.one_time_buyers IS DISTINCT FROM expected.one_time_buyers
   OR actual.repeat_buyers IS DISTINCT FROM expected.repeat_buyers
   OR actual.purchases IS DISTINCT FROM expected.purchases
   OR actual.buyers IS DISTINCT FROM actual.one_time_buyers + actual.repeat_buyers
   OR (100::NUMERIC * actual.repeat_buyers / NULLIF(actual.buyers, 0))
        IS DISTINCT FROM
      (100::NUMERIC * expected.repeat_buyers / NULLIF(expected.buyers, 0))
