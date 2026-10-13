{{ config(materialized='table', unique_key='prestamo_key') }}

{#-
    dim_prestamo.sql  (ACTUALIZADO)
    PSEUDO-DIMENSION, y ahora esta DECLARADA como tal.

    Grano de hecho (1 prestamo = 1 fila) con medidas, pero se usa como dimension
    SLEUT: es el puente que permite analizar pagos y garantias dentro del ciclo
    de vida de un credito, que es la pregunta del negocio.

    Se declara explicitamente en el bus matrix como pseudo-dimension, con el
    aviso de que NO se puede hacer SUM(saldo_actual_bs) cruzando fact_pagos
    con esta tabla, porque el saldo se contaria una vez por pago. Para eso esta
    fact_derechos_reales, que baja el saldo al grano del gravamen.
-#}

select
    {{ dbt_utils.generate_surrogate_key(['p.prestamo_id']) }} as prestamo_key,
    p.prestamo_id,
    p.solicitud_id,

    -- ===== FKs que la hacen recorrerse como dimension =====
    cu.numero_id_hash                                            as cliente_numero_id_hash,
    cu.numero_identificacion                                     as cliente_id,
    {{ dbt_utils.generate_surrogate_key(['cu.numero_identificacion']) }} as cliente_key,
    p.agencia_id,
    {{ dbt_utils.generate_surrogate_key(['p.agencia_id']) }}     as agencia_key,
    p.producto_id,
    {{ dbt_utils.generate_surrogate_key(['p.producto_id']) }}    as producto_key,
    p.estado_prestamo_tipo_id,
    {{ dbt_utils.generate_surrogate_key(['p.estado_prestamo_tipo_id']) }}
                                                                  as estado_prestamo_key,
    -- el estado en texto, para no tener que recorrer la dimension en el BI
    e.nombre_estado                                              as estado_prestamo,

    p.fecha_originacion,
    p.fecha_vencimiento,
    p.monto_aprobado_bs,
    p.plazo_aprobado_meses,
    p.tasa_interes_aplicada,
    p.cuota_mensual_bs,
    p.saldo_actual_bs,
    p.dias_atraso,
    p.bucket_mora,
    p.mora_vigente,

    -- atributos heredados de la solicitud (1:1 con prestamo)
    p.estado_solicitud,
    p.monto_solicitado_bs,
    p.plazo_solicitado_meses,
    p.tipo_rechazo_id,

    -- calidad del dato, para poder medir la confianza del DW
    p.vencimiento_calculado
from {{ ref('int_prestamos_limpios') }} p
left join {{ ref('int_clientes_unificados') }} cu
       on cu.cliente_id_legacy = p.cliente_id
left join {{ ref('stg_mysql__estado_prestamo_tipo') }} e
       on e.estado_id = p.estado_prestamo_tipo_id
