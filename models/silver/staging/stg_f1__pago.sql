-- =============================================================================
-- stg_f1__pago
-- Fuente: CBRONZE.MS1_PAGO
-- Familia: F1 (MySQL - nucleo operacional)
-- Destino: CSILVER (view)
--
-- Staging NO decide nada de negocio. Su unico trabajo es:
--   1. traer la tabla tal cual,
--   2. tipar las fechas de forma explicita (try_to_date),
--   3. tipar los montos y los identificadores de forma explicita,
--   4. limpiar el texto con limpiar_texto / limpiar_codigo.
--
-- IMPORTANTE: el staging NO normaliza la identidad. La identidad canonica de
-- 9 digitos se resuelve mas abajo, en los int_ y en el macro
-- normalizar_identidad, porque la regla de negocio (y no el simple formateo)
-- es lo que debe quedar en una sola decision del proyecto.
-- =============================================================================

{{ config(materialized='view') }}

with tipado as (

    select
        cast(pago_id as number(38,0)) as pago_id,
        cast(prestamo_id as number(38,0)) as prestamo_id,
        cast(cliente_id as number(38,0)) as cliente_id,
        try_to_date(fecha_pago) as fecha_pago,
        cast(monto_pagado_bs as number(18,2)) as monto_pagado_bs,
        cast(numero_cuota as number(38,0)) as numero_cuota,
        cast(dias_atraso_al_pago as number(38,0)) as dias_atraso_al_pago,
        {{ limpiar_codigo('tipo_pago') }} as tipo_pago,
        {{ limpiar_codigo('estado_pago') }} as estado_pago
    from {{ source('bronze', 'ms1_pago') }}

)

select
        cast(pago_id as number(38,0)) as pago_id,
        cast(prestamo_id as number(38,0)) as prestamo_id,
        cast(cliente_id as number(38,0)) as cliente_id,
        try_to_date(fecha_pago) as fecha_pago,
        cast(monto_pagado_bs as number(18,2)) as monto_pagado_bs,
        cast(numero_cuota as number(38,0)) as numero_cuota,
        cast(dias_atraso_al_pago as number(38,0)) as dias_atraso_al_pago,
        {{ limpiar_codigo('tipo_pago') }} as tipo_pago,
        {{ limpiar_codigo('estado_pago') }} as estado_pago
from tipado
