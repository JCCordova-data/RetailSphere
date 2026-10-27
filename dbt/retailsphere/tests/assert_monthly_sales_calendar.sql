WITH date_bounds AS (
    SELECT
        DATE_TRUNC('month', MIN(order_purchase_timestamp))::DATE AS first_month,
        DATE_TRUNC('month', MAX(order_purchase_timestamp))::DATE AS last_month
    FROM {{ ref('orders') }}
    WHERE order_status = 'delivered'
      AND order_purchase_timestamp IS NOT NULL
),

expected AS (
    SELECT
        first_month,
        last_month,
        COALESCE(
            EXTRACT(YEAR FROM AGE(last_month, first_month))::BIGINT * 12
            + EXTRACT(MONTH FROM AGE(last_month, first_month))::BIGINT + 1,
            0::BIGINT
        ) AS month_count
    FROM date_bounds
),

actual AS (
    SELECT
        MIN(month) AS first_month,
        MAX(month) AS last_month,
        COUNT(*) AS month_count,
        COUNT(*) FILTER (
            WHERE month IS DISTINCT FROM DATE_TRUNC('month', month)::DATE
        ) AS unaligned_month_count
    FROM {{ ref('monthly_sales') }}
)

-- Together with the unique/not_null key tests, count, bounds and alignment
-- guarantee complete monthly coverage without repeating generate_series.
SELECT
    expected.month_count AS expected_month_count,
    actual.month_count AS actual_month_count,
    expected.first_month AS expected_first_month,
    actual.first_month AS actual_first_month,
    expected.last_month AS expected_last_month,
    actual.last_month AS actual_last_month,
    actual.unaligned_month_count
FROM expected
CROSS JOIN actual
WHERE actual.month_count IS DISTINCT FROM expected.month_count
   OR actual.first_month IS DISTINCT FROM expected.first_month
   OR actual.last_month IS DISTINCT FROM expected.last_month
   OR actual.unaligned_month_count <> 0
