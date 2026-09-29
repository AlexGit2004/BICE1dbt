-- =============================================================================
-- fact_garantias
-- Fuente: int_garantias
-- Destino: CGOLD (table)
-- -----------------------------------------------------------------------------
-- QUE HACE
-- Hecho de garantias: una fila por garantia, con su tipo, avaluo, LTV y
-- cobertura.
--
-- GRAIN
-- garantia_id.
--
-- LAS MEDIDAS
-- -----------
--   valor_avaluo_bs          -> valor del bien que respalda
--   saldo_prestamo_bs        -> saldo del credito que respalda
--   ltv_pct                  -> saldo / avaluo (peso del credito sobre el bien)
--   cobertura_prestamo_pct   -> porcentaje que el garante cubre
--
-- Son medidas aditivas: se pueden sumar y agrupar. Por eso viven en un hecho.
--
-- EL LTV
-- -----
-- ltv_pct es el loan to value: el peso que tiene el credito sobre el valor
-- del bien. Un LTV alto significa que el bien respalda poco. nivel_ltv
-- clasifica ese peso en 4 niveles (Holgado, Razonable, Ajustado,
-- Sobre-garantizado).
--
-- OJO: este LTV es el de la garantia sobre el inmueble. NO es el ratio entre
-- el saldo y el monto aprobado que calcula int_prestamos. Son dos ratios
-- distintos y no se deben amalgamar.
--
-- LA VIGENCIA DEL AVALUO
-- ----------------------
-- vigencia_avaluo dice si el avaluo sigue siendo utilizable (menos de 3 anos).
-- antiguedad_avaluo_meses es cuanto tiempo tiene. Un avaluo viejo no describe
-- el mercado actual, por eso se marca aparte en vez de descartarlo.
--
-- EL CLIENTE
-- ----------
-- cliente_id viene de int_prestamos, que ya resolvio el prestamo -> cliente.
-- Si el prestamo no cruza, la garantia se conserva con cliente_id = null.
-- =============================================================================

select
    garantia_id,
    prestamo_id,
    cliente_id,
    tipo_garantia,
    descripcion_bien,
    estado_garantia,
    fecha_avaluo,
    vigencia_avaluo,
    antiguedad_avaluo_meses,
    saldo_prestamo_bs,
    monto_aprobado_bs,
    estado_prestamo,
    bucket_mora_prestamo,
    fecha_vencimiento_prestamo,
    valor_avaluo_bs,
    cobertura_prestamo_pct,
    ltv_pct,
    nivel_ltv,
    trimestre_avaluo,
    'F1'                                       as fuente
from {{ ref('int_garantias') }}
