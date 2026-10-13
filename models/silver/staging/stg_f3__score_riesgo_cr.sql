-- =============================================================================
-- stg_f3__score_riesgo_cr
-- Fuente: CBRONZE.SERVER3_SCORE_RIESGO_CR
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
        cast(score_cr_id as number(38,0)) as score_cr_id,
        cast(deudor_id as number(38,0)) as deudor_id,
        {{ limpiar_codigo('categoria_riesgo') }} as categoria_riesgo,
        cast(score_morosidad as number(38,0)) as score_morosidad,
        try_to_date(fecha_calculo) as fecha_calculo
    from {{ source('bronze', 'server3_score_riesgo_cr') }}

)

select
        cast(score_cr_id as number(38,0)) as score_cr_id,
        cast(deudor_id as number(38,0)) as deudor_id,
        {{ limpiar_codigo('categoria_riesgo') }} as categoria_riesgo,
        cast(score_morosidad as number(38,0)) as score_morosidad,
        try_to_date(fecha_calculo) as fecha_calculo
from tipado
