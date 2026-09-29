with source as (
    select * from {{ source('bronze', 'mysql_tipo_pago') }}
),

renamed as (
    select
        cast(tipo_pago_id as smallint) as tipo_pago_id,
        {{ limpiar_texto('nombre_tipo_pago') }} as nombre_tipo_pago,
        _airbyte_extracted_at,
        _airbyte_raw_id
    from source
),

deduplicated as (
    select *,
        row_number() over (
            partition by tipo_pago_id
            order by _airbyte_extracted_at desc nulls last,
                     _airbyte_raw_id desc nulls last
        ) as _rn
    from renamed
)

select tipo_pago_id, nombre_tipo_pago
from deduplicated
where _rn = 1