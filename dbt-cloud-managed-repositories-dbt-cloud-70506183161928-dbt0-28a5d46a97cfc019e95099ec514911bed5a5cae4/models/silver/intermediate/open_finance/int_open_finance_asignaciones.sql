{{ config(materialized='table') }}

{#-
    int_open_finance_asignaciones.sql  (CORREGIDO)

    REGLA 1 + REGLA 2: la fuente se procesa SOLO si el ObjectId resuelve a un
    CI/NIT por el crosswalk. Si no resuelve, la fila se descarta y queda
    contabilizada en el flag, para que el dashboard diga cuantos productos
    externos se pudieron atribuir y cuantos no.

    ANTES: el modelo hacia
        cast(numero_identificacion as bigint) as numero_identificacion
    leyendo un campo que el JSON no tiene, y de un ObjectId de 24 hex que no
    es un CI. El resultado eran 0 filas y un dashboard con
    productos_externos = 0 que parecia un dato real.
-#}

with src as (
    select * from {{ ref('stg_mongo__clientes_asociados') }}
    where numero_id_hash is not null
),

-- El JSON es un documento por producto, asi que no hay array que aplanar.
-- La granularidad correcta es 1 fila = 1 producto asignado a 1 cliente.
atribuibles as (
    select
        documento_id,
        user_id_mongo,
        producto_id,
        nombre_banco,
        tipo_producto,
        estado_producto,
        monto_producto,
        moneda,
        tasa_interes,
        plazo_max,
        fecha_apertura,
        numero_id_hash
    from src
),

-- Inventario de lo que se quedo afuera, para poder reportarlo.
no_atribuibles as (
    select
        count(*)                                              as filas_no_atribuibles,
        count(distinct user_id_mongo)                         as users_no_resueltos
    from {{ ref('stg_mongo__clientes_asociados') }}
    where numero_id_hash is null
)

select
    {{ dbt_utils.generate_surrogate_key(['documento_id', 'producto_id']) }} as asignacion_key,
    a.documento_id,
    a.user_id_mongo,
    a.producto_id,
    a.nombre_banco,
    a.tipo_producto,
    a.estado_producto,
    a.monto_producto,
    a.moneda,
    a.tasa_interes,
    a.plazo_max,
    a.fecha_apertura,
    a.numero_id_hash,                       -- el puente con dim_cliente
    -- solo los productos que el cliente mantiene activos cuentan como exposicion
    a.estado_producto = 'ACTIVE'            as es_producto_activo,
    na.filas_no_atribuibles,
    na.users_no_resueltos
from atribuibles a
cross join no_atribuibles na
