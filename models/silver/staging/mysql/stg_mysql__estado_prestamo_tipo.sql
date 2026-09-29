with source as (
    select * from {{ source('bronze', 'mysql_estado_prestamo_tipo') }}
),

renamed as (
    select
        cast(estado_prestamo_tipo_id as smallint) as estado_prestamo_tipo_id,
        {{ limpiar_texto('nombre_estado') }} as nombre_estado,
        _airbyte_extracted_at,
        _airbyte_raw_id
    from source
),

deduplicated as (
    select *,
        row_number() over (
            partition by estado_prestamo_tipo_id
            order by _airbyte_extracted_at desc nulls last,
                     _airbyte_raw_id desc nulls last
        ) as _rn
    from renamed
)

select estado_prestamo_tipo_id, nombre_estado
from deduplicated
where _rn = 1