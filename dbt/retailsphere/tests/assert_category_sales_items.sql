WITH clean_total AS (
    SELECT
        COUNT(*) AS clean_total_items
    FROM {{ ref('order_items') }} AS oi
    JOIN {{ ref('orders') }} AS o ON oi.order_id = o.order_id
    WHERE o.order_status = 'delivered'
),

analytics_total AS (
    SELECT
        SUM(total_items) AS total_items
    FROM {{ ref('category_sales') }}
)

SELECT c.clean_total_items, a.total_items
FROM clean_total AS c
CROSS JOIN analytics_total AS a
WHERE c.clean_total_items IS DISTINCT FROM a.total_items