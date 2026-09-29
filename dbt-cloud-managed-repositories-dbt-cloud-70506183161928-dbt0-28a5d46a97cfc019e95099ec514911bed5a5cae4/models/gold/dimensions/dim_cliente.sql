{{ config(materialized='table', unique_key='cliente_key') }}

{#-
    dim_cliente.sql  (REESCRITO)
    REGLA 2: TODAS las fuentes convergen aqui.

    LA CLAVE NATURAL DE ESTA TABLA ES EL CI/NIT
    ---------------------------------------------------------------------------
    dim_cliente.cliente_id  =  el CI/NIT. Ese es el cambio de fondo: los id
    genericos de F1 (1..5000), de F3 (deudor_id) y de F4 (empresa_id) se
    descartan como clave y sobreviven como atributos de linaje.

    dim_cliente.cliente_key  =  hash(CI/NIT), que es la FK de la estrella.

    Sobre el hash y la PII: se mantiene la politica de exponer el hash y no el
    CI en claro, para que el .pbix de la Direccion no se lleve PII. Eso obliga
    a que TODOS los joins del .pbix y del pipeline sean hash-contra-hash. El
    warning de que un SHA256 de un CI no protege nada esta en hash_pii.sql.
-#}

with cu as (
    select * from {{ ref('int_clientes_unificados') }}
),

perf as (
    select * from {{ ref('stg_mysql__caracteristica_cliente') }}
),

tipo_id as (
    select * from {{ ref('stg_mysql__tipo_identificacion') }}
),

flags as (
    select * from {{ ref('int_cliente_flags_riesgo') }}
),

lab as (
    select * from {{ ref('int_situacion_laboral') }}
),

-- REGLA 2: exposicion del grupo economico, para que dim_cliente sepa si el
-- cliente esta atado a otras empresas del registro mercantil.
grupo as (
    select
        cliente_hash,
        count(distinct empresa_id)                                  as empresas_vinculadas,
        sum(case when tipo_vinculo = 'ES_ACREEDORA'
                 then 1 else 0 end)                                as empresas_creedoras,
        sum(case when es_controlador or porcentaje_participacion > 50
                 then 1 else 0 end)                                as empresas_controladas,
        max(pct_controlador)                                       as pct_controlador_maximo
    from {{ ref('int_exposicion_empresa') }}
    group by 1
),

-- La garantia real, agregada al grano de la persona.
dr as (
    select
        cliente_numero_id_hash,
        count(distinct gravamen_id)                                as total_derechos_reales,
        count(distinct case when estado_gravamen = 'Vigente'
                           then gravamen_id end)                    as gravamenes_vigentes,
        boolor(case when estado_gravamen = 'Vigente'
                   and es_garantia then true else false end)       as mortgage_vigente,
        coalesce(sum(case when estado_gravamen = 'Vigente'
                          then monto_garantizado_bs else 0 end), 0) as valor_garantia_real_bs,
        coalesce(sum(case when estado_gravamen = 'Vigente'
                          then valor_avaluo_bs else 0 end), 0)      as valor_inmuebles_garantizados_bs
    from {{ ref('int_derechos_reales_garantia') }}
    group by 1
)

select
    {{ dbt_utils.generate_surrogate_key(['cu.numero_identificacion']) }} as cliente_key,
    cu.numero_identificacion                                          as cliente_id,

    -- PK natural. En CAPAORO no existe un id de cliente que no sea el CI/NIT.
    cu.numero_id_hash,
    cu.tipo_id,
    coalesce(ti.nombre_tipo, 'DESCONOCIDO')                         as tipo_identificacion,
    case cu.tipo_id
        when 1 then 'Natural'
        when 2 then 'Juridica'
        else        'Desconocido'
    end                                                             as tipo_persona,

    cu.nombre_completo,
    cu.apellido_paterno,
    cu.apellido_materno,
    cu.razon_social,
    coalesce(cu.estado_cliente, 'Activo')                           as estado_cliente,
    coalesce(cu.fecha_creacion, cu.fecha_evaluacion_laboral)        as fecha_creacion,

    -- ===== ATRIBUTOS DE LINAJE (ya NO son claves) =====
    cu.cliente_id_legacy,
    cu.origen_cliente,
    cu.xwalk_clave_origen,
    cu.metodo_match,
    cu.confianza_ponderada,
    cu.cobertura_identidad,
    cu.tipo_identidad,
    cu.num_fuentes_distintas,
    cu.id_origen_f2, cu.id_origen_f3,
    cu.id_origen_f4, cu.id_origen_f5, cu.id_origen_f5b, cu.id_origen_f6,

    -- ===== PERFIL =====
    coalesce(perf.fecha_nacimiento, date '1900-01-01')              as fecha_nacimiento,
    coalesce(perf.sexo, 'N/A')                                      as sexo,
    coalesce(perf.estado_civil, 'N/A')                              as estado_civil,
    coalesce(perf.nacionalidad, 'NO ESPECIFICADA')                  as nacionalidad,
    coalesce(perf.profesion, 'NO ESPECIFICADA')                     as profesion,

    -- ===== RIESGO (11 flags, PD-06) =====
    f.total_procesos_penales,
    f.tiene_proceso_activo,
    f.procesos_penales_activos,
    f.procesos_penales_vigentes,
    f.procesos_penales_archivados,
    f.estado_proceso_penal,
    f.procesos_sentenciados,
    f.sentencias_condenatorias,
    f.fecha_primer_proceso,
    f.deuda_externa_bs,
    f.max_dias_atraso_externo,
    f.total_obligaciones,
    f.num_entidades_acreedoras,
    f.score_morosidad_externo,
    f.categoria_riesgo_externo,
    f.entidad_principal_id,
    f.concentracion_entidad,
    f.deuda_tributaria_bs,
    f.es_moroso_tributario,
    f.max_dias_atraso_interno,
    f.tiene_atraso_vigente,
    f.total_prestamos,
    f.prestamos_en_mora,
    f.saldo_cartera_bs,

    -- ===== LABORAL (PD-02) =====
    coalesce(l.ingresos_mensuales_bs, 0)                           as ingreso_mensual_bs,
    coalesce(l.antiguedad_laboral_meses, 0)                         as antiguedad_laboral_meses,
    l.tipo_empleo,
    l.tipo_contrato,
    l.empresa_empleadora,
    l.sector_economico,
    l.cargo,
    l.ciudad,
    l.solidez_laboral,
    l.cumple_capacidad_pago_por_ingreso                             as cumple_capacidad_pago,
    l.tiene_prestamo_en_fuente                                     as tiene_prestamo_en_fuente_laboral,

    -- ===== GARANTIA REAL (F5, PD-08) =====
    coalesce(dr.total_derechos_reales, 0)                          as total_derechos_reales,
    coalesce(dr.gravamenes_vigentes, 0)                             as gravamenes_vigentes,
    coalesce(dr.mortgage_vigente, false)                           as mortgage_vigente,
    coalesce(dr.valor_garantia_real_bs, 0)                          as valor_garantia_real_bs,
    coalesce(dr.valor_inmuebles_garantizados_bs, 0)                 as valor_inmuebles_garantizados_bs,

    -- ===== GRUPO ECONOMICO (REGLA 3) =====
    coalesce(g.empresas_vinculadas, 0)                              as empresas_vinculadas,
    coalesce(g.empresas_creedoras, 0)                               as empresas_creedoras,
    coalesce(g.empresas_controladas, 0)                             as empresas_controladas,
    coalesce(g.pct_controlador_maximo, 0)                           as pct_controlador_maximo,

    -- ===== SEMAFORO DE RIESGO (PD-07) =====
    case
        when f.tiene_proceso_activo
          or f.tiene_atraso_vigente
          or coalesce(f.score_morosidad_externo, 100) < {{ var('score_morosidad_alto') }}
            then 'Alto'
        when f.es_moroso_tributario
          or coalesce(f.score_morosidad_externo, 100) < {{ var('score_morosidad_medio') }}
            then 'Medio'
        else 'Bajo'
    end                                                             as estado_riesgo
from cu
left join perf      perf on perf.cliente_id     = cu.cliente_id_legacy
left join tipo_id     ti on ti.tipo_id          = cu.tipo_id
left join flags        f on f.numero_id_hash    = cu.numero_id_hash
left join lab         l  on l.numero_id_hash    = cu.numero_id_hash
left join grupo       g  on g.cliente_hash      = cu.numero_id_hash
left join dr         dr  on dr.cliente_numero_id_hash = cu.numero_id_hash
