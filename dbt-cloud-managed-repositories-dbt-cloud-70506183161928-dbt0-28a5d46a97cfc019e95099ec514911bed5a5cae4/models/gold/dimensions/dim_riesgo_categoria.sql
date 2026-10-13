{{ config(materialized='table', unique_key='categoria_key') }}

{#-
    dim_riesgo_categoria.sql  (CORREGIDO)  *** REGLA 3 ***

    EL ERROR QUE ESTE MODELO TENIA (P-07)
    ---------------------------------------------------------------------------
    Antes hacia un `union` de DOS DOMINIOS DISTINTOS:
        (a) score_riesgo_cr.categoria_riesgo  -> 'Riesgo Alto', 'Riesgo Medio', 'Bajo'
        (b) pgsql_categoria_delito.nombre_categoria -> 'Violento', 'Economico', 'Fraude'
    y fact_riesgo calculaba su FK con
        generate_surrogate_key(['c.estado_riesgo'])
    donde estado_riesgo es el SEMAFORO 'Alto' / 'Medio' / 'Bajo'.

    Los dos conjuntos de strings NUNCA coinciden, asi que la FK devolvia 0 filas
    en el 100% de los casos. No daba error: la relacion salia vacia y el
    catalogo de 13 categorias parecia unusuable.

    "NIVEL DE RIESGO DE UN DEUDOR" y "TIPO DE DELITO" NO SON LA MISMA DIMENSION.
    Son dos tasas de analisis distintas, con dos ciertas preguntas distintas:
      - nivel de riesgo: "mis clientes mas riesgosos estan en que nivel?"
      - tipo de delito: "de que se acusa a la gente con proceso?"

    LA SEPARACION
    ---------------------------------------------------------------------------
      dim_riesgo_categoria  -> SOLO el dominio de riesgo, desde score_riesgo_cr
      dim_delito_categoria  -> SOLO el dominio de delito, desde pgsql
    Y fact_riesgo apunta a la primera, con el valor REAL de la columna, no con
    el semaforo.
-#}

with categorias as (
    select
        trim(categoria_riesgo)                  as categoria,
        'SCORE_CR'                              as origen_categoria,
        'Buro de credito (F3)'                  as descripcion_origen
    from {{ ref('stg_server__score_riesgo_cr') }}
    where categoria_riesgo is not null
      and trim(categoria_riesgo) <> ''
    group by 1, 2, 3
)

select
    {{ dbt_utils.generate_surrogate_key(['categoria']) }} as categoria_key,
    categoria,
    'SCORE_CR'                                              as origen_categoria,
    'Buro de credito (F3)'                                  as descripcion_origen,

    -- La FK de fact_riesgo se calcula sobre ESTA columna, con el valor real.
    -- Es lo que arregla la relacion: hash(mismo string) = mismo hash.
    case
        when upper(categoria) like '%MUY ALTO%' or upper(categoria) like '%CRITICO%'
            then 'Alto'
        when upper(categoria) like '%ALTO%'    then 'Alto'
        when upper(categoria) like '%MEDIO%'   then 'Medio'
        when upper(categoria) like '%BAJO%'    then 'Bajo'
        else                                       'Sin clasificar'
    end                                                    as nivel_normalizado,

    -- orden explicito, para que el semaforo del BI no ordene alfabeticamente
    case
        when upper(categoria) like '%MUY ALTO%' or upper(categoria) like '%CRITICO%' then 4
        when upper(categoria) like '%ALTO%'    then 3
        when upper(categoria) like '%MEDIO%'   then 2
        when upper(categoria) like '%BAJO%'    then 1
        else                                          0
    end                                                    as orden_nivel,

    -- el puntaje que acompana a la categoria, cuando la fuente lo trae
    'Niveles de riesgo de la central de riesgos. Dominio DISTINTO del de delitos.'
                                                       as nota_dominio
from categorias
