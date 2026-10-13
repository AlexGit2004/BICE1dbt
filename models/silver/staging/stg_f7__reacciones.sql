-- =============================================================================
-- stg_f7__reacciones
-- Fuente: CBRONZE.JSON7_REACCIONES
-- Familia: F7 (JSON - redes sociales)
-- Destino: CSILVER (view)
--
-- Staging NO decide nada de negocio. Su unico trabajo es:
--   1. traer la tabla tal cual,
--   2. tipar las fechas de forma explicita (try_to_date),
--   3. normalizar la identidad a 8 digitos canonicos,
--   4. limpiar el texto.
-- Las reglas de negocio van en los int_ y en los macros.
-- =============================================================================

{{ config(materialized='view') }}

with tipado as (

    select
        {{ limpiar_texto('_id') }} as _id,
        {{ limpiar_texto('post_id') }} as post_id,
        {{ limpiar_codigo('plataforma') }} as plataforma,
        {{ limpiar_codigo('tipo_reaccion') }} as tipo_reaccion,
        {{ limpiar_texto('usuario_id_red') }} as usuario_id_red,
        {{ limpiar_texto('nombre_usuario') }} as nombre_usuario,
        try_to_date(fecha_reaccion) as fecha_reaccion,
        try_to_date(fecha_extraccion) as fecha_extraccion
    from {{ source('bronze', 'json7_reacciones') }}

)

select
        {{ limpiar_texto('_id') }} as _id,
        {{ limpiar_texto('post_id') }} as post_id,
        {{ limpiar_codigo('plataforma') }} as plataforma,
        {{ limpiar_codigo('tipo_reaccion') }} as tipo_reaccion,
        {{ limpiar_texto('usuario_id_red') }} as usuario_id_red,
        {{ limpiar_texto('nombre_usuario') }} as nombre_usuario,
        try_to_date(fecha_reaccion) as fecha_reaccion,
        try_to_date(fecha_extraccion) as fecha_extraccion
from tipado
