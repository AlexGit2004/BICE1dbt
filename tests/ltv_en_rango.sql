-- =============================================================================
-- Test singular: LTV no negativo y no mayor a 10
-- -----------------------------------------------------------------------------
-- Verifica que el LTV (loan to value) esta en un rango razonable.
--
-- Un LTV negativo significa que el saldo o el avaluo son negativos, lo cual
-- es un error de datos. Un LTV mayor a 10 significa que el credito es 10
-- veces el valor del bien, lo cual es un error de calculo.
--
-- Si este test falla, el macro ltv_pct no esta manejando correctamente los
-- valores nulos o los ceros.
-- =============================================================================

with ltvs as (

    select
        ltv_pct
    from {{ ref('int_garantias') }}
    where ltv_pct is not null

)

select
    ltv_pct
from ltvs
where ltv_pct < 0
   or ltv_pct > 10
