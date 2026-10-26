-- Missing/failed conversions are reported by the column not_null tests.
SELECT order_id, order_item_id, price, freight_value
FROM {{ ref('order_items') }}
WHERE price <= 0
   OR freight_value < 0
   OR price IN ('NaN'::NUMERIC, 'Infinity'::NUMERIC, '-Infinity'::NUMERIC)
   OR freight_value IN ('NaN'::NUMERIC, 'Infinity'::NUMERIC, '-Infinity'::NUMERIC)
