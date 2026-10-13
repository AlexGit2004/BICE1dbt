{{ config(materialized='view') }}

{#-
    stg_xwalk__normalizacion.sql  (NUEVO)
    La serie de reglas de normalizacion es DATO, no codigo.
    Se expone como tabla para que sea auditable, y para que un test pueda
    verificar que las 7 fuentes tienen la serie completa.
-#}

with source as (
    select * from {{ source('bronze', 'mysql_regla_normalizacion_identidad') }}
),

renamed as (
    select
        cast(REGLA_ID       as smallint)   as regla_id,
        upper(trim(cast(ORIGEN_SISTEMA as varchar(8)))) as origen_sistema,
        cast(ORDEN          as smallint)   as orden,
        upper(trim(cast(OPERACION    as varchar(20))))  as operacion,
        cast(ARGUMENTO      as varchar(20)) as argumento,
        trim(cast(DESCRIPCION as varchar(200)))        as descripcion,
        _airbyte_extracted_at,
        _airbyte_raw_id
    from source
),

deduplicated as (
    select *,
        row_number() over (
            partition by regla_id
            order by _airbyte_extracted_at desc nulls last,
                     _airbyte_raw_id        desc nulls last
        ) as _rn
    from renamed
)

select
    regla_id,
    origen_sistema,
    orden,
    operacion,
    argumento,
    descripcion,
    -- metadato derivado: la serie completa por fuente, para validar cobertura
    count(*) over (partition by origen_sistema)                  as reglas_de_la_fuente,
    max(orden) over (partition by origen_sistema)                 as ultima_orden,
    case when sum(case when operacion = 'MAYUSCULAS' then 1 else 0 end)
              over (partition by origen_sistema) = 1
         then true else false end                                as tiene_mayusculas
from deduplicated
where _rn = 1
