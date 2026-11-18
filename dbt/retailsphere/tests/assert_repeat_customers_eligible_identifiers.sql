-- Exclusions must be visible as quality failures rather than silent KPI loss.
SELECT orders.order_id, orders.customer_id, customers.customer_unique_id
FROM {{ ref('orders') }} AS orders
LEFT JOIN {{ ref('customers') }} AS customers
    ON orders.customer_id = customers.customer_id
WHERE orders.order_status = 'delivered'
  AND (
      NULLIF(BTRIM(orders.order_id), '') IS NULL
      OR NULLIF(BTRIM(orders.customer_id), '') IS NULL
      OR customers.customer_id IS NULL
      OR NULLIF(BTRIM(customers.customer_unique_id), '') IS NULL
  )
