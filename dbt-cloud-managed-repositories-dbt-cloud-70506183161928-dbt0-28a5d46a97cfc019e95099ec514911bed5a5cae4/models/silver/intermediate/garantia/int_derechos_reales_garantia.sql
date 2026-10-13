{{ config(materialized='table') }}

{#-
    int_derechos_reales_garantia.sql  (NUEVO)

    Capa puente de F5 (babsa_derechos_reales). Une el mundo notarial con el
    credito colocado y deja el resultado listo para fact_derechos_reales.

    REGLA 1: el cruce se hace por clave NATURAL (matricula, numero_inscripcion,
    prestamo_id) y por CI/NIT. Nunca por un id generico.

    REGLA 2: el hash se calcula UNA SOLA VEZ, en este modelo, y despues todos
    los joins son hash-contra-hash. Si dos modelos hashearan la misma cadena,
    el cruce falla en silencio.
-#}

with g as (
    select * from {{ ref('stg_mysql__gravamen_garantia_prestamo') }}
),

i as (
    select * from {{ ref('stg_mysql__derecho_real_inscripcion') }}
),

b as (
    select * from {{ ref('stg_mysql__bien_inmueble') }}
),

t as (
    select * from {{ ref('stg_mysql__tipo_derecho_real') }}
),

prest as (
    select * from {{ ref('int_prestamos_limpios') }}
),

-- El hash del titular se calcula UNA vez y se propaga.
titular as (
    select
        g.gravamen_id,
        {{ normalizar_identidad('g.numero_identificacion') }} as cliente_numero_norm,
        {{ hash_pii( normalizar_identidad('g.numero_identificacion') ) }} as cliente_numero_id_hash
    from g
),

-- El hash del titular del prestamo tambien, para poder unir por hash y no
-- depender de recorrer la dimension en cada uno de los 4 consumers.
prest_hash as (
    select
        p.prestamo_id,
        cu.numero_id_hash as cliente_numero_id_hash,
        p.cliente_id,
        p.saldo_actual_bs,
        p.monto_aprobado_bs,
        p.cuota_mensual_bs,
        p.plazo_aprobado_meses,
        p.fecha_originacion,
        p.fecha_vencimiento,
        p.dias_atraso,
        p.bucket_mora,
        p.estado_prestamo_tipo_id
    from prest p
    left join {{ ref('int_clientes_unificados') }} cu
           on cu.cliente_id_legacy = p.cliente_id
)

select
    g.gravamen_id,
    g.inscripcion_id,
    g.inmueble_id,
    g.tipo_derecho_real_id,
    g.prestamo_id,

    -- ===== LAS DOS CLAVES DE CRUCE (REGLA 2) =====
    t2.cliente_numero_id_hash,
    t2.cliente_numero_norm                      as cliente_numero_identificacion,
    ph.cliente_id                               as cliente_id_legacy,
    -- bandera de calidad: si el titular del gravamen NO es el deudor del
    -- prestamo, es una garantia de tercero. Eso cambia el analisis de riesgo
    -- y antes no se podia ver.
    case when ph.cliente_numero_id_hash = t2.cliente_numero_id_hash
         then true else false end               as titular_es_deudor,

    -- ===== datos notariales =====
    i.numero_inscripcion,
    i.fecha_inscripcion,
    i.fecha_vencimiento                         as inscripcion_vence,
    i.estado_inscripcion,
    i.monto_base_bs,
    i.notario,
    b.matricula_inmueble,
    b.tipo_inmueble,
    b.direccion,
    b.zona,
    b.departamento                               as inmueble_departamento,
    b.superficie_m2,
    b.valor_comercial_bs,
    b.valor_avaluo_bs,
    b.fecha_avaluo,
    b.estado_inmueble,
    t.codigo                                     as derecho_real_codigo,
    t.nombre_tipo                                as derecho_real_nombre,
    t.es_garantia,
    t.es_transmision,
    t.requiere_valuacion,

    -- ===== el gravamen =====
    g.fecha_inscripcion_gravamen,
    g.fecha_liberacion,
    g.estado_gravamen,
    g.monto_garantizado_bs,
    g.porcentaje_cobertura                       as cobertura_declarada_bd,

    -- ===== el credito que respalda =====
    ph.saldo_actual_bs,
    ph.monto_aprobado_bs,
    ph.cuota_mensual_bs,
    ph.plazo_aprobado_meses,
    ph.fecha_originacion,
    ph.fecha_vencimiento,
    ph.dias_atraso,
    ph.bucket_mora,
    ph.estado_prestamo_tipo_id,

    -- ===== MEDIDAS DERIVADAS (PD-08) =====
    -- cobertura REAL, recalculada contra el saldo. El porcentaje de la BD es
    -- lo que declara el acreedor; este es el que se puede verificar.
    case when coalesce(ph.saldo_actual_bs, 0) > 0
         then round(g.monto_garantizado_bs / ph.saldo_actual_bs, 4)
    end                                         as cobertura_real,
    -- loan to value: proporcion del credito que respalda el inmueble
    {{ ltv_pct('ph.saldo_actual_bs', 'b.valor_avaluo_bs') }}      as ltv_pct,
    {{ nivel_sobregarantizacion("{{ ltv_pct('ph.saldo_actual_bs', 'b.valor_avaluo_bs') }}") }}
                                                  as nivel_garantia,
    -- dias que el gravamen lleva vigente: para el KPI de antiguedad de respaldo
    datediff('day', g.fecha_inscripcion_gravamen,
             coalesce(g.fecha_liberacion, current_date))        as dias_gravamen_vigente,
    -- diferencia entre lo declarado y lo verificado. Si es positiva, el
    -- analista esta declarando mas cobertura de la que existe.
    case when coalesce(ph.saldo_actual_bs, 0) > 0
         then round(g.monto_garantizado_bs / ph.saldo_actual_bs
                    - coalesce(g.porcentaje_cobertura, 0), 4)
    end                                         as brecha_cobertura
from g
join titular t2  on t2.gravamen_id = g.gravamen_id
join i  on i.inscripcion_id           = g.inscripcion_id
join b  on b.inmueble_id              = g.inmueble_id
join t  on t.tipo_derecho_real_id     = g.tipo_derecho_real_id
join prest_hash ph on ph.prestamo_id  = g.prestamo_id
