SELECT r.order_id
FROM raw.orders AS r
LEFT JOIN clean.orders AS c ON r.order_id = c.order_id
WHERE c.order_id IS NULL
