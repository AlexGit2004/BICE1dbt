-- =============================================================================
-- dim_tipo_garantia
-- Fuente: int_garantias
-- Destino: CGOLD (table)
-- -----------------------------------------------------------------------------
-- QUE HACE
-- Dimension de tipos de garantia: una fila por tipo de garantia que el banco
-- acepta.
--
-- GRAIN
-- tipo_garantia.
--
-- POR QUE DESDE int_garantias
-- --------------------------
-- El tipo de garantia se limpio en int_garantias con limpiar_codigo. La
-- dimension lo enumera para que el tablero pueda agrupar por tipo de garantia
-- (hipotecaria, prendaria, personal) sin tener que recordar como se escribe
-- cada una en la fuente.
--
-- LA RELACION CON fact_garantias
-- ------------------------------
-- fact_garantias trae tipo_garantia ya limpio. Se une a esta dimension para
-- obtener el catalogo completo, incluyendo los tipos que hoy no tienen
-- garantias vigentes pero que el banco acepta.
-- =============================================================================

with tipos as (

    select
        tipo_garantia
    from {{ ref('int_garantias') }}

)

select
    tipo_garantia,
    'F1'                                       as fuente
from tipos
where tipo_garantia is not null
group by tipo_garantia
