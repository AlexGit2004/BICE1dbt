with source as (
    select * from {{ source('bronze', 'mysql_solicitud_credito') }}
),

renamed as (
    select
        cast(solicitud_id            as bigint)   as solicitud_id,
        cast(cliente_id              as integer)  as cliente_id,
        cast(producto_id             as smallint) as producto_id,
        cast(fecha_solicitud         as date)     as fecha_solicitud,
        cast(monto_solicitado_bs     as decimal(14,2)) as monto_solicitado_bs,
        cast(plazo_solicitado_meses  as integer)  as plazo_solicitado_meses,
        {{ limpiar_texto('estado_solicitud') }}   as estado_solicitud,
        cast(tipo_rechazo_id         as smallint) as tipo_rechazo_id,
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
                     _airbyte_raw_id desc nulls last
        ) as _rn
    from renamed
)

select
    solicitud_id, cliente_id, producto_id, fecha_solicitud,
    monto_solicitado_bs, plazo_solicitado_meses,
    estado_solicitud, tipo_rechazo_id
from deduplicated
where _rn = 1