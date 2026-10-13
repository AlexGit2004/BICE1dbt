-- =============================================================================
-- dim_estado_garantia
-- Fuente: int_garantias
-- Destino: CGOLD (table)
-- -----------------------------------------------------------------------------
-- QUE HACE
-- Dimension de estados de garantia: una fila por estado en que puede estar
-- una garantia.
--
-- GRAIN
-- estado_garantia.
--
-- LOS ESTADOS
-- -----------
-- El estado de la garantia viene de la fuente (F1) y se conserva tal cual.
-- No se deriva de ninguna fecha: es un atributo que el banco actualiza
-- manualmente cuando la garantia se constituye, se libera o se ejecuta.
--
-- POR QUE ES UNA DIMENSION
-- -----------------------
-- Es un atributo de la garantia, pero es una de las dimensiones que el negocio
-- usa para cortar (garantias vigentes vs liberadas vs ejecutadas). Si no
-- existiera como dimension propia, el tablero tendria que arrastrar
-- fact_garantias completa solo para agrupar por estado.
-- =============================================================================

with estados as (

    select
        estado_garantia
    from {{ ref('int_garantias') }}

)

select
    estado_garantia,
    'F1'                                       as fuente
from estados
where estado_garantia is not null
group by estado_garantia
