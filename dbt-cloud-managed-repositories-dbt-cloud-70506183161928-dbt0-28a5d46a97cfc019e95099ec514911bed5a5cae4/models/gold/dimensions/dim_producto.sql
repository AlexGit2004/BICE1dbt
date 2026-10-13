{{ config(materialized='table', unique_key='producto_key') }}

select
    {{ dbt_utils.generate_surrogate_key(['p.producto_id']) }} as producto_key,
    p.producto_id,
    p.nombre_producto,
    p.tipo_prod_id,
    coalesce(tp.nombre_tipo_prod, 'SIN TIPO')                 as tipo_producto,
    p.tasa_interes_base,
    p.plazo_minimo_meses,
    p.plazo_maximo_meses,
    p.monto_minimo_bs,
    p.monto_maximo_bs,
    p.estado_producto
from {{ ref('stg_mysql__producto_crediticio') }} p
left join {{ ref('stg_mysql__tipo_producto') }} tp
    on tp.tipo_prod_id = p.tipo_prod_id