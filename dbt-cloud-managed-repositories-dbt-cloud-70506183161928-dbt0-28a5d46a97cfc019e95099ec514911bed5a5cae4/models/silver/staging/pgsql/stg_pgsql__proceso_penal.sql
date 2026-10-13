with source as (
    select * from {{ source('bronze', 'pgsql_proceso_penal') }}
),

renamed as (
    select
        cast(PROCESO_ID as integer) as proceso_penal_id,
        cast(NUM_IDENTIFICACION as bigint) as numero_identificacion,
        cast(tipo_delito_id as integer) as tipo_delito_id,
        cast(ESTADO_PROCESO_ID as integer) as estado_proceso_penal_id,
        cast(FECHA_INICIO_PROCESO as date) as fecha_inicio,
        cast(null as date) as fecha_sentencia,       
        '' as descripcion_breve,                     
        _airbyte_extracted_at,
        _airbyte_raw_id
    from source
),

deduplicated as (
    select *,
        row_number() over (
            partition by proceso_penal_id
            order by _airbyte_extracted_at desc nulls last,
                     _airbyte_raw_id desc nulls last
        ) as _rn
    from renamed
)

select
    proceso_penal_id, numero_identificacion, tipo_delito_id,
    estado_proceso_penal_id, fecha_inicio, fecha_sentencia,
    descripcion_breve
from deduplicated where _rn = 1