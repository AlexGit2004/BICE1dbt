-- =============================================================================
-- Test singular: bucket_mora consistente con dias_atraso
-- -----------------------------------------------------------------------------
-- Verifica que el bucket de mora es consistente con los dias de atraso.
--
-- Si este test falla, el macro bucket_mora tiene cortes distintos a los
-- declarados en dbt_project.yml, y el tablero de cobranza no cuadra con el
-- de cartera.
-- =============================================================================

with buckets as (

    select
        dias_atraso,
        bucket_mora
    from {{ ref('int_prestamos') }}
    where dias_atraso is not null

)

select
    dias_atraso,
    bucket_mora
from buckets
where (dias_atraso = 0 and bucket_mora <> 'Al dia')
   or (dias_atraso between 1 and 30 and bucket_mora <> 'Leve')
   or (dias_atraso between 31 and 60 and bucket_mora <> 'Moderada')
   or (dias_atraso between 61 and 90 and bucket_mora <> 'Severa')
   or (dias_atraso > 90 and bucket_mora <> 'Critica')
