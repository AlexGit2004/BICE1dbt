{#-
    int_riesgo_cliente.sql
    Consolidacion de riesgo por cliente, una fila por cliente.

    Reune en UNA sola fila lo que cuatro fuentes distintas dicen del mismo
    cliente. Sin esto, cada tablero recalcula el riesgo con su propia formula y
    el mismo cliente aparece con dos puntajes distintos en dos reportes.

    Grano: una fila por cliente del maestro F1 (56.400).
-#}

{{ config(materialized='table') }}

with ident as (

    select * from {{ ref('int_identidad_resuelta') }}

),

-- --- F3: central de riesgos ---------------------------------------------
-- La fuente trae 40.000 deudores, uno por identidad, y el score y la deuda se
-- cuelgan de deudor_id. Se conserva deudor_id en el CTE para poder unir
-- score y deuda por ahi: si se agrupara solo por identidad, deudor_id
-- desapareceria y los dos joins siguientes no tendrian con que enlazar.
deudor as (

    select
        deudor_id,
        numero_identificacion  as ci_canonico,
        tipo_persona           as tipo_persona_cr,
        cantidad_instituciones_acreedor
                                as instituciones_acreedoras,
        monto_total_deuda_bs   as monto_deuda_cr,
        fecha_ultima_consulta
    from {{ ref('stg_f3__deudor_central_riesgos') }}
    where numero_identificacion is not null

),

score as (

    -- deudor ya expone la identidad como ci_canonico, no como
    -- numero_identificacion: dentro de un CTE no se puede volver a pedir la
    -- columna con el nombre que tenia en la tabla de origen.
    select
        d.ci_canonico,
        s.categoria_riesgo,
        s.score_morosidad,
        s.fecha_calculo
    from {{ ref('stg_f3__score_riesgo_cr') }} s
    join deudor d
      on s.deudor_id = d.deudor_id
    where d.ci_canonico is not null

),

-- si el score llegara duplicado, se toma el mas reciente: el vigente es el
-- ultimo calculado, no el promedio historico.
score_ultimo as (

    select
        ci_canonico,
        categoria_riesgo,
        score_morosidad,
        fecha_calculo,
        row_number() over (partition by ci_canonico
                           order by fecha_calculo desc) as rn
    from score

),

-- --- F2: antecedentes penales -------------------------------------------
antecedentes as (

    select
        numero_identificacion as ci_canonico,
        max(cantidad_procesos_activos)         as procesos_activos,
        max(cantidad_sentencias_condenatorias)  as sentencias_condenatorias,
        -- tiene_antecedentes_penales llega como 0/1 (NUMBER), no como
        -- BOOLEAN: en Snowflake un 1 no es true. Se compara contra 1 y el
        -- resultado se castea a BOOLEAN recien ahi.
        max(case when tiene_antecedentes_penales = 1 then 1 else 0 end)
            as flag_antecedentes
    from {{ ref('stg_f2__consolidado_antecedentes') }}
    where numero_identificacion is not null
    group by 1

),

delito_grave as (

    select
        pp.numero_identificacion as ci_canonico,
        count(distinct td.nombre_delito) as delitos_distintos,
        min(td.nombre_delito)            as delito_ejemplo
    from {{ ref('stg_f2__proceso_penal') }} pp
    join {{ ref('stg_f2__tipo_delito') }} td
      on pp.tipo_delito_id = td.tipo_delito_id
    where pp.numero_identificacion is not null
    group by 1

),

-- --- F6: historial financiero externo -----------------------------------
externo as (

    select
        numero_identificacion as ci_canonico,
        count(*)              as productos_externos,
        max(saldo_actual)    as saldo_externo,
        sum(saldo_actual)    as saldo_externo_total,
        max(dias_mora)       as dias_mora_externo,
        max(calificacion_asfi) as calificacion_asfi
    from {{ ref('stg_f6__historial_financiero_externo') }}
    where numero_identificacion is not null
    group by 1

),

-- --- F4: tributario (solo juridicas) -------------------------------------
-- OJO: empresa_id de F4 es una clave sustituta (1, 2, 3...) y NO es el NIT.
-- Medido: 0 de 10.152 juridicas de F1 coinciden con empresa_id de F4, pero
-- 10.150 coinciden con nit_empresa de F4. El union correcto es por NIT.
empresa as (

    select
        empresa_id,
        nit_empresa
    from {{ ref('stg_f4__empresa_registro_mercantil') }}
    where nit_empresa is not null

),

tributario as (

    select
        e.nit_empresa,
        max(t.estado_tributario)            as estado_tributario,
        sum(t.monto_impuestos_adeudados_bs) as impuestos_adeudados
    from {{ ref('stg_f4__situacion_tributaria_rm') }} t
    join empresa e on t.empresa_id = e.empresa_id
    group by 1

)

select
    i.cliente_id,
    i.ci_canonico,
    i.es_persona_juridica,

    -- --- F3
    d.deudor_id             as deudor_id_cr,
    d.tipo_persona_cr,
    d.instituciones_acreedoras,
    d.monto_deuda_cr,
    d.fecha_ultima_consulta,
    s.categoria_riesgo              as categoria_riesgo_origen,
    s.score_morosidad,
    s.fecha_calculo                 as fecha_score,

    -- La categoria del proveedor, estandarizada a un vocabulario propio.
    -- NO se recalcula desde el score: en esta fuente categoria y score son
    -- independientes (el promedio de score da ~650 en las cinco categorias).
    -- Ver la nota completa en macros/bucket_mora.sql.
    {{ categoria_riesgo('s.score_morosidad', 's.categoria_riesgo') }}
                                    as categoria_riesgo,
    -- el score se conserva en su escala real (350-950, ASFI), no 0-100
    {{ nivel_score_morosidad('s.score_morosidad') }}
                                    as nivel_por_score,

    -- --- F2
    a.procesos_activos,
    a.sentencias_condenatorias,
    a.flag_antecedentes,
    dg.delitos_distintos,
    dg.delito_ejemplo,

    -- --- F6
    x.productos_externos,
    x.saldo_externo,
    x.saldo_externo_total,
    x.dias_mora_externo,
    x.calificacion_asfi,

    -- --- F4
    t.estado_tributario,
    t.impuestos_adeudados

from ident i
left join deudor d      on i.ci_canonico = d.ci_canonico
left join score_ultimo s
       on i.ci_canonico = s.ci_canonico and s.rn = 1
left join antecedentes a on i.ci_canonico = a.ci_canonico
left join delito_grave dg on i.ci_canonico = dg.ci_canonico
left join externo x      on i.ci_canonico = x.ci_canonico
-- el tributario se une por NIT: unirlo por empresa_id daria 0 filas, porque
-- empresa_id de F4 es una clave sustituta y no el NIT de la empresa.
left join tributario t
       on i.es_persona_juridica
      and t.nit_empresa = i.nit_empresa
