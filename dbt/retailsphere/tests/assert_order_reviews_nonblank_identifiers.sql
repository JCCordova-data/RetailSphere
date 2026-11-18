SELECT review_id, order_id
FROM {{ ref('order_reviews') }}
WHERE NULLIF(BTRIM(review_id), '') IS NULL
   OR NULLIF(BTRIM(order_id), '') IS NULL
