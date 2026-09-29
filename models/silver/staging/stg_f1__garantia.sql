-- =============================================================================
-- stg_f1__garantia
-- Fuente: CBRONZE.MS1_GARANTIA
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
        cast(garantia_id as number(38,0)) as garantia_id,
        cast(prestamo_id as number(38,0)) as prestamo_id,
        {{ limpiar_codigo('tipo_garantia') }} as tipo_garantia,
        {{ limpiar_texto('descripcion_bien') }} as descripcion_bien,
        cast(valor_avaluo_bs as number(18,2)) as valor_avaluo_bs,
        try_to_date(fecha_avaluo) as fecha_avaluo,
        cast(cobertura_prestamo_porcentaje as number(18,2)) as cobertura_prestamo_porcentaje,
        {{ limpiar_codigo('estado_garantia') }} as estado_garantia
    from {{ source('bronze', 'ms1_garantia') }}

)

select
        cast(garantia_id as number(38,0)) as garantia_id,
        cast(prestamo_id as number(38,0)) as prestamo_id,
        {{ limpiar_codigo('tipo_garantia') }} as tipo_garantia,
        {{ limpiar_texto('descripcion_bien') }} as descripcion_bien,
        cast(valor_avaluo_bs as number(18,2)) as valor_avaluo_bs,
        try_to_date(fecha_avaluo) as fecha_avaluo,
        cast(cobertura_prestamo_porcentaje as number(18,2)) as cobertura_prestamo_porcentaje,
        {{ limpiar_codigo('estado_garantia') }} as estado_garantia
from tipado
