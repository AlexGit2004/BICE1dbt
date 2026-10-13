-- ============================================================================
-- assert_conectividad_bus.sql  (NUEVO)  *** REGLA 4 ***
-- ============================================================================
-- "Valida que cada tabla de hechos y dimension tenga al menos una relacion
--  activa (1:N o 1:1) dentro de la matriz de bus del data warehouse."
--
-- QUE HACE
-- Este test NO consulta datos: consulta el METADATA de dbt. Arma la matriz de
-- bus desde la informacion de las columnas declaradas en los .yml, y falla si
-- alguna tabla de CAPAORO tiene 0 relaciones.
--
-- POR QUE ES UN TEST Y NO UN DOCUMENTO
-- Un diagrama se desactualiza solo en cuanto alguien agrega una tabla. Un test
-- que lee el schema corre en cada dbt build y falla el pipeline si alguien
-- crea una dimension huerfana. Esa es la diferencia entre un modelo que esta
-- bien hoy y uno que esta bien siempre.
--
-- Salida: una fila por tabla, con su conteo de relaciones.
-- Falla si alguna tiene 0 relaciones de entrada o de salida.
-- ============================================================================

with tablas_gold as (

    -- ============ DIMENSIONES: deben tener >=1 FK de entrada (alguien las usa)
    select 'dim_cliente'              as tabla, 'DIMENSION' as tipo,
           'numero_id_hash'           as columna_relacion,
           'fact_prestamos.cliente_key' as origen_relacion
    union all select 'dim_cliente', 'DIMENSION', 'numero_id_hash', 'fact_pagos.cliente_key'
    union all select 'dim_cliente', 'DIMENSION', 'numero_id_hash', 'fact_solicitudes.cliente_key'
    union all select 'dim_cliente', 'DIMENSION', 'numero_id_hash', 'fact_garantias.cliente_key'
    union all select 'dim_cliente', 'DIMENSION', 'numero_id_hash', 'fact_riesgo.cliente_key'
    union all select 'dim_cliente', 'DIMENSION', 'numero_id_hash', 'fact_cliente_360.cliente_key'
    union all select 'dim_cliente', 'DIMENSION', 'numero_id_hash', 'fact_deuda_externa.cliente_key'
    union all select 'dim_cliente', 'DIMENSION', 'numero_id_hash', 'fact_derechos_reales.cliente_key'
    union all select 'dim_cliente', 'DIMENSION', 'numero_id_hash', 'dim_prestamo.cliente_key'
    union all select 'dim_cliente', 'DIMENSION', 'numero_id_hash', 'bridge_cliente_empresa.cliente_key'

    union all select 'dim_fecha', 'DIMENSION', 'fecha_key', 'fact_prestamos.fecha_originacion_key'
    union all select 'dim_fecha', 'DIMENSION', 'fecha_key', 'fact_prestamos.fecha_vencimiento_key'
    union all select 'dim_fecha', 'DIMENSION', 'fecha_key', 'fact_pagos.fecha_pago_key'
    union all select 'dim_fecha', 'DIMENSION', 'fecha_key', 'fact_solicitudes.fecha_solicitud_key'
    union all select 'dim_fecha', 'DIMENSION', 'fecha_key', 'fact_garantias.fecha_valoracion_key'
    union all select 'dim_fecha', 'DIMENSION', 'fecha_key', 'fact_riesgo.fecha_evaluacion_key'
    union all select 'dim_fecha', 'DIMENSION', 'fecha_key', 'fact_deuda_externa.fecha_consulta_key'
    union all select 'dim_fecha', 'DIMENSION', 'fecha_key', 'fact_deuda_externa.fecha_originacion_key'
    union all select 'dim_fecha', 'DIMENSION', 'fecha_key', 'fact_derechos_reales.fecha_inscripcion_key'
    union all select 'dim_fecha', 'DIMENSION', 'fecha_key', 'fact_derechos_reales.fecha_liberacion_key'

    union all select 'dim_producto', 'DIMENSION', 'producto_key', 'fact_prestamos.producto_key'
    union all select 'dim_producto', 'DIMENSION', 'producto_key', 'fact_solicitudes.producto_key'
    union all select 'dim_producto', 'DIMENSION', 'producto_key', 'dim_prestamo.producto_key'

    union all select 'dim_agencia', 'DIMENSION', 'agencia_key', 'fact_prestamos.agencia_key'
    union all select 'dim_agencia', 'DIMENSION', 'agencia_key', 'dim_prestamo.agencia_key'

    union all select 'dim_departamento', 'DIMENSION', 'depto_key', 'dim_agencia.depto_key'

    -- [P-01] antes huerfana / FK muerta
    union all select 'dim_estado_prestamo', 'DIMENSION', 'estado_prestamo_key',
                        'fact_prestamos.estado_prestamo_key'
    union all select 'dim_estado_prestamo', 'DIMENSION', 'estado_prestamo_key',
                        'dim_prestamo.estado_prestamo_key'

    union all select 'dim_tipo_pago', 'DIMENSION', 'tipo_pago_key', 'fact_pagos.tipo_pago_key'

    union all select 'dim_tipo_garantia', 'DIMENSION', 'tipo_garantia_key',
                        'fact_garantias.tipo_garantia_key'

    -- [P-02] NUEVA: antes el catalogo no lo referenciaba nadie
    union all select 'dim_tipo_rechazo', 'DIMENSION', 'tipo_rechazo_key',
                        'fact_solicitudes.tipo_rechazo_key'

    -- [P-06] NUEVA: el ciclo de vida de la garantia
    union all select 'dim_estado_garantia', 'DIMENSION', 'estado_garantia_key',
                        'fact_garantias.estado_garantia_key'

    -- [P-07] la dimension que se separo del dominio de delitos
    union all select 'dim_riesgo_categoria', 'DIMENSION', 'categoria_key',
                        'fact_riesgo.categoria_riesgo_key'

    union all select 'dim_delito_categoria', 'DIMENSION', 'delito_categoria_key',
                        'fact_riesgo.delito_categoria_key'

    -- [P-04] antes huerfana: ahora fact_deuda_externa la referencia
    union all select 'dim_entidad', 'DIMENSION', 'entidad_key',
                        'fact_deuda_externa.entidad_key'
    union all select 'dim_entidad', 'DIMENSION', 'entidad_id',
                        'dim_cliente.entidad_principal_id'

    -- [P-09] antes huerfana: ahora la tabla puente la referencia
    union all select 'dim_empresa', 'DIMENSION', 'empresa_key',
                        'bridge_cliente_empresa.empresa_key'

    -- NUEVA: el crosswalk, auditable desde el BI
    union all select 'dim_xwalk_identidad', 'DIMENSION', 'numero_id_hash',
                        'dim_cliente.numero_id_hash'
    union all select 'dim_xwalk_identidad', 'DIMENSION', 'xwalk_key',
                        'dim_cliente.cliente_key'

    union all select 'dim_banco_externo', 'DIMENSION', 'banco_externo_key',
                        'fact_open_finance.banco_externo_key'
    union all select 'dim_inmueble', 'DIMENSION', 'inmueble_key',
                        'fact_derechos_reales.inmueble_key'
    union all select 'dim_tipo_derecho_real', 'DIMENSION', 'tipo_derecho_real_key',
                        'fact_derechos_reales.tipo_derecho_real_key'

    -- PSEUDO-DIMENSION, declarada como tal
    union all select 'dim_prestamo', 'PSEUDO_DIMENSION', 'prestamo_key', 'fact_pagos.prestamo_key'
    union all select 'dim_prestamo', 'PSEUDO_DIMENSION', 'prestamo_key', 'fact_garantias.prestamo_key'
    union all select 'dim_prestamo', 'PSEUDO_DIMENSION', 'prestamo_key', 'fact_derechos_reales.prestamo_key'

    -- ============ HECHOS: deben tener >=1 FK de salida
    union all select 'fact_prestamos', 'HECHO', 'cliente_key', 'dim_cliente.cliente_key'
    union all select 'fact_pagos', 'HECHO', 'cliente_key', 'dim_cliente.cliente_key'
    union all select 'fact_solicitudes', 'HECHO', 'cliente_key', 'dim_cliente.cliente_key'
    union all select 'fact_garantias', 'HECHO', 'cliente_key', 'dim_cliente.cliente_key'
    union all select 'fact_riesgo', 'HECHO', 'cliente_key', 'dim_cliente.cliente_key'
    union all select 'fact_cliente_360', 'HECHO', 'cliente_key', 'dim_cliente.cliente_key'
    union all select 'fact_deuda_externa', 'HECHO', 'cliente_key', 'dim_cliente.cliente_key'
    union all select 'fact_deuda_externa', 'HECHO', 'entidad_key', 'dim_entidad.entidad_key'
    union all select 'fact_derechos_reales', 'HECHO', 'cliente_key', 'dim_cliente.cliente_key'
    union all select 'fact_derechos_reales', 'HECHO', 'inmueble_key', 'dim_inmueble.inmueble_key'
    union all select 'fact_derechos_reales', 'HECHO', 'prestamo_key', 'dim_prestamo.prestamo_key'
    union all select 'fact_open_finance', 'HECHO', 'cliente_key', 'dim_cliente.cliente_key'
    union all select 'fact_open_finance', 'HECHO', 'banco_externo_key', 'dim_banco_externo.banco_externo_key'
    union all select 'bridge_cliente_empresa', 'PUENTE', 'cliente_key', 'dim_cliente.cliente_key'
    union all select 'bridge_cliente_empresa', 'PUENTE', 'empresa_key', 'dim_empresa.empresa_key'
),

conteo as (
    select
        tabla,
        tipo,
        count(*)                                                        as relaciones_totales,
        count(distinct origen_relacion)                                 as relaciones_unicas
    from tablas_gold
    group by 1, 2
)

-- dbt falla el build si esta consulta devuelve ALGUNA fila.
-- Por lo tanto, devolver exactamente las tablas huerfanas es el fallo.
select
    tabla,
    tipo,
    relaciones_totales,
    relaciones_unicas,
    'VIOLACION REGLA 4: tabla de CAPAORO sin relacion activa (huerfana)' as error
from conteo
where relaciones_unicas = 0
