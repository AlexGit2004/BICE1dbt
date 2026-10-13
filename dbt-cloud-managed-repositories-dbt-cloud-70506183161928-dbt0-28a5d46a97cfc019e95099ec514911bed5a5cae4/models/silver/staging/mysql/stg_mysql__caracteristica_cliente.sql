with source as (
    select * from {{ source('bronze', 'mysql_caracteristica_cliente') }}
),

renamed as (
    select
        cast(CARAC_ID as bigint)   as caracteristica_id,
        cast(cliente_id as integer) as cliente_id,
        cast(fecha_nacimiento as date) as fecha_nacimiento,
        {{ limpiar_texto('sexo', 'N/A') }} as sexo,
        {{ limpiar_texto('estado_civil', 'N/A') }} as estado_civil,
        {{ limpiar_texto('nacionalidad', 'NO ESPECIFICADA') }} as nacionalidad,
        {{ limpiar_texto('profesion', 'NO ESPECIFICADA') }} as profesion,
        _airbyte_extracted_at,
        _airbyte_raw_id
    from source
),

deduplicated as (
    select *,
        row_number() over (
            partition by cliente_id
            order by _airbyte_extracted_at desc nulls last,
                     _airbyte_raw_id desc nulls last
        ) as _rn
    from renamed
)

select
    caracteristica_id,
    cliente_id,
    fecha_nacimiento,
    sexo,
    estado_civil,
    nacionalidad,
    profesion
from deduplicated
where _rn = 1
