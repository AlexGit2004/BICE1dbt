{{ config(materialized='table') }}

{#-
    int_clientes_unificados.sql  (REESCRITO)
    REGLA 2: TODA fuente externa converge en dim_cliente.

    EL CAMBIO DE FONDO
    ---------------------------------------------------------------------------
    Este modelo es el corazon del pipeline, y su premisa es exactamente la de la
    consigna: en CAPAORO la clave del cliente es el CI/NIT, y los id genericos
    (cliente_id 1..5000, deudor_id 1..2000, empresa_id 1..700) se descartan
    porque no verifican unicidad de persona.

    QUE HABIA Y QUE HAY
      antes: cliente_id = autoincremental de F1 (1..5000), y los clientes de F6
             se colaban con row_number() + 5000. El hash se calculaba sobre ese
             id generico, no sobre el CI.
      ahora: cliente_id = el CI/NIT. El id de F1 sobrevive como
             cliente_id_legacy, que es un ATRIBUTO DE LINAJE y no una clave.

    POR QUE EL CROSSWALK Y NO "UNION"
    ---------------------------------------------------------------------------
    Con un union solo, las 7 fuentes siguen siendo identidades separadas y la
    deduplicacion depende de que los strings coincidan byte a byte. Usando
    int_xwalk_identidad, la resolucion del CI/NIT ya esta hecha, validada y
    auditada. Este modelo ya no resuelve identidades: solo agrega.
-#}

with xw as (
    -- 1 por CI/NIT, ya resueltas por la tabla maestra de identidad
    select * from {{ ref('int_xwalk_identidad') }}
    where identidad_confirmada
),

-- ---- F1: core operacional. Aporta los datos personales y la fecha de alta.
f1 as (
    select
        c.cliente_id                                        as cliente_id_legacy,
        {{ normalizar_identidad('c.numero_identificacion') }} as numero_identificacion_norm,
        {{ hash_pii( normalizar_identidad('c.numero_identificacion') ) }} as numero_id_hash,
        c.tipo_id,
        c.nombre_completo,
        c.apellido_paterno,
        c.apellido_materno,
        c.estado_cliente,
        c.fecha_creacion
    from {{ ref('stg_mysql__cliente') }} c
),

-- ---- F2: antecedentes penales. Aporta el nombre cuando el core no lo tiene.
f2 as (
    select
        {{ hash_pii( normalizar_identidad('p.numero_identificacion') ) }} as numero_id_hash,
        max({{ normalizar_identidad('p.numero_identificacion') }})        as numero_identificacion_norm,
        max(p.descripcion_breve)                                        as nombre_alternativo
    from {{ ref('stg_pgsql__proceso_penal') }} p
    group by 1
),

-- ---- F3: buro de credito. Aporta el tipo de persona ya clasificado.
f3 as (
    select
        {{ hash_pii( normalizar_identidad('d.numero_identificacion') ) }} as numero_id_hash,
        max({{ normalizar_identidad('d.numero_identificacion') }})        as numero_identificacion_norm
    from {{ ref('stg_server__deudor_central_riesgos') }} d
    group by 1
),

-- ---- F4: registro mercantil. Aporta la razon social de las juridicas.
f4 as (
    select
        {{ hash_pii( normalizar_identidad('e.numero_identificacion') ) }} as numero_id_hash,
        max({{ normalizar_identidad('e.numero_identificacion') }})        as numero_identificacion_norm,
        max(e.razon_social)                                               as razon_social
    from {{ ref('stg_maria__empresa_registro_mercantil') }} e
    group by 1
),

-- ---- F6: situacion laboral. Aporta los 3.000 clientes sin prestamo, YA
--      resueltos por el crosswalk (antes se rompeaba en el cast a bigint).
f6 as (
    select
        sl.numero_id_hash,
        max(sl.numero_identificacion)          as numero_identificacion_norm,
        max(sl.ingresos_mensuales_bs)           as ingresos_mensuales_bs,
        max(sl.antiguedad_laboral_meses)        as antiguedad_laboral_meses,
        max(sl.tipo_empleo)                     as tipo_empleo,
        max(sl.empresa)                         as empresa_empleadora,
        max(sl.sector_economico)                as sector_economico,
        max(sl.fecha_actualizacion)             as fecha_evaluacion_laboral
    from {{ ref('stg_csv__situacion_laboral') }} sl
    where sl.numero_id_hash is not null
    group by 1
),

-- ---- Ensamblado por hash. TODOS los cruces son hash-contra-hash (REGLA 2).
unificado as (
    select
        x.numero_id_hash,
        -- === LA CLAVE NATURAL DEL DW: el CI/NIT ===
        x.numero_identificacion_norm                        as numero_identificacion,
        x.tipo_id,
        x.clave_origen                                      as xwalk_clave_origen,
        x.metodo_match,
        x.confianza_ponderada,
        x.num_fuentes_distintas,
        x.cobertura_identidad,
        x.tipo_identidad,
        x.id_origen_f1, x.id_origen_f2, x.id_origen_f3,
        x.id_origen_f4, x.id_origen_f5, x.id_origen_f5b, x.id_origen_f6,

        -- datos de F1 (pueden ser null: hay clientes que solo existen en F6)
        f1.cliente_id                                       as cliente_id_legacy,
        f1.nombre_completo,
        f1.apellido_paterno,
        f1.apellido_materno,
        f1.estado_cliente,
        f1.fecha_creacion,
        case when f1.cliente_id is not null then 'F1' else 'F_SOLO_EXTERNA' end
                                                              as origen_cliente,

        -- datos de otras fuentes
        f2.nombre_alternativo,
        f4.razon_social,
        f6.ingresos_mensuales_bs,
        f6.antiguedad_laboral_meses,
        f6.tipo_empleo,
        f6.empresa_empleadora,
        f6.sector_economico,
        f6.fecha_evaluacion_laboral
    from xw x
    left join f1 on f1.numero_id_hash          = x.numero_id_hash
    left join f2 on f2.numero_id_hash          = x.numero_id_hash
    left join f3 on f3.numero_id_hash          = x.numero_id_hash
    left join f4 on f4.numero_id_hash          = x.numero_id_hash
    left join f6 on f6.numero_id_hash          = x.numero_id_hash
)

select * from unificado
