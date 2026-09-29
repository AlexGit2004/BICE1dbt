with source as (
    select * from {{ source('bronze', 'mysql_tipo_identificacion') }}
),

renamed as (
    select
        cast(tipo_id as smallint) as tipo_id,
        {{ limpiar_texto('nombre_tipo') }} as nombre_tipo,
        _airbyte_extracted_at,
        _airbyte_raw_id
    from source
),

deduplicated as (
    select *,
        row_number() over (
            partition by tipo_id
            order by _airbyte_extracted_at desc nulls last,
                     _airbyte_raw_id desc nulls last
        ) as _rn
    from renamed
)

select tipo_id, nombre_tipo
from deduplicated
where _rn = 1