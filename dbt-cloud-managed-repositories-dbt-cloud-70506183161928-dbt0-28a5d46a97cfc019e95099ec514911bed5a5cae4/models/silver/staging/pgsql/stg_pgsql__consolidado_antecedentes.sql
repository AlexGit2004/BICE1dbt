with source as (
    select * from {{ source('bronze', 'pgsql_consolidado_antecedentes') }}
),

renamed as (
    select
        cast(NUM_IDENTIFICACION as bigint) as numero_identificacion,
        coalesce(cast(CANTIDAD_PROCESOS_ACTIVOS as integer), 0)          as cantidad_procesos_activos,
        cast(FECHA_ULTIMA_ACTUALIZACION as date)                          as fecha_ultima_actualizacion,
        coalesce(cast(TIENE_ANTECEDENTES_PENALES as boolean), false)      as tiene_antecedentes_penales,
        coalesce(cast(CANTIDAD_SENTENCIAS_CONDENATORIAS as integer), 0)   as cantidad_sentencias_condenatorias,
        _airbyte_extracted_at,
        _airbyte_raw_id
    from source
),

deduplicated as (
    select *,
        row_number() over (
            partition by numero_identificacion    -- en minusculas, el alias nuevo
            order by _airbyte_extracted_at desc nulls last,
                     _airbyte_raw_id desc nulls last
        ) as _rn
    from renamed
)

select
    numero_identificacion,
    cantidad_procesos_activos,
    fecha_ultima_actualizacion,
    tiene_antecedentes_penales,
    cantidad_sentencias_condenatorias
from deduplicated where _rn = 1
