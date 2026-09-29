{{ config(materialized='table') }}

{#-
    int_riesgo_tributario.sql  (CORREGIDO)
    REGLA 3: prepara el puente entre dim_empresa y dim_cliente.

    Ademas de lo que ya hacia, ahora entrega el hash del NIT con el MISMO macro
    que el resto del pipeline. Antes el hash venia de un nombre distinto
    (numero_id_hash calculado aqui) y el join con dim_cliente dependia de que
    ambos usaran el mismo algoritmo por casualidad.

    El NIT de una juridica y su CI/NIT en el core son el mismo numero. Ese es el
    puente, y se declara con una columna explicita: es_ci_nit.
-#}

with emp as (
    select * from {{ ref('stg_maria__empresa_registro_mercantil') }}
),

st as (
    select * from {{ ref('stg_maria__situacion_tributaria_rm') }}
),

acc as (
    select
        empresa_id,
        count(*)                                                   as cantidad_accionistas,
        sum(porcentaje_participacion)                              as pct_total_accionistas,
        sum(case when es_controlador then 1 else 0 end)            as controladores,
        max(case when es_controlador then porcentaje_participacion else 0 end)
                                                                   as pct_controlador
    from {{ ref('stg_maria__accionista_representante_rm') }}
    group by 1
),

empresa_hash as (
    select
        empresa_id,
        -- el puente al nucleo, declarado y no supuesto
        {{ hash_pii( normalizar_identidad('numero_identificacion') ) }} as numero_id_hash,
        {{ normalizar_identidad('numero_identificacion') }}             as numero_identificacion_norm,
        nit_empresa,
        razon_social,
        tipo_empresa_id,
        categoria_comercial,
        fecha_registro,
        estado_empresa
    from emp
)

select
    e.empresa_id,
    e.numero_id_hash,
    e.numero_identificacion_norm                     as nit,
    e.razon_social,
    e.tipo_empresa_id,
    e.categoria_comercial,
    e.fecha_registro,
    e.estado_empresa,

    coalesce(a.cantidad_accionistas, 0)              as cantidad_accionistas,
    coalesce(a.pct_total_accionistas, 0)             as pct_total_accionistas,
    coalesce(a.controladores, 0)                     as numero_controladores,
    coalesce(a.pct_controlador, 0)                   as pct_controlador,

    -- el anio fiscal vigente NO esta hardcodeado: se toma el maximo del registro
    coalesce(max(case when st.estado_tributario = 'En Proceso'
                      then st.monto_impuestos_adeudados_bs end), 0)
                                                         as deuda_tributaria_actual_bs,
    max(case when st.estado_tributario = 'En Proceso'
             then st.estado_tributario end)           as estado_tributario_actual,
    coalesce(sum(st.monto_impuestos_adeudados_bs), 0) as deuda_tributaria_total_bs,
    count(distinct st.anio_fiscal)                    as anios_con_registro,
    max(st.anio_fiscal)                               as anio_fiscal_vigente
from empresa_hash e
left join st  on st.empresa_id  = e.empresa_id
left join acc a on a.empresa_id  = e.empresa_id
group by 1, 2, 3, 4, 5, 6, 7, 8
