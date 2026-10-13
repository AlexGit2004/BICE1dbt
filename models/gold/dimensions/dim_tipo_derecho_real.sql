-- =============================================================================
-- dim_tipo_derecho_real
-- Fuente: stg_f5__tipo_derecho_real
-- Destino: CGOLD (table)
-- -----------------------------------------------------------------------------
-- QUE HACE
-- Dimension de tipos de derecho real: una fila por tipo de derecho que se
-- puede inscribir sobre un bien.
--
-- GRAIN
-- tipo_derecho_real_id.
--
-- LOS ATRIBUTOS
-- -------------
--   es_garantia        -> el derecho respalda un credito (hipoteca, prenda)
--   es_transmision     -> el derecho transfiere la propiedad (compraventa)
--   requiere_valuacion -> el derecho necesita un avaluo para inscribirse
--
-- Son banderas del catalogo, no decisiones del DW. Se conservan tal cual.
--
-- LA RELACION CON fact_derechos_reales
-- ------------------------------------
-- fact_derechos_reales trae tipo_derecho_real_id, nombre_tipo_derecho,
-- codigo_tipo_derecho y las tres banderas. Esta dimension es el catalogo
-- completo; el hecho es el uso que se hace de el.
-- =============================================================================

select
    tipo_derecho_real_id,
    {{ limpiar_texto('nombre_tipo') }}          as nombre_tipo_derecho,
    {{ limpiar_codigo('codigo') }}              as codigo_tipo_derecho,
    es_garantia,
    es_transmision,
    requiere_valuacion,
    'F5'                                       as fuente
from {{ ref('stg_f5__tipo_derecho_real') }}
