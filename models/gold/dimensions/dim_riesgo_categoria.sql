-- =============================================================================
-- dim_riesgo_categoria
-- Fuente: int_riesgo_cliente
-- Destino: CGOLD (table)
-- -----------------------------------------------------------------------------
-- QUE HACE
-- Dimension de categorias de riesgo: una fila por categoria estandarizada.
--
-- GRAIN
-- categoria_riesgo.
--
-- EL VOCABULARIO
-- --------------
-- El macro categoria_riesgo estandariza las categorias del proveedor a un
-- vocabulario propio:
--
--   Bajo      <- Sin Riesgo, Bajo, Riesgo Bajo
--   Medio     <- Medio, Riesgo Medio
--   Alto      <- Alto, Riesgo Alto
--   Muy alto  <- Muy Alto, Riesgo Muy Alto, Muy Alta
--   Sin dato  <- null o valor no reconocido
--
-- Son 5 categorias, mutuamente excluyentes. La dimension las enumera para que
-- el tablero pueda mostrarlas en orden (Bajo -> Muy alto) sin tener que
-- recordar el orden alfabetico, que pondria "Muy alto" antes que "Bajo".
--
-- EL ORDEN
-- --------
-- Se agrega un numero de orden para que el tablero las muestre en la escala
-- correcta de riesgo, no en orden alfabetico.
-- =============================================================================

with categorias as (

    select
        categoria_riesgo
    from {{ ref('int_riesgo_cliente') }}

)

select
    categoria_riesgo,
    case categoria_riesgo
        when 'Bajo'      then 1
        when 'Medio'     then 2
        when 'Alto'      then 3
        when 'Muy alto'  then 4
        when 'Sin dato'  then 5
        else 6
    end                                        as orden,
    'F3'                                       as fuente
from categorias
where categoria_riesgo is not null
group by categoria_riesgo
