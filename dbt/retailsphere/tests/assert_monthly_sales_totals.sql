-- Count orders independently of the one-to-many item relationship.
WITH expected_orders AS (
    SELECT COUNT(DISTINCT order_id) AS total_orders
    FROM {{ ref('orders') }}
    WHERE order_status = 'delivered'
      AND order_purchase_timestamp IS NOT NULL
),

expected_items AS (
    SELECT
        COALESCE(SUM(items.price), 0::NUMERIC) AS product_revenue,
        COUNT(*) AS total_items
    FROM {{ ref('order_items') }} AS items
    WHERE EXISTS (
        SELECT 1
        FROM {{ ref('orders') }} AS orders
        WHERE orders.order_id = items.order_id
          AND orders.order_status = 'delivered'
          AND orders.order_purchase_timestamp IS NOT NULL
    )
),

actual AS (
    SELECT
        COALESCE(SUM(product_revenue), 0::NUMERIC) AS product_revenue,
        COALESCE(SUM(total_orders), 0::NUMERIC) AS total_orders,
        COALESCE(SUM(total_items), 0::NUMERIC) AS total_items
    FROM {{ ref('monthly_sales') }}
)

SELECT
    expected_items.product_revenue AS expected_product_revenue,
    actual.product_revenue AS actual_product_revenue,
    expected_orders.total_orders AS expected_total_orders,
    actual.total_orders AS actual_total_orders,
    expected_items.total_items AS expected_total_items,
    actual.total_items AS actual_total_items
FROM expected_orders
CROSS JOIN expected_items
CROSS JOIN actual
WHERE actual.product_revenue IS DISTINCT FROM expected_items.product_revenue
   OR actual.total_orders IS DISTINCT FROM expected_orders.total_orders
   OR actual.total_items IS DISTINCT FROM expected_items.total_items
