SELECT
    order_id,
    is_delivery_date_missing
FROM clean.orders
WHERE is_delivery_date_missing IS DISTINCT FROM (
    order_status = 'delivered'
    AND order_delivered_customer_date IS NULL
)
