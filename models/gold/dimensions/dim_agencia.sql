-- =============================================================================
-- dim_agencia
-- Fuente: stg_f1__agencia
-- Destino: CGOLD (table)
-- -----------------------------------------------------------------------------
-- QUE HACE
-- Dimension de agencias: una fila por agencia, con su ubicacion y tipo.
--
-- GRAIN
-- agencia_id.
--
-- EL DEPARTAMENTO
-- ---------------
-- departamento vive en la agencia, no en una tabla aparte. Se conserva aqui
-- y se expone tambien como dim_departamento para que el tablero pueda
-- agrupar por departamento sin tener que recordar que esta dentro de
-- dim_agencia.
-- =============================================================================

select
    agencia_id,
    {{ limpiar_texto('nombre_agencia') }}       as nombre_agencia,
    {{ limpiar_codigo('codigo_agencia') }}      as codigo_agencia,
    {{ limpiar_texto('departamento') }}         as departamento,
    {{ limpiar_codigo('tipo_agencia') }}        as tipo_agencia,
    {{ limpiar_codigo('estado_agencia') }}      as estado_agencia,
    'F1'                                       as fuente
from {{ ref('stg_f1__agencia') }}
