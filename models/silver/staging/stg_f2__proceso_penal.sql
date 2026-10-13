-- =============================================================================
-- stg_f2__proceso_penal
-- Fuente: CBRONZE.PG2_PROCESO_PENAL
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
        cast(proceso_id as number(38,0)) as proceso_id,
        numero_identificacion as numero_identificacion_origen,
        {{ limpiar_texto('numero_proceso') }} as numero_proceso,
        cast(tipo_delito_id as number(38,0)) as tipo_delito_id,
        cast(estado_proceso_id as number(38,0)) as estado_proceso_id,
        {{ limpiar_codigo('juzgado_origen') }} as juzgado_origen,
        try_to_date(fecha_inicio_proceso) as fecha_inicio_proceso,
        try_to_date(fecha_ultima_actuacion) as fecha_ultima_actuacion,
        try_to_date(fecha_sentencia) as fecha_sentencia,
        {{ limpiar_texto('descripcion_breve') }} as descripcion_breve
    from {{ source('bronze', 'pg2_proceso_penal') }}

)

select
        cast(proceso_id as number(38,0)) as proceso_id,
        numero_identificacion_origen as numero_identificacion_origen,
        {{ normalizar_identidad_valida('numero_identificacion_origen') }} as numero_identificacion,
        {{ limpiar_texto('numero_proceso') }} as numero_proceso,
        cast(tipo_delito_id as number(38,0)) as tipo_delito_id,
        cast(estado_proceso_id as number(38,0)) as estado_proceso_id,
        {{ limpiar_codigo('juzgado_origen') }} as juzgado_origen,
        try_to_date(fecha_inicio_proceso) as fecha_inicio_proceso,
        try_to_date(fecha_ultima_actuacion) as fecha_ultima_actuacion,
        try_to_date(fecha_sentencia) as fecha_sentencia,
        {{ limpiar_texto('descripcion_breve') }} as descripcion_breve
from tipado
