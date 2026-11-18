SELECT *
FROM {{ ref('customer_satisfaction') }}
WHERE review_record_count IS NULL
   OR valid_review_count IS NULL
   OR review_record_count < 0
   OR valid_review_count < 0
   OR valid_review_count > review_record_count
   OR review_score NOT BETWEEN 1 AND 5
   OR has_valid_review IS DISTINCT FROM (review_score IS NOT NULL)
   OR has_valid_review IS DISTINCT FROM (valid_review_count > 0)
   OR is_positive_review IS DISTINCT FROM (review_score >= 4)
