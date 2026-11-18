WITH expected AS (
    -- DISTINCT ON provides a separate implementation of the winner policy.
    SELECT DISTINCT ON (order_id)
        order_id, review_id, review_score, review_creation_date, review_answer_timestamp
    FROM {{ ref('order_reviews') }}
    WHERE review_score BETWEEN 1 AND 5
    ORDER BY order_id,
        review_answer_timestamp DESC NULLS LAST,
        review_creation_date DESC NULLS LAST,
        review_id COLLATE "C" ASC NULLS LAST,
        review_score ASC
)

SELECT actual.*, expected.review_id AS expected_review_id
FROM {{ ref('customer_satisfaction') }} AS actual
LEFT JOIN expected USING (order_id)
WHERE actual.selected_review_id IS DISTINCT FROM expected.review_id
   OR actual.review_score IS DISTINCT FROM expected.review_score
   OR actual.review_creation_date IS DISTINCT FROM expected.review_creation_date
   OR actual.review_answer_timestamp IS DISTINCT FROM expected.review_answer_timestamp
