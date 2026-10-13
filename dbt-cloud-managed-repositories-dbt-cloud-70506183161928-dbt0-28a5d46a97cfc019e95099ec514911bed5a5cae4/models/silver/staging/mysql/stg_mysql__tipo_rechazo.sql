with source as (
    select * from {{ source('bronze', 'mysql_tipo_rechazo') }}
),

renamed as (
    select
        cast(tipo_rechazo_id as smallint) as tipo_rechazo_id,
        {{ limpiar_texto('nombre_motivo') }} as nombre_motivo,
        {{ limpiar_texto('categoria', 'NO APLICA') }} as categoria,
        _airbyte_extracted_at,
        _airbyte_raw_id
    from source
),

deduplicated as (
    select *,
        row_number() over (
            partition by tipo_rechazo_id
            order by _airbyte_extracted_at desc nulls last,
                     _airbyte_raw_id desc nulls last
        ) as _rn
    from renamed
)

select tipo_rechazo_id, nombre_motivo, categoria
from deduplicated
where _rn = 1