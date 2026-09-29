with source as (
    select * from {{ source('bronze', 'mysql_tipo_garantia') }}
),

renamed as (
    select
        cast(tipo_garantia_id as smallint) as tipo_garantia_id,
        {{ limpiar_texto('nombre_tipo_garantia') }} as nombre_tipo_garantia,
        _airbyte_extracted_at,
        _airbyte_raw_id
    from source
),

deduplicated as (
    select *,
        row_number() over (
            partition by tipo_garantia_id
            order by _airbyte_extracted_at desc nulls last,
                     _airbyte_raw_id desc nulls last
        ) as _rn
    from renamed
)

select tipo_garantia_id, nombre_tipo_garantia
from deduplicated
where _rn = 1