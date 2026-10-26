SELECT order_id, order_item_id
FROM {{ ref('order_items') }}
WHERE pg_typeof(order_id) <> 'text'::regtype
   OR pg_typeof(order_item_id) <> 'text'::regtype
   OR pg_typeof(product_id) <> 'text'::regtype
   OR pg_typeof(seller_id) <> 'text'::regtype
   OR pg_typeof(shipping_limit_date) <> 'timestamp without time zone'::regtype
   OR pg_typeof(price) <> 'numeric'::regtype
   OR pg_typeof(freight_value) <> 'numeric'::regtype
   OR pg_typeof(is_shipping_limit_date_invalid) <> 'boolean'::regtype
   OR pg_typeof(is_price_invalid) <> 'boolean'::regtype
   OR pg_typeof(is_freight_value_invalid) <> 'boolean'::regtype
