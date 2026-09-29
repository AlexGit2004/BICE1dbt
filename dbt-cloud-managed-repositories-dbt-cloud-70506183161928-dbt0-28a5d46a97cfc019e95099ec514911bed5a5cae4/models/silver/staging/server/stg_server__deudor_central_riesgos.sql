with source as (
    select * from {{ source('bronze', 'server_deudor_central_riesgos') }}
),

renamed as (
    select
        cast(deudor_id as integer) as deudor_id,
        cast(NUM_IDENTIFICACION as bigint) as numero_identificacion,
        '' as nombre_deudor,                          
        cast(1 as integer) as tipo_entidad_financiera_id,  
        coalesce(cast(cantidad_instituciones_acreedor as integer), 0) as cantidad_instituciones_acreedor,
        cast(0 as integer) as cantidad_obligaciones,  
        _airbyte_extracted_at,
        _airbyte_raw_id
    from source
    where num_identificacion is not null
),

deduplicated as (
    select *,
        row_number() over (
            partition by deudor_id
            order by _airbyte_extracted_at desc nulls last,
                     _airbyte_raw_id desc nulls last
        ) as _rn
    from renamed
)

select
    deudor_id, numero_identificacion, nombre_deudor,
    tipo_entidad_financiera_id, cantidad_instituciones_acreedor,
    cantidad_obligaciones
from deduplicated where _rn = 1