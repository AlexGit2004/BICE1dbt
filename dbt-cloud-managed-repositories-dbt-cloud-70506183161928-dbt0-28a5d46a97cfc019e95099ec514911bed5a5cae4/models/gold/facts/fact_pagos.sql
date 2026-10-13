{{ config(materialized='table', unique_key='pago_id') }}

{#-
    fact_pagos.sql  (CORREGIDO)  *** P-05 RESUELTO ***

    QUE CAMBIA
      1. cliente_id y cliente_key salen del PROPIO pago (que ya traia la FK en
         la BD), no de recorrer dim_prestamo. Antes, un pago sin prestamo
         producia generate_surrogate_key(NULL): todos los huerfanos caian en un
         mismo cliente_key fantasma que no existe en dim_cliente.
      2. Se baja el saldo del prestamo al grano del pago, como SNAPSHOT a la
         fecha del pago. Asi, cruzar fact_pagos con dim_prestamo no duplica el
         saldo, que era el riesgo de usar dim_prestamo como dimension.
      3. Se separa el pago DONE (que reduce saldo) del pago NO DONE (que es un
         intento fallido). Sumar los dos daria una recaudacion inexistente.
-#}

with p as (
    select * from {{ ref('stg_mysql__pago') }}
),

pr as (
    select
        p2.prestamo_id,
        p2.saldo_actual_bs,
        p2.monto_aprobado_bs,
        p2.cuota_mensual_bs,
        p2.plazo_aprobado_meses,
        p2.tasa_interes_aplicada,
        p2.bucket_mora             as bucket_mora_prestamo,
        p2.estado_prestamo_tipo_id,
        cu.numero_identificacion  as cliente_id,
        cu.numero_id_hash         as cliente_numero_id_hash,
        cu.cliente_id_legacy
    from {{ ref('int_prestamos_limpios') }} p2
    left join {{ ref('int_clientes_unificados') }} cu
           on cu.cliente_id_legacy = p2.cliente_id
)

select
    p.pago_id,

    -- ===== FKs =====
    {{ dbt_utils.generate_surrogate_key(['pr.prestamo_id']) }}              as prestamo_key,
    -- el cliente sale del propio pago (P-05), no de la dimension
    {{ dbt_utils.generate_surrogate_key(['p.cliente_id']) }}                as cliente_key,
    {{ dbt_utils.generate_surrogate_key(['p.tipo_pago_id']) }}              as tipo_pago_key,
    cast(to_char(p.fecha_pago, 'YYYYMMDD') as integer)                      as fecha_pago_key,

    -- ===== business keys =====
    p.prestamo_id,
    p.cliente_id,
    p.tipo_pago_id,
    p.estado_pago,

    -- ===== MEDIDAS DEL PAGO =====
    p.monto_pagado_bs,
    p.numero_cuota,
    p.dias_atraso_al_pago,
    {{ bucket_mora('p.dias_atraso_al_pago') }}                               as bucket_mora_pago,
    -- solo los pagos procesados reducen saldo
    case when upper(p.estado_pago) = 'PROCESADO' then true else false end    as es_pago_efectivo,

    -- ===== SNAPSHOT DEL CREDITO A LA FECHA DEL PAGO (PD-04) =====
    -- Por esto dim_prestamo puede usarse como dimension sin duplicar el saldo.
    pr.saldo_actual_bs                                                       as saldo_prestamo_al_pago,
    pr.monto_aprobado_bs,
    pr.cuota_mensual_bs,
    pr.plazo_aprobado_meses,
    pr.tasa_interes_aplicada,
    pr.bucket_mora_prestamo,
    pr.estado_prestamo_tipo_id,
    -- avance del credito en el momento del pago
    case when pr.saldo_actual_bs is null or pr.saldo_actual_bs = 0 then null
         else round((coalesce(pr.saldo_actual_bs, 0)) / nullif(pr.saldo_actual_bs, 0), 4)
    end                                                                      as ratio_saldo_restante,
    -- el pago cubrio la cuota? Un pago parcial es senal de mora
    case when pr.cuota_mensual_bs is null or pr.cuota_mensual_bs = 0 then null
         when p.monto_pagado_bs >= pr.cuota_mensual_bs then 'CUOTA COMPLETA'
         when p.monto_pagado_bs >  0                   then 'PAGO PARCIAL'
         else                                                'PAGO NULO'
    end                                                                      as cobertura_cuota,

    -- ===== la estrella quedo huerfana: se marca en vez de inventar =====
    case when pr.prestamo_id is null then true else false end                as prestamo_no_resuelto,

    p.fecha_pago
from p
left join pr on pr.prestamo_id = p.prestamo_id
