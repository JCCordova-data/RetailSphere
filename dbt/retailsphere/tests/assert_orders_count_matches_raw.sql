SELECT
    (SELECT COUNT(*) FROM raw.orders) AS raw_count,
    (SELECT COUNT(*) FROM clean.orders) AS clean_count
WHERE
    (SELECT COUNT(*) FROM raw.orders)
    <>
    (SELECT COUNT(*) FROM clean.orders)
