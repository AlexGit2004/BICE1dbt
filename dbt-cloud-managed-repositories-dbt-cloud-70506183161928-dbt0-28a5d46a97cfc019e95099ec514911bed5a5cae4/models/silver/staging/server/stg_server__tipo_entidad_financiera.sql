with source as (
    select * from {{ source('bronze', 'server_tipo_entidad_financiera') }}
),

renamed as (
    select
        cast(TIPO_ENTIDAD_ID as integer) as tipo_entidad_financiera_id,
        {{ limpiar_texto('NOMBRE_TIPO') }} as nombre_tipo_entidad,
        _airbyte_extracted_at,
        _airbyte_raw_id
    from source
),

deduplicated as (
    select *,
        row_number() over (
            partition by tipo_entidad_financiera_id   
            order by _airbyte_extracted_at desc nulls last,
                     _airbyte_raw_id desc nulls last
        ) as _rn
    from renamed
)

select tipo_entidad_financiera_id, nombre_tipo_entidad
from deduplicated where _rn = 1