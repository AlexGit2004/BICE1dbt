{{ config(materialized='table', unique_key='tipo_garantia_key') }}

{#-
    dim_tipo_garantia.sql  (ACTUALIZADO)
    [CAMBIO] se agrega es_inmueble, que estaba en el DDL y no se leia.

    Es la columna que hace que la garantia tenga SENTIDO: "Hipoteca" y "Prenda"
    no son lo mismo como respaldo. Prenda es un bien movil de valor menor;
    hipoteca es un inmueble, con matricula y avaluo, verificable contra el
    Registro de Derechos Reales (fuente F5).

    Con esta bandera, la estrella 4 y la estrella 7 se conectan por el mismo
    atributo, y se puede medir que proporcion de la cartera tiene respaldo
    INMUEBLE (verificable) frente a respaldo MOVIL (confiable en el papel).
-#}

select
    {{ dbt_utils.generate_surrogate_key(['tipo_garantia_id']) }} as tipo_garantia_key,
    tipo_garantia_id                                    as tipo_garantia_id,
    nombre_tipo_garantia,
    requiere_avaluo,
    -- la bandera que distingue el respaldo real del declarado
    coalesce(es_inmueble, false)                        as es_inmueble,
    -- orden de fuerza del respaldo, para ordenar la cartera por calidad
    case when es_inmueble then 1 else 2 end             as orden_fuerza_respaldo,
    case
        when es_inmueble then 'GARANTIA INMUEBLE (verificable en F5)'
        when requiere_avaluo then 'GARANTIA MOBIL CON AVALUO'
        else 'GARANTIA SOLIDARIA'
    end                                                 as naturaleza_respaldo
from {{ ref('stg_mysql__tipo_garantia') }}
