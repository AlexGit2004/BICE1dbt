-- =============================================================================
-- stg_f4__accionista_representante_rm
-- Fuente: CBRONZE.MARIA4_ACCIONISTA_REPRESENTANTE_RM
-- Familia: F4 (MariaDB - registro mercantil)
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
        cast(participante_id as number(38,0)) as participante_id,
        cast(empresa_id as number(38,0)) as empresa_id,
        numero_identificacion as numero_identificacion_origen,
        {{ limpiar_texto('nombre_completo') }} as nombre_completo,
        {{ limpiar_codigo('tipo_participacion') }} as tipo_participacion,
        cast(porcentaje_participacion as number(18,2)) as porcentaje_participacion,
        es_controlador as es_controlador
    from {{ source('bronze', 'maria4_accionista_representante_rm') }}

)

select
        cast(participante_id as number(38,0)) as participante_id,
        cast(empresa_id as number(38,0)) as empresa_id,
        numero_identificacion_origen as numero_identificacion_origen,
        {{ normalizar_identidad_valida('numero_identificacion_origen') }} as numero_identificacion,
        {{ limpiar_texto('nombre_completo') }} as nombre_completo,
        {{ limpiar_codigo('tipo_participacion') }} as tipo_participacion,
        cast(porcentaje_participacion as number(18,2)) as porcentaje_participacion,
        es_controlador as es_controlador
from tipado
