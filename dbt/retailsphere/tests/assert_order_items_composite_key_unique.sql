SELECT
    order_id,
    order_item_id,
    COUNT(*) AS item_count
FROM {{ ref('order_items') }}
GROUP BY order_id, order_item_id
HAVING COUNT(*) > 1
