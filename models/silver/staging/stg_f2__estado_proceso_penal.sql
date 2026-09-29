-- =============================================================================
-- stg_f2__estado_proceso_penal
-- Fuente: CBRONZE.PG2_ESTADO_PROCESO_PENAL
-- Familia: F2 (PostgreSQL - antecedentes penales)
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
        cast(estado_proceso_id as number(38,0)) as estado_proceso_id,
        {{ limpiar_texto('nombre_estado') }} as nombre_estado,
        es_terminal as es_terminal
    from {{ source('bronze', 'pg2_estado_proceso_penal') }}

)

select
        cast(estado_proceso_id as number(38,0)) as estado_proceso_id,
        {{ limpiar_texto('nombre_estado') }} as nombre_estado,
        es_terminal as es_terminal
from tipado
