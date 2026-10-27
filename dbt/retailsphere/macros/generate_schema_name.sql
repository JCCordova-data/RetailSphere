{% macro generate_schema_name(custom_schema_name, node) -%}
    {# Keep ANALYTICS separate when the profile's default schema is clean. #}
    {%- if node.resource_type == 'model'
        and node.package_name == 'retailsphere'
        and node.fqn[1] == 'analytics'
        and custom_schema_name == 'analytics' -%}
        analytics
    {%- else -%}
        {{ dbt.default__generate_schema_name(custom_schema_name, node) }}
    {%- endif -%}
{%- endmacro %}
