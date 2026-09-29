with source as (
    select * from {{ source('bronze', 'pgsql_estado_proceso_penal') }}
),

renamed as (
    select
        cast(ESTADO_PROCESO_ID as integer) as estado_proceso_penal_id,
        {{ limpiar_texto('nombre_estado') }} as nombre_estado,
        _airbyte_extracted_at,
        _airbyte_raw_id
    from source
),

deduplicated as (
    select *,
        row_number() over (
            partition by estado_proceso_penal_id
            order by _airbyte_extracted_at desc nulls last,
                     _airbyte_raw_id desc nulls last
        ) as _rn
    from renamed
)

select estado_proceso_penal_id, nombre_estado
from deduplicated where _rn = 1