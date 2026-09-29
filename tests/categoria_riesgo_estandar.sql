-- =============================================================================
-- Test singular: categoria_riesgo en vocabulario estandar
-- -----------------------------------------------------------------------------
-- Verifica que la categoria de riesgo estandarizada solo usa el vocabulario
-- del proyecto: Bajo, Medio, Alto, Muy alto, Sin dato.
--
-- Si este test falla, el macro categoria_riesgo no esta estandarizando
-- correctamente y el tablero mostrara categorias duplicadas ('Bajo' y
-- 'Sin Riesgo' como si fueran distintas).
-- =============================================================================

with categorias as (

    select
        categoria_riesgo
    from {{ ref('int_riesgo_cliente') }}
    where categoria_riesgo is not null

)

select
    categoria_riesgo
from categorias
where categoria_riesgo not in ('Bajo', 'Medio', 'Alto', 'Muy alto', 'Sin dato')
