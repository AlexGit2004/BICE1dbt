{{ config(materialized='table', unique_key='estado_prestamo_key') }}

{#-
    dim_estado_prestamo.sql  (CORREGIDO)
    P-01: la dimension era inalcanzable porque prestamo.estado_prestamo era un
    ENUM de texto que el stg convertia en NULL. Con el DDL corregido,
    prestamo.estado_prestamo_id es una FK real, y la dimension tiene hechos que
    la referencian.

    Tambien se deja de RECALCULAR es_estado_terminal: la fuente ya trae esa
    columna y el catalogo es la verdad. El CASE queda como fallback para
    catalogos viejos que no la tengan poblada, no como fuente de verdad.
-#}

select
    {{ dbt_utils.generate_surrogate_key(['estado_prestamo_tipo_id']) }} as estado_prestamo_key,
    estado_prestamo_tipo_id                                       as estado_prestamo_id,
    nombre_estado,
    descripcion,
    -- la fuente manda; el CASE es fallback, no la verdad
    coalesce(es_estado_terminal,
             case when upper(nombre_estado) in ('PAGADO','INCOBRABLE')
                  then true else false end)                     as es_estado_terminal,

    -- atributos de gestion del ciclo de vida, que el BI usa para ordenar
    case
        when upper(nombre_estado) = 'VIGENTE'     then 1
        when upper(nombre_estado) = 'VENCIDO'     then 2
        when upper(nombre_estado) = 'EN EJECUCION' then 3
        when upper(nombre_estado) = 'RENOVADO'    then 4
        when upper(nombre_estado) = 'REFINANCIADO' then 5
        when upper(nombre_estado) = 'PAGADO'      then 6
        when upper(nombre_estado) = 'INCOBRABLE'  then 7
        else 0
    end                                                          as orden_ciclo_vida,
    case
        when upper(nombre_estado) = 'VIGENTE' then 'Saludable'
        when upper(nombre_estado) in ('PAGADO') then 'Cerrado sin perdida'
        when upper(nombre_estado) in ('VENCIDO','EN EJECUCION','INCOBRABLE')
             then 'En recuperacion'
        else 'En transicion'
    end                                                          as situacion_cartera
from {{ ref('stg_mysql__estado_prestamo_tipo') }}
