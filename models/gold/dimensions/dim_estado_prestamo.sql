-- =============================================================================
-- dim_estado_prestamo
-- Fuente: int_prestamos
-- Destino: CGOLD (table)
-- -----------------------------------------------------------------------------
-- QUE HACE
-- Dimension de estados de prestamo: una fila por estado contractual.
--
-- GRAIN
-- estado_prestamo.
--
-- POR QUE DESDE int_prestamos
-- --------------------------
-- El estado del prestamo se calcula en int_prestamos con el macro
-- clasificar_vencimiento, a partir de la fecha de vencimiento y la fecha de
-- corte. No viene de la fuente: es una decision del DW. Por eso la dimension
-- se construye desde el intermediario, no desde staging.
--
-- LOS ESTADOS
-- -----------
--   Vigente     -> fecha de vencimiento en el futuro
--   Por vencer   -> vence en los proximos 30 dias
--   Vencido     -> ya vencio
--   Sin fecha    -> no tiene fecha de vencimiento
--
-- Son mutuamente excluyentes y cubren todos los casos: un prestamo cae en
-- exactamente uno.
-- =============================================================================

with estados as (

    select
        estado_prestamo
    from {{ ref('int_prestamos') }}

)

select
    estado_prestamo,
    'F1'                                       as fuente
from estados
where estado_prestamo is not null
group by estado_prestamo
