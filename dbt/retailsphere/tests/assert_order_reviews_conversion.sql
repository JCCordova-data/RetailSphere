WITH typed_source AS (
    -- Spell out source conversions independently of the CLEAN macros.
    SELECT
        review_id,
        order_id,
        CASE WHEN pg_input_is_valid(review_score, 'integer')
            THEN review_score::INTEGER END AS review_score,
        review_score IS NOT NULL AS has_source_score,
        CASE WHEN pg_input_is_valid(review_creation_date, 'timestamp without time zone')
            THEN review_creation_date::TIMESTAMP END AS review_creation_date,
        CASE WHEN pg_input_is_valid(review_answer_timestamp, 'timestamp without time zone')
            THEN review_answer_timestamp::TIMESTAMP END AS review_answer_timestamp,
        review_creation_date IS NOT NULL AND NOT pg_input_is_valid(
            review_creation_date, 'timestamp without time zone'
        ) AS is_review_creation_date_invalid,
        review_answer_timestamp IS NOT NULL AND NOT pg_input_is_valid(
            review_answer_timestamp, 'timestamp without time zone'
        ) AS is_review_answer_timestamp_invalid
    FROM {{ source('raw', 'order_reviews') }}
),

expected AS (
    SELECT
        review_id, order_id, review_score, review_creation_date, review_answer_timestamp,
        is_review_creation_date_invalid, is_review_answer_timestamp_invalid,
        has_source_score AND (review_score IS NULL OR review_score NOT BETWEEN 1 AND 5)
            AS is_review_score_invalid
    FROM typed_source
),

actual AS (
    SELECT
        review_id, order_id, review_score, review_creation_date, review_answer_timestamp,
        is_review_creation_date_invalid, is_review_answer_timestamp_invalid,
        is_review_score_invalid
    FROM {{ ref('order_reviews') }}
)

(SELECT * FROM expected EXCEPT ALL SELECT * FROM actual)
UNION ALL
(SELECT * FROM actual EXCEPT ALL SELECT * FROM expected)
