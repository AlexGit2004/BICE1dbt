with source as (
    select * from {{ source('bronze', 'mysql_producto_crediticio') }}
),

renamed as (
    select
        cast(producto_id           as smallint) as producto_id,
        {{ limpiar_texto('nombre_producto') }}  as nombre_producto,
        cast(tipo_prod_id          as smallint) as tipo_prod_id,
        cast(tasa_interes_base     as decimal(5,2)) as tasa_interes_base,
        cast(plazo_minimo_meses    as integer)  as plazo_minimo_meses,
        cast(plazo_maximo_meses    as integer)  as plazo_maximo_meses,
        cast(monto_minimo_bs       as decimal(14,2)) as monto_minimo_bs,
        cast(monto_maximo_bs       as decimal(14,2)) as monto_maximo_bs,
        {{ limpiar_texto('estado_producto') }} as estado_producto,
        _airbyte_extracted_at,
        _airbyte_raw_id
    from source
),

deduplicated as (
    select *,
        row_number() over (
            partition by producto_id
            order by _airbyte_extracted_at desc nulls last,
                     _airbyte_raw_id desc nulls last
        ) as _rn
    from renamed
)

select
    producto_id, nombre_producto, tipo_prod_id, tasa_interes_base,
    plazo_minimo_meses, plazo_maximo_meses, monto_minimo_bs,
    monto_maximo_bs, estado_producto
from deduplicated
where _rn = 1