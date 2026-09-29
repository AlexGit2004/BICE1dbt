-- =============================================================================
-- fact_prestamos
-- Fuente: int_prestamos
-- Destino: CGOLD (table)
-- -----------------------------------------------------------------------------
-- QUE HACE
-- Hecho de prestamos: una fila por prestamo, con su monto, saldo, tasa, mora
-- y estado contractual.
--
-- GRAIN
-- prestamo_id.
--
-- LAS MEDIDAS
-- -----------
--   monto_aprobado_bs      -> lo que se le presto
--   saldo_actual_bs        -> lo que debe hoy
--   cuota_mensual_bs       -> lo que paga cada mes
--   dias_atraso            -> cuantos dias lleva en mora
--   saldo_sobre_aprobado_pct -> saldo / monto aprobado (desgaste del credito)
--   spread_sobre_base_pct  -> tasa aplicada - tasa base (margen del banco)
--
-- Son medidas aditivas: se pueden sumar, promediar y agrupar. Por eso viven
-- en un hecho y no en una dimension.
--
-- EL ESTADO CONTRACTUAL
-- ---------------------
-- estado_prestamo se calcula con clasificar_vencimiento, a partir de la
-- fecha de vencimiento y la fecha de corte. Es una decision del DW, no un
-- dato de la fuente.
--
-- LA MORA
-- -------
-- bucket_mora clasifica los dias de atraso en 5 buckets (Al dia, Leve,
-- Moderada, Severa, Critica). mora_vigente es true cuando los dias de atraso
-- superan el umbral de 90 dias. Ambos vienen de int_prestamos, que ya los
-- calculo con el macro bucket_mora.
--
-- NO SE UNE CON dim_fecha AQUI
-- -----------------------------
-- Las fechas (fecha_originacion, fecha_vencimiento) se dejan como columnas de
-- fecha crudas. El tablero las une con dim_fecha cuando necesita agrupar por
-- mes o trimestre. No se hace el join aqui porque duplicaria el hecho si un
-- prestamo tuviera varias fechas relevantes.
-- =============================================================================

select
    prestamo_id,
    solicitud_id,
    cliente_id,
    producto_id,
    agencia_id,
    fecha_originacion,
    fecha_vencimiento,
    antiguedad_dias,
    antiguedad_meses,
    estado_prestamo,
    tipo_producto,
    nombre_producto,
    estado_producto,
    monto_aprobado_bs,
    cuota_mensual_bs,
    saldo_actual_bs,
    tasa_interes_aplicada,
    plazo_aprobado_meses,
    tasa_interes_base,
    plazo_minimo_mes,
    plazo_maximo_mes,
    dias_atraso,
    dias_mora_ultimo_pago,
    bucket_mora,
    mora_vigente,
    estado_vencimiento,
    nombre_agencia,
    departamento_agencia,
    tipo_agencia,
    estado_agencia,
    fecha_solicitud,
    monto_solicitado_bs,
    plazo_solicitado_mes,
    estado_solicitud,
    fecha_nacimiento,
    sexo,
    estado_civil,
    nacionalidad,
    profesion,
    edad_anios,
    saldo_sobre_aprobado_pct,
    spread_sobre_base_pct,
    'F1'                                       as fuente
from {{ ref('int_prestamos') }}
