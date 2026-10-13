{{ config(materialized='table', unique_key='depto_key') }}

select
    {{ dbt_utils.generate_surrogate_key(['depto_id']) }} as depto_key,
    depto_id,
    nombre_depto
from {{ ref('stg_mysql__departamento') }}