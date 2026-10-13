{{ config(materialized='table', unique_key='fecha_key') }}

with spine as (
    {{ dbt_utils.date_spine(
        datepart="day",
        start_date="cast('" ~ var('fecha_min_hechos') ~ "' as date)",
        end_date="cast('"   ~ var('fecha_max_hechos') ~ "' as date)"
    ) }}
)

select
    cast(to_char(date_day, 'YYYYMMDD') as integer) as fecha_key,
    date_day                                        as fecha,
    extract(year    from date_day)                  as anio,
    extract(quarter from date_day)                  as trimestre,
    extract(month   from date_day)                  as mes,
    to_char(date_day, 'TMMonth')                    as nombre_mes,
    extract(week    from date_day)                  as semana,
    extract(day     from date_day)                  as dia,
    extract(dow     from date_day)                  as dia_semana,
    to_char(date_day, 'YYYY-MM')                    as anio_mes,
    case when extract(dow from date_day) in (0,6)
         then true else false end                   as es_fin_semana
from spine