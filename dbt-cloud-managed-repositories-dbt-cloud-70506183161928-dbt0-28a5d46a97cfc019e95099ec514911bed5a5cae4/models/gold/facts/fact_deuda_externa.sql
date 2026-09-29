{{ config(materialized='table', unique_key='deuda_id') }}

{#-
    fact_deuda_externa.sql  (NUEVO)  *** REGLA 3 RESUELTA ***

    "Conecta dim_entidad a fact_riesgo o fact_cliente_360 mediante entidad_key
     para analizar la deuda por institucion acreedora"

    ESTA ES LA FACT QUE LE SACA EL STATUS DE HUERFANA A dim_entidad
    ---------------------------------------------------------------------------
    Grano: 1 fila = 1 deudor x 1 entidad acreedora x 1 fecha de consulta.

    La razon por la que no existia antes es precisa: int_riesgo_central hacia
    GROUP BY numero_identificacion y descartaba entidad_financiera_id al
    agregar. Al tirar la granularidad mas fina, la dimension se quedaba sin
    hechos. Ahora la agregacion a nivel de cliente vive en
    int_deuda_externa_cliente, y este modelo conserva el grano fino.

    QUE PERMITE RESPONDER, que antes no se podia
      - "de cuanto estoy expuesto en cada banco?"
      - "en que institucion financiera se concentra mi cartera de riesgo?"
      - "la mora externa que reporta cada acreedor es comparable entre bancos?"
        (para eso esta factor_prioridad_cobro en dim_entidad: una cooperativa
         micro y un banco no reportan igual)
-#}

with f as (
    select * from {{ ref('int_riesgo_central') }}
),

-- El peso de la institucion en el score combinado del cliente: ponderar la
-- deuda externa por la calidad del acreedor es mas honesto que sumar todo igual.
cat as (
    select
        d.tipo_entidad_id,
        d.nombre_entidad,
        d.tipo_entidad,
        d.factor_prioridad_cobro
    from {{ ref('dim_entidad') }} d
)

select
    f.deuda_id,

    -- ===== FKs =====
    -- LA FK QUE LE DA VIDA A dim_entidad
    {{ dbt_utils.generate_surrogate_key(['f.entidad_id']) }}            as entidad_key,
    {{ dbt_utils.generate_surrogate_key(['f.numero_id_hash']) }}        as cliente_key,
    -- rol de fecha: la fecha de consulta del buro
    cast(to_char(f.fecha_consulta, 'YYYYMMDD') as integer)              as fecha_consulta_key,
    -- rol de fecha: cuando se origino la obligacion
    cast(to_char(f.fecha_originacion, 'YYYYMMDD') as integer)            as fecha_originacion_key,

    -- ===== business keys =====
    f.deudor_id,
    f.entidad_id,
    f.numero_identificacion                                           as cliente_id,
    f.numero_id_hash,
    f.categoria_riesgo,
    f.tipo_obligacion,
    f.tipo_persona,

    -- ===== MEDIDAS =====
    f.monto_deuda_actual_bs,
    f.dias_atraso_actual,
    f.score_morosidad,
    {{ bucket_mora('f.dias_atraso_actual') }}                            as bucket_mora_externa,

    -- ===== MEDIDAS DERIVADAS =====
    -- saldo ponderado por la calidad del acreedor: una deuda con un banco pesa
    -- mas que la misma deuda con una cooperativa micro
    round(f.monto_deuda_actual_bs * coalesce(c.factor_prioridad_cobro, 0.5), 2)
                                                                     as saldo_ponderado_bs,
    -- antiguedad de la obligacion, para separar deuda vieja de deuda fresca
    datediff('day', f.fecha_originacion, f.fecha_consulta)               as antiguedad_deuda_dias,
    case
        when f.dias_atraso_actual = 0                             then 'Al dia'
        when f.dias_atraso_actual <= 30                           then 'Leve'
        when f.dias_atraso_actual <= 90                           then 'Moderada'
        else                                                           'Critica'
    end                                                               as situacion_mora_externa,
    -- la obligacion mas antigua y la mas reciente del acreedor
    min(f.fecha_originacion) over (partition by f.deudor_id)            as primera_obligacion_deudor,
    max(f.fecha_originacion) over (partition by f.deudor_id)            as ultima_obligacion_deudor,

    c.nombre_entidad,
    c.tipo_entidad,
    c.factor_prioridad_cobro,

    f.fecha_consulta,
    f.fecha_originacion
from f
left join cat c on c.tipo_entidad_id = f.entidad_id
