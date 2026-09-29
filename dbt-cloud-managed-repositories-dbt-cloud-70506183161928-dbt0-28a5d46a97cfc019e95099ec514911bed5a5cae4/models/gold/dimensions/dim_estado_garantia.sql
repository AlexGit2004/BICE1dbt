{{ config(materialized='table', unique_key='estado_garantia_key') }}

{#-
    dim_estado_garantia.sql  (NUEVO)
    P-06: el ciclo de vida de la garantia es informacion LEGAL, no opcional.

    Antes el estado era un ENUM de texto en el DDL que silver descartaba, asi que
    el DW no podia responder "cuantas garantias se ejecutaron este anio" ni "el
    cliente X todavia tiene el inmueble en garantia o ya se lo devolvimos".

    Now es un catalogo con dimension propia, referenciado por
    fact_garantias.estado_garantia_key.

    permite_reexigir es el atributo que hace que la dimension sirva: una garantia
    EJECUTADA ya no respalda el credito, y el indice de cobertura de la cartera
    tiene que excluirla. Sin esa columna, el LTV de la cartera se sobreestima.
-#}

select
    {{ dbt_utils.generate_surrogate_key(['estado_garantia_id']) }} as estado_garantia_key,
    estado_garantia_id                                     as estado_garantia_id,
    nombre_estado,
    descripcion,
    permite_reexigir,

    -- ciclo de vida ordenado, para que el BI no ordene alfabeticamente
    case upper(nombre_estado)
        when 'VIGENTE'    then 1
        when 'EJECUTADA'  then 2
        when 'TRANSFERIDA' then 3
        when 'LIBERADA'   then 4
        else 0
    end                                                     as orden_ciclo_vida,
    case
        when permite_reexigir        then 'ACTIVA'
        when upper(nombre_estado) = 'EJECUTADA'  then 'EJECUTADA (PERDIDA)'
        else                                           'CERRADA'
    end                                                     as situacion_garantia,
    -- True si el bien sigue respaldando el credito. Es el filtro que debe
    -- aplicarse a cualquier calculo de cobertura de cartera.
    coalesce(permite_reexigir, false)                     as cuenta_para_cobertura
from {{ ref('stg_mysql__estado_garantia_tipo') }}
