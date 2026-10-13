-- =============================================================================
-- stg_f1__prestamo
-- Fuente: CBRONZE.MS1_PRESTAMO
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
        cast(prestamo_id as number(38,0)) as prestamo_id,
        cast(solicitud_id as number(38,0)) as solicitud_id,
        cast(cliente_id as number(38,0)) as cliente_id,
        cast(producto_id as number(38,0)) as producto_id,
        cast(agencia_id as number(38,0)) as agencia_id,
        try_to_date(fecha_originacion) as fecha_originacion,
        try_to_date(fecha_vencimiento) as fecha_vencimiento,
        cast(monto_aprobado_bs as number(18,2)) as monto_aprobado_bs,
        cast(tasa_interes_aplicada as number(18,2)) as tasa_interes_aplicada,
        cast(plazo_aprobado_meses as number(38,0)) as plazo_aprobado_meses,
        cast(cuota_mensual_bs as number(18,2)) as cuota_mensual_bs,
        cast(saldo_actual_bs as number(18,2)) as saldo_actual_bs,
        cast(dias_atraso as number(38,0)) as dias_atraso,
        cast(dias_mora_al_ultimo_pago as number(38,0)) as dias_mora_al_ultimo_pago,
        {{ limpiar_codigo('estado_prestamo') }} as estado_prestamo
    from {{ source('bronze', 'ms1_prestamo') }}

)

select
        cast(prestamo_id as number(38,0)) as prestamo_id,
        cast(solicitud_id as number(38,0)) as solicitud_id,
        cast(cliente_id as number(38,0)) as cliente_id,
        cast(producto_id as number(38,0)) as producto_id,
        cast(agencia_id as number(38,0)) as agencia_id,
        try_to_date(fecha_originacion) as fecha_originacion,
        try_to_date(fecha_vencimiento) as fecha_vencimiento,
        cast(monto_aprobado_bs as number(18,2)) as monto_aprobado_bs,
        cast(tasa_interes_aplicada as number(18,2)) as tasa_interes_aplicada,
        cast(plazo_aprobado_meses as number(38,0)) as plazo_aprobado_meses,
        cast(cuota_mensual_bs as number(18,2)) as cuota_mensual_bs,
        cast(saldo_actual_bs as number(18,2)) as saldo_actual_bs,
        cast(dias_atraso as number(38,0)) as dias_atraso,
        cast(dias_mora_al_ultimo_pago as number(38,0)) as dias_mora_al_ultimo_pago,
        {{ limpiar_codigo('estado_prestamo') }} as estado_prestamo
from tipado
