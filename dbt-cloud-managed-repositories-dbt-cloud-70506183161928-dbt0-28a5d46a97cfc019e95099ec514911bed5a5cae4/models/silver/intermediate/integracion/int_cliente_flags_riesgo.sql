{{ config(materialized='table') }}

{#-
    int_cliente_flags_riesgo.sql  (REESCRITO)
    REGLA 2: TODOS los cruces son hash-contra-hash.

    ANTES: los joins eran
        left join pen on pen.numero_identificacion = c.numero_identificacion
    donde pen.numero_identificacion venia en claro y c.numero_identificacion
    tambien. Funcionaba, pero el nombre significaba una cosa en int_clientes_unificados
    (en claro) y otra en dim_cliente (el hash). Mismo nombre, dos contenidos.

    AHORA: cada modelo de riesgo expone numero_id_hash y numero_identificacion
    (normalizado, en claro). El cruce es SIEMPRE por hash, y el valor en claro
    viaja solo para trazar.

    Tambien se separan los dominios: el.scoreLegal viene de la central de
    riesgos, y los delitos van por su cuenta hacia dim_delito_categoria. No se
    mezclan (ver P-07).
-#}

with cli as (
    select
        numero_identificacion,
        numero_id_hash,
        cliente_id_legacy
    from {{ ref('int_clientes_unificados') }}
),

pen as (select * from {{ ref('int_riesgo_penal') }}),
cen as (select * from {{ ref('int_deuda_externa_cliente') }}),
tri as (select * from {{ ref('int_riesgo_tributario') }}),

-- Mora interna al grano de la PERSONA, no del prestamo. Sin este group by, el
-- mismo cliente aparece una vez por prestamo y los flags se multiplican.
mor as (
    select
        cu.numero_id_hash,
        cu.numero_identificacion,
        max(p.dias_atraso)                        as max_dias_atraso_interno,
        boolor_agg(p.mora_vigente)                as tiene_atraso_vigente,
        count(distinct p.prestamo_id)             as total_prestamos,
        count(distinct case when p.mora_vigente
                           then p.prestamo_id end) as prestamos_en_mora,
        sum(case when p.saldo_actual_bs > 0
                 then p.saldo_actual_bs else 0 end) as saldo_cartera_bs
    from {{ ref('int_clientes_unificados') }} cu
    left join {{ ref('int_prestamos_limpios') }} p
           on p.cliente_id = cu.cliente_id_legacy
    group by 1, 2
),

-- Grupos de riesgo del core, al grano de persona.
-- Se eliminan: no aportan a los flags y creaban una dependencia circular
-- (silver no puede referenciar fact_riesgo, que esta en gold).

-- Dominio DELITO, separado del dominio de RIESGO. Nunca se suman entre si.
delitos as (
    select
        pen.numero_id_hash,
        count(distinct pen.proceso_penal_id)                            as procesos_penales,
        boolor_agg(pen.tiene_proceso_activo)                            as tiene_proceso_activo,
        count(distinct case when pen.fecha_sentencia is not null
                            then pen.proceso_penal_id end)               as procesos_sentenciados,
        count(distinct pen.tipo_delito_id)                              as tipos_delito_distintos
    from pen
    group by 1
)

select
    c.numero_identificacion,
    c.numero_id_hash,

    -- ===== RIESGO LEGAL (F2) =====
    coalesce(pen.total_procesos, 0)               as total_procesos_penales,
    coalesce(pen.tiene_proceso_activo, false)     as tiene_proceso_activo,
    coalesce(pen.procesos_activos, 0)             as procesos_penales_activos,
    coalesce(pen.procesos_vigentes, 0)            as procesos_penales_vigentes,
    coalesce(pen.procesos_archivados, 0)          as procesos_penales_archivados,
    pen.estado_proceso_actual                    as estado_proceso_penal,
    coalesce(pen.dias_desde_primer_proceso, 0)     as dias_desde_primer_proceso,
    coalesce(pen.procesos_sentenciados, 0)        as procesos_sentenciados,
    coalesce(pen.sentencias_condenatorias, 0)     as sentencias_condenatorias,
    coalesce(pen.fecha_primer_proceso, null)      as fecha_primer_proceso,

    -- ===== RIESGO FINANCIERO EXTERNO (F3) =====
    -- agregado desde el grano fino, para no perder la entidad (ver P-04)
    coalesce(cen.deuda_total_externa_bs, 0)       as deuda_externa_bs,
    coalesce(cen.max_dias_atraso_externo, 0)      as max_dias_atraso_externo,
    coalesce(cen.total_obligaciones, 0)           as total_obligaciones,
    coalesce(cen.num_entidades_acreedoras, 0)     as num_entidades_acreedoras,
    coalesce(cen.score_morosidad, 100)            as score_morosidad_externo,
    coalesce(cen.categoria_riesgo, 'BAJO')        as categoria_riesgo_externo,
    coalesce(cen.entidad_principal_id, null)      as entidad_principal_id,

    -- ===== RIESGO TRIBUTARIO (F4) =====
    coalesce(tri.deuda_tributaria_actual_bs, 0)   as deuda_tributaria_bs,
    case when coalesce(tri.deuda_tributaria_actual_bs, 0) > 0
              and coalesce(tri.estado_tributario_actual, 'Al Dia') <> 'En Proceso'
         then true else false end                 as es_moroso_tributario,

    -- ===== MORA INTERNA (F1) =====
    coalesce(mor.max_dias_atraso_interno, 0)      as max_dias_atraso_interno,
    coalesce(mor.tiene_atraso_vigente, false)     as tiene_atraso_vigente,
    coalesce(mor.total_prestamos, 0)              as total_prestamos,
    coalesce(mor.prestamos_en_mora, 0)            as prestamos_en_mora,
    coalesce(mor.saldo_cartera_bs, 0)             as saldo_cartera_bs,

    -- ===== DELITOS: dominio separado, NUNCA sumado al score de riesgo =====
    coalesce(del.procesos_penales, 0)             as procesos_penales_detallados,
    coalesce(del.tipos_delito_distintos, 0)       as tipos_delito_distintos
from cli c
left join pen     on pen.numero_id_hash     = c.numero_id_hash
left join cen     on cen.numero_id_hash     = c.numero_id_hash
left join tri     on tri.numero_id_hash     = c.numero_id_hash
left join mor     on mor.numero_id_hash     = c.numero_id_hash
left join delitos del on del.numero_id_hash = c.numero_id_hash
