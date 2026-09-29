{{ config(materialized='view') }}

{#-
    stg_xwalk__cliente.sql  (NUEVO)
    REGLA 1: mecanismo de mapeo/crosswalk estandarizado.

    Lee el dato maestro de identidad (F7) y lo normaliza con la MISMA macro que
    usan las 7 fuentes, para que la comparacion sea posible byte a byte.

    Da salida las 3 piezas que todo el pipeline necesita:
      clave_origen            -> como se busca el id nativo
      numero_identificacion   -> el CI/NIT real (clave natural del DW)
      numero_id_hash          -> el hash, que es con lo que se hace el join
-#}

with source as (
    select * from {{ source('bronze', 'mysql_xwalk_cliente') }}
),

renamed as (
    select
        cast(XWALK_ID              as integer)      as xwalk_id,
        cast(ORIGEN_SISTEMA        as varchar(8))   as origen_sistema,
        trim(cast(ID_ORIGEN        as varchar(64))) as id_origen,
        trim(cast(CLAVE_ORIGEN     as varchar(64))) as clave_origen_raw,
        trim(cast(NUMERO_IDENTIFICACION as varchar(20))) as numero_identificacion,
        cast(TIPO_ID               as smallint)     as tipo_id,
        {{ limpiar_texto('NOMBRE_COMPLETO', 'SIN NOMBRE') }} as nombre_completo,
        upper(trim(cast(METODO_MATCH as varchar(12))))     as metodo_match,
        cast(CONFIANZA             as decimal(3,2)) as confianza,
        upper(trim(cast(ESTADO      as varchar(10))))     as estado,
        cast(FECHA_ALTA            as date)         as fecha_alta,
        _airbyte_extracted_at,
        _airbyte_raw_id
    from source
),

deduplicated as (
    select *,
        row_number() over (
            partition by origen_sistema, id_origen
            order by _airbyte_extracted_at desc nulls last,
                     _airbyte_raw_id        desc nulls last
        ) as _rn
    from renamed
),

final as (
    select
        xwalk_id,
        origen_sistema,
        id_origen,
        -- el id nativo tambien normalizado: es la clave contra la que se busca
        {{ normalizar_identidad('clave_origen_raw') }} as clave_origen,
        -- el CI/NIT normalizado: es la clave natural de CAPAORO
        {{ normalizar_identidad('numero_identificacion') }} as numero_identificacion_norm,
        {{ hash_pii( normalizar_identidad('numero_identificacion') ) }} as numero_id_hash,
        tipo_id,
        nombre_completo,
        metodo_match,
        confianza,
        estado,
        fecha_alta
    from deduplicated
    where _rn = 1
)

select * from final
