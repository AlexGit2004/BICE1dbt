-- =============================================================================
-- stg_f1__caracteristica_cliente
-- Fuente: CBRONZE.MS1_CARACTERISTICA_CLIENTE
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
        cast(carac_id as number(38,0)) as carac_id,
        cast(cliente_id as number(38,0)) as cliente_id,
        try_to_date(fecha_nacimiento) as fecha_nacimiento,
        {{ limpiar_codigo('sexo') }} as sexo,
        {{ limpiar_codigo('estado_civil') }} as estado_civil,
        {{ limpiar_texto('nacionalidad') }} as nacionalidad,
        {{ limpiar_texto('profesion') }} as profesion
    from {{ source('bronze', 'ms1_caracteristica_cliente') }}

)

select
        cast(carac_id as number(38,0)) as carac_id,
        cast(cliente_id as number(38,0)) as cliente_id,
        try_to_date(fecha_nacimiento) as fecha_nacimiento,
        {{ limpiar_codigo('sexo') }} as sexo,
        {{ limpiar_codigo('estado_civil') }} as estado_civil,
        {{ limpiar_texto('nacionalidad') }} as nacionalidad,
        {{ limpiar_texto('profesion') }} as profesion
from tipado
