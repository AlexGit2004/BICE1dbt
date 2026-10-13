{{ config(materialized='view') }}

{#-
    stg_mysql__bien_inmueble.sql  (NUEVO)  *** F5 ***
    Maestro de inmuebles. La PK DE NEGOCIO es matricula_inmueble, no
    inmueble_id: el numero autoincremental no significa nada fuera de esta base,
    que es el mismo problema de cliente_id, resuelto al reves.
-#}

with source as (
    select * from {{ source('bronze', 'mysql_bien_inmueble') }}
),

renamed as (
    select
        cast(INMUEBLE_ID        as integer)        as inmueble_id,
        {{ limpiar_texto('MATRICULA_INMUEBLE', 'SIN MATRICULA') }} as matricula_inmueble,
        {{ limpiar_texto('TIPO_INMUEBLE', 'SIN CLASIFICAR') }}  as tipo_inmueble,
        {{ limpiar_texto('DESCRIPCION', '') }}    as descripcion,
        {{ limpiar_texto('DIRECCION', '') }}       as direccion,
        {{ limpiar_texto('ZONA', '') }}            as zona,
        -- departamento es TEXTO y no FK contra babsa_creditos.departamento:
        -- MySQL no admite FK entre bases. Se normaliza con la misma serie de
        -- reglas que el crosswalk para poder cruzarlo en el silver.
        {{ limpiar_texto('DEPARTAMENTO', 'SIN DATO') }} as departamento,
        cast(SUPERFICIE_M2    as decimal(12,2))    as superficie_m2,
        cast(VALOR_COMERCIAL_BS as decimal(14,2))  as valor_comercial_bs,
        cast(VALOR_AVALUO_BS  as decimal(14,2))    as valor_avaluo_bs,
        cast(FECHA_AVALUO     as date)             as fecha_avaluo,
        {{ limpiar_texto('ESTADO_INMUEBLE', 'SIN DATO') }} as estado_inmueble,
        _airbyte_extracted_at,
        _airbyte_raw_id
    from source
),

deduplicated as (
    select *,
        row_number() over (
            partition by inmueble_id
            order by _airbyte_extracted_at desc nulls last,
                     _airbyte_raw_id        desc nulls last
        ) as _rn
    from renamed
)

select
    inmueble_id,
    matricula_inmueble,
    tipo_inmueble,
    descripcion,
    direccion,
    zona,
    departamento,
    superficie_m2,
    valor_comercial_bs,
    valor_avaluo_bs,
    fecha_avaluo,
    estado_inmueble
from deduplicated
where _rn = 1
