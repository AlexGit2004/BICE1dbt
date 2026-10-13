{{ config(materialized='view') }}

{#-
    stg_csv__situacion_laboral.sql  (CORREGIDO)
    REGLA 1: mapeo/crosswalk de id_cliente al CI/NIT.

    QUE CAMBIA  (ver P-11)
    El stg anterior pedia 10 columnas que NO existen en el CSV entregado:
        REGISTRO_ID, NUM_IDENTIFICACION, TIPO_ID, INGRESOS_MENSUALES_BS,
        ANTIGUEDAD_LABORAL_MESES, PRESTAMO_ID, FECHA_EVALUACION
    El header real es:
        id_cliente, fecha_actualizacion, tipo_empleo, empresa, sector_economico,
        cargo, antiguedad_meses, ingreso_mensual, tipo_contrato, ciudad,
        estado_empleo
    Y el dato critico: id_cliente viene como TEXTO 'C00001'..'C01000'. El stg
    anterior hacia cast(... as bigint), que revienta, y de paso id_cliente no es
    un CI/NIT boliviano (que son de 6 a 8 digitos) sino un ID interno de
    simulacion. Por eso NO SE PUEDE derivar: hay que resolverlo, y para eso
    existe el crosswalk F7.

    ALCANCE DE LA CORRECCION, HONESTAMENTE:
    Se arregla el contrato de columnas y la identidad. NO se inventa el
    PRESTAMO_ID que el CSV no trae: el cruce con el credito sigue sin existir, y
    por lo tanto ratio_cuota_ingreso y cumple_capacidad_pago NO se pueden
    calcular. Ese punto queda abierto y documentado, porque la unica forma
    correcta de cerrarlo es que la fuente entregue el CI del titular y el
    prestamo al que se evalua, no que dbt lo adivine.
-#}

with source as (
    select * from {{ source('bronze', 'csv_situacion_laboral') }}
),

renamed as (
    select
        -- la clave del REGISTRO laboral, que es interna del CSV
        {{ normalizar_id_origen('ID_CLIENTE') }}                     as id_cliente_norm,
        cast(ID_CLIENTE                as varchar(20))              as id_cliente,
        cast(FECHA_ACTUALIZACION       as date)                     as fecha_actualizacion,
        {{ limpiar_texto('TIPO_EMPLEO',   'DESCONOCIDO') }}         as tipo_empleo,
        {{ limpiar_texto('EMpresa',       'SIN EMPRESA') }}          as empresa,
        {{ limpiar_texto('SECTOR_ECONOMICO', 'OTROS') }}            as sector_economico,
        {{ limpiar_texto('CARGO',         'SIN CARGO') }}            as cargo,
        coalesce(cast(ANTIGUEDAD_MESES  as integer), 0)              as antiguedad_laboral_meses,
        coalesce(cast(INGRESO_MENSUAL   as decimal(14,2)), 0)        as ingresos_mensuales_bs,
        {{ limpiar_texto('TIPO_CONTRATO', 'DESCONOCIDO') }}          as tipo_contrato,
        {{ limpiar_texto('CIUDAD',        'SIN DATO') }}             as ciudad,
        {{ limpiar_texto('ESTADO_EMPLEO', 'DESCONOCIDO') }}         as estado_empleo,
        _airbyte_extracted_at,
        _airbyte_raw_id
    from source
),

-- ===== REGLA 1: resolucion de id_cliente al CI/NIT =====
resuelto as (
    select
        r.*,
        {{ validar_xwalk_origen('F6', 'r.id_cliente') }} as numero_identificacion,
        {{ hash_pii( validar_xwalk_origen('F6', 'r.id_cliente') ) }} as numero_id_hash
    from renamed r
),

deduplicated as (
    select *,
        row_number() over (
            partition by id_cliente_norm, fecha_actualizacion
            order by _airbyte_extracted_at desc nulls last,
                     _airbyte_raw_id        desc nulls last
        ) as _rn
    from resuelto
)

select
    id_cliente,
    id_cliente_norm,
    fecha_actualizacion,
    tipo_empleo,
    empresa,
    sector_economico,
    cargo,
    antiguedad_laboral_meses,
    ingresos_mensuales_bs,
    tipo_contrato,
    ciudad,
    estado_empleo,
    numero_identificacion,   -- CI/NIT resuelto por el crosswalk
    numero_id_hash,          -- listo para el join hash-contra-hash
    -- flag de trazabilidad: deja visible que el cruce con el prestamo no existe
    false as prestamo_id_disponible
from deduplicated
where _rn = 1
