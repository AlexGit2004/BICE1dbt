{{ config(materialized='table', unique_key='prestamo_id') }}

{#-
    fact_prestamos.sql  (CORREGIDO)  *** P-01 RESUELTO ***
    ESTADO_PRESTAMO_KEY antes era hash(NULL) en el 100% de las filas.

    QUE CAMBIA
      1. La FK a dim_cliente se construye desde el CI/NIT, NO desde el id
         generico de F1. Es el cambio que exige la consigna.
      2. estado_prestamo_key sale de la FK real de la fuente.
      3. Las dos fechas van por ROL: origenacion y vencimiento. Nunca una
         fecha_key a secas.
      4. Se anaden fecha_inicio_gracia y dias_vigencia, que salen de la fecha
         real de vencimiento y permiten el KPI de "cartera por vencer".
-#}

with p as (
    select * from {{ ref('int_prestamos_limpios') }}
),

cu as (
    select
        cliente_id_legacy,
        numero_identificacion,
        numero_id_hash
    from {{ ref('int_clientes_unificados') }}
)

select
    -- ===== PK natural del hecho =====
    p.prestamo_id,

    -- ===== FKs de la estrella (surrogadas) =====
    {{ dbt_utils.generate_surrogate_key(['cu.numero_identificacion']) }} as cliente_key,
    {{ dbt_utils.generate_surrogate_key(['p.producto_id']) }}            as producto_key,
    {{ dbt_utils.generate_surrogate_key(['p.agencia_id']) }}             as agencia_key,
    -- la FK de estado deja de ser NULL (P-01)
    {{ dbt_utils.generate_surrogate_key(['p.estado_prestamo_tipo_id']) }} as estado_prestamo_key,

    -- ===== ROLES DE FECHA: 2 FKs distintas a la MISMA dimension =====
    cast(to_char(p.fecha_originacion, 'YYYYMMDD') as integer)           as fecha_originacion_key,
    cast(to_char(p.fecha_vencimiento, 'YYYYMMDD') as integer)           as fecha_vencimiento_key,

    -- ===== business keys, para trazabilidad y para el BI =====
    cu.numero_identificacion                                          as cliente_id,
    cu.numero_id_hash                                                 as cliente_numero_id_hash,
    p.producto_id,
    p.agencia_id,
    p.estado_prestamo_tipo_id,
    p.solicitud_id,

    -- ===== MEDIDAS =====
    p.monto_aprobado_bs,
    p.saldo_actual_bs,
    p.cuota_mensual_bs,
    p.tasa_interes_aplicada,
    p.plazo_aprobado_meses,
    p.dias_atraso,
    p.bucket_mora,
    p.mora_vigente,

    -- ===== atributos DEGENERADOS de la solicitud (1:1 con el prestamo) =====
    p.monto_solicitado_bs,
    p.plazo_solicitado_meses,
    p.estado_solicitud,
    p.tipo_rechazo_id,
    -- diferencia entre lo pedido y lo entregado: el KPI de "recorte de plazo"
    case when p.monto_solicitado_bs > 0
         then round((p.monto_solicitado_bs - p.monto_aprobado_bs)
                    / p.monto_solicitado_bs, 4)
    end                                                               as pct_rechazo_monto,

    -- ===== MEDIDAS DE TIEMPO, derivadas de la fecha REAL de vencimiento =====
    datediff('day', p.fecha_originacion, p.fecha_vencimiento)          as dias_vigencia,
    datediff('day', current_date,     p.fecha_vencimiento)            as dias_para_vencer,
    case when datediff('day', current_date, p.fecha_vencimiento) between 0 and 30
         then true else false end                                     as vence_este_mes,

    -- ===== calidad =====
    p.vencimiento_calculado
from p
left join cu on cu.cliente_id_legacy = p.cliente_id
