# El override de generate_schema_name es lo que hace que dbt respete CSILVER y
# CGOLD literalmente. Sin este macro, dbt antepondria el schema del perfil
# (target.schema) y las tablas terminarian en AIRBYTE_DATABASE.<PERFIL>_CSILVER.
#
# Se conserva unicamente el override, que es sintaxis probada. El resto de los
# macros de ce1 se reescriben con otra logica.
{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- if custom_schema_name is none -%}
        {{ target.schema }}
    {%- elif custom_schema_name | trim == '' -%}
        {{ target.schema }}
    {%- else -%}
        {{ custom_schema_name | trim | upper }}
    {%- endif -%}
{%- endmacro %}
