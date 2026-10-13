{{ config(materialized='table', unique_key='tipo_pago_key') }}

select
    {{ dbt_utils.generate_surrogate_key(['tipo_pago_id']) }} as tipo_pago_key,
    tipo_pago_id,
    nombre_tipo_pago
from {{ ref('stg_mysql__tipo_pago') }}