{{ config(materialized='view') }}

{#-
    stg_mysql__derecho_real_inscripcion.sql  (NUEVO)  *** F5 ***
    El hecho notarial: una inscripcion en el Registro de Derechos Reales.

    REGLA 1 + REGLA 2: el titular se normaliza y se hashea AQUI, una sola vez, con
    el mismo macro que las otras 6 fuentes. Es el unico lugar donde se calcula el
    hash del titular, para que despues todos los cruces sean hash-contra-hash.
-#}

with source as (
    select * from {{ source('bronze', 'mysql_derecho_real_inscripcion') }}
),

renamed as (
    select
        cast(INSCRIPCION_ID     as integer)     as inscripcion_id,
        {{ limpiar_texto('NUMERO_INSCRIPCION', 'S/N') }} as numero_inscripcion,
        cast(INMUEBLE_ID        as integer)     as inmueble_id,
        cast(TIPO_DERECHO_REAL_ID as integer)   as tipo_derecho_real_id,
        -- ===== EL PUENTE AL NUCLEO =====
        {{ normalizar_identidad('NUMERO_IDENTIFICACION_TITULAR') }} as titular_norm,
        {{ hash_pii( normalizar_identidad('NUMERO_IDENTIFICACION_TITULAR') ) }} as titular_hash,
        -- la cadena de dominio: permite trazar quien era el titular anterior
        {{ normalizar_identidad('NUMERO_IDENTIFICACION_ANTERIOR') }} as titular_anterior_norm,
        {{ hash_pii( normalizar_identidad('NUMERO_IDENTIFICACION_ANTERIOR') ) }} as titular_anterior_hash,
        cast(FECHA_INSCRIPCION  as date)         as fecha_inscripcion,
        cast(FECHA_VENCIMIENTO  as date)         as fecha_vencimiento,
        cast(MONTO_BASE_BS      as decimal(14,2)) as monto_base_bs,
        {{ limpiar_texto('NOTARIO', '') }}      as notario,
        {{ limpiar_texto('ESTADO_INSCRIPCION', 'SIN DATO') }} as estado_inscripcion,
        _airbyte_extracted_at,
        _airbyte_raw_id
    from source
),

deduplicated as (
    select *,
        row_number() over (
            partition by inscripcion_id
            order by _airbyte_extracted_at desc nulls last,
                     _airbyte_raw_id        desc nulls last
        ) as _rn
    from renamed
)

select
    inscripcion_id,
    numero_inscripcion,
    inmueble_id,
    tipo_derecho_real_id,
    titular_norm,
    titular_hash,
    titular_anterior_norm,
    titular_anterior_hash,
    fecha_inscripcion,
    fecha_vencimiento,
    -- la fecha de vencimiento solo aplica a usufructo y servidumbre. Se deja en
    -- NULL a proposito en vez de inventarse: es la diferencia entre dominio
    -- pleno y derecho con plazo.
    case when fecha_vencimiento is not null
         then true else false end                as tiene_plazo,
    datediff('day', fecha_inscripcion, coalesce(fecha_vencimiento, fecha_inscripcion))
                                                      as dias_plazo,
    monto_base_bs,
    notario,
    estado_inscripcion
from deduplicated
where _rn = 1
