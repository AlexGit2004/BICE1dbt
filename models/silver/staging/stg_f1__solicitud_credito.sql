-- =============================================================================
-- stg_f1__solicitud_credito
-- Fuente: CBRONZE.MS1_SOLICITUD_CREDITO
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
        cast(solicitud_id as number(38,0)) as solicitud_id,
        cast(cliente_id as number(38,0)) as cliente_id,
        cast(producto_id as number(38,0)) as producto_id,
        try_to_date(fecha_solicitud) as fecha_solicitud,
        cast(monto_solicitado_bs as number(18,2)) as monto_solicitado_bs,
        cast(plazo_solicitado_meses as number(38,0)) as plazo_solicitado_meses,
        {{ limpiar_codigo('estado_solicitud') }} as estado_solicitud,
        cast(tipo_rechazo_id as number(38,0)) as tipo_rechazo_id
    from {{ source('bronze', 'ms1_solicitud_credito') }}

)

select
        cast(solicitud_id as number(38,0)) as solicitud_id,
        cast(cliente_id as number(38,0)) as cliente_id,
        cast(producto_id as number(38,0)) as producto_id,
        try_to_date(fecha_solicitud) as fecha_solicitud,
        cast(monto_solicitado_bs as number(18,2)) as monto_solicitado_bs,
        cast(plazo_solicitado_meses as number(38,0)) as plazo_solicitado_meses,
        {{ limpiar_codigo('estado_solicitud') }} as estado_solicitud,
        cast(tipo_rechazo_id as number(38,0)) as tipo_rechazo_id
from tipado
