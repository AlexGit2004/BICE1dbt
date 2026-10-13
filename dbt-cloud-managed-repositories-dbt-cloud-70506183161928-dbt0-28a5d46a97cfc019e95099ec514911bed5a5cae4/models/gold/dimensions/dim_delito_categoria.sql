{{ config(materialized='table', unique_key='delito_categoria_key') }}

{#-
    dim_delito_categoria.sql  (NUEVO)
    REGLA 3: separar los dominios de riesgo y de delito.

    Este catalogo vivia dentro de dim_riesgo_categoria mezclado con un `union`,
    lo que hacia que la FK de fact_riesgo nunca encontrara su padre. Aqui vive
    solo, y responde a la pregunta que le corresponde: DE QUE se acusa a la
    gente con proceso.

    Es consumida por fact_riesgo como atributo de contexto, no como dimension de
    la estrella de riesgo: el delito explica al cliente de riesgo, pero la
    dimension de la estrella es la categoria de riesgo.
-#}

with cat as (
    select
        categoria_delito_id,
        {{ limpiar_texto('nombre_categoria') }}  as categoria_delito,
        {{ limpiar_texto('descripcion', '') }}   as descripcion_categoria
    from {{ ref('stg_pgsql__categoria_delito') }}
),

delitos as (
    select
        tipo_delito_id,
        {{ limpiar_texto('nombre_delito') }} as nombre_delito,
        codigo_penal,
        categoria_delito_id
    from {{ ref('stg_pgsql__tipo_delito') }}
)

select
    {{ dbt_utils.generate_surrogate_key(['c.categoria_delito_id']) }} as delito_categoria_key,
    c.categoria_delito_id                              as delito_categoria_id,
    c.categoria_delito,
    c.descripcion_categoria,
    count(distinct d.tipo_delito_id)                  as tipos_delito,
    -- un catalogo sin articulos no sirve: sin esto el nombre de la categoria
    -- no se puede mostrar en el BI
    string_agg(distinct d.nombre_delito, ', ')
        within group (order by d.nombre_delito)       asemplos_delito
from cat c
left join delitos d on d.categoria_delito_id = c.categoria_delito_id
group by 1, 2, 3, 4
