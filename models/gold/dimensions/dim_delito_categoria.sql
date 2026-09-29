-- =============================================================================
-- dim_delito_categoria
-- Fuente: stg_f2__categoria_delito
-- Destino: CGOLD (table)
-- -----------------------------------------------------------------------------
-- QUE HACE
-- Dimension de categorias de delito: una fila por categoria de delito penal.
--
-- GRAIN
-- categoria_delito_id.
--
-- PARA QUE SIRVE
-- --------------
-- Cuando un cliente tiene antecedentes penales, F2 registra el tipo de delito.
-- Esta dimension permite agrupar los antecedentes por categoria (violencia,
-- fraude, patrimonio) y ver cual es la mas comun. Sin ella, el tablero solo
-- podria decir "tiene antecedentes", no entender que tipo de riesgo representa.
--
-- LA RELACION CON int_riesgo_cliente
-- ----------------------------------
-- int_riesgo_cliente trae delitos_distintos y delito_ejemplo, que son el
-- resumen del cruce con F2. Esta dimension es el catalogo completo de
-- categorias; el resumen del cliente se une a esta dimension para entender
-- que significa.
-- =============================================================================

select
    categoria_delito_id,
    {{ limpiar_texto('nombre_categoria') }}     as nombre_categoria,
    {{ limpiar_texto('descripcion') }}          as descripcion,
    'F2'                                       as fuente
from {{ ref('stg_f2__categoria_delito') }}
