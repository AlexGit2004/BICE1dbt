-- =============================================================================
-- dim_producto
-- Fuente: stg_f1__producto_crediticio
-- Destino: CGOLD (table)
-- -----------------------------------------------------------------------------
-- QUE HACE
-- Dimension de productos crediticios: una fila por producto, con sus
-- condiciones comerciales (tasa, plazo, montos).
--
-- GRAIN
-- producto_id.
--
-- POR QUE DESDE STAGING Y NO DESDE int_prestamos
-- ----------------------------------------------
-- int_prestamos trae los atributos del producto repetidos en cada prestamo
-- (141.000 filas). La dimension los resume a una fila por producto. Si se
-- construyera desde int_prestamos habria que hacer distinct, y el distinct
-- sobre 141.000 filas es mas caro y mas fragil que leer las 10 filas del
-- catalogo.
--
-- EL ESTADO
-- ---------
-- estado_producto dice si el producto esta activo, inactivo o en evaluacion.
-- Se conserva tal cual, sin reinterpretar: es un dato del catalogo, no una
-- decision del DW.
-- =============================================================================

select
    producto_id,
    {{ limpiar_texto('nombre_producto') }}     as nombre_producto,
    {{ limpiar_codigo('tipo_producto') }}      as tipo_producto,
    tasa_interes_base,
    plazo_minimo_meses,
    plazo_maximo_meses,
    monto_minimo_bs,
    monto_maximo_bs,
    {{ limpiar_codigo('estado_producto') }}    as estado_producto,
    'F1'                                       as fuente
from {{ ref('stg_f1__producto_crediticio') }}
