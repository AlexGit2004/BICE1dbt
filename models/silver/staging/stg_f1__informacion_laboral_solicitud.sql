-- =============================================================================
-- stg_f1__informacion_laboral_solicitud
-- Fuente: CBRONZE.MS1_INFORMACION_LABORAL_SOLICITUD
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
        cast(info_laboral_id as number(38,0)) as info_laboral_id,
        cast(solicitud_id as number(38,0)) as solicitud_id,
        cast(cliente_id as number(38,0)) as cliente_id,
        try_to_date(fecha_actualizacion) as fecha_actualizacion,
        {{ limpiar_codigo('tipo_empleo') }} as tipo_empleo,
        {{ limpiar_texto('empresa') }} as empresa,
        {{ limpiar_texto('sector_economico') }} as sector_economico,
        {{ limpiar_texto('cargo') }} as cargo,
        cast(antiguedad_meses as number(38,0)) as antiguedad_meses,
        cast(ingreso_mensual_bs as number(18,2)) as ingreso_mensual_bs,
        {{ limpiar_codigo('tipo_contrato') }} as tipo_contrato,
        {{ limpiar_texto('ciudad') }} as ciudad,
        {{ limpiar_codigo('estado_empleo') }} as estado_empleo
    from {{ source('bronze', 'ms1_informacion_laboral_solicitud') }}

)

select
        cast(info_laboral_id as number(38,0)) as info_laboral_id,
        cast(solicitud_id as number(38,0)) as solicitud_id,
        cast(cliente_id as number(38,0)) as cliente_id,
        try_to_date(fecha_actualizacion) as fecha_actualizacion,
        {{ limpiar_codigo('tipo_empleo') }} as tipo_empleo,
        {{ limpiar_texto('empresa') }} as empresa,
        {{ limpiar_texto('sector_economico') }} as sector_economico,
        {{ limpiar_texto('cargo') }} as cargo,
        cast(antiguedad_meses as number(38,0)) as antiguedad_meses,
        cast(ingreso_mensual_bs as number(18,2)) as ingreso_mensual_bs,
        {{ limpiar_codigo('tipo_contrato') }} as tipo_contrato,
        {{ limpiar_texto('ciudad') }} as ciudad,
        {{ limpiar_codigo('estado_empleo') }} as estado_empleo
from tipado
