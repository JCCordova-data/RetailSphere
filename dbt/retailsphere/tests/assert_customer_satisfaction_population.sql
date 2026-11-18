WITH source_counts AS (
    SELECT
        order_id,
        COUNT(*) AS review_record_count,
        COUNT(*) FILTER (
            WHERE CASE WHEN pg_input_is_valid(review_score, 'integer')
                THEN review_score::INTEGER BETWEEN 1 AND 5 ELSE FALSE END
        ) AS valid_review_count
    FROM {{ source('raw', 'order_reviews') }}
    GROUP BY order_id
),

expected AS (
    SELECT
        orders.order_id,
        orders.order_purchase_timestamp,
        COALESCE(reviews.review_record_count, 0::BIGINT) AS review_record_count,
        COALESCE(reviews.valid_review_count, 0::BIGINT) AS valid_review_count
    FROM {{ ref('orders') }} AS orders
    LEFT JOIN source_counts AS reviews USING (order_id)
    WHERE orders.order_status = 'delivered'
)

SELECT actual.*, expected.order_id AS expected_order_id
FROM {{ ref('customer_satisfaction') }} AS actual
FULL OUTER JOIN expected USING (order_id)
WHERE actual.order_id IS NULL
   OR expected.order_id IS NULL
   OR actual.order_purchase_timestamp IS DISTINCT FROM expected.order_purchase_timestamp
   OR actual.review_record_count IS DISTINCT FROM expected.review_record_count
   OR actual.valid_review_count IS DISTINCT FROM expected.valid_review_count
