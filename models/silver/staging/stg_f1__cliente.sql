-- =============================================================================
-- stg_f1__cliente
-- Fuente: CBRONZE.MS1_CLIENTE
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
        cast(cliente_id as number(38,0)) as cliente_id,
        numero_identificacion as numero_identificacion_origen,
        cast(tipo_id as number(38,0)) as tipo_id,
        es_persona_juridica as es_persona_juridica,
        nit_empresa as nit_empresa_origen,
        ci_representante_legal as ci_representante_legal_origen,
        {{ limpiar_texto('nombre_completo') }} as nombre_completo,
        {{ limpiar_texto('nombre_representante_legal') }} as nombre_representante_legal,
        {{ limpiar_codigo('estado_cliente') }} as estado_cliente,
        try_to_date(fecha_creacion) as fecha_creacion
    from {{ source('bronze', 'ms1_cliente') }}

)

select
        cast(cliente_id as number(38,0)) as cliente_id,
        numero_identificacion_origen as numero_identificacion_origen,
        {{ normalizar_identidad_valida('numero_identificacion_origen') }} as numero_identificacion,
        cast(tipo_id as number(38,0)) as tipo_id,
        es_persona_juridica as es_persona_juridica,
        nit_empresa_origen as nit_empresa_origen,
        {{ normalizar_identidad_valida('nit_empresa_origen') }} as nit_empresa,
        ci_representante_legal_origen as ci_representante_legal_origen,
        {{ normalizar_identidad_valida('ci_representante_legal_origen') }} as ci_representante_legal,
        {{ limpiar_texto('nombre_completo') }} as nombre_completo,
        {{ limpiar_texto('nombre_representante_legal') }} as nombre_representante_legal,
        {{ limpiar_codigo('estado_cliente') }} as estado_cliente,
        try_to_date(fecha_creacion) as fecha_creacion
from tipado
