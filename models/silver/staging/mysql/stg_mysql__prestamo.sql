with source as (
    select * from {{ source('bronze', 'mysql_prestamo') }}
),

renamed as (
    select
        cast(prestamo_id               as bigint)   as prestamo_id,
        cast(solicitud_id              as bigint)   as solicitud_id,
        cast(cliente_id                as integer)  as cliente_id,
        cast(agencia_id                as smallint) as agencia_id,
        cast(fecha_originacion         as date)     as fecha_originacion,
        cast(monto_aprobado_bs         as decimal(14,2)) as monto_aprobado_bs,
        cast(plazo_aprobado_meses      as integer)  as plazo_aprobado_meses,
        cast(tasa_interes_aplicada     as decimal(5,2))  as tasa_interes_aplicada,
        cast(cuota_mensual_bs          as decimal(12,2)) as cuota_mensual_bs,
        cast(saldo_actual_bs           as decimal(14,2)) as saldo_actual_bs,
        cast(dias_atraso               as integer)  as dias_atraso,
        cast(estado_prestamo_tipo_id   as smallint) as estado_prestamo_tipo_id,
        cast(fecha_vencimiento         as date)     as fecha_vencimiento,
        _airbyte_extracted_at,
        _airbyte_raw_id
    from source
    where prestamo_id is not null
),

deduplicated as (
    select *,
        row_number() over (
            partition by prestamo_id
            order by _airbyte_extracted_at desc nulls last,
                     _airbyte_raw_id desc nulls last
        ) as _rn
    from renamed
)

select
    prestamo_id, solicitud_id, cliente_id, agencia_id,
    fecha_originacion, monto_aprobado_bs, plazo_aprobado_meses,
    tasa_interes_aplicada, cuota_mensual_bs, saldo_actual_bs,
    dias_atraso, estado_prestamo_tipo_id, fecha_vencimiento
from deduplicated
where _rn = 1