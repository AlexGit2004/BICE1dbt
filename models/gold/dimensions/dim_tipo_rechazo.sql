-- =============================================================================
-- dim_tipo_rechazo
-- Fuente: stg_f1__tipo_rechazo
-- Destino: CGOLD (table)
-- -----------------------------------------------------------------------------
-- QUE HACE
-- Dimension de motivos de rechazo de solicitud: una fila por tipo de rechazo.
--
-- GRAIN
-- tipo_rechazo_id.
--
-- PARA QUE SIRVE
-- --------------
-- Cuando una solicitud se rechaza, el banco registra el motivo. Esta dimension
-- permite agrupar los rechazos por categoria (capacidad de pago, documentacion,
-- riesgo) y ver cual es el motivo mas comun. Sin ella, el tablero solo podria
-- contar rechazos, no entender por que se rechazaron.
-- =============================================================================

select
    tipo_rechazo_id,
    {{ limpiar_texto('nombre_motivo') }}        as nombre_motivo,
    {{ limpiar_codigo('categoria') }}           as categoria,
    'F1'                                       as fuente
from {{ ref('stg_f1__tipo_rechazo') }}
