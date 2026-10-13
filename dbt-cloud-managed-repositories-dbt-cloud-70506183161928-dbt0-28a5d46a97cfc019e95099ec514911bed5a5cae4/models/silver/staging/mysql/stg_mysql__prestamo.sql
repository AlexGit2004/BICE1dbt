{{ config(materialized='view') }}

{#-
    stg_mysql__prestamo.sql  (CORREGIDO)
    REGLA 1: no se admiten columnas inventadas ni ENUMs de texto.

    QUE CAMBIA
      [1] estado_prestamo_tipo_id: era  cast(null as smallint)  -> ahora lee la
          FK real que declara el DDL corregido. Con esto
          fact_prestamos.estado_prestamo_key deja de ser NULL y
          dim_estado_prestamo deja de ser una dimension muerta.
      [1] fecha_vencimiento: era  cast(null as date)  -> ahora lee la columna
          real. int_prestamos_limpios deja de inventarla con dateadd().
      [1] dias_atraso: ahora sale de dias_mora_al_ultimo_pago, que es el hecho
          que origina la mora, y no de un contador manual.
      [2] numero_id_hash: se calcula sobre el texto NORMALIZADO, para que el
          cruce con las otras 6 fuentes sea hash-contra-hash de verdad.
      [3] SE ELIMINAN las columnas que no vienen de la fuente.
-#}

with source as (
    select * from {{ source('bronze', 'mysql_prestamo') }}
),

renamed as (
    select
        cast(PRESTAMO_ID           as bigint)        as prestamo_id,
        cast(SOLICITUD_ID          as bigint)        as solicitud_id,
        cast(CLIENTE_ID            as integer)       as cliente_id,
        cast(PRODUCTO_ID           as smallint)      as producto_id,
        cast(AGENCIA_ID            as smallint)      as agencia_id,
        cast(FECHA_ORIGINACION     as date)          as fecha_originacion,
        cast(FECHA_VENCIMIENTO    as date)          as fecha_vencimiento,
        cast(MONTO_APROBADO_BS    as decimal(14,2)) as monto_aprobado_bs,
        cast(TASA_INTERES_APLICADA as decimal(5,2))  as tasa_interes_aplicada,
        cast(PLAZO_APROBADO_MESES as integer)       as plazo_aprobado_meses,
        cast(CUOTA_MENSUAL_BS      as decimal(12,2)) as cuota_mensual_bs,
        cast(SALDO_ACTUAL_BS      as decimal(14,2)) as saldo_actual_bs,
        -- [1] la mora real observada, no un contador
        cast(DIAS_MORA_AL_ULTIMO_PAGO as integer)    as dias_atraso,
        -- [1] LA FK REAL. Antes era NULL.
        cast(ESTADO_PRESTAMO_ID   as integer)       as estado_prestamo_tipo_id,
        _airbyte_extracted_at,
        _airbyte_raw_id
    from source
    where prestamo_id is not null
),

deduplicated as (
    select *,
        row_number() over (
            partition by prestamo_id
            order by _airbyte_extracted_at desc nulls last,
                     _airbyte_raw_id        desc nulls last
        ) as _rn
    from renamed
)

select
    prestamo_id,
    solicitud_id,
    cliente_id,
    producto_id,
    agencia_id,
    fecha_originacion,
    fecha_vencimiento,
    monto_aprobado_bs,
    tasa_interes_aplicada,
    plazo_aprobado_meses,
    cuota_mensual_bs,
    saldo_actual_bs,
    dias_atraso,
    estado_prestamo_tipo_id          -- [1] ya no es NULL
from deduplicated
where _rn = 1
