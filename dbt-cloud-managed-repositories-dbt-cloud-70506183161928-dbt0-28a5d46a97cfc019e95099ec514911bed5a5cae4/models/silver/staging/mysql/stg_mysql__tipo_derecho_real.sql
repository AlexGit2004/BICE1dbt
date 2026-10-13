{{ config(materialized='view') }}

{#-
    stg_mysql__tipo_derecho_real.sql  (NUEVO)  *** F5 ***
    Catalogo del Codigo Civil: derechos reales y cargas sobre inmuebles.
    Consumido por derecho_real_inscripcion y gravamen_garantia_prestamo.
-#}

with source as (
    select * from {{ source('bronze', 'mysql_tipo_derecho_real') }}
),

renamed as (
    select
        cast(TIPO_DERECHO_REAL_ID as integer)      as tipo_derecho_real_id,
        {{ limpiar_texto('CODIGO', 'SIN CODIGO') }} as codigo,
        {{ limpiar_texto('NOMBRE_TIPO', 'SIN TIPO') }} as nombre_tipo,
        {{ limpiar_texto('DESCRIPCION', '') }}    as descripcion,
        cast(ES_GARANTIA        as boolean)        as es_garantia,
        cast(ES_TRANSMISION     as boolean)        as es_transmision,
        cast(REQUIERE_VALUACION as boolean)        as requiere_valuacion,
        _airbyte_extracted_at,
        _airbyte_raw_id
    from source
),

deduplicated as (
    select *,
        row_number() over (
            partition by tipo_derecho_real_id
            order by _airbyte_extracted_at desc nulls last,
                     _airbyte_raw_id        desc nulls last
        ) as _rn
    from renamed
)

select
    tipo_derecho_real_id,
    codigo,
    nombre_tipo,
    descripcion,
    es_garantia,
    es_transmision,
    requiere_valuacion
from deduplicated
where _rn = 1
