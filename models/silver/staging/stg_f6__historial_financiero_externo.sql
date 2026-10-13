-- =============================================================================
-- stg_f6__historial_financiero_externo
-- Fuente: CBRONZE.CSV6_HISTORIAL_FINANCIERO_EXTERNO
-- Familia: F6 (CSV - historial financiero externo)
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
        numero_identificacion as numero_identificacion_origen,
        cast(tipo_identificacion as number(38,0)) as tipo_identificacion,
        {{ limpiar_texto('banco_acreedor') }} as banco_acreedor,
        {{ limpiar_codigo('tipo_producto') }} as tipo_producto,
        {{ limpiar_codigo('moneda') }} as moneda,
        cast(monto_originado as number(18,2)) as monto_originado,
        cast(saldo_actual as number(18,2)) as saldo_actual,
        cast(cuota_mensual as number(18,2)) as cuota_mensual,
        cast(plazo_meses as number(38,0)) as plazo_meses,
        try_to_date(fecha_originacion) as fecha_originacion,
        try_to_date(fecha_vencimiento) as fecha_vencimiento,
        try_to_date(fecha_ultimo_pago) as fecha_ultimo_pago,
        cast(dias_mora as number(38,0)) as dias_mora,
        {{ limpiar_codigo('calificacion_asfi') }} as calificacion_asfi,
        {{ limpiar_codigo('estado_credito') }} as estado_credito,
        {{ limpiar_codigo('tipo_garantia') }} as tipo_garantia,
        try_to_date(fecha_extraccion) as fecha_extraccion
    from {{ source('bronze', 'csv6_historial_financiero_externo') }}

)

select
        numero_identificacion_origen as numero_identificacion_origen,
        {{ normalizar_identidad_valida('numero_identificacion_origen') }} as numero_identificacion,
        cast(tipo_identificacion as number(38,0)) as tipo_identificacion,
        {{ limpiar_texto('banco_acreedor') }} as banco_acreedor,
        {{ limpiar_codigo('tipo_producto') }} as tipo_producto,
        {{ limpiar_codigo('moneda') }} as moneda,
        cast(monto_originado as number(18,2)) as monto_originado,
        cast(saldo_actual as number(18,2)) as saldo_actual,
        cast(cuota_mensual as number(18,2)) as cuota_mensual,
        cast(plazo_meses as number(38,0)) as plazo_meses,
        try_to_date(fecha_originacion) as fecha_originacion,
        try_to_date(fecha_vencimiento) as fecha_vencimiento,
        try_to_date(fecha_ultimo_pago) as fecha_ultimo_pago,
        cast(dias_mora as number(38,0)) as dias_mora,
        {{ limpiar_codigo('calificacion_asfi') }} as calificacion_asfi,
        {{ limpiar_codigo('estado_credito') }} as estado_credito,
        {{ limpiar_codigo('tipo_garantia') }} as tipo_garantia,
        try_to_date(fecha_extraccion) as fecha_extraccion
from tipado
