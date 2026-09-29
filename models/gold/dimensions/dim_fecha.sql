-- =============================================================================
-- dim_fecha
-- Fuente: generada (date spine)
-- Destino: CGOLD (table)
-- -----------------------------------------------------------------------------
-- QUE HACE
-- Dimension de tiempo, generada con un date spine de 10 anos (2020-2029).
--
-- POR QUE SE GENERA Y NO VIENE DE UNA FUENTE
-- -------------------------------------------
-- Ninguna de las 7 fuentes trae una dimension de fechas. Sin ella, los hechos
-- solo podrian agrupar por la fecha cruda, y el tablero no podria responder
-- "que paso en el Q3" o "cuantos pagos cayeron en fin de semana" sin
-- recalcularlo en DAX. Una dimension de fechas resuelve eso de una vez.
--
-- EL RANGO
-- --------
-- 2020-01-01 a 2029-12-31 (3650 dias). Cubre todos los datos historicos de las
-- 7 fuentes (el registro mas viejo es de 2015) y deja margen para el futuro.
-- Si un hecho trae una fecha fuera de rango, el join con dim_fecha no
-- encuentra pareja y la fila se cae del reporte: ese es el comportamiento
-- correcto, porque una fecha fuera de rango es un dato que no se entiende.
--
-- GRAIN
-- fecha (unica).
-- =============================================================================

with fechas as (

    select
        dateadd('day', seq4(), '2020-01-01'::date) as fecha
    from table(generator(rowcount => 3650))

)

select
    fecha,
    year(fecha)                                as anio,
    quarter(fecha)                             as trimestre_num,
    'Q' || quarter(fecha)                      as trimestre,
    month(fecha)                               as mes_num,
    monthname(fecha)                           as mes_nombre,
    day(fecha)                                 as dia_mes,
    dayofweek(fecha)                           as dia_semana_num,
    dayname(fecha)                             as dia_semana_nombre,
    weekofyear(fecha)                          as semana_anio,
    case
        when dayofweek(fecha) in (0, 6) then true
        else false
    end                                        as es_fin_de_semana,
    case
        when month(fecha) in (1, 2, 3) then 'Q1'
        when month(fecha) in (4, 5, 6) then 'Q2'
        when month(fecha) in (7, 8, 9) then 'Q3'
        else 'Q4'
    end                                        as trimestre_nombre,
    'GENERADA'                                 as fuente
from fechas
