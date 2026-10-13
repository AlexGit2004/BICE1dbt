{{ config(materialized='table') }}

{#-
    int_deuda_externa_cliente.sql  (NUEVO)

    REGLA 3: "Conecta dim_entidad a fact_riesgo o fact_cliente_360 mediante
    entidad_key para analisar la deuda por institucion acreedora".

    Este modelo hace las DOS mitades que antes no existian:
      1. El grano FINO por entidad (viene de int_riesgo_central) que alimenta
         fact_deuda_externa, y por lo tanto le da una fact a dim_entidad.
      2. El agregado por cliente que necesitan los flags de riesgo.

    La entidad PRINCIPAL es la de mayor saldo. Se elige con el mayor monto, no
    con la primera fila: "en que banco esta mas expuesto" es la pregunta que se
    hace el area de riesgo, y contestarla con la entidad arbitrariamente
  primera del alphabet seria mentira.
-#}

with fino as (
    -- grano: 1 fila = 1 deudor x 1 entidad acreedora x 1 fecha de consulta
    select * from {{ ref('int_riesgo_central') }}
),

-- La entidad con mayor exposicion por deudor.
principal as (
    select
        deudor_id,
        tipo_entidad_financiera_id,
        monto_deuda_actual_bs,
        row_number() over (
            partition by deudor_id
            order by coalesce(monto_deuda_actual_bs, 0) desc,
                     tipo_entidad_financiera_id
        ) as rn
    from fino
    where tipo_entidad_financiera_id is not null
)

select
    f.numero_id_hash,
    f.numero_identificacion,

    -- ===== medidas agregadas por cliente =====
    coalesce(sum(f.monto_deuda_actual_bs), 0)                  as deuda_total_externa_bs,
    coalesce(max(f.dias_atraso_actual), 0)                     as max_dias_atraso_externo,
    count(distinct f.deuda_id)                                  as total_obligaciones,
    count(distinct f.entidad_id)                                as num_entidades_acreedoras,
    -- el score es 1:1 con el deudor: se toma el max para que no se multiplique
    coalesce(max(f.score_morosidad), 100)                      as score_morosidad,
    max(f.categoria_riesgo)                                     as categoria_riesgo,
    -- p90 de la mora externa: mas informativo que el max, que se distorciona
    percentile_cont(0.90) within group (order by coalesce(f.dias_atraso_actual, 0))
                                                              as p90_dias_atraso_externo,
    count(distinct case when f.dias_atraso_actual > {{ var('dias_atraso_umbral') }}
                        then f.deuda_id end)                    as obligaciones_en_mora,

    -- ===== la entidad principal, que se expone en la dimension de cliente =====
    p.tipo_entidad_financiera_id                                as entidad_principal_id,
    p.monto_deuda_actual_bs                                     as monto_entidad_principal_bs,

    -- concentracion: cuanto de la deuda externa esta en la entidad principal.
    -- Alto = todo con un solo acreedor = sin capacidad de refinanciar.
    case when coalesce(sum(f.monto_deuda_actual_bs), 0) > 0
         then round(p.monto_deuda_actual_bs
                   / sum(f.monto_deuda_actual_bs), 3)
    end                                                          as concentracion_entidad
from fino f
left join principal p
       on p.deudor_id = f.deudor_id and p.rn = 1
group by 1, 2, 6, 7
