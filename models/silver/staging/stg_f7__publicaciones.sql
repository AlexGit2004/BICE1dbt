-- =============================================================================
-- stg_f7__publicaciones
-- Fuente: CBRONZE.JSON7_PUBLICACIONES
-- Familia: F7 (JSON - redes sociales)
-- Destino: CSILVER (view)
-- =============================================================================

{{ config(materialized='view') }}

with base as (

    select
        coalesce(_id, data:_id::varchar) as _id,
        data:post_id_red::varchar as post_id_red,
        data:plataforma::varchar as plataforma,
        data:cuenta_propietaria::varchar as cuenta_propietaria,
        data:fecha_publicacion::varchar as fecha_publicacion,
        data:descripcion::varchar as descripcion,
        data:url_post::varchar as url_post,
        data:total_comentarios::varchar as total_comentarios,
        data:total_reacciones::varchar as total_reacciones,
        data:total_compartidos::varchar as total_compartidos,
        data:fecha_extraccion::varchar as fecha_extraccion
    from {{ source('bronze', 'json7_publicaciones') }}

),

tipado as (

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
    from base

)

select
    _id,
    post_id_red,
    plataforma,
    cuenta_propietaria,
    fecha_publicacion,
    descripcion,
    url_post,
    total_comentarios,
    total_reacciones,
    total_compartidos,
    fecha_extraccion
from tipado