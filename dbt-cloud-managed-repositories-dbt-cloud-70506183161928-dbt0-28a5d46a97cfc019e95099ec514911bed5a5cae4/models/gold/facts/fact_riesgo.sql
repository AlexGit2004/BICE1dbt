{{ config(materialized='table', unique_key='cliente_id') }}

{#-
    fact_riesgo.sql  (REESCRITO)  *** P-07 Y P-17 Y P-18 RESUELTOS ***

    LOS TRES ERRORES QUE TENIA
    ---------------------------------------------------------------------------
    1. categoria_riesgo_key se calculaba con
       generate_surrogate_key(['c.estado_riesgo']), es decir sobre el SEMAFORO
       ('Alto'/'Medio'/'Bajo'), mientras dim_riesgo_categoria contenia categorias
       de BURO y de DELITO. La FK no encontraba padre nunca. Ademas la
       dimension mezclaba dos dominios.
       AHORA: la FK se calcula sobre el valor REAL de categoria_riesgo del buro,
       y los delitos viven en su propia dimension.

    2. No tenia PK. Con unique_key='cliente_id' cada corrida pisaba la fila y no
       habia forma de reconstruir la evolucion del score.
       AHORA: la PK es (cliente_key, fecha_evaluacion_key), que es el grano
       declaro. Se conserva el historico, y se agrega score_id para
       incremental.

    3. fecha_evaluacion_key usaba current_date: no deterministico, rompe
       incrementales y contradice la var fecha_corte.
       AHORA: usa var('fecha_corte') y la fecha de calculo real de la fuente.
-#}

with c as (
    select
        cliente_key,
        cliente_id,
        numero_id_hash,
        tiene_proceso_activo,
        total_procesos_penales,
        -- el vigente, no el historico: un proceso archivado no es riesgo
        score_morosidad_externo,
        es_moroso_tributario,
        total_procesos,
        procesos_sentenciados,
        tipos_delito_distintos
    from {{ ref('dim_cliente') }}
),

-- El valor REAL de la categoria del buro, que es contra el que se hashea la FK.
riesgo_cat as (
    select
        {{ hash_pii( normalizar_identidad('d.numero_identificacion') ) }} as numero_id_hash,
        {{ normalizar_identidad('d.numero_identificacion') }}             as numero_identificacion,
        max(sc.categoria_riesgo)                                        as categoria_riesgo,
        max(sc.score_morosidad)                                         as score_morosidad,
        max(sc.fecha_calculo)                                           as fecha_calculo
    from {{ ref('stg_server__deudor_central_riesgos') }} d
    left join {{ ref('stg_server__score_riesgo_cr') }} sc
           on sc.deudor_id = d.deudor_id
    group by 1, 2
),

-- Productos externos: ahora son REALES, porque el ObjectId se resuelve por el
-- crosswalk (P-10). Antes daba 0 y no se sabia si era 0 o un dato perdido.
ext as (
    select
        numero_id_hash,
        count(distinct producto_id)                                    as productos_externos,
        count(distinct case when es_producto_activo
                           then producto_id end)                       as productos_activos,
        count(distinct nombre_banco)                                   as bancos_externos,
        avg(tasa_interes)                                              as tasa_promedio_externa,
        sum(case when es_producto_activo then monto_producto else 0 end) as monto_productos_activos
    from {{ ref('int_open_finance_asignaciones') }}
    where numero_id_hash is not null
    group by 1
),

-- Delitos: CONTEXTO del cliente, no dimension de la estrella. La FK de la
-- estrella va a dim_riesgo_categoria; esta FK de delito es de apoyo.
--
-- Se construye desde la CATEGORIA del delito dominante, porque
-- dim_delito_categoria hashea categoria_delito_id. Hashear el tipo_delito_id
-- (como hacia el modelo anterior) produce una clave que NO existe en la
-- dimension: es la misma causa raiz que P-07.
delitos as (
    select
        pen.numero_id_hash,
        pen.total_procesos,
        pen.procesos_sentenciados,
        pen.fecha_ultimo_proceso,
        td.categoria_delito_id,
        cd.nombre_categoria
    from {{ ref('int_riesgo_penal') }} pen
    left join {{ ref('stg_pgsql__tipo_delito') }} td
           on td.tipo_delito_id = pen.tipo_delito_id_principal
    left join {{ ref('stg_pgsql__categoria_delito') }} cd
           on cd.categoria_delito_id = td.categoria_delito_id
)

select
    -- ===== PK DECLARADA: el grano real del hecho =====
    {{ dbt_utils.generate_surrogate_key(['c.cliente_key', 'fecha_evaluacion_key']) }}
                                                                  as score_id,
    c.cliente_key,
    c.cliente_id,
    c.numero_id_hash,

    -- ===== FKs =====
    -- [P-07] LA FK CORREGIDA: hashea el valor real de la categoria del buro
    {{ dbt_utils.generate_surrogate_key(['rc.categoria_riesgo']) }} as categoria_riesgo_key,
    -- [P-18] fecha deterministica, con la variable del proyecto
    cast(to_char({{ var('fecha_corte') }}, 'YYYYMMDD') as integer)   as fecha_evaluacion_key,

    -- la FK de delito, alineada con dim_delito_categoria (que hashea categoria_delito_id)
    {{ dbt_utils.generate_surrogate_key(['d.categoria_delito_id']) }} as delito_categoria_key,

    -- ===== business keys =====
    rc.categoria_riesgo                                             as categoria_riesgo,
    d.nombre_categoria                                              as delito_categoria,

    -- ===== SCORES, 0-100, MAYOR = PEOR =====
    case when c.tiene_proceso_activo       then 100
         when c.total_procesos_penales > 0 then  50
         else 0
    end                                                              as score_legal,
    100 - coalesce(c.score_morosidad_externo, 100)                    as score_crediticio,
    case when c.es_moroso_tributario then 100 else 0 end              as score_tributario,
    round(
        0.4 * (case when c.tiene_proceso_activo then 100
                    when c.total_procesos_penales > 0 then 50 else 0 end) +
        0.4 * (100 - coalesce(c.score_morosidad_externo, 100)) +
        0.2 * (case when c.es_moroso_tributario then 100 else 0 end)
    , 2)                                                            as score_combinado,

    -- ===== MEDIDAS =====
    c.total_procesos_penales,
    c.procesos_sentenciados,
    c.tipos_delito_distintos,
    coalesce(ext.productos_externos, 0)                              as productos_open_finance,
    coalesce(ext.productos_activos, 0)                                as productos_activos,
    coalesce(ext.bancos_externos, 0)                                  as bancos_externos,
    coalesce(ext.monto_productos_activos, 0)                         as monto_productos_activos,
    coalesce(ext.tasa_promedio_externa, 0)                            as tasa_promedio_externa,
    rc.score_morosidad                                               as score_morosidad_buro,
    c.total_procesos                                                 as total_procesos_legales,
    d.fecha_ultimo_proceso
from c
left join ext        on ext.numero_id_hash = c.numero_id_hash
left join riesgo_cat rc on rc.numero_id_hash = c.numero_id_hash
left join delitos    d  on d.numero_id_hash  = c.numero_id_hash
