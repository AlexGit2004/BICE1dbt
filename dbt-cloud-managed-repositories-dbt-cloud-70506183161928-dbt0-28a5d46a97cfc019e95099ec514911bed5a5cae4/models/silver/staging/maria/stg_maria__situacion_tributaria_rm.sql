with source as (
    select * from {{ source('bronze', 'maria_situacion_tributaria_rm') }}
),

renamed as (
    select
        cast(situacion_tributaria_id as bigint) as situacion_tributaria_id,
        cast(empresa_id as integer) as empresa_id,
        cast(anio_fiscal as integer) as anio_fiscal,
        {{ limpiar_texto('estado_tributario', 'DESCONOCIDO') }} as estado_tributario,
        coalesce(cast(IMPUESTOS_ADEUDADOS_BS as decimal(14,2)), 0) as monto_impuestos_adeudados_bs,
        cast(FECHA_ACTUALIZACION as date) as fecha_ultima_declaracion,
        _airbyte_extracted_at,
        _airbyte_raw_id
    from source
),

deduplicated as (
    select *,
        row_number() over (
            partition by situacion_tributaria_id
            order by _airbyte_extracted_at desc nulls last,
                     _airbyte_raw_id desc nulls last
        ) as _rn
    from renamed
)

select
    situacion_tributaria_id, empresa_id, anio_fiscal, estado_tributario,
    monto_impuestos_adeudados_bs, fecha_ultima_declaracion
from deduplicated where _rn = 1