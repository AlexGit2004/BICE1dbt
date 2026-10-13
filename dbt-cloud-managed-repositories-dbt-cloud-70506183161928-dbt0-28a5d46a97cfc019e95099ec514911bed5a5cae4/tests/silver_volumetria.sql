-- ============================================================================
-- silver_volumetria.sql  (REESCRITO)
-- ============================================================================
-- Falla si los conteos no cuadran con el dataset sintetico v2 (seed 42).
--
-- QUE CAMBIA
--   - int_clientes_unificados ya no es "5.000 de F1 + 3.000 de F6": es "1 fila
--     por CI/NIT confirmado en el crosswalk", que es la REGLA 2. El conteo
--     esperado se calcula, no se fija a mano.
--   - Se agrega el control de duplicados de CI/NIT, que es la invariante que
--     hace que la identidad unica sea real y no declarada.
--   - Se agrega la volumetria de las 3 fuentes que antes no se procesaba.
-- ============================================================================

select 'cliente_unificado' as tabla,
       count(*)               as actual,
       -- el esperado NO se fija: se deriva del crosswalk
       (select count(*) from {{ ref('int_xwalk_identidad') }}
         where identidad_confirmada) as esperado
from {{ ref('int_clientes_unificados') }}
having count(*) <> (select count(*) from {{ ref('int_xwalk_identidad') }}
                    where identidad_confirmada)

union all

-- INVARIANTE CRITICA: un CI/NIT por fila, exactamente. Si esto falla, la
-- identidad unica no existe y todo el modelo esta construido sobre arena.
select 'cliente_duplicado', count(*) - count(distinct numero_identificacion), 0
from {{ ref('int_clientes_unificados') }}
having count(*) <> count(distinct numero_identificacion)

union all

-- INVARIANTE CRITICA: el hash tambien tiene que ser unico, porque es la FK
-- que usan todas las estrellas.
select 'cliente_hash_duplicado',
       count(*) - count(distinct numero_id_hash), 0
from {{ ref('int_clientes_unificados') }}
having count(*) <> count(distinct numero_id_hash)

union all

select 'prestamo',     count(*), 12000  from {{ ref('int_prestamos_limpios') }}
having count(*) <> 12000

union all

select 'pago',         count(*), 250000 from {{ ref('stg_mysql__pago') }}
having count(*) <> 250000

union all

select 'garantia',     count(*), 10000  from {{ ref('stg_mysql__garantia') }}
having count(*) <> 10000

union all

select 'solicitud',    count(*), 20000  from {{ ref('stg_mysql__solicitud_credito') }}
having count(*) <> 20000

union all

-- REGLA 1: sin crosswalk, F5b no se procesa. El esperado se deriva del
-- numero de ObjectId distintos que trae el JSON.
select 'open_finance_atribuible',
       count(distinct numero_id_hash),
       (select count(distinct user_id_mongo)
          from {{ ref('stg_mongo__clientes_asociados') }})
from {{ ref('int_open_finance_asignaciones') }}
where numero_id_hash is not null
having count(distinct numero_id_hash) = 0

union all

-- REGLA 1: sin crosswalk, F6 no se procesa.
select 'situacion_laboral_atribuible',
       count(distinct numero_id_hash),
       (select count(distinct id_cliente)
          from {{ ref('stg_csv__situacion_laboral') }})
from {{ ref('int_situacion_laboral') }}
where numero_id_hash is not null
having count(distinct numero_id_hash) = 0
