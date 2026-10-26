-- Compare multisets in both directions to retain duplicate and NULL identifiers.
(
SELECT order_id, order_item_id, product_id, seller_id
FROM raw.order_items

EXCEPT ALL

SELECT order_id, order_item_id, product_id, seller_id
FROM {{ ref('order_items') }}
)

UNION ALL

(
SELECT order_id, order_item_id, product_id, seller_id
FROM {{ ref('order_items') }}

EXCEPT ALL

SELECT order_id, order_item_id, product_id, seller_id
FROM raw.order_items
)
