-- =============================================================================
-- Test singular: identidad canonica de 9 digitos
-- -----------------------------------------------------------------------------
-- Verifica que la identidad canonica de int_identidad_resuelta cumple la
-- regla del proyecto: 9 digitos, primero entre 1 y 9.
--
-- Si este test falla, el crosswalk de identidad esta roto y todos los joins
-- entre fuentes (F1 con F2, F3, F4, F5, F6) devuelven cero filas sin error.
-- =============================================================================

with validas as (

    select
        ci_canonico
    from {{ ref('int_identidad_resuelta') }}
    where ci_canonico is not null

)

select
    ci_canonico
from validas
where length(ci_canonico) <> 9
   or not (ci_canonico rlike '^[1-9][0-9]{8}$')
