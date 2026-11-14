SELECT
    COALESCE(p.product_category_name, 'unknown') AS product_category_name,
    COUNT(DISTINCT o.order_id) AS total_orders,
    COUNT(oi.order_item_id) AS total_items,
    SUM(oi.price) AS product_revenue
FROM {{ ref('products') }} AS p 
JOIN {{ ref('order_items') }} AS oi 
    ON p.product_id = oi.product_id 
JOIN {{ ref('orders') }} AS o 
    ON oi.order_id = o.order_id 
WHERE o.order_status = 'delivered' 
GROUP BY COALESCE(p.product_category_name, 'unknown') 