WITH validated AS (
    SELECT
        *,
        -- Match whole non-finite NUMERIC inputs, including signed infinity aliases.
        (
            pg_input_is_valid(price, 'numeric')
            AND price !~* '^[[:space:]]*(nan|[+-]?inf(inity)?)[[:space:]]*$'
        ) AS is_price_valid,
        (
            pg_input_is_valid(freight_value, 'numeric')
            AND freight_value !~* '^[[:space:]]*(nan|[+-]?inf(inity)?)[[:space:]]*$'
        ) AS is_freight_value_valid
    FROM raw.order_items
)

-- Preserve all rows, including duplicate keys, missing values and invalid amounts.
SELECT
    order_id,
    order_item_id,
    product_id,
    seller_id,
    {{ safe_timestamp('shipping_limit_date') }} AS shipping_limit_date,
    CASE
        WHEN is_price_valid THEN CAST(price AS NUMERIC)
        ELSE NULL
    END AS price,
    CASE
        WHEN is_freight_value_valid THEN CAST(freight_value AS NUMERIC)
        ELSE NULL
    END AS freight_value,
    {{ is_invalid_timestamp('shipping_limit_date') }} AS is_shipping_limit_date_invalid,
    (price IS NOT NULL AND NOT is_price_valid) AS is_price_invalid,
    (freight_value IS NOT NULL AND NOT is_freight_value_valid) AS is_freight_value_invalid
FROM validated
