{{ config(materialized='view') }}

{#-
    stg_mysql__solicitud_credito.sql  (CORREGIDO)
    REGLA 1: el catalogo tipo_rechazo DEBE estar conectado.

    QUE CAMBIA
      [2] tipo_rechazo_id: era  cast(null as smallint)  -> ahora lee la FK real
          que declara el DDL corregido. Con esto fact_solicitudes.motivo_rechazo
          y categoria_rechazo dejan de decir 'NO APLICA' en las 20.000 solicitudes,
          y dim_tipo_rechazo deja de ser el catalogo huerfano que era.

    El DDL garantiza que toda solicitud 'Rechazada' tenga motivo
    (chk_solicitud_rechazo_requerido), asi que aqui no hace falta un case de
    respaldo: si viene null, el dato esta mal en la fuente y debe fallar el test.
-#}

with source as (
    select * from {{ source('bronze', 'mysql_solicitud_credito') }}
),

renamed as (
    select
        cast(SOLICITUD_ID         as bigint)        as solicitud_id,
        cast(CLIENTE_ID           as integer)       as cliente_id,
        cast(PRODUCTO_ID          as smallint)      as producto_id,
        cast(FECHA_SOLICITUD      as date)          as fecha_solicitud,
        cast(MONTO_SOLICITADO_BS as decimal(14,2)) as monto_solicitado_bs,
        cast(PLAZO_SOLICITADO_MESES as integer)    as plazo_solicitado_meses,
        {{ limpiar_texto('ESTADO_SOLICITUD') }}    as estado_solicitud,
        -- [2] LA FK REAL. Antes era NULL.
        cast(TIPO_RECHAZO_ID      as smallint)      as tipo_rechazo_id,
        _airbyte_extracted_at,
        _airbyte_raw_id
    from source
    where solicitud_id is not null
),

deduplicated as (
    select *,
        row_number() over (
            partition by solicitud_id
            order by _airbyte_extracted_at desc nulls last,
                     _airbyte_raw_id        desc nulls last
        ) as _rn
    from renamed
)

select
    solicitud_id,
    cliente_id,
    producto_id,
    fecha_solicitud,
    monto_solicitado_bs,
    plazo_solicitado_meses,
    estado_solicitud,
    tipo_rechazo_id,          -- [2] ya no es NULL en las rechazadas
    -- flag derivado: permite el KPI de tasa de rechazo sin volver al catalogo
    case when estado_solicitud = 'Rechazada' then true else false end as fue_rechazada
from deduplicated
where _rn = 1
