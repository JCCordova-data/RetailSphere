SELECT
    r.order_id,
    r.customer_id
FROM raw.orders AS r
LEFT JOIN {{ ref('customers') }} AS c ON r.customer_id = c.customer_id
WHERE c.customer_id IS NULL
