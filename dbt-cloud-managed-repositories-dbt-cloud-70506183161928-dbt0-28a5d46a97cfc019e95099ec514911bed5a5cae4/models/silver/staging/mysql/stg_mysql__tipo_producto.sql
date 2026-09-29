with source as (
    select * from {{ source('bronze', 'mysql_tipo_producto') }}
),

renamed as (
    select
        cast(tipo_prod_id as smallint) as tipo_prod_id,
        {{ limpiar_texto('NOMBRE_TIPO') }} as nombre_tipo_prod,
        {{ limpiar_texto('descripcion', '') }} as descripcion,
        _airbyte_extracted_at,
        _airbyte_raw_id
    from source
),

deduplicated as (
    select *,
        row_number() over (
            partition by tipo_prod_id
            order by _airbyte_extracted_at desc nulls last,
                     _airbyte_raw_id desc nulls last
        ) as _rn
    from renamed
)

select tipo_prod_id, nombre_tipo_prod, descripcion
from deduplicated
where _rn = 1
