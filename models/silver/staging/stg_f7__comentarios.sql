-- =============================================================================
-- stg_f7__comentarios
-- Fuente: CBRONZE.JSON7_COMENTARIOS
-- Familia: F7 (JSON - redes sociales)
-- Destino: CSILVER (view)
-- =============================================================================

{{ config(materialized='view') }}

with base as (

    select
        coalesce(_id, data:_id::varchar) as _id,
        data:post_id::varchar as post_id,
        data:comment_id_red::varchar as comment_id_red,
        data:plataforma::varchar as plataforma,
        data:usuario_id_red::varchar as usuario_id_red,
        data:nombre_usuario::varchar as nombre_usuario,
        data:nombre_pantalla::varchar as nombre_pantalla,
        data:texto_comentario::varchar as texto_comentario,
        data:fecha_comentario::varchar as fecha_comentario,
        data:parent_comment_id::varchar as parent_comment_id,
        data:reacciones_comentario::varchar as reacciones_comentario,
        data:sentimiento_score::varchar as sentimiento_score,
        data:sentimiento_etiqueta::varchar as sentimiento_etiqueta,
        data:fecha_extraccion::varchar as fecha_extraccion
    from {{ source('bronze', 'json7_comentarios') }}

),

tipado as (

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
    from base

)

select
    _id,
    post_id,
    comment_id_red,
    plataforma,
    usuario_id_red,
    nombre_usuario,
    nombre_pantalla,
    texto_comentario,
    fecha_comentario,
    parent_comment_id,
    reacciones_comentario,
    sentimiento_score,
    sentimiento_etiqueta,
    fecha_extraccion
from tipado