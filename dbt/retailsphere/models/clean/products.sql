WITH validated AS (
    SELECT
        *,
        pg_input_is_valid(product_name_lenght, 'integer') AS is_product_name_lenght_valid,
        pg_input_is_valid(product_description_lenght, 'integer') AS is_product_description_lenght_valid,
        pg_input_is_valid(product_photos_qty, 'integer') AS is_product_photos_qty_valid,
        (
            pg_input_is_valid(product_weight_g, 'numeric')
            AND product_weight_g !~* '^[[:space:]]*(nan|[+-]?inf(inity)?)[[:space:]]*$'
        ) AS is_product_weight_g_valid,
        (
            pg_input_is_valid(product_length_cm, 'numeric')
            AND product_length_cm !~* '^[[:space:]]*(nan|[+-]?inf(inity)?)[[:space:]]*$'
        ) AS is_product_length_cm_valid,
        (
            pg_input_is_valid(product_height_cm, 'numeric')
            AND product_height_cm !~* '^[[:space:]]*(nan|[+-]?inf(inity)?)[[:space:]]*$'
        ) AS is_product_height_cm_valid,
        (
            pg_input_is_valid(product_width_cm, 'numeric')
            AND product_width_cm !~* '^[[:space:]]*(nan|[+-]?inf(inity)?)[[:space:]]*$'
        ) AS is_product_width_cm_valid
    FROM raw.products
),

converted AS (
    SELECT
        product_id,
        product_category_name,
        CASE
            WHEN is_product_name_lenght_valid THEN CAST(product_name_lenght AS INTEGER)
            ELSE NULL
        END AS product_name_lenght,
        CASE
            WHEN is_product_description_lenght_valid THEN CAST(product_description_lenght AS INTEGER)
            ELSE NULL
        END AS product_description_lenght,
        CASE
            WHEN is_product_photos_qty_valid THEN CAST(product_photos_qty AS INTEGER)
            ELSE NULL
        END AS product_photos_qty,
        CASE
            WHEN is_product_weight_g_valid THEN CAST(product_weight_g AS NUMERIC)
            ELSE NULL
        END AS product_weight_g,
        CASE
            WHEN is_product_length_cm_valid THEN CAST(product_length_cm AS NUMERIC)
            ELSE NULL
        END AS product_length_cm,
        CASE
            WHEN is_product_height_cm_valid THEN CAST(product_height_cm AS NUMERIC)
            ELSE NULL
        END AS product_height_cm,
        CASE
            WHEN is_product_width_cm_valid THEN CAST(product_width_cm AS NUMERIC)
            ELSE NULL
        END AS product_width_cm,
        (product_name_lenght IS NOT NULL AND NOT is_product_name_lenght_valid) AS is_product_name_lenght_invalid,
        (product_description_lenght IS NOT NULL AND NOT is_product_description_lenght_valid) AS is_product_description_lenght_invalid,
        (product_photos_qty IS NOT NULL AND NOT is_product_photos_qty_valid) AS is_product_photos_qty_invalid,
        (product_weight_g IS NOT NULL AND NOT is_product_weight_g_valid) AS is_product_weight_g_invalid,
        (product_length_cm IS NOT NULL AND NOT is_product_length_cm_valid) AS is_product_length_cm_invalid,
        (product_height_cm IS NOT NULL AND NOT is_product_height_cm_valid) AS is_product_height_cm_invalid,
        (product_width_cm IS NOT NULL AND NOT is_product_width_cm_valid) AS is_product_width_cm_invalid
    FROM validated
)

-- Preserve every source row and NULL; range violations are reported by tests.
SELECT
    *,
    COALESCE(product_weight_g = 0, FALSE) AS is_weight_zero
FROM converted
