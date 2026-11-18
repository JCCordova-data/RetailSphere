WITH buyer_orders AS (
    -- Deduplicate buyer/order pairs before counting, independently of ANALYTICS.
    SELECT DISTINCT customers.customer_unique_id, orders.order_id
    FROM {{ ref('orders') }} AS orders
    JOIN {{ ref('customers') }} AS customers
        ON orders.customer_id = customers.customer_id
    WHERE orders.order_status = 'delivered'
      AND NULLIF(BTRIM(orders.order_id), '') IS NOT NULL
      AND NULLIF(BTRIM(orders.customer_id), '') IS NOT NULL
      AND NULLIF(BTRIM(customers.customer_unique_id), '') IS NOT NULL
),

expected AS (
    SELECT customer_unique_id, COUNT(*) AS completed_purchases
    FROM buyer_orders
    GROUP BY customer_unique_id
)

SELECT
    actual.customer_unique_id,
    expected.customer_unique_id AS expected_customer_unique_id,
    actual.completed_purchases,
    expected.completed_purchases AS expected_completed_purchases
FROM {{ ref('repeat_customers') }} AS actual
FULL OUTER JOIN expected USING (customer_unique_id)
WHERE actual.customer_unique_id IS NULL
   OR expected.customer_unique_id IS NULL
   OR actual.completed_purchases IS DISTINCT FROM expected.completed_purchases
