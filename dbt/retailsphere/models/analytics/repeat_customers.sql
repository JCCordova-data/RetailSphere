WITH customer_purchases AS (
    SELECT
        customers.customer_unique_id,
        COUNT(DISTINCT orders.order_id) AS completed_purchases
    FROM {{ ref('orders') }} AS orders
    JOIN {{ ref('customers') }} AS customers
        ON orders.customer_id = customers.customer_id
    WHERE orders.order_status = 'delivered'
      AND NULLIF(BTRIM(orders.order_id), '') IS NOT NULL
      AND NULLIF(BTRIM(orders.customer_id), '') IS NOT NULL
      AND NULLIF(BTRIM(customers.customer_unique_id), '') IS NOT NULL
    GROUP BY customers.customer_unique_id
)

SELECT
    customer_unique_id,
    completed_purchases,
    completed_purchases >= 2 AS is_repeat_customer
FROM customer_purchases
