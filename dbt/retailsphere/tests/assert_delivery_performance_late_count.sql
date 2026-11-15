WITH expected AS (
    -- Recompute directly from CLEAN timestamps, independently of classification.
    SELECT COUNT(*) AS late_deliveries
    FROM {{ ref('orders') }}
    WHERE order_status = 'delivered'
      AND order_delivered_customer_date::DATE > order_estimated_delivery_date::DATE
),

actual AS (
    SELECT SUM(late_deliveries) AS late_deliveries
    FROM {{ ref('delivery_performance') }}
)

SELECT
    actual.late_deliveries,
    expected.late_deliveries AS expected_late_deliveries
FROM actual
CROSS JOIN expected
WHERE actual.late_deliveries IS DISTINCT FROM expected.late_deliveries
