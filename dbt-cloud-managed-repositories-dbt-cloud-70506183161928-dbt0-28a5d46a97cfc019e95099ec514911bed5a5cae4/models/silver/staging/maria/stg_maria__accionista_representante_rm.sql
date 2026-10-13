with source as (
    select * from {{ source('bronze', 'maria_accionista_representante_rm') }}
),

renamed as (
    select
        cast(PARTICIPANTE_ID as integer) as accionista_id,
        cast(empresa_id as integer) as empresa_id,
        cast(NUM_IDENTIFICACION as bigint) as numero_identificacion,
        {{ limpiar_texto('NOMBRE_COMPLETO', '') }} as nombre_accionista,
        {{ limpiar_texto('tipo_participacion', 'ACCIONISTA') }} as tipo_participacion,
        cast(porcentaje_participacion as decimal(5,2)) as porcentaje_participacion,
        _airbyte_extracted_at,
        _airbyte_raw_id
    from source
),

deduplicated as (
    select *,
        row_number() over (
            partition by accionista_id
            order by _airbyte_extracted_at desc nulls last,
                     _airbyte_raw_id desc nulls last
        ) as _rn
    from renamed
)

select
    accionista_id, empresa_id, numero_identificacion, nombre_accionista,
    tipo_participacion, porcentaje_participacion
from deduplicated where _rn = 1