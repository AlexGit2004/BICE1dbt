with source as (
    select * from {{ source('bronze', 'maria_empresa_registro_mercantil') }}
),

renamed as (
    select
        cast(empresa_id as integer) as empresa_id,
        cast(NUM_IDENTIFICACION as bigint) as numero_identificacion,
        cast(tipo_empresa_id as smallint) as tipo_empresa_id,
        {{ limpiar_texto('razon_social') }} as razon_social,
        'OTROS' as categoria_comercial,               
        cast(FECHA_CONSTITUCION as date) as fecha_registro,
        'ACTIVA' as estado_empresa,                   
        _airbyte_extracted_at,
        _airbyte_raw_id
    from source
),

deduplicated as (
    select *,
        row_number() over (
            partition by empresa_id
            order by _airbyte_extracted_at desc nulls last,
                     _airbyte_raw_id desc nulls last
        ) as _rn
    from renamed
)

select
    empresa_id, numero_identificacion, tipo_empresa_id, razon_social,
    categoria_comercial, fecha_registro, estado_empresa
from deduplicated where _rn = 1