SELECT product_id, product_weight_g, is_weight_zero
FROM {{ ref('products') }}
WHERE is_weight_zero IS DISTINCT FROM COALESCE(product_weight_g = 0, FALSE)
