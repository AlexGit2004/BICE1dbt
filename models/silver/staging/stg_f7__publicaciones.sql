-- =============================================================================
-- stg_f7__publicaciones
-- Fuente: CBRONZE.JSON7_PUBLICACIONES
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
        {{ limpiar_texto('post_id_red') }} as post_id_red,
        {{ limpiar_codigo('plataforma') }} as plataforma,
        {{ limpiar_texto('cuenta_propietaria') }} as cuenta_propietaria,
        try_to_date(fecha_publicacion) as fecha_publicacion,
        {{ limpiar_texto('descripcion') }} as descripcion,
        {{ limpiar_texto('url_post') }} as url_post,
        cast(total_comentarios as number(38,0)) as total_comentarios,
        cast(total_reacciones as number(38,0)) as total_reacciones,
        cast(total_compartidos as number(38,0)) as total_compartidos,
        try_to_date(fecha_extraccion) as fecha_extraccion
    from {{ source('bronze', 'json7_publicaciones') }}

)

select
        {{ limpiar_texto('_id') }} as _id,
        {{ limpiar_texto('post_id_red') }} as post_id_red,
        {{ limpiar_codigo('plataforma') }} as plataforma,
        {{ limpiar_texto('cuenta_propietaria') }} as cuenta_propietaria,
        try_to_date(fecha_publicacion) as fecha_publicacion,
        {{ limpiar_texto('descripcion') }} as descripcion,
        {{ limpiar_texto('url_post') }} as url_post,
        cast(total_comentarios as number(38,0)) as total_comentarios,
        cast(total_reacciones as number(38,0)) as total_reacciones,
        cast(total_compartidos as number(38,0)) as total_compartidos,
        try_to_date(fecha_extraccion) as fecha_extraccion
from tipado
