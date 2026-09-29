-- =============================================================================
-- stg_f5__derecho_real_inscripcion
-- Fuente: CBRONZE.MS5_DERECHO_REAL_INSCRIPCION
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
        cast(inscripcion_id as number(38,0)) as inscripcion_id,
        {{ limpiar_texto('numero_inscripcion') }} as numero_inscripcion,
        cast(inmueble_id as number(38,0)) as inmueble_id,
        cast(tipo_derecho_real_id as number(38,0)) as tipo_derecho_real_id,
        numero_identificacion_titular as numero_identificacion_titular_origen,
        try_to_date(fecha_inscripcion) as fecha_inscripcion,
        try_to_date(fecha_vencimiento) as fecha_vencimiento,
        cast(monto_base_bs as number(18,2)) as monto_base_bs,
        {{ limpiar_codigo('notario') }} as notario,
        {{ limpiar_codigo('estado_inscripcion') }} as estado_inscripcion
    from {{ source('bronze', 'ms5_derecho_real_inscripcion') }}

)

select
        cast(inscripcion_id as number(38,0)) as inscripcion_id,
        {{ limpiar_texto('numero_inscripcion') }} as numero_inscripcion,
        cast(inmueble_id as number(38,0)) as inmueble_id,
        cast(tipo_derecho_real_id as number(38,0)) as tipo_derecho_real_id,
        numero_identificacion_titular_origen as numero_identificacion_titular_origen,
        {{ normalizar_identidad_valida('numero_identificacion_titular_origen') }} as numero_identificacion_titular,
        try_to_date(fecha_inscripcion) as fecha_inscripcion,
        try_to_date(fecha_vencimiento) as fecha_vencimiento,
        cast(monto_base_bs as number(18,2)) as monto_base_bs,
        {{ limpiar_codigo('notario') }} as notario,
        {{ limpiar_codigo('estado_inscripcion') }} as estado_inscripcion
from tipado
