-- =============================================================================
-- stg_f5__bien_inmueble
-- Fuente: CBRONZE.MS5_BIEN_INMUEBLE
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
        cast(inmueble_id as number(38,0)) as inmueble_id,
        {{ limpiar_texto('matricula_inmueble') }} as matricula_inmueble,
        {{ limpiar_texto('tipo_inmueble') }} as tipo_inmueble,
        {{ limpiar_texto('descripcion') }} as descripcion,
        {{ limpiar_texto('direccion') }} as direccion,
        {{ limpiar_texto('zona') }} as zona,
        {{ limpiar_codigo('departamento') }} as departamento,
        cast(superficie_m2 as number(18,2)) as superficie_m2,
        cast(valor_comercial_bs as number(18,2)) as valor_comercial_bs,
        cast(valor_avaluo_bs as number(18,2)) as valor_avaluo_bs,
        try_to_date(fecha_avaluo) as fecha_avaluo,
        {{ limpiar_codigo('estado_inmueble') }} as estado_inmueble
    from {{ source('bronze', 'ms5_bien_inmueble') }}

)

select
        cast(inmueble_id as number(38,0)) as inmueble_id,
        {{ limpiar_texto('matricula_inmueble') }} as matricula_inmueble,
        {{ limpiar_texto('tipo_inmueble') }} as tipo_inmueble,
        {{ limpiar_texto('descripcion') }} as descripcion,
        {{ limpiar_texto('direccion') }} as direccion,
        {{ limpiar_texto('zona') }} as zona,
        {{ limpiar_codigo('departamento') }} as departamento,
        cast(superficie_m2 as number(18,2)) as superficie_m2,
        cast(valor_comercial_bs as number(18,2)) as valor_comercial_bs,
        cast(valor_avaluo_bs as number(18,2)) as valor_avaluo_bs,
        try_to_date(fecha_avaluo) as fecha_avaluo,
        {{ limpiar_codigo('estado_inmueble') }} as estado_inmueble
from tipado
