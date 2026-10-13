-- =============================================================================
-- stg_f5__gravamen_garantia_prestamo
-- Fuente: CBRONZE.MS5_GRAVAMEN_GARANTIA_PRESTAMO
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
        cast(gravamen_id as number(38,0)) as gravamen_id,
        cast(inscripcion_id as number(38,0)) as inscripcion_id,
        cast(prestamo_id as number(38,0)) as prestamo_id,
        try_to_date(fecha_inscripcion_gravamen) as fecha_inscripcion_gravamen,
        cast(monto_garantizado_bs as number(18,2)) as monto_garantizado_bs,
        try_to_date(fecha_liberacion) as fecha_liberacion,
        {{ limpiar_codigo('estado_gravamen') }} as estado_gravamen
    from {{ source('bronze', 'ms5_gravamen_garantia_prestamo') }}

)

select
        cast(gravamen_id as number(38,0)) as gravamen_id,
        cast(inscripcion_id as number(38,0)) as inscripcion_id,
        cast(prestamo_id as number(38,0)) as prestamo_id,
        try_to_date(fecha_inscripcion_gravamen) as fecha_inscripcion_gravamen,
        cast(monto_garantizado_bs as number(18,2)) as monto_garantizado_bs,
        try_to_date(fecha_liberacion) as fecha_liberacion,
        {{ limpiar_codigo('estado_gravamen') }} as estado_gravamen
from tipado
