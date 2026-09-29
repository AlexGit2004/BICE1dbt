with source as (
    select * from {{ source('bronze', 'mysql_garantia') }}
),

renamed as (
    select
        cast(garantia_id            as bigint)   as garantia_id,
        cast(prestamo_id            as bigint)   as prestamo_id,
        cast(tipo_garantia_id       as smallint) as tipo_garantia_id,
        {{ limpiar_texto('descripcion_garantia', '') }} as descripcion_garantia,
        cast(valor_avaluo_bs        as decimal(14,2)) as valor_avaluo_bs,
        cast(cobertura_obligacion   as decimal(5,2))  as cobertura_obligacion,
        cast(fecha_valoracion       as date)     as fecha_valoracion,
        _airbyte_extracted_at,
        _airbyte_raw_id
    from source
),

deduplicated as (
    select *,
        row_number() over (
            partition by garantia_id
            order by _airbyte_extracted_at desc nulls last,
                     _airbyte_raw_id desc nulls last
        ) as _rn
    from renamed
)

select
    garantia_id, prestamo_id, tipo_garantia_id, descripcion_garantia,
    valor_avaluo_bs, cobertura_obligacion, fecha_valoracion
from deduplicated
where _rn = 1