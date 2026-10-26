SELECT
    customer_id,
    customer_zip_code_prefix
FROM {{ ref('customers') }}
WHERE customer_zip_code_prefix IS NULL
   OR customer_zip_code_prefix !~ '^[0-9]{5}$'
