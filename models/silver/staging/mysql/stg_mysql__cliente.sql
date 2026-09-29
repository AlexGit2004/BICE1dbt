with source as (
    select * from {{ source('bronze', 'mysql_cliente') }}
),

renamed as (
    select
        cast(cliente_id          as integer)  as cliente_id,
        cast(num_identificacion  as bigint)   as numero_identificacion,
        cast(tipo_id             as smallint) as tipo_id,
        {{ limpiar_texto('nombre_completo')  }} as nombre_completo,
        {{ limpiar_texto('apellido_paterno', '') }} as apellido_paterno,
        {{ limpiar_texto('apellido_materno', '') }} as apellido_materno,
        {{ limpiar_texto('estado_cliente')   }} as estado_cliente,
        cast(fecha_creacion      as date)     as fecha_creacion,
        _airbyte_extracted_at,
        _airbyte_raw_id
    from source
    where cliente_id is not null
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
    cliente_id,
    numero_identificacion,
    tipo_id,
    nombre_completo,
    apellido_paterno,
    apellido_materno,
    estado_cliente,
    fecha_creacion
from deduplicated
where _rn = 1
