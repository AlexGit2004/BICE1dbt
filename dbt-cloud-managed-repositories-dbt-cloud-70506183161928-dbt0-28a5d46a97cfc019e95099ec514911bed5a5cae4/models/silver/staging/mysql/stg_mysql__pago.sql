{{ config(materialized='view') }}

{#-
    stg_mysql__pago.sql  (CORREGIDO)
    REGLA 2: la fact de pagos tiene que poder colgar DIRECTAMENTE de dim_cliente.

    QUE CAMBIA
      [5] cliente_id: la columna EXISTIA en babsa_creditos.pago y silver la
          descartaba. Eso obligaba a que fact_pagos dedujera el cliente
          recorriendo dim_prestamo, y si el prestamo no existia la clave surrogada
          quedaba hasheada sobre NULL: todos los pagos huerfanos caian en un
          mismo cliente_key fantasma. Ahora el pago se une a dim_cliente por su
          propia FK, y un pago huerfano es detectable con un test, no invisible.
-#}

with source as (
    select * from {{ source('bronze', 'mysql_pago') }}
),

renamed as (
    select
        cast(PAGO_ID            as bigint)        as pago_id,
        cast(PRESTAMO_ID        as bigint)        as prestamo_id,
        -- [5] SE RECUPERA. Estaba en la BD y se perdia en silver.
        cast(CLIENTE_ID         as integer)       as cliente_id,
        cast(TIPO_PAGO_ID       as smallint)      as tipo_pago_id,
        cast(FECHA_PAGO         as date)          as fecha_pago,
        cast(NUMERO_CUOTA       as integer)       as numero_cuota,
        cast(MONTO_PAGADO_BS    as decimal(12,2)) as monto_pagado_bs,
        cast(DIAS_ATRASO_AL_PAGO as integer)      as dias_atraso_al_pago,
        {{ limpiar_texto('ESTADO_PAGO') }}       as estado_pago,
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
                     _airbyte_raw_id        desc nulls last
        ) as _rn
    from renamed
)

select
    pago_id,
    prestamo_id,
    cliente_id,          -- [5] recuperado
    tipo_pago_id,
    fecha_pago,
    numero_cuota,
    monto_pagado_bs,
    dias_atraso_al_pago,
    estado_pago
from deduplicated
where _rn = 1
