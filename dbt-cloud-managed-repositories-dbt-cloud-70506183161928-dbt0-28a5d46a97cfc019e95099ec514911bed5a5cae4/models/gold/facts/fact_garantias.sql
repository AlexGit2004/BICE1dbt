{{ config(materialized='table', unique_key='garantia_id') }}

{#-
    fact_garantias.sql  (CORREGIDO)  *** P-06 RESUELTO ***

    ANTES: estado_garantia se descartaba en el stg, y cobertura_obligacion era un
    porcentaje DECLARADO por el analista, sin ninguna evidencia.

    AHORA: el estado llega (FK real), y la cobertura se contrasta contra la
    garantia real de F5, de modo que el porcentaje declarado y el verificado
    conviven en la misma fila. La diferencia entre ambos es el indicador.
-#}

with g as (
    select * from {{ ref('stg_mysql__garantia') }}
),

pr as (
    select
        p.prestamo_id,
        p.saldo_actual_bs,
        p.monto_aprobado_bs,
        p.cuota_mensual_bs,
        p.fecha_originacion,
        cu.numero_identificacion as cliente_id,
        cu.numero_id_hash        as cliente_numero_id_hash
    from {{ ref('int_prestamos_limpios') }} p
    left join {{ ref('int_clientes_unificados') }} cu
           on cu.cliente_id_legacy = p.cliente_id
),

-- La garantia INMUEBLE verificada, agregada al prestamo. F5.
dr as (
    select
        l.prestamo_id,
        count(distinct l.gravamen_id)                        as gravamenes_inscritos,
        count(distinct l.inmueble_id)                       as inmuebles_distintos,
        sum(l.monto_garantizado_bs)                         as monto_garantizado_real_bs,
        max(l.valor_avaluo_bs)                               as valor_avaluo_max_bs,
        max(l.ltv_pct)                                       as ltv_pct_max
    from {{ ref('int_derechos_reales_garantia') }} l
    group by 1
)

select
    g.garantia_id,

    -- ===== FKs =====
    {{ dbt_utils.generate_surrogate_key(['pr.prestamo_id']) }}         as prestamo_key,
    {{ dbt_utils.generate_surrogate_key(['pr.numero_id_hash']) }}      as cliente_key,
    {{ dbt_utils.generate_surrogate_key(['g.tipo_garantia_id']) }}     as tipo_garantia_key,
    -- [3] FK al catalogo del ciclo de vida, que antes no existia
    {{ dbt_utils.generate_surrogate_key(['g.estado_garantia_id']) }}   as estado_garantia_key,
    cast(to_char(g.fecha_valoracion, 'YYYYMMDD') as integer)           as fecha_valoracion_key,

    -- ===== business keys =====
    g.prestamo_id,
    pr.numero_identificacion                                           as cliente_id,
    pr.numero_id_hash                                                  as cliente_numero_id_hash,
    g.tipo_garantia_id,
    g.estado_garantia_id,
    g.descripcion_bien,
    g.fecha_valoracion,

    -- ===== MEDIDAS DECLARADAS (F1) =====
    g.valor_avaluo_bs,
    g.cobertura_obligacion,

    -- ===== MEDIDAS VERIFICADAS (F5) =====
    -- la cobertura REAL: calculada contra el saldo, no declarada
    case when coalesce(pr.saldo_actual_bs, 0) > 0
         then round(coalesce(dr.monto_garantizado_real_bs, 0) / pr.saldo_actual_bs, 4)
    end                                                                as cobertura_verificada,
    dr.monto_garantizado_real_bs,
    dr.valor_avaluo_max_bs,
    dr.ltv_pct_max,
    dr.gravamenes_inscritos,

    -- ===== EL INDICADOR NUEVO =====
    -- brecha = declarado - verificado.
    -- Positiva: el analista declaro MAS cobertura de la que existe.
    -- Negativa: hay respaldo real sin declarada (capital liberado).
    case when coalesce(pr.saldo_actual_bs, 0) > 0
              and dr.gravamenes_inscritos > 0
         then round(coalesce(g.cobertura_obligacion, 0)
                    - coalesce(dr.monto_garantizado_real_bs, 0) / pr.saldo_actual_bs, 4)
    end                                                                as brecha_cobertura,
    case when coalesce(pr.saldo_actual_bs, 0) > 0
              and dr.gravamenes_inscritos > 0
         then round(coalesce(g.cobertura_obligacion, 0)
                    / nullif(coalesce(dr.monto_garantizado_real_bs, 0) / pr.saldo_actual_bs, 0), 4)
    end                                                                as ratio_cobertura_declarada_vs_verificada,

    -- ===== SEMAFORO DE LA GARANTIA =====
    case when coalesce(dr.monto_garantizado_real_bs, 0) = 0
              and g.cobertura_obligacion > 0            then 'SIN RESPALDO DOCUMENTAL'
         when dr.ltv_pct_max is not null and dr.ltv_pct_max < 0.4 then 'SOBRE-GARANTIZADA'
         when g.cobertura_obligacion >= 1.0              then 'COBERTURA SUFICIENTE'
         when g.cobertura_obligacion > 0                 then 'COBERTURA PARCIAL'
         else                                                  'SIN COBERTURA'
    end                                                                as situacion_garantia,

    -- ===== snapshot del credito, para no depender de dim_prestamo =====
    pr.saldo_actual_bs                                                 as saldo_prestamo,
    pr.monto_aprobado_bs,
    pr.cuota_mensual_bs,
    pr.fecha_originacion
from g
left join pr on pr.prestamo_id = g.prestamo_id
left join dr on dr.prestamo_id = g.prestamo_id
