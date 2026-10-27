WITH eligible_orders AS (
    SELECT order_id, order_purchase_timestamp
    FROM {{ ref('orders') }}
    WHERE order_status = 'delivered'
      AND order_purchase_timestamp IS NOT NULL
),

date_bounds AS (
    SELECT
        DATE_TRUNC('month', MIN(order_purchase_timestamp)) AS first_month,
        DATE_TRUNC('month', MAX(order_purchase_timestamp)) AS last_month
    FROM eligible_orders
),

calendar AS (
    SELECT month_start::DATE AS month
    FROM date_bounds
    CROSS JOIN LATERAL GENERATE_SERIES(
        first_month,
        last_month,
        INTERVAL '1 month'
    ) AS months(month_start)
),

monthly_totals AS (
    SELECT
        DATE_TRUNC('month', orders.order_purchase_timestamp)::DATE AS month,
        SUM(items.price) AS product_revenue,
        COUNT(DISTINCT orders.order_id) AS total_orders,
        -- Count matched rows even when an item's identifier or price is NULL.
        COUNT(items.order_id) AS total_items
    FROM eligible_orders AS orders
    LEFT JOIN {{ ref('order_items') }} AS items
        ON orders.order_id = items.order_id
    GROUP BY DATE_TRUNC('month', orders.order_purchase_timestamp)::DATE
)

SELECT
    calendar.month,
    COALESCE(totals.product_revenue, 0::NUMERIC) AS product_revenue,
    COALESCE(totals.total_orders, 0::BIGINT) AS total_orders,
    COALESCE(totals.total_items, 0::BIGINT) AS total_items,
    COALESCE(totals.product_revenue, 0::NUMERIC)
        / NULLIF(totals.total_orders, 0) AS average_order_value
FROM calendar
LEFT JOIN monthly_totals AS totals ON calendar.month = totals.month
