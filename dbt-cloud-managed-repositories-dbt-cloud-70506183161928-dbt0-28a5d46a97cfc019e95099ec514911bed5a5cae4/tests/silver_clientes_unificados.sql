-- ============================================================================
-- silver_clientes_unificados.sql  (REESCRITO)
-- ============================================================================
-- Verifica la REGLA 2: TODA fuente externa converge en dim_cliente por el
-- identificador unico de negocio (CI/NIT).
--
-- QUE CAMBIA
-- La version anterior hacia:
--     select sl.numero_identificacion from stg_csv__situacion_laboral sl
--     left join int_clientes_unificados c on c.numero_identificacion = sl.numero_identificacion
--     where sl.prestamo_id is null and c.numero_identificacion is null
-- Se unia sobre numero_identificacion en claro, la columna que el CSV NO tiene
-- (se llama id_cliente y es texto C#####). El test comparaba un campo
-- inexistente contra si mismo y no podia fallar.
--
-- Ahora:
--   1. Se compara por hash, que es como se cruza en serio.
--   2. Se cubren LAS 7 fuentes, no solo F6.
--   3. Cada verificacion mira si un hash resuelto llego al cliente unificado.
-- ============================================================================

-- F6: situacion laboral
select 'F6' as origen, sl.numero_id_hash as id_sin_unificar
from {{ ref('stg_csv__situacion_laboral') }} sl
left join {{ ref('int_clientes_unificados') }} c
       on c.numero_id_hash = sl.numero_id_hash
where sl.numero_id_hash is not null
  and c.numero_id_hash is null

union all

-- F5b: Open Finance
select 'F5b', m.numero_id_hash
from {{ ref('stg_mongo__clientes_asociados') }} m
left join {{ ref('int_clientes_unificados') }} c
       on c.numero_id_hash = m.numero_id_hash
where m.numero_id_hash is not null
  and c.numero_id_hash is null

union all

-- F2: procesos penales
select 'F2', p.numero_id_hash
from {{ ref('int_riesgo_penal') }} p
left join {{ ref('int_clientes_unificados') }} c
       on c.numero_id_hash = p.numero_id_hash
where p.numero_id_hash is not null
  and c.numero_id_hash is null

union all

-- F3: central de riesgos
select 'F3', f.numero_id_hash
from {{ ref('int_riesgo_central') }} f
left join {{ ref('int_clientes_unificados') }} c
       on c.numero_id_hash = f.numero_id_hash
where f.numero_id_hash is not null
  and c.numero_id_hash is null

union all

-- F4: registro mercantil
select 'F4', t.numero_id_hash
from {{ ref('int_riesgo_tributario') }} t
left join {{ ref('int_clientes_unificados') }} c
       on c.numero_id_hash = t.numero_id_hash
where t.numero_id_hash is not null
  and c.numero_id_hash is null

union all

-- F5: derechos reales
select 'F5', g.cliente_numero_id_hash
from {{ ref('int_derechos_reales_garantia') }} g
left join {{ ref('int_clientes_unificados') }} c
       on c.numero_id_hash = g.cliente_numero_id_hash
where g.cliente_numero_id_hash is not null
  and c.numero_id_hash is null

union all

-- F1: el core. Si un cliente de F1 no llega al unificado, el modelo esta roto.
select 'F1', f1.numero_id_hash
from {{ ref('stg_mysql__cliente') }} f1
left join {{ ref('int_clientes_unificados') }} c
       on c.numero_id_hash =
          {{ hash_pii( normalizar_identidad('f1.numero_identificacion') ) }}
where c.numero_id_hash is null
