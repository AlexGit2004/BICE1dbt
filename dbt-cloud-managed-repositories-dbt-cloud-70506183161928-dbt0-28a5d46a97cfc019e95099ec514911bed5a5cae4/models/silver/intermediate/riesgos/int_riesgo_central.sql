{{ config(materialized='table') }}

{#-
    int_riesgo_central.sql  (CORESCRITO)  *** MODELO MAESTRA DE F3 ***

    REGLA 3: "Conecta dim_entidad a fact_riesgo o fact_cliente_360 mediante
    entidad_key para analisar la deuda por institucion acreedora".

    ANTES: este modelo hacia GROUP BY numero_identificacion y tiraba la
    granularidad mas fina (deudor x entidad financiera). resultado: la
    dimension dim_entidad no la referenciaba ninguna fact y quedaba huerfana.

    AHORA: este modelo DEJA de agregar y pasa a ser la fuente de la fact
    fact_deuda_externa, con el grano correcto: deudor x entidad x fecha. La
    agregacion a nivel de cliente se hace aparte, en int_cliente_flags_riesgo,
    porque son dos preguntas distintas:
      - "cuanta deuda tiene este cliente"      -> agregado por cliente
      - "en que bancos esta debe y cuanto"      -> grano fino, con entidad
-#}

with d as (
    select * from {{ ref('stg_server__deudor_central_riesgos') }}
),

deu as (
    select * from {{ ref('stg_server__deuda_cr') }}
),

sc as (
    select * from {{ ref('stg_server__score_riesgo_cr') }}
),

deudor_hash as (
    select
        {{ hash_pii( normalizar_identidad('numero_identificacion') ) }} as numero_id_hash,
        {{ normalizar_identidad('numero_identificacion') }}             as numero_identificacion_norm,
        deudor_id,
        tipo_persona,
        cantidad_instituciones_acreedor
    from d
),

-- El grano FINO se conserva: 1 fila = 1 deudor x 1 entidad acreedora.
deuda_por_entidad as (
    select
        dh.numero_id_hash,
        dh.numero_identificacion_norm                                   as numero_identificacion,
        dh.deudor_id,
        dh.tipo_persona,
        -- [4] LA FK QUE ANTES SE PERDIA. Sin esto dim_entidad es huerfana.
        de.tipo_entidad_financiera_id                                   as entidad_id,
        de.deuda_id,
        de.tipo_obligacion,
        de.monto_deuda_actual_bs,
        de.dias_atraso_actual,
        de.fecha_originacion,
        de.fecha_consulta
    from deudor_hash dh
    join deu de on de.deudor_id = dh.deudor_id
),

-- El score es 1:1 con el deudor. Se une una sola vez, antes de agregar.
score_por_deudor as (
    select
        deudor_id,
        categoria_riesgo,
        score_morosidad,
        fecha_calculo
    from sc
)

select
    de.numero_id_hash,
    de.numero_identificacion,
    de.deudor_id,
    de.tipo_persona,
    de.entidad_id,
    de.deuda_id,
    de.tipo_obligacion,
    de.monto_deuda_actual_bs,
    de.dias_atraso_actual,
    de.fecha_originacion,
    de.fecha_consulta,
    s.categoria_riesgo,
    s.score_morosidad,
    s.fecha_calculo
from deuda_por_entidad de
left join score_por_deudor s on s.deudor_id = de.deudor_id
