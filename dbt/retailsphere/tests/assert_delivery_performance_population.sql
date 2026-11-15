WITH expected AS (
    SELECT
        COUNT(*) AS total_delivered_orders,
        COUNT(*) FILTER (
            WHERE order_delivered_customer_date IS NOT NULL
              AND order_estimated_delivery_date IS NOT NULL
        ) AS evaluable_delivered_orders,
        COUNT(*) FILTER (
            WHERE order_delivered_customer_date IS NULL
               OR order_estimated_delivery_date IS NULL
        ) AS missing_delivery_dates
    FROM {{ ref('orders') }}
    WHERE order_status = 'delivered'
),

actual AS (
    -- Aggregate the view to detect missing or extra summary rows as well.
    SELECT
        COUNT(*) AS summary_rows,
        SUM(total_delivered_orders) AS total_delivered_orders,
        SUM(evaluable_delivered_orders) AS evaluable_delivered_orders,
        SUM(missing_delivery_dates) AS missing_delivery_dates
    FROM {{ ref('delivery_performance') }}
)

SELECT
    actual.*,
    expected.total_delivered_orders AS expected_total_delivered_orders,
    expected.evaluable_delivered_orders AS expected_evaluable_delivered_orders,
    expected.missing_delivery_dates AS expected_missing_delivery_dates
FROM actual
CROSS JOIN expected
WHERE actual.summary_rows <> 1
   OR actual.total_delivered_orders IS DISTINCT FROM expected.total_delivered_orders
   OR actual.evaluable_delivered_orders IS DISTINCT FROM expected.evaluable_delivered_orders
   OR actual.missing_delivery_dates IS DISTINCT FROM expected.missing_delivery_dates
   OR actual.total_delivered_orders IS DISTINCT FROM
        actual.evaluable_delivered_orders + actual.missing_delivery_dates
