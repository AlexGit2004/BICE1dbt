{{ config(materialized='view') }}

{#-
    stg_mongo__bancos.sql  (CORREGIDO)
    REGLA 1: el modelo tiene que leer el JSON que REALMENTE llega.

    QUE CAMBIA  (ver P-10)
    El stg anterior hacia:
        lateral flatten(input => PRODUCTOS) as prod
        con prod.value:producto_id, prod.value:tipo_producto,
        prod.value:tasa_interes, prod.value:plazo_max
    El JSON real (FuentesNoSQL/open_finance.external_products.json) NO tiene
    ningun array PRODUCTOS. Es un documento POR PRODUCTO, con los campos
    aplanados y en PascalCase:
        _id, ProductId, ProductBank, ProductStatus, ProductType,
        ProductAmount, ProductCurrency, ProductInterestRate,
        ProductDate.OpeningDate, ProductCustomer.UserName,
        ProductCustomer.UserId, GreenProductNarrative,
        RepaymentPeriod, LoanCollateral
    Resultado del stg anterior: 3 modelos rotos y 0 filas de Open Finance.

    Aqui se lee el shape real, y el UserId se RESUELVE por el crosswalk (F7),
    que es la REGLA 1 para esta fuente.
-#}

with source as (
    select * from {{ source('bronze', 'mongo_open_finance_bancos') }}
),

renamed as (
    select
        cast(_id.$oid                              as varchar(64)) as documento_id,
        cast(ProductId                             as varchar(32)) as producto_id,
        cast(ProductBank                           as varchar(120)) as nombre_banco,
        upper(trim(cast(ProductStatus              as varchar(20)))) as estado_producto,
        upper(trim(cast(ProductType                as varchar(20)))) as tipo_producto,
        cast(ProductAmount                         as decimal(14,2)) as monto_producto,
        upper(trim(cast(ProductCurrency            as varchar(8))))  as moneda,
        cast(ProductInterestRate                   as decimal(9,4))  as tasa_interes,
        cast(ProductDate.OpeningDate.$date         as date)          as fecha_apertura,
        cast(RepaymentPeriod                       as integer)       as plazo_max,
        upper(trim(cast(LoanCollateral             as varchar(40)))) as garantia_producto,
        {{ limpiar_texto('GreenProductNarrative', '') }} as descripcion_producto,

        -- ===== REGLA 1: resolucion del ObjectId al CI/NIT =====
        -- ProductCustomer.UserId es un ObjectId de Mongo de 24 hex. NO es un CI.
        -- Sin el crosswalk, esta fuente no se puede unir a nada.
        cast(ProductCustomer.UserId.$oid          as varchar(64)) as user_id_mongo,
        cast(ProductCustomer.UserName             as varchar(120)) as user_name_mongo,

        _AB_CDC_UPDATED_AT,
        _airbyte_extracted_at,
        _airbyte_raw_id
    from source
),

-- REGLA 1: el UserId se resuelve a CI/NIT por el crosswalk. Si no resuelve,
-- el dbt test assert_xwalk_resuelto hace fallar el build: es la garantia
-- ejecutable de que esta fuente no aporta identidades inventadas.
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
            partition by documento_id
            order by _AB_CDC_UPDATED_AT  desc nulls last,
                     _airbyte_raw_id      desc nulls last
        ) as _rn
    from resuelto
)

select
    documento_id,
    producto_id,
    nombre_banco,
    estado_producto,
    tipo_producto,
    monto_producto,
    moneda,
    tasa_interes,
    fecha_apertura,
    plazo_max,
    garantia_producto,
    descripcion_producto,
    user_id_mongo,
    user_name_mongo,
    numero_identificacion,   -- CI/NIT resuelto (puede ser null si el crosswalk no lo cubre)
    numero_id_hash           -- hash-contra-hash, listo para el join
from deduplicated
where _rn = 1
