with source as (
    select * from {{ source('bronze', 'pgsql_categoria_delito') }}
),

renamed as (
    select
        cast(categoria_delito_id as integer) as categoria_delito_id,
        {{ limpiar_texto('nombre_categoria') }} as nombre_categoria,
        _airbyte_extracted_at,
        _airbyte_raw_id
    from source
),

deduplicated as (
    select *,
        row_number() over (
            partition by categoria_delito_id
            order by _airbyte_extracted_at desc nulls last,
                     _airbyte_raw_id desc nulls last
        ) as _rn
    from renamed
)

select categoria_delito_id, nombre_categoria
from deduplicated where _rn = 1