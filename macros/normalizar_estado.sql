{% macro normalizar_estado(col) %}
  case
    when upper(trim({{ col }})) in ('VIGENTE','ACTIVO','ACTIVA')      then 'Vigente'
    when upper(trim({{ col }})) in ('PAGADO','CANCELADO','LIQUIDADO') then 'Pagado'
    when upper(trim({{ col }})) in ('VENCIDO','MORA','ATRASADO')      then 'Vencido'
    when upper(trim({{ col }})) in ('RENOVADO','REFINANCIADO')        then 'Renovado'
    when upper(trim({{ col }})) in ('INCOBRABLE','CASTIGADO')         then 'Incobrable'
    else 'Desconocido'
  end
{% endmacro %}
