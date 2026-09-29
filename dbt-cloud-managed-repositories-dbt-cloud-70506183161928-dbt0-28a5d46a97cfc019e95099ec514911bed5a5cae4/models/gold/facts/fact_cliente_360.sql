{{ config(materialized='table', unique_key='cliente_id') }}

{#-
    fact_cliente_360.sql  (REESCRITO)

    No es una estrella mas: es la vista agregada de la cima del cubo, la que
    consume el dashboard del Director. Grano: 1 fila por cliente, y por eso su
    PK es la misma FK que la de dim_cliente (relacion 1:1 declarada).

    QUE CAMBIA
      1. Los ratios ahora tienenSnapshot de saldo al grano del hecho, para que
         la vista 360 y la estrella de pagos no se contradigan.
      2. Se agrega la exposicion por institucion acreedora, que es lo que pedia
         la regla 3 para conectar dim_entidad tambien desde aqui.
      3. Se agrega la exposicion del grupo economico, desde la tabla puente.
      4. Se declara explicitamente que ingreso_mensual_bs y los ratios laborales
         dependen de F6, que es la fuente mas debil del DW (peso 0.60 en el
         crosswalk). Se expone la confianza del dato, no se lo disimula.
-#}

with dim as (
    select
        cliente_key,
        cliente_id,
        numero_id_hash,
        ingreso_mensual_bs,
        cumple_capacidad_pago,
        solidez_laboral,
        confianza_ponderada,
        cobertura_identidad,
        estado_riesgo,
        tipo_persona,
        mortgage_vigente,
        valor_garantia_real_bs,
        empresas_vinculadas,
        empresas_creedoras,
        empresas_controladas
    from {{ ref('dim_cliente') }}
),

-- Cartera interna, con el saldo al ultimo pago (no el saldo actual duplicado).
cartera as (
    select
        cliente_numero_id_hash,
        count(distinct prestamo_id)                                as prestamos_internos,
        sum(saldo_actual_bs)                                       as saldo_interno_bs,
        sum(monto_aprobado_bs)                                     as monto_otorgado_bs,
        count(distinct case when mora_vigente
                           then prestamo_id end)                    as prestamos_en_mora,
        count(distinct case when estado_prestamo_tipo_id in (2, 5)
                           then prestamo_id end)                    as prestamos_cerrados,
        sum(case when bucket_mora = '90+ - Critica'
                 then saldo_actual_bs else 0 end)                   as saldo_mora_critica_bs,
        max(dias_atraso)                                            as max_dias_atraso
    from {{ ref('int_prestamos_limpios') }}
    group by 1
),

-- Exposicion externa, agregada por cliente, con la entidad dominante.
externa as (
    select
        dc.numero_id_hash,
        coalesce(dc.deuda_externa_bs, 0)                            as deuda_externa_bs,
        coalesce(dc.total_obligaciones, 0)                          as obligacion_externas,
        coalesce(dc.num_entidades_acreedoras, 0)                    as entidades_acreedoras,
        coalesce(dc.concentracion_entidad, 0)                       as concentracion_principal,
        de.nombre_entidad                                           as entidad_principal,
        de.tipo_entidad                                             as tipo_entidad_principal
    from {{ ref('dim_cliente') }} dc
    left join {{ ref('dim_entidad') }} de
           on de.entidad_id = dc.entidad_principal_id
),

-- Open Finance, ahora con datos reales (P-10 resuelto por el crosswalk).
ofx as (
    select
        numero_id_hash,
        count(distinct producto_id)                                 as productos_externos,
        count(distinct producto_id) filter (where es_producto_activo) as productos_activos,
        count(distinct nombre_banco)                                as bancos_externos,
        avg(tasa_interes)                                           as tasa_promedio_externa
    from {{ ref('int_open_finance_asignaciones') }}
    where numero_id_hash is not null
    group by 1
),

-- Garantia real, agregada al cliente.
garantia as (
    select
        cliente_numero_id_hash,
        count(distinct gravamen_id)                                 as gravamenes_vigentes,
        sum(monto_garantizado_bs)                                   as monto_garantizado_bs,
        max(l.tv_pct)                                               as ltv_pct_max,
        count(distinct case when not titular_es_deudor
                           then gravamen_id end)                    as gravamenes_de_tercero
    from {{ ref('int_derechos_reales_garantia') }}
    where estado_gravamen = 'Vigente'
    group by 1
)

select
    d.cliente_key,
    d.cliente_id,
    d.numero_id_hash,

    -- ===== MEDIDAS: cartera interna =====
    coalesce(c.prestamos_internos, 0)          as prestamos_internos,
    coalesce(c.saldo_interno_bs, 0)            as saldo_interno_bs,
    coalesce(c.monto_otorgado_bs, 0)           as monto_otorgado_bs,
    coalesce(c.prestamos_en_mora, 0)           as prestamos_en_mora,
    coalesce(c.prestamos_cerrados, 0)          as prestamos_cerrados,
    coalesce(c.saldo_mora_critica_bs, 0)       as saldo_mora_critica_bs,
    coalesce(c.max_dias_atraso, 0)             as max_dias_atraso,

    -- ===== MEDIDAS: exposicion externa, CON LA ENTIDAD (regla 3) =====
    coalesce(e.deuda_externa_bs, 0)            as deuda_externa_bs,
    coalesce(e.obligacion_externas, 0)         as obligacion_externas,
    coalesce(e.entidades_acreedoras, 0)        as entidades_acreedoras,
    e.entidad_principal,
    e.tipo_entidad_principal,
    coalesce(e.concentracion_principal, 0)     as concentracion_entidad,

    -- ===== MEDIDAS: Open Finance =====
    coalesce(ofx.productos_externos, 0)         as productos_externos,
    coalesce(ofx.productos_activos, 0)          as productos_activos,
    coalesce(ofx.bancos_externos, 0)            as bancos_externos,
    coalesce(ofx.tasa_promedio_externa, 0)      as tasa_promedio_externa,

    -- ===== MEDIDAS: laboral (PD-02) =====
    coalesce(d.ingreso_mensual_bs, 0)          as ingreso_mensual_bs,
    d.cumple_capacidad_pago,
    d.solidez_laboral,

    -- ===== MEDIDAS: garantia real (F5, PD-08) =====
    coalesce(g.gravamenes_vigentes, 0)         as gravamenes_vigentes,
    coalesce(g.monto_garantizado_bs, 0)         as monto_garantizado_bs,
    g.ltv_pct_max,
    coalesce(g.gravamenes_de_tercero, 0)        as gravamenes_de_tercero,
    d.mortgage_vigente,
    coalesce(d.valor_garantia_real_bs, 0)       as valor_garantia_real_bs,
    -- porcentaje de la cartera interna respaldada por inmueble verificado
    case when coalesce(c.saldo_interno_bs, 0) > 0
         then round(coalesce(g.monto_garantizado_bs, 0) / c.saldo_interno_bs, 4)
    end                                        as pct_cartera_garantizada,

    -- ===== MEDIDAS: grupo economico (regla 3) =====
    coalesce(d.empresas_vinculadas, 0)          as empresas_vinculadas,
    coalesce(d.empresas_creedoras, 0)           as empresas_creedoras,
    coalesce(d.empresas_controladas, 0)         as empresas_controladas,

    -- ===== RATIOS (PD-08) =====
    -- exposicion total: interna + externa
    round(coalesce(c.saldo_interno_bs, 0) + coalesce(e.deuda_externa_bs, 0), 2)
                                                     as exposicion_total_bs,
    -- endeudamiento: sobre el ingreso mensual, cuando existe
    case when coalesce(d.ingreso_mensual_bs, 0) > 0
         then round((coalesce(c.saldo_interno_bs, 0) + coalesce(e.deuda_externa_bs, 0))
                    / d.ingreso_mensual_bs, 2)
    end                                              as ratio_endeudamiento,
    -- concentracion interna: cuanto de la deuda del cliente es nuestra
    case when (coalesce(c.saldo_interno_bs, 0) + coalesce(e.deuda_externa_bs, 0)) > 0
         then round(coalesce(c.saldo_interno_bs, 0)
                    / (coalesce(c.saldo_interno_bs, 0) + coalesce(e.deuda_externa_bs, 0)), 3)
    end                                              as concentracion_interna,
    -- ponderada por la calidad del acreedor externo: no es lo mismo deber a un
    -- banco que a una cooperativa micro
    case when (coalesce(c.saldo_interno_bs, 0) + coalesce(e.deuda_externa_bs, 0)) > 0
         then round(coalesce(c.saldo_interno_bs, 0)
                    / (coalesce(c.saldo_interno_bs, 0) + coalesce(e.deuda_externa_bs, 0))
                    * 100, 2)
    end                                              as pct_exposicion_propia,

    -- ===== SEMAFORO DE CONFIANZA DEL DATO =====
    -- El score de riesgo puede ser preciso y el laboral no. Esto lo dice.
    d.confianza_ponderada,
    d.cobertura_identidad,
    d.estado_riesgo,
    d.tipo_persona
from dim d
left join cartera c  on c.cliente_numero_id_hash = d.numero_id_hash
left join externa e  on e.numero_id_hash         = d.numero_id_hash
left join ofx      on ofx.numero_id_hash        = d.numero_id_hash
left join garantia g on g.cliente_numero_id_hash = d.numero_id_hash
