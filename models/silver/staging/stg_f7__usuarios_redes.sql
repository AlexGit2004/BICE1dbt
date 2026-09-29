-- =============================================================================
-- stg_f7__usuarios_redes
-- Fuente: CBRONZE.JSON7_USUARIOS_REDES
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
        {{ limpiar_codigo('plataforma') }} as plataforma,
        {{ limpiar_texto('usuario_id_red') }} as usuario_id_red,
        {{ limpiar_texto('nombre_usuario') }} as nombre_usuario,
        cast(total_comentarios_realizados as number(38,0)) as total_comentarios_realizados,
        cast(total_reacciones_realizadas as number(38,0)) as total_reacciones_realizadas,
        try_to_date(primera_interaccion) as primera_interaccion,
        try_to_date(ultima_interaccion) as ultima_interaccion
    from {{ source('bronze', 'json7_usuarios_redes') }}

)

select
        {{ limpiar_texto('_id') }} as _id,
        {{ limpiar_codigo('plataforma') }} as plataforma,
        {{ limpiar_texto('usuario_id_red') }} as usuario_id_red,
        {{ limpiar_texto('nombre_usuario') }} as nombre_usuario,
        cast(total_comentarios_realizados as number(38,0)) as total_comentarios_realizados,
        cast(total_reacciones_realizadas as number(38,0)) as total_reacciones_realizadas,
        try_to_date(primera_interaccion) as primera_interaccion,
        try_to_date(ultima_interaccion) as ultima_interaccion
from tipado
