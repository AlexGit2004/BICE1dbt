-- =============================================================================
-- stg_f3__tipo_entidad_financiera
-- Fuente: CBRONZE.SERVER3_TIPO_ENTIDAD_FINANCIERA
-- Familia: F3 (Server - central de riesgos)
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
        cast(tipo_entidad_id as number(38,0)) as tipo_entidad_id,
        {{ limpiar_texto('nombre_tipo') }} as nombre_tipo,
        {{ limpiar_texto('descripcion') }} as descripcion
    from {{ source('bronze', 'server3_tipo_entidad_financiera') }}

)

select
        cast(tipo_entidad_id as number(38,0)) as tipo_entidad_id,
        {{ limpiar_texto('nombre_tipo') }} as nombre_tipo,
        {{ limpiar_texto('descripcion') }} as descripcion
from tipado
