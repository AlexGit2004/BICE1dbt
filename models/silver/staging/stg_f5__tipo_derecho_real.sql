-- =============================================================================
-- stg_f5__tipo_derecho_real
-- Fuente: CBRONZE.MS5_TIPO_DERECHO_REAL
-- Familia: F5 (MySQL - derechos reales)
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
        cast(tipo_derecho_real_id as number(38,0)) as tipo_derecho_real_id,
        {{ limpiar_codigo('codigo') }} as codigo,
        {{ limpiar_texto('nombre_tipo') }} as nombre_tipo,
        es_garantia as es_garantia,
        es_transmision as es_transmision,
        requiere_valuacion as requiere_valuacion
    from {{ source('bronze', 'ms5_tipo_derecho_real') }}

)

select
        cast(tipo_derecho_real_id as number(38,0)) as tipo_derecho_real_id,
        {{ limpiar_codigo('codigo') }} as codigo,
        {{ limpiar_texto('nombre_tipo') }} as nombre_tipo,
        es_garantia as es_garantia,
        es_transmision as es_transmision,
        requiere_valuacion as requiere_valuacion
from tipado
