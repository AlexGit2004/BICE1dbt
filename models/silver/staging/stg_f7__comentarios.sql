-- =============================================================================
-- stg_f7__comentarios
-- Fuente: CBRONZE.JSON7_COMENTARIOS
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
        {{ limpiar_texto('comment_id_red') }} as comment_id_red,
        {{ limpiar_codigo('plataforma') }} as plataforma,
        {{ limpiar_texto('usuario_id_red') }} as usuario_id_red,
        {{ limpiar_texto('nombre_usuario') }} as nombre_usuario,
        {{ limpiar_texto('nombre_pantalla') }} as nombre_pantalla,
        {{ limpiar_texto('texto_comentario') }} as texto_comentario,
        try_to_date(fecha_comentario) as fecha_comentario,
        {{ limpiar_texto('parent_comment_id') }} as parent_comment_id,
        cast(reacciones_comentario as number(38,0)) as reacciones_comentario,
        cast(sentimiento_score as number(6,4)) as sentimiento_score,
        {{ limpiar_codigo('sentimiento_etiqueta') }} as sentimiento_etiqueta,
        try_to_date(fecha_extraccion) as fecha_extraccion
    from {{ source('bronze', 'json7_comentarios') }}

)

select
        {{ limpiar_texto('_id') }} as _id,
        {{ limpiar_texto('post_id') }} as post_id,
        {{ limpiar_texto('comment_id_red') }} as comment_id_red,
        {{ limpiar_codigo('plataforma') }} as plataforma,
        {{ limpiar_texto('usuario_id_red') }} as usuario_id_red,
        {{ limpiar_texto('nombre_usuario') }} as nombre_usuario,
        {{ limpiar_texto('nombre_pantalla') }} as nombre_pantalla,
        {{ limpiar_texto('texto_comentario') }} as texto_comentario,
        try_to_date(fecha_comentario) as fecha_comentario,
        {{ limpiar_texto('parent_comment_id') }} as parent_comment_id,
        cast(reacciones_comentario as number(38,0)) as reacciones_comentario,
        cast(sentimiento_score as number(6,4)) as sentimiento_score,
        {{ limpiar_codigo('sentimiento_etiqueta') }} as sentimiento_etiqueta,
        try_to_date(fecha_extraccion) as fecha_extraccion
from tipado
