-- =============================================================================
-- fact_pagos
-- Fuente: int_pagos
-- Destino: CGOLD (table)
-- -----------------------------------------------------------------------------
-- QUE HACE
-- Hecho de pagos: una fila por pago, con el monto, la cuota y la mora al
-- momento del pago.
--
-- GRAIN
-- pago_id.
--
-- LAS MEDIDAS
-- -----------
--   monto_pagado_bs        -> lo que se pago
--   numero_cuota           -> que cuota del prestamo es
--   dias_atraso_al_pago    -> mora que tenia ESE pago cuando se registro
--
-- Son medidas aditivas: se pueden sumar y agrupar. Por eso viven en un hecho.
--
-- LAS DOS MORAS
-- -------------
--   dias_atraso_al_pago  -> la mora del pago en el momento de pagar
--   dias_atraso_actual    -> la mora del prestamo hoy
--
-- Son distintas y no se deben mezclar. Un pago puede haberse hecho al dia
-- (dias_atraso_al_pago = 0) pero el prestamo estar hoy en critica
-- (dias_atraso_actual = 120). El tablero de cobranza mira la primera; el de
-- cartera, la segunda.
--
-- EL ESTADO
-- ---------
-- estado_pago dice si el pago fue aplicado, pendiente, revertido o rechazado.
-- Se conserva tal cual, sin reinterpretar.
--
-- NO SE UNE CON dim_fecha AQUI
-- -----------------------------
-- fecha_pago se deja como columna cruda. El tablero la une con dim_fecha
-- cuando necesita agrupar por mes o trimestre.
-- =============================================================================

select
    pago_id,
    prestamo_id,
    cliente_id,
    fecha_pago,
    monto_pagado_bs,
    numero_cuota,
    tipo_pago,
    estado_pago,
    dias_atraso_al_pago,
    bucket_mora_al_pago,
    pago_en_mora,
    estado_prestamo,
    bucket_mora_actual,
    dias_atraso_actual,
    fecha_vencimiento_prestamo,
    saldo_actual_prestamo,
    monto_aprobado_prestamo,
    tasa_interes,
    trimestre_pago,
    mes_pago,
    'F1'                                       as fuente
from {{ ref('int_pagos') }}
