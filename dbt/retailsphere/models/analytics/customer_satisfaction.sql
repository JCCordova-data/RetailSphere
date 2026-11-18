WITH review_counts AS (
    SELECT
        order_id,
        COUNT(*) AS review_record_count,
        COUNT(*) FILTER (WHERE review_score BETWEEN 1 AND 5) AS valid_review_count
    FROM {{ ref('order_reviews') }}
    GROUP BY order_id
),

ranked_valid_reviews AS (
    SELECT
        order_id,
        review_id,
        review_score,
        review_creation_date,
        review_answer_timestamp,
        ROW_NUMBER() OVER (
            PARTITION BY order_id
            ORDER BY
                review_answer_timestamp DESC NULLS LAST,
                review_creation_date DESC NULLS LAST,
                review_id COLLATE "C" ASC NULLS LAST,
                -- Conservative final fallback for otherwise identical conflicts.
                review_score ASC
        ) AS review_rank
    FROM {{ ref('order_reviews') }}
    WHERE review_score BETWEEN 1 AND 5
)

SELECT
    orders.order_id,
    orders.order_purchase_timestamp,
    COALESCE(counts.review_record_count, 0::BIGINT) AS review_record_count,
    COALESCE(counts.valid_review_count, 0::BIGINT) AS valid_review_count,
    reviews.review_id AS selected_review_id,
    reviews.review_score,
    reviews.review_creation_date,
    reviews.review_answer_timestamp,
    reviews.review_score IS NOT NULL AS has_valid_review,
    -- NULL means unreviewed/non-evaluable; FALSE means a valid score of 1-3.
    reviews.review_score >= 4 AS is_positive_review
FROM {{ ref('orders') }} AS orders
LEFT JOIN review_counts AS counts ON orders.order_id = counts.order_id
LEFT JOIN ranked_valid_reviews AS reviews
    ON orders.order_id = reviews.order_id AND reviews.review_rank = 1
WHERE orders.order_status = 'delivered'
