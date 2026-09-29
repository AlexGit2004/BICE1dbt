-- =============================================================================
-- stg_f2__tipo_delito
-- Fuente: CBRONZE.PG2_TIPO_DELITO
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
        cast(tipo_delito_id as number(38,0)) as tipo_delito_id,
        cast(categoria_delito_id as number(38,0)) as categoria_delito_id,
        {{ limpiar_texto('nombre_delito') }} as nombre_delito,
        {{ limpiar_codigo('codigo_penal') }} as codigo_penal
    from {{ source('bronze', 'pg2_tipo_delito') }}

)

select
        cast(tipo_delito_id as number(38,0)) as tipo_delito_id,
        cast(categoria_delito_id as number(38,0)) as categoria_delito_id,
        {{ limpiar_texto('nombre_delito') }} as nombre_delito,
        {{ limpiar_codigo('codigo_penal') }} as codigo_penal
from tipado
