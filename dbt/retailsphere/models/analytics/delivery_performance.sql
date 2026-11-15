WITH delivered_orders AS (
    SELECT
        order_delivered_customer_date::DATE AS actual_delivery_date,
        order_estimated_delivery_date::DATE AS estimated_delivery_date
    FROM {{ ref('orders') }}
    WHERE order_status = 'delivered'
),

classified_orders AS (
    SELECT
        actual_delivery_date,
        estimated_delivery_date,
        CASE
            WHEN actual_delivery_date IS NULL OR estimated_delivery_date IS NULL
                THEN NULL
            WHEN actual_delivery_date < estimated_delivery_date THEN 'early'
            WHEN actual_delivery_date = estimated_delivery_date THEN 'on_time'
            WHEN actual_delivery_date > estimated_delivery_date THEN 'late'
        END AS delivery_class
    FROM delivered_orders
),

delivery_totals AS (
    SELECT
        COUNT(*) AS total_delivered_orders,
        COUNT(delivery_class) AS evaluable_delivered_orders,
        COUNT(*) FILTER (WHERE delivery_class IS NULL) AS missing_delivery_dates,
        COUNT(*) FILTER (WHERE delivery_class = 'early') AS early_deliveries,
        COUNT(*) FILTER (WHERE delivery_class = 'on_time') AS on_time_deliveries,
        COUNT(*) FILTER (WHERE delivery_class = 'late') AS late_deliveries,
        ROUND(
            AVG(actual_delivery_date - estimated_delivery_date)
                FILTER (WHERE delivery_class = 'late'),
            2
        ) AS avg_late_days
    FROM classified_orders
)

SELECT
    total_delivered_orders,
    evaluable_delivered_orders,
    missing_delivery_dates,
    early_deliveries,
    on_time_deliveries,
    late_deliveries,
    ROUND(
        100::NUMERIC * late_deliveries / NULLIF(evaluable_delivered_orders, 0),
        2
    ) AS late_delivery_rate_pct,
    avg_late_days
FROM delivery_totals
