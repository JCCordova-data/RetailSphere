-- Multiset comparison detects lost/added rows, including exact duplicates.
(
SELECT
    review_id, order_id, review_score, review_comment_title,
    review_comment_message, review_creation_date, review_answer_timestamp
FROM {{ source('raw', 'order_reviews') }}

EXCEPT ALL

SELECT
    review_id, order_id, review_score_raw, review_comment_title,
    review_comment_message, review_creation_date_raw, review_answer_timestamp_raw
FROM {{ ref('order_reviews') }}
)

UNION ALL

(
SELECT
    review_id, order_id, review_score_raw, review_comment_title,
    review_comment_message, review_creation_date_raw, review_answer_timestamp_raw
FROM {{ ref('order_reviews') }}

EXCEPT ALL

SELECT
    review_id, order_id, review_score, review_comment_title,
    review_comment_message, review_creation_date, review_answer_timestamp
FROM {{ source('raw', 'order_reviews') }}
)
