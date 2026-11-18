WITH converted AS (
    SELECT
        review_id,
        order_id,
        review_score AS review_score_raw,
        CASE
            WHEN pg_input_is_valid(review_score, 'integer')
                THEN CAST(review_score AS INTEGER)
            ELSE NULL
        END AS review_score,
        review_comment_title,
        review_comment_message,
        review_creation_date AS review_creation_date_raw,
        review_answer_timestamp AS review_answer_timestamp_raw,
        {{ safe_timestamp('review_creation_date') }} AS review_creation_date,
        {{ safe_timestamp('review_answer_timestamp') }} AS review_answer_timestamp,
        {{ is_invalid_timestamp('review_creation_date') }} AS is_review_creation_date_invalid,
        {{ is_invalid_timestamp('review_answer_timestamp') }} AS is_review_answer_timestamp_invalid
    FROM {{ source('raw', 'order_reviews') }}
)

-- Preserve every source row, including repeated IDs and invalid or missing scores.
SELECT
    *,
    (
        review_score_raw IS NOT NULL
        AND (review_score IS NULL OR review_score NOT BETWEEN 1 AND 5)
    ) AS is_review_score_invalid
FROM converted
