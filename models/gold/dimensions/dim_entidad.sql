-- =============================================================================
-- dim_entidad
-- Fuente: stg_f3__tipo_entidad_financiera
-- Destino: CGOLD (table)
-- -----------------------------------------------------------------------------
-- QUE HACE
-- Dimension de entidades financieras acreedoras: una fila por tipo de entidad
-- que reporta deuda a la central de riesgos.
--
-- GRAIN
-- tipo_entidad_id.
--
-- POR QUE ES UNA DIMENSION Y NO UN ATRIBUTO
-- -----------------------------------------
-- La entidad financiera es un atributo de la deuda externa, pero es una
-- dimension que el negocio usa para cortar (con cuantas instituciones
-- distintas tiene deuda un cliente, que tipo de entidades le prestan). Si no
-- existiera como dimension propia, el tablero tendria que arrastrar la tabla
-- completa de deudas solo para agrupar por entidad.
--
-- LA RELACION CON int_deuda
-- -------------------------
-- int_deuda ya trae entidad_financiera_id, nombre_entidad y descripcion_entidad.
-- Esta dimension es el catalogo completo; int_deuda es el uso que se hace de
-- el. Se unen por entidad_financiera_id = tipo_entidad_id.
-- =============================================================================

select
    tipo_entidad_id,
    {{ limpiar_texto('nombre_tipo') }}          as nombre_entidad,
    {{ limpiar_texto('descripcion') }}          as descripcion_entidad,
    'F3'                                       as fuente
from {{ ref('stg_f3__tipo_entidad_financiera') }}
