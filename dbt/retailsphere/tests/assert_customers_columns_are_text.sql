SELECT customer_id
FROM {{ ref('customers') }}
WHERE pg_typeof(customer_id) <> 'text'::regtype
   OR pg_typeof(customer_unique_id) <> 'text'::regtype
   OR pg_typeof(customer_zip_code_prefix) <> 'text'::regtype
   OR pg_typeof(customer_city) <> 'text'::regtype
   OR pg_typeof(customer_state) <> 'text'::regtype
