with source as (
    select * from {{ source('bronze', 'mysql_pago') }}
),

renamed as (
    select
        cast(pago_id               as bigint)   as pago_id,
        cast(prestamo_id           as bigint)   as prestamo_id,
        cast(fecha_pago            as date)     as fecha_pago,
        cast(numero_cuota          as integer)  as numero_cuota,
        cast(monto_pagado_bs       as decimal(12,2)) as monto_pagado_bs,
        cast(tipo_pago_id          as smallint) as tipo_pago_id,
        cast(dias_atraso_al_pago   as integer)  as dias_atraso_al_pago,
        {{ limpiar_texto('estado_pago') }} as estado_pago,
        _airbyte_extracted_at,
        _airbyte_raw_id
    from source
    where pago_id is not null
),

deduplicated as (
    select *,
        row_number() over (
            partition by pago_id
            order by _airbyte_extracted_at desc nulls last,
                     _airbyte_raw_id desc nulls last
        ) as _rn
    from renamed
)

select
    pago_id, prestamo_id, fecha_pago, numero_cuota,
    monto_pagado_bs, tipo_pago_id, dias_atraso_al_pago, estado_pago
from deduplicated
where _rn = 1