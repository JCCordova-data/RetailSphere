-- Legitimate NULLs are allowed; conversion failures are checked separately.
SELECT
    product_id,
    product_name_lenght,
    product_description_lenght,
    product_photos_qty,
    product_weight_g,
    product_length_cm,
    product_height_cm,
    product_width_cm
FROM {{ ref('products') }}
WHERE product_name_lenght < 0
   OR product_description_lenght < 0
   OR product_photos_qty < 0
   OR product_weight_g < 0
   OR product_length_cm <= 0
   OR product_height_cm <= 0
   OR product_width_cm <= 0
   OR product_weight_g IN ('NaN'::NUMERIC, 'Infinity'::NUMERIC, '-Infinity'::NUMERIC)
   OR product_length_cm IN ('NaN'::NUMERIC, 'Infinity'::NUMERIC, '-Infinity'::NUMERIC)
   OR product_height_cm IN ('NaN'::NUMERIC, 'Infinity'::NUMERIC, '-Infinity'::NUMERIC)
   OR product_width_cm IN ('NaN'::NUMERIC, 'Infinity'::NUMERIC, '-Infinity'::NUMERIC)
