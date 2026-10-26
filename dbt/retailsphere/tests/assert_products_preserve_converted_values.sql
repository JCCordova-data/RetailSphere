-- Derive expected values from RAW, then compare complete records as multisets.
WITH expected AS (
    SELECT
        product_id,
        product_category_name,
        CASE
            WHEN pg_input_is_valid(product_name_lenght, 'integer')
            THEN CAST(product_name_lenght AS INTEGER)
            ELSE NULL
        END AS product_name_lenght,
        CASE
            WHEN pg_input_is_valid(product_description_lenght, 'integer')
            THEN CAST(product_description_lenght AS INTEGER)
            ELSE NULL
        END AS product_description_lenght,
        CASE
            WHEN pg_input_is_valid(product_photos_qty, 'integer')
            THEN CAST(product_photos_qty AS INTEGER)
            ELSE NULL
        END AS product_photos_qty,
        CASE
            WHEN pg_input_is_valid(product_weight_g, 'numeric')
                AND product_weight_g !~* '^[[:space:]]*(nan|[+-]?inf(inity)?)[[:space:]]*$'
            THEN CAST(product_weight_g AS NUMERIC)
            ELSE NULL
        END AS product_weight_g,
        CASE
            WHEN pg_input_is_valid(product_length_cm, 'numeric')
                AND product_length_cm !~* '^[[:space:]]*(nan|[+-]?inf(inity)?)[[:space:]]*$'
            THEN CAST(product_length_cm AS NUMERIC)
            ELSE NULL
        END AS product_length_cm,
        CASE
            WHEN pg_input_is_valid(product_height_cm, 'numeric')
                AND product_height_cm !~* '^[[:space:]]*(nan|[+-]?inf(inity)?)[[:space:]]*$'
            THEN CAST(product_height_cm AS NUMERIC)
            ELSE NULL
        END AS product_height_cm,
        CASE
            WHEN pg_input_is_valid(product_width_cm, 'numeric')
                AND product_width_cm !~* '^[[:space:]]*(nan|[+-]?inf(inity)?)[[:space:]]*$'
            THEN CAST(product_width_cm AS NUMERIC)
            ELSE NULL
        END AS product_width_cm,
        (
            product_name_lenght IS NOT NULL
            AND NOT pg_input_is_valid(product_name_lenght, 'integer')
        ) AS is_product_name_lenght_invalid,
        (
            product_description_lenght IS NOT NULL
            AND NOT pg_input_is_valid(product_description_lenght, 'integer')
        ) AS is_product_description_lenght_invalid,
        (
            product_photos_qty IS NOT NULL
            AND NOT pg_input_is_valid(product_photos_qty, 'integer')
        ) AS is_product_photos_qty_invalid,
        (
            product_weight_g IS NOT NULL
            AND (
                NOT pg_input_is_valid(product_weight_g, 'numeric')
                OR product_weight_g ~* '^[[:space:]]*(nan|[+-]?inf(inity)?)[[:space:]]*$'
            )
        ) AS is_product_weight_g_invalid,
        (
            product_length_cm IS NOT NULL
            AND (
                NOT pg_input_is_valid(product_length_cm, 'numeric')
                OR product_length_cm ~* '^[[:space:]]*(nan|[+-]?inf(inity)?)[[:space:]]*$'
            )
        ) AS is_product_length_cm_invalid,
        (
            product_height_cm IS NOT NULL
            AND (
                NOT pg_input_is_valid(product_height_cm, 'numeric')
                OR product_height_cm ~* '^[[:space:]]*(nan|[+-]?inf(inity)?)[[:space:]]*$'
            )
        ) AS is_product_height_cm_invalid,
        (
            product_width_cm IS NOT NULL
            AND (
                NOT pg_input_is_valid(product_width_cm, 'numeric')
                OR product_width_cm ~* '^[[:space:]]*(nan|[+-]?inf(inity)?)[[:space:]]*$'
            )
        ) AS is_product_width_cm_invalid,
        -- Compare the RAW number directly so this also detects lost zero weights.
        CASE
            WHEN pg_input_is_valid(product_weight_g, 'numeric')
                AND product_weight_g !~* '^[[:space:]]*(nan|[+-]?inf(inity)?)[[:space:]]*$'
            THEN CAST(product_weight_g AS NUMERIC) = 0
            ELSE FALSE
        END AS is_weight_zero
    FROM raw.products
),

actual AS (
    SELECT
        product_id,
        product_category_name,
        product_name_lenght,
        product_description_lenght,
        product_photos_qty,
        product_weight_g,
        product_length_cm,
        product_height_cm,
        product_width_cm,
        is_product_name_lenght_invalid,
        is_product_description_lenght_invalid,
        is_product_photos_qty_invalid,
        is_product_weight_g_invalid,
        is_product_length_cm_invalid,
        is_product_height_cm_invalid,
        is_product_width_cm_invalid,
        is_weight_zero
    FROM {{ ref('products') }}
)

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
