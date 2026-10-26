-- Compare multisets in both directions, including duplicate and NULL attributes.
(
SELECT product_id, product_category_name
FROM raw.products

EXCEPT ALL

SELECT product_id, product_category_name
FROM {{ ref('products') }}
)

UNION ALL

(
SELECT product_id, product_category_name
FROM {{ ref('products') }}

EXCEPT ALL

SELECT product_id, product_category_name
FROM raw.products
)
