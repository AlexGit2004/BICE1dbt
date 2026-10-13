-- =============================================================================
-- stg_f2__consolidado_antecedentes
-- Fuente: CBRONZE.PG2_CONSOLIDADO_ANTECEDENTES
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
        cast(antecedente_id as number(38,0)) as antecedente_id,
        numero_identificacion as numero_identificacion_origen,
        cast(tiene_antecedentes_penales as number(38,0)) as tiene_antecedentes_penales,
        cast(cantidad_procesos_activos as number(38,0)) as cantidad_procesos_activos,
        cast(cantidad_sentencias_condenatorias as number(38,0)) as cantidad_sentencias_condenatorias,
        try_to_date(fecha_ultima_actualizacion) as fecha_ultima_actualizacion
    from {{ source('bronze', 'pg2_consolidado_antecedentes') }}

)

select
        cast(antecedente_id as number(38,0)) as antecedente_id,
        numero_identificacion_origen as numero_identificacion_origen,
        {{ normalizar_identidad_valida('numero_identificacion_origen') }} as numero_identificacion,
        cast(tiene_antecedentes_penales as number(38,0)) as tiene_antecedentes_penales,
        cast(cantidad_procesos_activos as number(38,0)) as cantidad_procesos_activos,
        cast(cantidad_sentencias_condenatorias as number(38,0)) as cantidad_sentencias_condenatorias,
        try_to_date(fecha_ultima_actualizacion) as fecha_ultima_actualizacion
from tipado
