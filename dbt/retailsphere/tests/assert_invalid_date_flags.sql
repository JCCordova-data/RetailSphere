SELECT
    c.order_id
FROM clean.orders AS c
INNER JOIN raw.orders AS r
    ON c.order_id = r.order_id
WHERE
    c.is_purchase_date_invalid IS DISTINCT FROM
        {{ is_invalid_timestamp('r.order_purchase_timestamp') }}

    OR c.is_approval_date_invalid IS DISTINCT FROM
        {{ is_invalid_timestamp('r.order_approved_at') }}

    OR c.is_carrier_date_invalid IS DISTINCT FROM
        {{ is_invalid_timestamp('r.order_delivered_carrier_date') }}

    OR c.is_customer_delivery_date_invalid IS DISTINCT FROM
        {{ is_invalid_timestamp('r.order_delivered_customer_date') }}

    OR c.is_estimated_delivery_date_invalid IS DISTINCT FROM
        {{ is_invalid_timestamp('r.order_estimated_delivery_date') }}
