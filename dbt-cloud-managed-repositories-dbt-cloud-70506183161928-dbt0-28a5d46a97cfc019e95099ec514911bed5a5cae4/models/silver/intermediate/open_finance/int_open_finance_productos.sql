{{ config(materialized='table') }}

{#-
    int_open_finance_productos.sql  (CORREGIDO)

    El modelo anterior hacia  select * from stg_mongo__bancos , que con el
    shape real del JSON traia un documento por producto con 15 campos en
    PascalCase, no las 6 columnas que el stg anterior deliveraba.

    Aqui se renombra al snake_case que usa la dimension de oro, y se separa lo
    que es del BANCO (catalogo) de lo que es del PRODUCTO (atributo del
    producto): nombre_banco es un catalogo, y como tal va a una dimension
    dim_banco_externo, no a la fact.
-#}

with b as (
    select * from {{ ref('stg_mongo__bancos') }}
    where producto_id is not null
)

select
    {{ dbt_utils.generate_surrogate_key(['banco_nombre', 'producto_id']) }} as producto_externo_key,
    producto_id,
    -- catalogo de la institucion financiera externa
    upper(trim(nombre_banco))                                  as banco_nombre,
    upper(trim(tipo_producto))                                 as tipo_producto,
    estado_producto,
    tasa_interes,
    plazo_max,
    monto_producto,
    moneda,
    fecha_apertura,
    garantia_producto,
    descripcion_producto,
    -- el name del banco es un valor repetido: se usa como clave de la dim
    count(*) over (partition by nombre_banco)                    as productos_del_banco
from b
