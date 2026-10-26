WITH sample_dates(raw_date, expected_invalid) AS (
    VALUES
        ('2018-07-24 20:41:37', FALSE),
        (NULL, FALSE),
        ('fecha_invalida', TRUE)
),

validated AS (
    SELECT
        raw_date,
        expected_invalid,
        CASE
            WHEN pg_input_is_valid(
                raw_date,
                'timestamp without time zone'
            )
            THEN CAST(raw_date AS TIMESTAMP)
            ELSE NULL
        END AS clean_date,
        (
            raw_date IS NOT NULL
            AND NOT pg_input_is_valid(
                raw_date,
                'timestamp without time zone'
            )
        ) AS is_date_invalid
    FROM sample_dates
)

SELECT *
FROM validated
WHERE is_date_invalid IS DISTINCT FROM expected_invalid
   OR (expected_invalid = TRUE AND clean_date IS NOT NULL)
   OR (raw_date IS NULL AND clean_date IS NOT NULL)
   OR (raw_date = '2018-07-24 20:41:37'
       AND clean_date IS DISTINCT FROM TIMESTAMP '2018-07-24 20:41:37')
