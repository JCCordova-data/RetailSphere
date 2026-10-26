{% macro is_invalid_timestamp(column_name) %}
    (
        {{ column_name }} IS NOT NULL
        AND NOT pg_input_is_valid(
            {{ column_name }},
            'timestamp without time zone'
        )
    )
{% endmacro %}
