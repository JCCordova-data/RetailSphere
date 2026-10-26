-- Convert RAW values before comparison: monetary TEXT is never compared to NUMERIC.
WITH expected AS (
    SELECT
        order_id,
        order_item_id,
        product_id,
        seller_id,
        {{ safe_timestamp('shipping_limit_date') }} AS shipping_limit_date,
        CASE
            WHEN pg_input_is_valid(price, 'numeric')
                AND price !~* '^[[:space:]]*(nan|[+-]?inf(inity)?)[[:space:]]*$'
            THEN CAST(price AS NUMERIC)
            ELSE NULL
        END AS price,
        CASE
            WHEN pg_input_is_valid(freight_value, 'numeric')
                AND freight_value !~* '^[[:space:]]*(nan|[+-]?inf(inity)?)[[:space:]]*$'
            THEN CAST(freight_value AS NUMERIC)
            ELSE NULL
        END AS freight_value,
        {{ is_invalid_timestamp('shipping_limit_date') }} AS is_shipping_limit_date_invalid,
        (
            price IS NOT NULL
            AND (
                NOT pg_input_is_valid(price, 'numeric')
                OR price ~* '^[[:space:]]*(nan|[+-]?inf(inity)?)[[:space:]]*$'
            )
        ) AS is_price_invalid,
        (
            freight_value IS NOT NULL
            AND (
                NOT pg_input_is_valid(freight_value, 'numeric')
                OR freight_value ~* '^[[:space:]]*(nan|[+-]?inf(inity)?)[[:space:]]*$'
            )
        ) AS is_freight_value_invalid
    FROM raw.order_items
),

actual AS (
    SELECT
        order_id,
        order_item_id,
        product_id,
        seller_id,
        shipping_limit_date,
        price,
        freight_value,
        is_shipping_limit_date_invalid,
        is_price_invalid,
        is_freight_value_invalid
    FROM {{ ref('order_items') }}
)

-- Include the identifiers with the values to detect changes between items.
(
SELECT * FROM expected
EXCEPT ALL
SELECT * FROM actual
)

UNION ALL

(
SELECT * FROM actual
EXCEPT ALL
SELECT * FROM expected
)
