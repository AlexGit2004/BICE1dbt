-- =============================================================================
-- stg_f1__producto_crediticio
-- Fuente: CBRONZE.MS1_PRODUCTO_CREDITICIO
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
        cast(producto_id as number(38,0)) as producto_id,
        {{ limpiar_texto('nombre_producto') }} as nombre_producto,
        {{ limpiar_codigo('tipo_producto') }} as tipo_producto,
        cast(tasa_interes_base as number(18,2)) as tasa_interes_base,
        cast(plazo_minimo_meses as number(38,0)) as plazo_minimo_meses,
        cast(plazo_maximo_meses as number(38,0)) as plazo_maximo_meses,
        cast(monto_minimo_bs as number(18,2)) as monto_minimo_bs,
        cast(monto_maximo_bs as number(18,2)) as monto_maximo_bs,
        {{ limpiar_codigo('estado_producto') }} as estado_producto
    from {{ source('bronze', 'ms1_producto_crediticio') }}

)

select
        cast(producto_id as number(38,0)) as producto_id,
        {{ limpiar_texto('nombre_producto') }} as nombre_producto,
        {{ limpiar_codigo('tipo_producto') }} as tipo_producto,
        cast(tasa_interes_base as number(18,2)) as tasa_interes_base,
        cast(plazo_minimo_meses as number(38,0)) as plazo_minimo_meses,
        cast(plazo_maximo_meses as number(38,0)) as plazo_maximo_meses,
        cast(monto_minimo_bs as number(18,2)) as monto_minimo_bs,
        cast(monto_maximo_bs as number(18,2)) as monto_maximo_bs,
        {{ limpiar_codigo('estado_producto') }} as estado_producto
from tipado
