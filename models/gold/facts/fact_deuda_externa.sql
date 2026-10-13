-- =============================================================================
-- fact_deuda_externa
-- Fuente: int_deuda
-- Destino: CGOLD (table)
-- -----------------------------------------------------------------------------
-- QUE HACE
-- Hecho de deuda externa: una fila por obligacion reportada a la central de
-- riesgos, con el monto, la mora y la entidad acreedora.
--
-- GRAIN
-- deuda_id.
--
-- LAS MEDIDAS
-- -----------
--   monto_deuda_actual_bs   -> lo que se debe hoy en esa obligacion
--   dias_atraso_actual      -> dias de atraso de esa obligacion
--   deudor_monto_total_bs   -> deuda total del deudor (todas las obligaciones)
--   deudor_cantidad_instituciones -> cuantas entidades le prestan
--
-- OJO: monto_deuda_actual_bs y deudor_monto_total_bs NO se suman entre si.
-- La primera es una obligacion; la segunda es el total del deudor. Sumarlas
-- seria contar dos veces la misma deuda.
--
-- LA ENTIDAD
-- ----------
-- entidad_financiera_id, nombre_entidad y descripcion_entidad identifican al
-- acreedor. Se unen con dim_entidad por entidad_financiera_id = tipo_entidad_id.
--
-- EL CLIENTE
-- ----------
-- cliente_id e identidad_cliente vienen del cruce con int_riesgo_cliente, que
-- ya resolvio deudor_id_cr -> cliente_id. Si el deudor no cruza con ningun
-- cliente del nucleo, la fila se conserva con cliente_id = null: perder una
-- deuda porque su deudor no esta en el nucleo seria subestimar la deuda
-- externa del sistema.
--
-- LA MORA
-- -------
-- bucket_mora clasifica los dias de atraso. en_mora es true cuando los dias
-- de atraso son mayores a 0. Ambos vienen de int_deuda, que ya los calculo.
-- =============================================================================

select
    deuda_id,
    deudor_id,
    cliente_id,
    identidad_cliente,
    categoria_riesgo_cliente,
    score_morosidad_cliente,
    tipo_obligacion,
    monto_deuda_actual_bs,
    dias_atraso_actual,
    fecha_origenacion_deuda,
    fecha_consulta,
    bucket_mora,
    en_mora,
    entidad_financiera_id,
    nombre_entidad,
    descripcion_entidad,
    deudor_cantidad_instituciones,
    deudor_monto_total_bs,
    deudor_fecha_ultima_consulta,
    trimestre_consulta,
    'F3'                                       as fuente
from {{ ref('int_deuda') }}
