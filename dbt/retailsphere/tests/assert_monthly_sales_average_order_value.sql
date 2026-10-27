SELECT month, product_revenue, total_orders, average_order_value
FROM {{ ref('monthly_sales') }}
WHERE total_orders > 0
  AND average_order_value IS DISTINCT FROM product_revenue / NULLIF(total_orders, 0)
