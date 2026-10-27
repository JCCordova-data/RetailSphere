-- Aggregate order counts before touching item data, and compare each month
-- so that moving sales between months cannot pass the global reconciliation.
WITH expected_orders AS (
    SELECT
        DATE_TRUNC('month', order_purchase_timestamp)::DATE AS month,
        COUNT(DISTINCT order_id) AS total_orders
    FROM {{ ref('orders') }}
    WHERE order_status = 'delivered'
      AND order_purchase_timestamp IS NOT NULL
    GROUP BY DATE_TRUNC('month', order_purchase_timestamp)::DATE
),

expected_items AS (
    SELECT
        DATE_TRUNC('month', orders.order_purchase_timestamp)::DATE AS month,
        SUM(items.price) AS product_revenue,
        COUNT(*) AS total_items
    FROM {{ ref('order_items') }} AS items
    INNER JOIN {{ ref('orders') }} AS orders
        ON items.order_id = orders.order_id
    WHERE orders.order_status = 'delivered'
      AND orders.order_purchase_timestamp IS NOT NULL
    GROUP BY DATE_TRUNC('month', orders.order_purchase_timestamp)::DATE
),

expected AS (
    SELECT
        orders.month,
        COALESCE(items.product_revenue, 0::NUMERIC) AS product_revenue,
        orders.total_orders,
        COALESCE(items.total_items, 0::BIGINT) AS total_items
    FROM expected_orders AS orders
    LEFT JOIN expected_items AS items ON orders.month = items.month
)

SELECT
    COALESCE(expected.month, actual.month) AS month,
    expected.product_revenue AS expected_product_revenue,
    actual.product_revenue AS actual_product_revenue,
    expected.total_orders AS expected_total_orders,
    actual.total_orders AS actual_total_orders,
    expected.total_items AS expected_total_items,
    actual.total_items AS actual_total_items
FROM expected
FULL OUTER JOIN {{ ref('monthly_sales') }} AS actual
    ON expected.month = actual.month
WHERE actual.product_revenue IS DISTINCT FROM COALESCE(expected.product_revenue, 0::NUMERIC)
   OR actual.total_orders IS DISTINCT FROM COALESCE(expected.total_orders, 0::BIGINT)
   OR actual.total_items IS DISTINCT FROM COALESCE(expected.total_items, 0::BIGINT)
