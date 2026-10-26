SELECT
    order_id,
    customer_id,
    order_status,
    {{ safe_timestamp('order_purchase_timestamp') }} AS order_purchase_timestamp,
    {{ safe_timestamp('order_approved_at') }} AS order_approved_at,
    {{ safe_timestamp('order_delivered_carrier_date') }} AS order_delivered_carrier_date,
    {{ safe_timestamp('order_delivered_customer_date') }} AS order_delivered_customer_date,
    {{ safe_timestamp('order_estimated_delivery_date') }} AS order_estimated_delivery_date,
    CASE
        WHEN order_status = 'delivered' AND order_delivered_customer_date IS NULL
        THEN TRUE
        ELSE FALSE
    END AS is_delivery_date_missing,
    {{ is_invalid_timestamp('order_approved_at') }} AS is_approval_date_invalid,
    {{ is_invalid_timestamp('order_purchase_timestamp') }} AS is_purchase_date_invalid,
    {{ is_invalid_timestamp('order_delivered_carrier_date') }} AS is_carrier_date_invalid,
    {{ is_invalid_timestamp('order_delivered_customer_date') }} AS is_customer_delivery_date_invalid,
    {{ is_invalid_timestamp('order_estimated_delivery_date') }} AS is_estimated_delivery_date_invalid
FROM raw.orders
