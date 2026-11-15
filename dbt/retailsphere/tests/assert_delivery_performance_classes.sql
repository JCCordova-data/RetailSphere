SELECT
    evaluable_delivered_orders,
    early_deliveries,
    on_time_deliveries,
    late_deliveries
FROM {{ ref('delivery_performance') }}
WHERE evaluable_delivered_orders IS DISTINCT FROM
    early_deliveries + on_time_deliveries + late_deliveries
