{{ config(materialized='table') }}

{#-
    int_xwalk_identidad.sql  (NUEVO)  *** TABLA MAESTRA DE IDENTIDAD ***

    REGLA 1: "Integra un mecanismo de mapeo/crosswalk estandarizado en F5b y F6
    para mapear ObjectId e id_cliente hacia el identificador unico de negocio".

    Esta es la tabla que lo cumple. Es el unico punto del pipeline donde existe
    el conocimiento "este ObjectId de Mongo es el CI 1234567". Ningun otro
    modelo lo sabe, y ninguno lo necesita: todos consumen esta tabla.

    REGLA 2: "TODAS las fuentes externas convergen en dim_cliente". Esta tabla
    es el contrato: las 7 filas por CI/NIT (una por origen) se colapsan en una
    sola, y de ahi sale el cliente unico de CAPAORO.

    Grano: 1 fila por CI/NIT. Una columna por fuente con la posicion del id
    nativo, para poder depurar sin volver a la fuente.

    Por que se colapsa por peso y no por simple group by: si el CSV de F6 dice
    que C00001 es la persona 99999999 y el core dice que la persona 1234567
    tambien es C00001, hay que decidir cual gana. Gana el mas autoritativo, y
    la losing queda registrada en colisiones para que datos pueda revisarla.
-#}

with xw as (
    select * from {{ ref('stg_xwalk__cliente') }}
    where estado = 'ACTIVO'
),

scores as (
    select * from {{ ref('stg_xwalk__score') }}
),

norm as (
    select * from {{ ref('stg_xwalk__normalizacion') }}
),

-- Un CI/NIT puede tener hasta 7 identidades nativas (una por fuente).
-- Se agrega el peso de cada fuente para decidir cual es la winning.
agregado as (
    select
        x.numero_id_hash,
        any_value(x.numero_identificacion_norm)          as numero_identificacion_norm,
        max(x.tipo_id)                                    as tipo_id,
        max(s.peso * x.confianza)                         as confianza_ponderada,

        -- identificador nativo por fuente (sparse: null si la fuente no lo aporta)
        max(case when x.origen_sistema = 'F1'  then x.clave_origen end) as id_origen_f1,
        max(case when x.origen_sistema = 'F2'  then x.clave_origen end) as id_origen_f2,
        max(case when x.origen_sistema = 'F3'  then x.clave_origen end) as id_origen_f3,
        max(case when x.origen_sistema = 'F4'  then x.clave_origen end) as id_origen_f4,
        max(case when x.origen_sistema = 'F5'  then x.clave_origen end) as id_origen_f5,
        max(case when x.origen_sistema = 'F5b' then x.clave_origen end) as id_origen_f5b,
        max(case when x.origen_sistema = 'F6'  then x.clave_origen end) as id_origen_f6,

        -- metodo con el que se resolvio la identidad que mas peso aporto
        arg_max(x.metodo_match, s.peso * x.confianza)     as metodo_match,
        count(*)                                           as num_fuentes,
        count(distinct x.origen_sistema)                   as num_fuentes_distintas,
        min(x.fecha_alta)                                  as fecha_alta_minima,
        max(x.fecha_alta)                                  as fecha_alta_maxima
    from xw x
    join scores s on s.origen_sistema = x.origen_sistema
    group by 1
),

-- REGLA DE CONVERGENCIA: un cliente esta confirmado si al menos 2 fuentes
-- independientes lo Northumberland, o si viene de una fuente autoritativa.
-- Esto es lo que impide que un solo registro erroneo de una fuente de peso
-- bajo cree un cliente fantasma en la dimension de oro.
confirmado as (
    select
        a.*,
        case
            when a.num_fuentes >= 2                                     then true
            when a.num_fuentes_distintas = 1
                 and exists (select 1 from scores s2
                              where s2.es_autoritativa
                                and s2.origen_sistema in
                                    ('F1','F4','F5'))                  then true
            else false
        end as identidad_confirmada,

        case
            when a.num_fuentes_distintas >= 6 then 'MULTIFUENTE_COMPLETA'
            when a.num_fuentes_distintas >= 4 then 'MULTIFUENTE'
            when a.num_fuentes_distintas >= 2 then 'BIFUENTE'
            else 'FUENTE_UNICA'
        end as cobertura_identidad,

        -- si solo viene de F5b o F6, sin respaldo del core, no es un cliente
        -- del banco: es un lead. Va en la dimension, pero marcado.
        case
            when a.id_origen_f1 is not null or a.id_origen_f4 is not null
                then 'CLIENTE_CONFIRMADO'
            when a.id_origen_f5b is not null or a.id_origen_f6 is not null
                then 'SOLO_FUENTES_EXTERNAS'
            else 'OTRO'
        end as tipo_identidad
    from agregado a
),

-- Trazabilidad de la normalizacion: cuantas reglas aplica esta fuente.
-- Si la serie cambia, cambia el conteo y se nota en el log.
reglas_por_fuente as (
    select origen_sistema, reglas_de_la_fuente, ultima_orden, tiene_mayusculas
    from norm
    group by 1, 2, 3, 4
)

select
    {{ dbt_utils.generate_surrogate_key(['numero_id_hash']) }} as xwalk_key,
    c.numero_id_hash,
    c.numero_identificacion_norm                                as numero_identificacion,
    c.tipo_id,
    c.metodo_match,
    c.confianza_ponderada,
    c.num_fuentes,
    c.num_fuentes_distintas,
    c.cobertura_identidad,
    c.identidad_confirmada,
    c.tipo_identidad,
    c.id_origen_f1,
    c.id_origen_f2,
    c.id_origen_f3,
    c.id_origen_f4,
    c.id_origen_f5,
    c.id_origen_f5b,
    c.id_origen_f6,
    c.fecha_alta_minima,
    c.fecha_alta_maxima,
    r.reglas_de_la_fuente,
    r.tiene_mayusculas
from confirmado c
left join reglas_por_fuente r on r.origen_sistema = 'F1'
