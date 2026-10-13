-- =============================================================================
-- stg_f3__deuda_cr
-- Fuente: CBRONZE.SERVER3_DEUDA_CR
-- Familia: F3 (Server - central de riesgos)
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
        cast(deuda_id as number(38,0)) as deuda_id,
        cast(deudor_id as number(38,0)) as deudor_id,
        cast(entidad_financiera_id as number(38,0)) as entidad_financiera_id,
        {{ limpiar_codigo('tipo_obligacion') }} as tipo_obligacion,
        cast(monto_deuda_actual_bs as number(18,2)) as monto_deuda_actual_bs,
        cast(dias_atraso_actual as number(38,0)) as dias_atraso_actual,
        try_to_date(fecha_originacion) as fecha_originacion,
        try_to_date(fecha_consulta) as fecha_consulta
    from {{ source('bronze', 'server3_deuda_cr') }}

)

select
        cast(deuda_id as number(38,0)) as deuda_id,
        cast(deudor_id as number(38,0)) as deudor_id,
        cast(entidad_financiera_id as number(38,0)) as entidad_financiera_id,
        {{ limpiar_codigo('tipo_obligacion') }} as tipo_obligacion,
        cast(monto_deuda_actual_bs as number(18,2)) as monto_deuda_actual_bs,
        cast(dias_atraso_actual as number(38,0)) as dias_atraso_actual,
        try_to_date(fecha_originacion) as fecha_originacion,
        try_to_date(fecha_consulta) as fecha_consulta
from tipado
