SELECT *
FROM {{ ref('repeat_customers') }}
WHERE NULLIF(BTRIM(customer_unique_id), '') IS NULL
   OR completed_purchases IS NULL
   OR completed_purchases < 1
   OR is_repeat_customer IS DISTINCT FROM (completed_purchases >= 2)
