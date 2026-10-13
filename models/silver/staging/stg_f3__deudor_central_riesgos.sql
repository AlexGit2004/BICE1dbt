-- =============================================================================
-- stg_f3__deudor_central_riesgos
-- Fuente: CBRONZE.SERVER3_DEUDOR_CENTRAL_RIESGOS
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
        cast(deudor_id as number(38,0)) as deudor_id,
        numero_identificacion as numero_identificacion_origen,
        cast(tipo_persona as number(38,0)) as tipo_persona,
        cast(cantidad_instituciones_acreedor as number(38,0)) as cantidad_instituciones_acreedor,
        cast(monto_total_deuda_bs as number(18,2)) as monto_total_deuda_bs,
        try_to_date(fecha_ultima_consulta) as fecha_ultima_consulta
    from {{ source('bronze', 'server3_deudor_central_riesgos') }}

)

select
        cast(deudor_id as number(38,0)) as deudor_id,
        numero_identificacion_origen as numero_identificacion_origen,
        {{ normalizar_identidad_valida('numero_identificacion_origen') }} as numero_identificacion,
        cast(tipo_persona as number(38,0)) as tipo_persona,
        cast(cantidad_instituciones_acreedor as number(38,0)) as cantidad_instituciones_acreedor,
        cast(monto_total_deuda_bs as number(18,2)) as monto_total_deuda_bs,
        try_to_date(fecha_ultima_consulta) as fecha_ultima_consulta
from tipado
