{#-
    bucket_mora.sql
    Reglas de negocio de mora y riesgo, materializadas UNA vez.

    El motivo de que vivan en un macro y no en cada .sql: el bucket de mora se
    usa en fact_prestamos (cartera) y en fact_pagos (cobranza). Duplicado, el
    dia que el negocio cambie un corte, un hecho cambia y el otro no, y el
    tablero de cobranza deja de cuadrar con el de cartera sin que nada falle.

    El corte de 90 dias no es arbitrario: es el mismo umbral que decide si un
    atraso se considera vigente. Bucket 'Critica' y flag tiene_mora_vigente
    tienen que ser la MISMA decision, no dos decisiones parecidas.
-#}

{% macro bucket_mora(col_dias) -%}
    case
        when {{ col_dias }} is null                        then 'Sin dato'
        when {{ col_dias }} <= 0                           then 'Al dia'
        when {{ col_dias }} <= {{ var('dias_mora_leve') }}        then 'Leve'
        when {{ col_dias }} <= {{ var('dias_mora_moderada') }}    then 'Moderada'
        when {{ col_dias }} <= {{ var('dias_mora_severa') }}      then 'Severa'
        else                                                      'Critica'
    end
{%- endmacro %}


{% macro mora_es_vigente(col_dias) -%}
    coalesce({{ col_dias }}, 0) > {{ var('umbral_mora_vigente') }}
{%- endmacro %}


{% macro categoria_riesgo(col_score, col_categoria) -%}
{#- ---------------------------------------------------------------------------
    MEDIDO: score_morosidad NO es una escala 0-100.
    ---------------------------------------------------------------------------
    Rango real en server3_score_riesgo_cr: 350 a 950, 601 valores distintos.
    Es la escala de calificacion ASFI, donde 350 es riesgo MINIMO y 950 riesgo
    MAXIMO: mas alto es mas riesgoso, al reves de un score de morosidad
    tipico donde mas alto es mejor.

    Peor: la columna categoria_riesgo del proveedor (Sin Riesgo / Bajo / Medio
    / Alto / Muy Alto) NO guarda relacion con el score. Medido sobre las
    40.000 filas: el promedio de score es 650.9 en 'Medio', 652.4 en 'Bajo',
    649.8 en 'Sin Riesgo', 650.8 en 'Alto' y 649.4 en 'Muy Alto'. Las cinco
    categorias tienen practicamente el mismo score.

    Es decir: en esta fuente, categoria y score son variables INDEPENDIENTES.
    Reclasificar por score destruiria la categoria que el proveedor si
    entrego, y es lo que paso al empezar: los cortes 40/70 sobre un valor de
    350-950 mandaban las 40.000 filas a 'Riesgo bajo', incluyendo las 3.251
    etiquetadas 'Muy Alto' por el proveedor.

    Decision: la categoria del proveedor es la que se respeta, y se
    ESTANDARIZA a un vocabulario propio para que el tablero no dependa de como
    lo escriba cada fuente. El score se conserva tal cual, con su rango real,
    y se usa solo para ordenar, nunca para reclasificar.

    El vocabulario estandar tiene 5 valores (Bajo, Medio, Alto, Muy alto,
    Sin dato). No se unifica a menos categorias porque el negocio necesita
    distinguir 'Sin Riesgo' de 'Bajo' y 'Alto' de 'Muy alto'.
-#}
    case
        when {{ col_categoria }} is null                       then 'Sin dato'
        when ({{ limpiar_codigo(col_categoria) }} in
              ('SIN RIESGO', 'SIN RIES GO', 'SIN RIESGO '))     then 'Bajo'
        when ({{ limpiar_codigo(col_categoria) }} in
              ('BAJO', 'RIESGO BAJO'))                        then 'Bajo'
        when ({{ limpiar_codigo(col_categoria) }} in
              ('MEDIO', 'RIESGO MEDIO'))                      then 'Medio'
        when ({{ limpiar_codigo(col_categoria) }} in
              ('ALTO', 'RIESGO ALTO'))                        then 'Alto'
        when ({{ limpiar_codigo(col_categoria) }} in
              ('MUY ALTO', 'RIESGO MUY ALTO', 'MUY ALTA'))     then 'Muy alto'
        else 'Sin dato'
    end
{%- endmacro %}


{% macro nivel_score_morosidad(col_score) -%}
{#- El score se mantiene en su escala real 350-950 y solo se ordena. Los cortes
    son de la escala ASFI, no de una escala 0-100. -#}
    case
        when {{ col_score }} is null                 then 'Sin dato'
        when {{ col_score }} <  450                  then 'Bajo'
        when {{ col_score }} <  650                  then 'Medio'
        when {{ col_score }} <  800                  then 'Alto'
        else                                             'Muy alto'
    end
{%- endmacro %}


{% macro ltv_pct(saldo, avaluo) -%}
{#- Loan to value: fraccion del credito que el avaluo del bien respalda.
    El avaluo de mas de var(avaluo_vigencia_max_anios) anos no se usa para
    decidir cobertura hoy: un avaluo de hace 5 anos describe un mercado que
    ya no existe. Por eso el macro tambien toma la fecha. -#}
    case
        when {{ avaluo }} is null or {{ avaluo }} = 0 then null
        when {{ saldo }}   is null                     then null
        else round(cast({{ saldo }} as decimal(18,2))
                 / cast({{ avaluo }} as decimal(18,2)), 4)
    end
{%- endmacro %}


{% macro nivel_cobertura(ltv) -%}
    case
        when {{ ltv }} is null            then 'Sin dato'
        when {{ ltv }} <= 0.40           then 'Holgado'
        when {{ ltv }} <= 0.70           then 'Razonable'
        when {{ ltv }} <= {{ var('ltv_maximo_aceptable') }} then 'Ajustado'
        else                                  'Sobre-garantizado'
    end
{%- endmacro %}


{% macro avaluo_vigente(fecha_avaluo) -%}
{#- Un avaluo deja de ser utilizable al superar la vigencia maxima en anos.
    Se usa date_diff con anos completos, no una resta de dias, para no marcar
    como vigente un avaluo de 2 anos y 11 meses. -#}
    case
        when {{ fecha_avaluo }} is null then null
        else datediff('year', {{ fecha_avaluo }}, '{{ var("fecha_corte") }}')::int
             <= {{ var('avaluo_vigencia_max_anios') }}
    end
{%- endmacro %}


{% macro capacidad_pago(ingreso, cuota, es_juridica) -%}
{#- Relacion cuota/ingreso. El limite depende de quien es el titular: una
    persona juridica tiene flujo de caja mas estable y admite un ratio mayor.
    El ingreso minimo se aplica solo a juridicas, porque el de una persona
    natural depende de su evaluacion individual. -#}
    case
        when {{ cuota }} is null or {{ ingreso }} is null or {{ ingreso }} = 0
            then null
        when {{ es_juridica }} and {{ ingreso }} < {{ var('ingreso_minimo_mensual_nit') }}
            then null
        else round(cast({{ cuota }} as decimal(18,2))
                 / cast({{ ingreso }} as decimal(18,2)), 4)
    end
{%- endmacro %}


{% macro capacidad_de_pago_suficiente(ratio, es_juridica) -%}
    case
        when {{ ratio }} is null then null
        when {{ es_juridica }} and {{ ratio }} <= {{ var('ratio_cuota_ingreso_nit') }}
            then true
        when not {{ es_juridica }} and {{ ratio }} <= {{ var('ratio_cuota_ingreso_ci') }}
            then true
        else false
    end
{%- endmacro %}
