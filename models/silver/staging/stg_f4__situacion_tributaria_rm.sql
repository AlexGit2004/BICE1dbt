-- =============================================================================
-- stg_f4__situacion_tributaria_rm
-- Fuente: CBRONZE.MARIA4_SITUACION_TRIBUTARIA_RM
-- Familia: F4 (MariaDB - registro mercantil)
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
        cast(situacion_tributaria_id as number(38,0)) as situacion_tributaria_id,
        cast(empresa_id as number(38,0)) as empresa_id,
        cast(anio_fiscal as number(38,0)) as anio_fiscal,
        cast(monto_impuestos_adeudados_bs as number(18,2)) as monto_impuestos_adeudados_bs,
        {{ limpiar_codigo('estado_tributario') }} as estado_tributario,
        try_to_date(fecha_actualizacion) as fecha_actualizacion
    from {{ source('bronze', 'maria4_situacion_tributaria_rm') }}

)

select
        cast(situacion_tributaria_id as number(38,0)) as situacion_tributaria_id,
        cast(empresa_id as number(38,0)) as empresa_id,
        cast(anio_fiscal as number(38,0)) as anio_fiscal,
        cast(monto_impuestos_adeudados_bs as number(18,2)) as monto_impuestos_adeudados_bs,
        {{ limpiar_codigo('estado_tributario') }} as estado_tributario,
        try_to_date(fecha_actualizacion) as fecha_actualizacion
from tipado
