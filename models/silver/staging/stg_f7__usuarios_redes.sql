-- =============================================================================
-- stg_f7__usuarios_redes
-- Fuente: CBRONZE.JSON7_USUARIOS
-- Familia: F7 (JSON - redes sociales)
-- Destino: CSILVER (view)
-- =============================================================================

{{ config(materialized='view') }}

with base as (

    select
        coalesce(_id, data:_id::varchar) as _id,
        data:plataforma::varchar as plataforma,
        data:usuario_id_red::varchar as usuario_id_red,
        data:nombre_usuario::varchar as nombre_usuario,
        data:total_comentarios_realizados::varchar as total_comentarios_realizados,
        data:total_reacciones_realizadas::varchar as total_reacciones_realizadas,
        data:primera_interaccion::varchar as primera_interaccion,
        data:ultima_interaccion::varchar as ultima_interaccion
    from {{ source('bronze', 'json7_usuarios') }}

),

tipado as (

    select
        {{ limpiar_texto('_id') }} as _id,
        {{ limpiar_codigo('plataforma') }} as plataforma,
        {{ limpiar_texto('usuario_id_red') }} as usuario_id_red,
        {{ limpiar_texto('nombre_usuario') }} as nombre_usuario,
        cast(total_comentarios_realizados as number(38,0)) as total_comentarios_realizados,
        cast(total_reacciones_realizadas as number(38,0)) as total_reacciones_realizadas,
        try_to_date(primera_interaccion) as primera_interaccion,
        try_to_date(ultima_interaccion) as ultima_interaccion
    from base

)

select
    _id,
    plataforma,
    usuario_id_red,
    nombre_usuario,
    total_comentarios_realizados,
    total_reacciones_realizadas,
    primera_interaccion,
    ultima_interaccion
from tipado