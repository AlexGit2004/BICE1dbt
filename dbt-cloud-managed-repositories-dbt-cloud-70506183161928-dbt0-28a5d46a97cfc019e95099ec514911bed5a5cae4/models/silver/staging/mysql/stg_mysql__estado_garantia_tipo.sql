{{ config(materialized='view') }}

{#-
    stg_mysql__estado_garantia_tipo.sql  (NUEVO)
    Catalogo del ciclo de vida de la garantia. Antes el estado era un ENUM de
    texto sin catalogo, y silver lo descartaba. Ahora es una dimension.
-#}

with source as (
    select * from {{ source('bronze', 'mysql_estado_garantia_tipo') }}
),

renamed as (
    select
        cast(ESTADO_GARANTIA_ID as integer)      as estado_garantia_id,
        {{ limpiar_texto('NOMBRE_ESTADO') }}     as nombre_estado,
        {{ limpiar_texto('DESCRIPCION', '') }}   as descripcion,
        cast(PERMITE_REEXIGIR as boolean)        as permite_reexigir,
        _airbyte_extracted_at,
        _airbyte_raw_id
    from source
),

deduplicated as (
    select *,
        row_number() over (
            partition by estado_garantia_id
            order by _airbyte_extracted_at desc nulls last,
                     _airbyte_raw_id        desc nulls last
        ) as _rn
    from renamed
)

select estado_garantia_id, nombre_estado, descripcion, permite_reexigir
from deduplicated
where _rn = 1
