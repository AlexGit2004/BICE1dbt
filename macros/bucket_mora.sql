{% macro bucket_mora(col_dias) %}
  case
    when coalesce({{ col_dias }}, 0) = 0                     then 'Al día'
    when {{ col_dias }} between 1  and 30                    then '1-30 días'
    when {{ col_dias }} between 31 and 90                    then '31-90 días'
    when {{ col_dias }} > 90                                 then '>90 días'
    else 'Sin dato'
  end
{% endmacro %}
