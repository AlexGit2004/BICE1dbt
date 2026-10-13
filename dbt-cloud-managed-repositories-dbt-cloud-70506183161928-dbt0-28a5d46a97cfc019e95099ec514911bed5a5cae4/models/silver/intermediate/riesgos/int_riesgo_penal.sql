{{ config(materialized='table') }}

{#-
    int_riesgo_penal.sql  (CORREGIDO)
    REGLA 1: el catalogo estado_proceso_penal esta declarado en el DDL y lo
              integra este modelo, para que deje de estar suelto.
    REGLA 2: el cruce con consolidado_antecedentes es hash-contra-hash.
-#}

with pp as (
    select * from {{ ref('stg_pgsql__proceso_penal') }}
),

cons as (
    select * from {{ ref('stg_pgsql__consolidado_antecedentes') }}
),

-- Catalogo de estados del proceso. Distingue "en juicio" de "archivado": un
-- proceso archivado no es riesgo vigente, uno en juicio si.
estados as (
    select
        estado_proceso_penal_id,
        nombre_estado,
        es_terminal
    from {{ ref('stg_pgsql__estado_proceso_penal') }}
),

-- REGLA 2: el hash se calcula UNA vez, sobre el texto normalizado.
with_hash as (
    select
        {{ hash_pii( normalizar_identidad('pp.numero_identificacion') ) }} as numero_id_hash,
        {{ normalizar_identidad('pp.numero_identificacion') }}             as numero_identificacion_norm,
        pp.proceso_penal_id,
        pp.estado_proceso_penal_id,
        pp.tipo_delito_id,
        pp.fecha_inicio,
        pp.fecha_sentencia,
        e.nombre_estado                                                as estado_proceso,
        e.es_terminal                                                 as es_estado_terminal
    from pp
    left join estados e
           on e.estado_proceso_penal_id = pp.estado_proceso_penal_id
),

cons_hash as (
    select
        {{ hash_pii( normalizar_identidad('numero_identificacion') ) }} as numero_id_hash,
        tiene_antecedentes_penales,
        cantidad_procesos_activos,
        cantidad_sentencias_condenatorias,
        fecha_ultima_actualizacion
    from cons
)

select
    w.numero_id_hash,
    any_value(w.numero_identificacion_norm)                  as numero_identificacion,

    -- ===== CONTEOS =====
    count(distinct w.proceso_penal_id)                       as total_procesos,
    count(distinct case when w.estado_proceso_penal_id is not null
                        then w.proceso_penal_id end)          as procesos_activos,
    count(distinct case when w.fecha_sentencia is not null
                        then w.proceso_penal_id end)          as procesos_sentenciados,
    count(distinct case when w.es_estado_terminal
                        then w.proceso_penal_id end)          as procesos_archivados,
    -- El que de verdad importa: proceso abierto que NO esta archivado.
    -- "tiene proceso activo" no puede significar lo mismo que "tiene proceso".
    count(distinct case when not w.es_estado_terminal
                        then w.proceso_penal_id end)          as procesos_vigentes,

    -- ===== ESTADO, que antes no llegaba al DW =====
    max(w.estado_proceso)                                     as estado_proceso_actual,
    boolor_agg(not w.es_estado_terminal)                     as tiene_proceso_activo,
    -- argumento de negocio: un proceso vigente es motivo suficiente de riesgo
    -- alto, sin importar el score del buro
    boolor_agg(not w.es_estado_terminal)                     as tiene_proceso_vigente,

    -- ===== DELITO: el tipo dominante como ID, no como hash =====
    -- Se expone el id para que fact_riesgo pueda reconstruir la FK correcta
    -- hacia dim_delito_categoria, que hashea categoria_delito_id (ver P-07).
    min(w.tipo_delito_id)                                     as tipo_delito_id_principal,
    count(distinct w.tipo_delito_id)                          as tipos_delito,

    -- ===== FECHAS =====
    min(w.fecha_inicio)                                       as fecha_primer_proceso,
    max(w.fecha_inicio)                                       as fecha_ultimo_proceso,
    max(w.fecha_sentencia)                                    as fecha_ultima_sentencia,
    datediff('day', min(w.fecha_inicio), current_date)        as dias_desde_primer_proceso,

    -- ===== CONSOLIDADO =====
    max(c.tiene_antecedentes_penales)                         as tiene_antecedentes_penales,
    coalesce(max(c.cantidad_sentencias_condenatorias), 0)    as sentencias_condenatorias,
    max(c.cantidad_procesos_activos)                          as procesos_activos_consolidado,
    max(c.fecha_ultima_actualizacion)                         as fecha_snapshot_penal
from with_hash w
left join cons_hash c on c.numero_id_hash = w.numero_id_hash   -- REGLA 2
group by 1
