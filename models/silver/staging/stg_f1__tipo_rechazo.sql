-- =============================================================================
-- stg_f1__tipo_rechazo
-- Fuente: CBRONZE.MS1_TIPO_RECHAZO
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
        cast(tipo_rechazo_id as number(38,0)) as tipo_rechazo_id,
        {{ limpiar_texto('nombre_motivo') }} as nombre_motivo,
        {{ limpiar_codigo('categoria') }} as categoria
    from {{ source('bronze', 'ms1_tipo_rechazo') }}

)

select
        cast(tipo_rechazo_id as number(38,0)) as tipo_rechazo_id,
        {{ limpiar_texto('nombre_motivo') }} as nombre_motivo,
        {{ limpiar_codigo('categoria') }} as categoria
from tipado
