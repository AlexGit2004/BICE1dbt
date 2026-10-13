{#-
    bucket_mora.sql  (ACTUALIZADO)

    REGLA 3 aplicada a un atributo derivado: el bucket de mora no se calcula en
    Power BI, se materializa en el DW con UNA sola definicion, usada en dos
    lugares (cartera y pagos). Si el negocio cambia los cortes, se cambian en un
    archivo y los dos hechos se mueven juntos.

    5 segmentos (antes 4). El corte de 90 dias no es arbitrario: coincide con
    dbt_project.yml var dias_atraso_umbral, que es el mismo umbral que usa
    dim_cliente.tiene_atraso_vigente. Con 4 segmentos, "Severa" y ">90 dias"
   cian reglas distintas y el semaforo de mora no cuadraba con el flag de
    riesgo.
-#}

{% macro bucket_mora(col_dias) %}
  case
    when {{ col_dias }} is null                        then 'Sin dato'
    when {{ col_dias }} = 0                            then '0 - Al dia'
    when {{ col_dias }} between  1 and 30               then '1-30 - Leve'
    when {{ col_dias }} between 31 and 60               then '31-60 - Moderada'
    when {{ col_dias }} between 61 and {{ var('dias_atraso_umbral') }}
                                                            then '61-90 - Severa'
    when {{ col_dias }} >  {{ var('dias_atraso_umbral') }}
                                                            then '90+ - Critica'
  end
{% endmacro %}


{% macro mora_es_vigente(col_dias) %}
{#- Regla de negocio del flag de riesgo. Se define UNA vez, junto al bucket, para
    que "mora vigente" y "bucket Critica" no puedan quedar desalineados. -#}
  coalesce({{ col_dias }}, 0) > {{ var('dias_atraso_umbral') }}
{% endmacro %}


{% macro ltv_pct(saldo, avaluo) %}
{#- Loan to value. Proporcion del credito cubierta por el valor del inmueble.
    Valores de referencia para el negocio: < 40% holgado, 40-70% razonable,
    > 80% sobre-garantizado (el banco esta-proxy del valor del bien). -#}
  case
    when {{ avaluo }} is null or {{ avaluo }} = 0 then null
    when {{ saldo }}   is null                     then null
    else round(cast({{ saldo }} as decimal(18,4)) / cast({{ avaluo }} as decimal(18,4)), 4)
  end
{% endmacro %}


{% macro nivel_sobregarantizacion(ltv) %}
  case
    when {{ ltv }} is null                then 'Sin dato'
    when {{ ltv }} <  0.40                then 'Holgado  (<40%)'
    when {{ ltv }} <= 0.70                then 'Razonable (40-70%)'
    when {{ ltv }} <= 0.80                then 'Ajustado  (70-80%)'
    else                                      'Sobre-garantizado (>80%)'
  end
{% endmacro %}
