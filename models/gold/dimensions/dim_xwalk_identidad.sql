-- =============================================================================
-- dim_xwalk_identidad
-- Fuente: int_identidad_resuelta
-- Destino: CGOLD (table)
-- -----------------------------------------------------------------------------
-- QUE HACE
-- Crosswalk de identidad: una fila por cliente, con su identidad canonica y
-- las fuentes que la confirman.
--
-- GRAIN
-- cliente_id.
--
-- QUE ES UN CROSSWALK
-- -------------------
-- Un crosswalk es la tabla que dice "estas N identidades de N fuentes
-- distintas son la misma persona". Es la pieza que hace posible unir F1 con
-- F2, F3, F4, F5 y F6 sin que cada join tenga que rehacer la normalizacion.
--
-- POR QUE ES UNA DIMENSION Y NO UN HECHO
-- --------------------------------------
-- No es un hecho porque no tiene medidas ni grano de evento: es un atributo
-- del cliente. Cualquier modelo que necesite la identidad canonica de un
-- cliente se une a esta tabla, en vez de recalcular la normalizacion.
--
-- LAS FUENTES
-- -----------
-- fuentes_vistas es la lista de fuentes donde aparecio la identidad (F1, F2,
-- F3, F4, F5, F6). fuentes_confirmantes es cuantas de esas fuentes la
-- confirmaron con una identidad valida de 9 digitos. identidad_confirmada es
-- true cuando fuentes_confirmantes >= 2 (el umbral del proyecto).
--
-- UN CLIENTE PUEDE TENER VARIAS FILAS
-- -----------------------------------
-- Si un cliente tiene dos identidades distintas que no se pudieron reconciliar
-- (por ejemplo, una con 9 digitos y otra con 8), aparece dos veces. El tablero
-- debe saber que un cliente_id puede tener mas de una identidad canonica.
-- =============================================================================

select
    cliente_id,
    ci_canonico,
    ci_como_llego,
    tipo_id,
    es_persona_juridica,
    nit_empresa,
    ci_representante_legal,
    nombre_completo,
    nombre_representante_legal,
    estado_cliente,
    fecha_creacion,
    fuentes_confirmantes,
    fuentes_vistas,
    identidad_confirmada,
    'F1'                                       as fuente
from {{ ref('int_identidad_resuelta') }}
