-- =============================================================================
-- fact_derechos_reales
-- Fuente: int_derechos_reales
-- Destino: CGOLD (table)
-- -----------------------------------------------------------------------------
-- QUE HACE
-- Hecho de derechos reales inscritos: una fila por inscripcion, con el tipo
-- de derecho, el inmueble, el estado y el vinculo con el credito.
--
-- GRAIN
-- inscripcion_id.
--
-- LAS MEDIDAS
-- -----------
--   monto_base_bs            -> base imponible del derecho
--   monto_garantizado_bs      -> monto que respalda el credito
--   superficie_m2             -> superficie del inmueble
--   valor_comercial_bs       -> valor comercial del inmueble
--   valor_avaluo_inmueble_bs -> valor de avaluo del inmueble
--
-- Son medidas aditivas: se pueden sumar y agrupar. Por eso viven en un hecho.
--
-- EL TIPO DE DERECHO
-- ------------------
-- tipo_derecho_real_id, nombre_tipo_derecho, codigo_tipo_derecho y las tres
-- banderas (es_garantia, es_transmision, requiere_valuacion) identifican el
-- derecho inscrito. Se unen con dim_tipo_derecho_real por tipo_derecho_real_id.
--
-- EL INMUEBLE
-- -----------
-- inmueble_id, matricula_inmueble, tipo_inmueble, departamento_inmueble,
-- zona_inmueble, superficie_m2, valores y estado identifican el bien. Se
-- unen con dim_inmueble por inmueble_id.
--
-- EL VINCULO CON EL CREDITO
-- -------------------------
-- prestamo_id, monto_garantizado_bs, fecha_inscripcion_gravamen,
-- fecha_liberacion_gravamen, estado_gravamen y respalda_credito dicen si la
-- inscripcion respalda un credito de este portafolio. Si no lo respalda, la
-- fila se conserva con respalda_credito = false: un derecho real sin vinculo
-- con el banco sigue siendo un dato valido del registro.
--
-- EL TITULAR
-- ----------
-- titular_identificacion_origen, titular_identidad, cliente_id y
-- titular_reconciliado dicen quien es el titular del derecho. Si no cruza
-- con el nucleo de clientes, la fila se conserva con cliente_id = null y
-- titular_reconciliado = false.
--
-- EL ESTADO DE VENCIMIENTO
-- ------------------------
-- estado_vencimiento se calcula con clasificar_vencimiento, a partir de la
-- fecha de vencimiento y la fecha de corte. antiguedad_inscripcion_meses es
-- cuanto tiempo tiene la inscripcion.
-- =============================================================================

select
    inscripcion_id,
    numero_inscripcion,
    inmueble_id,
    tipo_derecho_real_id,
    nombre_tipo_derecho,
    codigo_tipo_derecho,
    es_garantia,
    es_transmision,
    requiere_valuacion,
    fecha_inscripcion,
    fecha_vencimiento,
    antiguedad_inscripcion_meses,
    estado_vencimiento,
    trimestre_inscripcion,
    matricula_inmueble,
    tipo_inmueble,
    departamento_inmueble,
    zona_inmueble,
    superficie_m2,
    valor_comercial_bs,
    valor_avaluo_inmueble_bs,
    fecha_avaluo_inmueble,
    vigencia_avaluo_inmueble,
    estado_inmueble,
    monto_base_bs,
    notario,
    estado_inscripcion,
    prestamo_id,
    monto_garantizado_bs,
    fecha_inscripcion_gravamen,
    fecha_liberacion_gravamen,
    estado_gravamen,
    respalda_credito,
    titular_identificacion_origen,
    titular_identidad,
    cliente_id,
    titular_reconciliado,
    'F5'                                       as fuente
from {{ ref('int_derechos_reales') }}
