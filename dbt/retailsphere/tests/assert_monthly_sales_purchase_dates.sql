-- Delivered orders must have a purchase timestamp to be assigned to a month.
SELECT order_id, order_purchase_timestamp
FROM {{ ref('orders') }}
WHERE order_status = 'delivered'
  AND order_purchase_timestamp IS NULL
