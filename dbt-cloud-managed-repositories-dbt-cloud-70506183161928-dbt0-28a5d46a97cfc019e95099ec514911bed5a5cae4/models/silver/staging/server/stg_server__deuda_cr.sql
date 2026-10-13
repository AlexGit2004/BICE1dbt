with source as (
    select * from {{ source('bronze', 'server_deuda_cr') }}
),

renamed as (
    select
        cast(deuda_id as bigint) as deuda_id,
        cast(deudor_id as integer) as deudor_id,
        cast(ENTIDAD_FINANCIERA_ID as integer) as tipo_entidad_financiera_id,
        {{ limpiar_texto('tipo_obligacion', 'OTROS') }} as tipo_obligacion,
        cast(monto_deuda_actual_bs as decimal(14,2)) as monto_deuda_actual_bs,
        cast(dias_atraso_actual as integer) as dias_atraso_actual,
        cast(fecha_originacion as date) as fecha_originacion,
        current_date as fecha_consulta,             
        _airbyte_extracted_at,
        _airbyte_raw_id
    from source
),

deduplicated as (
    select *,
        row_number() over (
            partition by deuda_id
            order by _airbyte_extracted_at desc nulls last,
                     _airbyte_raw_id desc nulls last
        ) as _rn
    from renamed
)

select
    deuda_id, deudor_id, tipo_entidad_financiera_id, tipo_obligacion,
    monto_deuda_actual_bs, dias_atraso_actual, fecha_originacion,
    fecha_consulta
from deduplicated where _rn = 1