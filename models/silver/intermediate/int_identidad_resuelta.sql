{#-
    int_identidad_resuelta.sql
    Resumen de identidad por cliente, una fila por CI canonico.

    Es el modelo que usan todos los hechos: une el maestro F1 con el conteo de
    fuentes que confirman cada identidad. Asi ningun hecho tiene que volver a
    contar fuentes, y el flag identidad_confirmada se calcula UNA sola vez.

    Grano: una fila por cliente del maestro F1 (56.400).
-#}

{{ config(materialized='table') }}

with maestro as (

    select
        cliente_id,
        numero_identificacion          as ci_canonico,
        numero_identificacion_origen   as ci_como_llego,
        tipo_id,
        es_persona_juridica,
        nit_empresa,
        ci_representante_legal,
        nombre_completo,
        nombre_representante_legal,
        estado_cliente,
        fecha_creacion
    from {{ ref('stg_f1__cliente') }}
    where numero_identificacion is not null

),

fuentes as (

    select
        ci_canonico,
        count(distinct fuente)     as fuentes_confirmantes,
        listagg(distinct fuente, ',') within group (order by fuente)
                                    as fuentes_vistas
    from {{ ref('int_identidad_fuente') }}
    group by 1

)

select
    m.cliente_id,
    m.ci_canonico,
    -- el CI en claro queda disponible solo en Silver. En Gold se hashea.
    m.ci_como_llego,
    m.tipo_id,
    m.es_persona_juridica,
    m.nit_empresa,
    m.ci_representante_legal,
    m.nombre_completo,
    m.nombre_representante_legal,
    m.estado_cliente,
    m.fecha_creacion,

    -- identidad confirmada: 2 o mas fuentes independientes la confirman.
    -- Un solo dato puede ser un error de tipeo; dos fuentes que coinciden
    -- ya no lo son.
    coalesce(f.fuentes_confirmantes, 1)   as fuentes_confirmantes,
    f.fuentes_vistas,
    case
        when coalesce(f.fuentes_confirmantes, 1)
             >= {{ var('identidad_fuentes_minimas') }} then true
        else false
    end                                    as identidad_confirmada

from maestro m
left join fuentes f
       on m.ci_canonico = f.ci_canonico
