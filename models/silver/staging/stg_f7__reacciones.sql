-- =============================================================================
-- stg_f7__reacciones
-- Fuente: CBRONZE.JSON7_REACCIONES
-- Familia: F7 (JSON - redes sociales)
-- Destino: CSILVER (view)
-- =============================================================================

{{ config(materialized='view') }}

with base as (

    select
        coalesce(_id, data:_id::varchar) as _id,
        data:post_id::varchar as post_id,
        data:plataforma::varchar as plataforma,
        data:tipo_reaccion::varchar as tipo_reaccion,
        data:usuario_id_red::varchar as usuario_id_red,
        data:nombre_usuario::varchar as nombre_usuario,
        data:fecha_reaccion::varchar as fecha_reaccion,
        data:fecha_extraccion::varchar as fecha_extraccion
    from {{ source('bronze', 'json7_reacciones') }}

),

tipado as (

    select
        {{ limpiar_texto('_id') }} as _id,
        {{ limpiar_texto('post_id') }} as post_id,
        {{ limpiar_codigo('plataforma') }} as plataforma,
        {{ limpiar_codigo('tipo_reaccion') }} as tipo_reaccion,
        {{ limpiar_texto('usuario_id_red') }} as usuario_id_red,
        {{ limpiar_texto('nombre_usuario') }} as nombre_usuario,
        try_to_date(fecha_reaccion) as fecha_reaccion,
        try_to_date(fecha_extraccion) as fecha_extraccion
    from base

)

select
    _id,
    post_id,
    plataforma,
    tipo_reaccion,
    usuario_id_red,
    nombre_usuario,
    fecha_reaccion,
    fecha_extraccion
from tipado