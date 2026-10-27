SELECT sales.*
FROM {{ ref('monthly_sales') }} AS sales
WHERE (
    sales.total_orders = 0
    OR NOT EXISTS (
        SELECT 1
        FROM {{ ref('orders') }} AS orders
        WHERE orders.order_status = 'delivered'
          AND DATE_TRUNC('month', orders.order_purchase_timestamp)::DATE = sales.month
    )
)
AND (
    sales.product_revenue IS DISTINCT FROM 0::NUMERIC
    OR sales.total_orders IS DISTINCT FROM 0::BIGINT
    OR sales.total_items IS DISTINCT FROM 0::BIGINT
    OR sales.average_order_value IS NOT NULL
)
