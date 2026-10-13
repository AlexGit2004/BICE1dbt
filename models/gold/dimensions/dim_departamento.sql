-- =============================================================================
-- dim_departamento
-- Fuente: stg_f1__agencia
-- Destino: CGOLD (table)
-- -----------------------------------------------------------------------------
-- QUE HACE
-- Dimension de departamentos: una fila por departamento donde el banco tiene
-- agencia.
--
-- GRAIN
-- departamento.
--
-- POR QUE ES UNA DIMENSION PROPIA
-- ------------------------------
-- El departamento es un atributo de la agencia, pero es una de las dimensiones
-- que el negocio usa para cortar (cartera por departamento, mora por
-- departamento). Si no existiera como dimension propia, el tablero tendria que
-- arrastrar dim_agencia completa solo para agrupar por departamento, y dos
-- agencias del mismo departamento no podrian compararse directamente.
--
-- SE CONSTRUYE DESDE AGENCIA PORQUE NO HAY CATALOGO
-- --------------------------------------------------
-- No existe una tabla de departamentos en ninguna de las 7 fuentes. Se deriva
-- de las agencias, con distinct. Si en el futuro se carga un catalogo
-- oficial, este modelo se cambia de fuente sin tocar los hechos.
-- =============================================================================

with agencias as (

    select
        {{ limpiar_texto('departamento') }}     as departamento
    from {{ ref('stg_f1__agencia') }}

)

select
    departamento,
    'F1'                                       as fuente
from agencias
where departamento is not null
group by departamento
