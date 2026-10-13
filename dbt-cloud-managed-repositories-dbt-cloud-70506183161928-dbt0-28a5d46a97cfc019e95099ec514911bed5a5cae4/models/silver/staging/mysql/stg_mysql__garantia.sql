{{ config(materialized='view') }}

{#-
    stg_mysql__garantia.sql  (CORREGIDO)
    REGLA 1: el estado de la garantia es informacion legal, no opcional.

    QUE CAMBIA
      [6] estado_garantia_id: el DDL original lo tenia como ENUM de texto
          (Vigente/Ejecutada/Liberada/Transferida) y silver lo descartaba. Con
          el DDL corregido es una FK a estado_garantia_tipo, y llega al DW.
          Con esto se puede responder "cuantas garantias se ejecutaron este
          anio" y "el cliente X todavia tiene el inmueble en garantia o ya se lo
          devolvimos".
      [7] NUMERO DE COLUMNA CORREGIDO: fecha_avaluo, no fecha_valoracion. El
          nombre del DDL es FECHA_AVALUO; el stg anterior lo pedia como
          fecha_valoracion, que no existe en la fuente.
-#}

with source as (
    select * from {{ source('bronze', 'mysql_garantia') }}
),

renamed as (
    select
        cast(GARANTIA_ID      as bigint)        as garantia_id,
        cast(PRESTAMO_ID      as bigint)        as prestamo_id,
        cast(TIPO_GARANTIA_ID as smallint)      as tipo_garantia_id,
        {{ limpiar_texto('DESCRIPCION_BIEN', '') }} as descripcion_bien,
        cast(VALOR_AVALUO_BS  as decimal(14,2)) as valor_avaluo_bs,
        cast(COBERTURA_PRESTAMO_PORCENTAJE as decimal(5,2)) as cobertura_obligacion,
        -- [7] nombre real de la columna en la fuente
        cast(FECHA_AVALUO     as date)          as fecha_valoracion,
        -- [6] LA FK REAL. Antes se perdia.
        cast(ESTADO_GARANTIA_ID as integer)     as estado_garantia_id,
        _airbyte_extracted_at,
        _airbyte_raw_id
    from source
),

deduplicated as (
    select *,
        row_number() over (
            partition by garantia_id
            order by _airbyte_extracted_at desc nulls last,
                     _airbyte_raw_id        desc nulls last
        ) as _rn
    from renamed
)

select
    garantia_id,
    prestamo_id,
    tipo_garantia_id,
    descripcion_bien,
    valor_avaluo_bs,
    cobertura_obligacion,
    fecha_valoracion,
    estado_garantia_id   -- [6] recuperado
from deduplicated
where _rn = 1
