with source as (
    select * from {{ source('bronze', 'server_score_riesgo_cr') }}
),

renamed as (
    select
        cast(SCORE_CR_ID as integer) as score_id,
        cast(deudor_id as integer) as deudor_id,
        cast(score_morosidad as decimal(5,2)) as score_morosidad,
        {{ limpiar_texto('categoria_riesgo', 'BAJO') }} as categoria_riesgo,
        cast(fecha_calculo as date) as fecha_calculo,
        _airbyte_extracted_at,
        _airbyte_raw_id
    from source
),

deduplicated as (
    select *,
        row_number() over (
            partition by score_id
            order by _airbyte_extracted_at desc nulls last,
                     _airbyte_raw_id desc nulls last
        ) as _rn
    from renamed
)

select score_id, deudor_id, score_morosidad, categoria_riesgo, fecha_calculo
from deduplicated where _rn = 1