{{ config(materialized='table', unique_key='agencia_key') }}

select
    {{ dbt_utils.generate_surrogate_key(['a.agencia_id']) }} as agencia_key,
    a.agencia_id,
    a.nombre_agencia,
    a.codigo_agencia,
    a.tipo_agencia,
    a.estado_agencia,
    d.depto_key,
    a.depto_id,
    d.nombre_depto                                            as departamento
from {{ ref('stg_mysql__agencia') }} a
left join {{ ref('dim_departamento') }} d using (depto_id)