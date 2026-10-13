with source as (
    select * from {{ source('bronze', 'mysql_agencia') }}
),

renamed as (
    select
        cast(agencia_id      as smallint) as agencia_id,
        {{ limpiar_texto('nombre_agencia') }} as nombre_agencia,
        {{ limpiar_texto('codigo_agencia') }} as codigo_agencia,
        cast(depto_id        as smallint) as depto_id,
        {{ limpiar_texto('tipo_agencia') }}   as tipo_agencia,
        {{ limpiar_texto('estado_agencia') }} as estado_agencia,
        _airbyte_extracted_at,
        _airbyte_raw_id
    from source
),

deduplicated as (
    select *,
        row_number() over (
            partition by agencia_id
            order by _airbyte_extracted_at desc nulls last,
                     _airbyte_raw_id desc nulls last
        ) as _rn
    from renamed
)

select agencia_id, nombre_agencia, codigo_agencia, depto_id,
       tipo_agencia, estado_agencia
from deduplicated
where _rn = 1