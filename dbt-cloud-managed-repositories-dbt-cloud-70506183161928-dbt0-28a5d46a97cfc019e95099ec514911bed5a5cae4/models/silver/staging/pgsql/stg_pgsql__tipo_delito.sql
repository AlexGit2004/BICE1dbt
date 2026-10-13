with source as (
    select * from {{ source('bronze', 'pgsql_tipo_delito') }}
),

renamed as (
    select
        cast(tipo_delito_id          as integer) as tipo_delito_id,
        cast(categoria_delito_id     as integer) as categoria_delito_id,
        {{ limpiar_texto('nombre_delito') }}     as nombre_delito,
        _airbyte_extracted_at,
        _airbyte_raw_id
    from source
),

deduplicated as (
    select *,
        row_number() over (
            partition by tipo_delito_id
            order by _airbyte_extracted_at desc nulls last,
                     _airbyte_raw_id desc nulls last
        ) as _rn
    from renamed
)

select tipo_delito_id, categoria_delito_id, nombre_delito
from deduplicated where _rn = 1