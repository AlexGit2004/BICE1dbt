{% macro limpiar_texto(col, default='NO ESPECIFICADO') %}
  coalesce(nullif(trim(upper(cast({{ col }} as varchar))), ''),
           '{{ default }}')
{% endmacro %}
