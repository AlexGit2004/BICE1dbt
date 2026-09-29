-- =============================================================================
-- stg_f1__agencia
-- Fuente: CBRONZE.MS1_AGENCIA
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
        cast(agencia_id as number(38,0)) as agencia_id,
        {{ limpiar_texto('nombre_agencia') }} as nombre_agencia,
        {{ limpiar_codigo('codigo_agencia') }} as codigo_agencia,
        {{ limpiar_codigo('departamento') }} as departamento,
        {{ limpiar_texto('tipo_agencia') }} as tipo_agencia,
        {{ limpiar_codigo('estado_agencia') }} as estado_agencia
    from {{ source('bronze', 'ms1_agencia') }}

)

select
        cast(agencia_id as number(38,0)) as agencia_id,
        {{ limpiar_texto('nombre_agencia') }} as nombre_agencia,
        {{ limpiar_codigo('codigo_agencia') }} as codigo_agencia,
        {{ limpiar_codigo('departamento') }} as departamento,
        {{ limpiar_texto('tipo_agencia') }} as tipo_agencia,
        {{ limpiar_codigo('estado_agencia') }} as estado_agencia
from tipado
