{{ config(materialized='view') }}

{#-
    stg_xwalk__score.sql  (NUEVO)
    Peso y autoridad de cada fuente como identificador.

    F1 y F4 son autoritativas: el Registro Mercantil es el registro publico de
    empresas, y el core operacional es el maestro de clientes. F6 (CSV de
    simulacion) vale 0.60: si una identidad de F6 contradice a F1, gana F1.

    Esto se usa en int_xwalk_identidad para resolver colisiones y para exponer
    el nivel de confianza en la dimension de oro.
-#}

with source as (
    select * from {{ source('bronze', 'mysql_xwalk_score') }}
),

renamed as (
    select
        upper(trim(cast(ORIGEN_SISTEMA as varchar(8))))   as origen_sistema,
        cast(PESO          as decimal(3,2)) as peso,
        cast(ES_AUTORITATIVA as boolean)     as es_autoritativa,
        trim(cast(DESCRIPCION as varchar(200)))         as descripcion,
        _airbyte_extracted_at,
        _airbyte_raw_id
    from source
),

deduplicated as (
    select *,
        row_number() over (
            partition by origen_sistema
            order by _airbyte_extracted_at desc nulls last,
                     _airbyte_raw_id        desc nulls last
        ) as _rn
    from renamed
)

select
    origen_sistema,
    peso,
    es_autoritativa,
    descripcion,
    -- nivel de autoridad como etiqueta, para usarla como color en el BI
    case when peso >= 0.95 then 'AUTORITATIVA'
         when peso >= 0.80 then 'ALTA'
         when peso >= 0.70 then 'MEDIA'
         else                   'BAJA'
    end as nivel_autoridad
from deduplicated
where _rn = 1
