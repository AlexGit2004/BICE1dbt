with source as (
    select * from {{ source('bronze', 'mysql_departamento') }}
),

renamed as (
    select
        cast(depto_id as smallint) as depto_id,
        {{ limpiar_texto('nombre_depto') }} as nombre_depto,
        _airbyte_extracted_at,
        _airbyte_raw_id
    from source
),

deduplicated as (
    select *,
        row_number() over (
            partition by depto_id
            order by _airbyte_extracted_at desc nulls last,
                     _airbyte_raw_id desc nulls last
        ) as _rn
    from renamed
)

select depto_id, nombre_depto
from deduplicated
where _rn = 1