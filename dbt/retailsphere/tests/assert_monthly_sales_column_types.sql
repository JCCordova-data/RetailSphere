SELECT month
FROM {{ ref('monthly_sales') }}
WHERE pg_typeof(month) <> 'date'::regtype
   OR pg_typeof(product_revenue) <> 'numeric'::regtype
   OR pg_typeof(total_orders) <> 'bigint'::regtype
   OR pg_typeof(total_items) <> 'bigint'::regtype
   OR pg_typeof(average_order_value) <> 'numeric'::regtype
