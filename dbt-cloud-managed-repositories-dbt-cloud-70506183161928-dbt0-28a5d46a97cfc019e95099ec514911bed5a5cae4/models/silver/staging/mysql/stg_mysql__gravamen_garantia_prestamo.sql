{{ config(materialized='view') }}

{#-
    stg_mysql__gravamen_garantia_prestamo.sql  (NUEVO)  *** F5 ***
    Tabla puente entre el mundo notarial (F5) y el credito colocado (F1).

    LLEVA LAS DOS CLAVES DE CRUCE A PROPOSITO:
      numero_identificacion -> permite cruzar por CI/NIT sin pasar por F1
      prestamo_id           -> permite cruzar por el credito
    Con las dos, el cruce se puede hacer desde cualquier lado. Si solo llevara
    prestamo_id, habria que pasar siempre por babsa_creditos y se perderia el
    cruce natural por CI/NIT que usan las demas fuentes.

    REGLA 1: tipo_derecho_real_id debe ser un derecho con es_garantia = TRUE. El
    trigger trg_gravamen_es_garantia lo valida en la fuente; el test
    silver_sin_huerfanos lo revalida en silver, porque un trigger se puede
    deshabilitar y un test no.
-#}

with source as (
    select * from {{ source('bronze', 'mysql_gravamen_garantia_prestamo') }}
),

renamed as (
    select
        cast(GRAVAMEN_ID          as integer)     as gravamen_id,
        cast(INSCRIPCION_ID       as integer)     as inscripcion_id,
        cast(INMUEBLE_ID          as integer)     as inmueble_id,
        cast(TIPO_DERECHO_REAL_ID as integer)     as tipo_derecho_real_id,
        -- ===== PUENTE 1: el credito =====
        cast(PRESTAMO_ID          as bigint)      as prestamo_id,
        -- ===== PUENTE 2: la persona, por CI/NIT =====
        {{ normalizar_identidad('NUMERO_IDENTIFICACION') }} as numero_identificacion_norm,
        {{ hash_pii( normalizar_identidad('NUMERO_IDENTIFICACION') ) }} as numero_id_hash,
        cast(FECHA_INSCRIPCION_GRAVAMEN as date)  as fecha_inscripcion_gravamen,
        cast(MONTO_GARANTIZADO_BS as decimal(14,2)) as monto_garantizado_bs,
        cast(PORCENTAJE_COBERTURA as decimal(5,2))  as porcentaje_cobertura,
        cast(FECHA_LIBERACION     as date)         as fecha_liberacion,
        {{ limpiar_texto('ESTADO_GRAVAMEN', 'SIN DATO') }} as estado_gravamen,
        _airbyte_extracted_at,
        _airbyte_raw_id
    from source
),

deduplicated as (
    select *,
        row_number() over (
            partition by gravamen_id
            order by _airbyte_extracted_at desc nulls last,
                     _airbyte_raw_id        desc nulls last
        ) as _rn
    from renamed
)

select
    gravamen_id,
    inscripcion_id,
    inmueble_id,
    tipo_derecho_real_id,
    prestamo_id,
    numero_identificacion_norm,
    numero_id_hash,
    fecha_inscripcion_gravamen,
    monto_garantizado_bs,
    porcentaje_cobertura,
    fecha_liberacion,
    estado_gravamen,
    -- derivado: el gravamen esta vigente? Sin esto, el indice de cobertura
    -- de cartera contaria tambien las garantias ya liberadas.
    case when upper(estado_gravamen) = 'VIGENTE' then true else false end as es_vigente,
    -- derivado: dias que lleva vigente. NULL en un gravamen ya liberado.
    case when fecha_liberacion is not null then null
         else datediff('day', fecha_inscripcion_gravamen, current_date)
    end                                                        as dias_vigente
from deduplicated
where _rn = 1
