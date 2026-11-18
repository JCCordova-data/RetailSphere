WITH typed_source AS (
    SELECT
        order_id,
        review_id,
        CASE WHEN pg_input_is_valid(review_score, 'integer')
            THEN review_score::INTEGER END AS review_score,
        CASE WHEN pg_input_is_valid(review_creation_date, 'timestamp without time zone')
            THEN review_creation_date::TIMESTAMP END AS review_creation_date,
        CASE WHEN pg_input_is_valid(review_answer_timestamp, 'timestamp without time zone')
            THEN review_answer_timestamp::TIMESTAMP END AS review_answer_timestamp
    FROM {{ source('raw', 'order_reviews') }}
),

source_winners AS (
    SELECT DISTINCT ON (order_id) order_id, review_score
    FROM typed_source
    WHERE review_score BETWEEN 1 AND 5
    ORDER BY order_id,
        review_answer_timestamp DESC NULLS LAST,
        review_creation_date DESC NULLS LAST,
        review_id COLLATE "C" ASC NULLS LAST,
        review_score ASC
),

expected AS (
    SELECT
        COUNT(*) AS eligible_orders,
        COUNT(reviews.review_score) AS reviewed_orders,
        COUNT(*) FILTER (WHERE reviews.review_score >= 4) AS positive_orders,
        AVG(reviews.review_score) AS average_score,
        ARRAY[
            COUNT(*) FILTER (WHERE reviews.review_score = 1),
            COUNT(*) FILTER (WHERE reviews.review_score = 2),
            COUNT(*) FILTER (WHERE reviews.review_score = 3),
            COUNT(*) FILTER (WHERE reviews.review_score = 4),
            COUNT(*) FILTER (WHERE reviews.review_score = 5)
        ] AS distribution
    FROM raw.orders AS orders
    LEFT JOIN source_winners AS reviews USING (order_id)
    WHERE orders.order_status = 'delivered'
),

actual AS (
    SELECT
        COUNT(*) AS eligible_orders,
        COUNT(*) FILTER (WHERE has_valid_review) AS reviewed_orders,
        COUNT(*) FILTER (WHERE is_positive_review) AS positive_orders,
        AVG(review_score) AS average_score,
        ARRAY[
            COUNT(*) FILTER (WHERE review_score = 1),
            COUNT(*) FILTER (WHERE review_score = 2),
            COUNT(*) FILTER (WHERE review_score = 3),
            COUNT(*) FILTER (WHERE review_score = 4),
            COUNT(*) FILTER (WHERE review_score = 5)
        ] AS distribution
    FROM {{ ref('customer_satisfaction') }}
)

SELECT actual.*, expected.distribution AS expected_distribution
FROM actual
CROSS JOIN expected
WHERE actual.eligible_orders IS DISTINCT FROM expected.eligible_orders
   OR actual.reviewed_orders IS DISTINCT FROM expected.reviewed_orders
   OR actual.positive_orders IS DISTINCT FROM expected.positive_orders
   OR actual.average_score IS DISTINCT FROM expected.average_score
   OR actual.distribution IS DISTINCT FROM expected.distribution
   OR (100::NUMERIC * actual.reviewed_orders / NULLIF(actual.eligible_orders, 0))
        IS DISTINCT FROM
      (100::NUMERIC * expected.reviewed_orders / NULLIF(expected.eligible_orders, 0))
   OR (100::NUMERIC * actual.positive_orders / NULLIF(actual.reviewed_orders, 0))
        IS DISTINCT FROM
      (100::NUMERIC * expected.positive_orders / NULLIF(expected.reviewed_orders, 0))
