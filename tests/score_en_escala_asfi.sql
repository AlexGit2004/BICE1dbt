-- =============================================================================
-- Test singular: score_morosidad en escala ASFI 350-950
-- -----------------------------------------------------------------------------
-- Verifica que el score de morosidad esta en la escala real de ASFI.
--
-- Si este test falla, el macro nivel_score_morosidad esta usando cortes de
-- una escala 0-100 sobre un valor de 350-950, y todos los clientes caen en
-- 'Riesgo bajo' sin que nada lo indique.
-- =============================================================================

with scores as (

    select
        score_morosidad
    from {{ ref('int_riesgo_cliente') }}
    where score_morosidad is not null

)

select
    score_morosidad
from scores
where score_morosidad < 350
   or score_morosidad > 950
