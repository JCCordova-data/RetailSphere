WITH clean_total AS (
    SELECT SUM(oi.price) AS clean_product_revenue FROM {{ ref('order_items') }} AS oi
    JOIN {{ ref('orders') }} AS o ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
),

analytics_total AS (
    SELECT SUM(product_revenue) AS product_revenue
    FROM {{ ref('category_sales') }}
)

SELECT c.clean_product_revenue, a.product_revenue
FROM clean_total AS c
CROSS JOIN analytics_total AS a
WHERE c.clean_product_revenue IS DISTINCT FROM a.product_revenue