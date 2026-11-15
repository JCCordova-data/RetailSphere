WITH expected AS (
    SELECT
        ROUND(
            AVG(order_delivered_customer_date::DATE - order_estimated_delivery_date::DATE),
            2
        ) AS avg_late_days
    FROM {{ ref('orders') }}
    WHERE order_status = 'delivered'
      AND order_delivered_customer_date::DATE > order_estimated_delivery_date::DATE
)

SELECT actual.*, expected.avg_late_days AS expected_avg_late_days
FROM {{ ref('delivery_performance') }} AS actual
CROSS JOIN expected
WHERE actual.late_delivery_rate_pct IS DISTINCT FROM ROUND(
        100::NUMERIC * actual.late_deliveries / NULLIF(actual.evaluable_delivered_orders, 0),
        2
    )
   OR actual.avg_late_days IS DISTINCT FROM expected.avg_late_days
   OR actual.total_delivered_orders < 0
   OR actual.evaluable_delivered_orders < 0
   OR actual.missing_delivery_dates < 0
   OR actual.early_deliveries < 0
   OR actual.on_time_deliveries < 0
   OR actual.late_deliveries < 0
   OR actual.late_delivery_rate_pct NOT BETWEEN 0 AND 100
