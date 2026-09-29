{{ config(materialized='table', unique_key='banco_externo_key') }}

{#-
    dim_banco_externo.sql  (NUEVO)
    Catalogo de las instituciones que publican datos via Open Finance (F5b).

    POR QUE ES UNA DIMENSION Y NO UNA COLUMNA
    ---------------------------------------------------------------------------
    int_open_finance_productos traia el nombre del banco repetido dentro de
    cada producto. Sin dimension, "en que bancos esta expuesto el cliente" solo
    se podia responder contando valores distintos, y el tipo de institucion
    (Banco / Cooperativa / Financiera) no existia en ningun lado.

    El nombre del BANCO es el catalogo; el PRODUCTO es un atributo de la
    exposicion y va en la fact, con el banco como FK.
-#}

with p as (
    select * from {{ ref('int_open_finance_productos') }}
)

select
    {{ dbt_utils.generate_surrogate_key(['p.banco_nombre']) }} as banco_externo_key,
    p.banco_nombre                                        as banco_nombre,
    -- tipo de institucion, derivado del nombre. Es la misma clasificacion que
    -- usa dim_entidad para el buro interno, y por eso se puede sumar
    -- exposicion interna y externa en la misma medida.
    case
        when p.banco_nombre like '%BANC%'       then 'Banco'
        when p.banco_nombre like '%COOPERATIVA%' then 'Cooperativa'
        when p.banco_nombre like '%FINANCIERA%'  then 'Financiera'
        when p.banco_nombre like '%MUTUAL%'      then 'Mutual'
        else                                         'Otra'
    end                                                   as tipo_institucion,
    case
        when p.banco_nombre like '%BANC%'       then 1.00
        when p.banco_nombre like '%FINANCIERA%'  then 0.85
        when p.banco_nombre like '%COOPERATIVA%' then 0.70
        else                                         0.50
    end                                                   as factor_prioridad_cobro,
    count(distinct p.producto_id)                          as productos_publicados,
    max(p.tasa_interes)                                   as tasa_maxima_publicada,
    avg(p.tasa_interes)                                   as tasa_promedio_publicada,
    avg(p.plazo_max)                                      as plazo_promedio_meses
from p
group by 1, 2
