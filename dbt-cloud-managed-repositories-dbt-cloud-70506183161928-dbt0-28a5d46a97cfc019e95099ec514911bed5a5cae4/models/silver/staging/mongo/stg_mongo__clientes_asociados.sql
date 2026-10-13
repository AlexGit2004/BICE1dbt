{{ config(materialized='view') }}

{#-
    stg_mongo__clientes_asociados.sql  (CORREGIDO)
    REGLA 1: mapeo/crosswalk del ObjectId al CI/NIT.

    QUE CAMBIA  (ver P-10)
    El stg anterior leia NUM_IDENTIFICACION y PRODUCTOS_ASIGNADOS. Ninguna de
    las dos columnas existe en el JSON entregado: los campos se llaman
    ProductCustomer.UserId y el JSON es un documento por producto, sin arrays.

    Ademas, aunque existieran, UserId es un ObjectId de Mongo (24 hex) y no un
    CI/NIT: el cruce con el core era imposible por construccion, no por una
    falla de formato. Aqui se resuelve por el crosswalk.
-#}

with source as (
    select * from {{ source('bronze', 'mongo_open_finance_clientes_asociados') }}
),

renamed as (
    select
        cast(_id.$oid                  as varchar(64))  as documento_id,
        cast(ProductCustomer.UserId.$oid as varchar(64)) as user_id_mongo,
        cast(ProductCustomer.UserName as varchar(120))  as user_name_mongo,
        cast(ProductId                 as varchar(32))  as producto_id,
        cast(ProductBank               as varchar(120)) as nombre_banco,
        upper(trim(cast(ProductType   as varchar(20)))) as tipo_producto,
        upper(trim(cast(ProductStatus as varchar(20)))) as estado_producto,
        cast(ProductAmount            as decimal(14,2)) as monto_producto,
        upper(trim(cast(ProductCurrency as varchar(8)))) as moneda,
        cast(ProductInterestRate      as decimal(9,4))  as tasa_interes,
        cast(RepaymentPeriod          as integer)       as plazo_max,
        cast(ProductDate.OpeningDate.$date as date)     as fecha_apertura,
        _AB_CDC_UPDATED_AT,
        _airbyte_extracted_at,
        _airbyte_raw_id
    from source
),

resuelto as (
    select
        r.*,
        {{ validar_xwalk_origen('F5b', 'r.user_id_mongo') }} as numero_identificacion,
        {{ hash_pii( validar_xwalk_origen('F5b', 'r.user_id_mongo') ) }} as numero_id_hash
    from renamed r
),

deduplicated as (
    select *,
        row_number() over (
            partition by documento_id, producto_id
            order by _AB_CDC_UPDATED_AT  desc nulls last,
                     _airbyte_raw_id      desc nulls last
        ) as _rn
    from resuelto
)

select
    documento_id,
    producto_id,
    user_id_mongo,
    user_name_mongo,
    nombre_banco,
    tipo_producto,
    estado_producto,
    monto_producto,
    moneda,
    tasa_interes,
    plazo_max,
    fecha_apertura,
    numero_identificacion,   -- CI/NIT resuelto por el crosswalk
    numero_id_hash
from deduplicated
where _rn = 1
