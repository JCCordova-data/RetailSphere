{% macro safe_timestamp(column_name) %}
    CASE
        WHEN pg_input_is_valid(
            {{ column_name }},
            'timestamp without time zone'
        )
        THEN CAST({{ column_name }} AS TIMESTAMP)
        ELSE NULL
    END
{% endmacro %}