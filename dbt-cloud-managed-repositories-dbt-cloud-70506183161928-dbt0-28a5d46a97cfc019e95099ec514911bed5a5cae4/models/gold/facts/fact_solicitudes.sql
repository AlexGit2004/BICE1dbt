{{ config(materialized='table', unique_key='solicitud_id') }}

{#-
    fact_solicitudes.sql  (CORREGIDO)  *** P-02 RESUELTO ***

    ANTES: motivo_rechazo y categoria_rechazo decian "NO APLICA" en las 20.000
    solicitudes, porque tipo_rechazo_id era cast(null as smallint) y el
    catalogo tipo_rechazo no lo referenciaba nadie.

    AHORA: tipo_rechazo_key es una FK REAL a dim_tipo_rechazo, y el catalogo
    pasa a ser una dimension con hechos que la usan.
-#}

with s as (
    select * from {{ ref('stg_mysql__solicitud_credito') }}
),

cu as (
    select
        cliente_id_legacy,
        numero_identificacion,
        numero_id_hash
    from {{ ref('int_clientes_unificados') }}
)

select
    s.solicitud_id,

    -- ===== FKs =====
    {{ dbt_utils.generate_surrogate_key(['cu.numero_identificacion']) }} as cliente_key,
    {{ dbt_utils.generate_surrogate_key(['s.producto_id']) }}             as producto_key,
    -- [2] LA FK QUE NO EXISTIA. Ahora dim_tipo_rechazo tiene hechos.
    {{ dbt_utils.generate_surrogate_key(['s.tipo_rechazo_id']) }}         as tipo_rechazo_key,
    cast(to_char(s.fecha_solicitud, 'YYYYMMDD') as integer)              as fecha_solicitud_key,

    -- ===== business keys =====
    cu.numero_identificacion                                              as cliente_id,
    cu.numero_id_hash                                                     as cliente_numero_id_hash,
    s.producto_id,
    s.tipo_rechazo_id,

    -- ===== MEDIDAS =====
    s.monto_solicitado_bs,
    s.plazo_solicitado_meses,
    -- monto anualizado, para comparar solicitudes de plazos distintos
    case when s.plazo_solicitado_meses > 0
         then round(s.monto_solicitado_bs / s.plazo_solicitado_meses * 12, 2)
    end                                                                   as monto_anualizado_bs,

    -- ===== ESTADO Y MOTIVO =====
    s.estado_solicitud,
    s.fue_rechazada,
    tr.nombre_motivo                                                      as motivo_rechazo,
    tr.categoria                                                          as categoria_rechazo,
    tr.familia_motivo,
    tr.es_motivo_de_riesgo,

    -- ===== MEDIDAS DEL EMBUDO =====
    -- numeradores y denominadores del KPI de aprobacion, listos para medir
    case when upper(s.estado_solicitud) = 'APROBADA'      then 1 else 0 end as fue_aprobada,
    case when upper(s.estado_solicitud) = 'DESEMBOLSADA'  then 1 else 0 end as fue_desembolsada,
    case when upper(s.estado_solicitud) = 'CANCELADA'     then 1 else 0 end as fue_cancelada,
    -- dias desde la solicitud hasta hoy: el tiempo de respuesta de la entidad
    datediff('day', s.fecha_solicitud, current_date)                      as dias_antiguedad_solicitud,

    -- ===== calidad: el DDL garantiza que toda rechazada tiene motivo =====
    case when s.fue_rechazada and s.tipo_rechazo_id is null
         then true else false end                                         as rechazo_sin_motivo,

    s.fecha_solicitud
from s
left join cu on cu.cliente_id_legacy = s.cliente_id
left join {{ ref('dim_tipo_rechazo') }} tr
       on tr.tipo_rechazo_id = s.tipo_rechazo_id
