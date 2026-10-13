-- ============================================================================
-- assert_xwalk_resuelto.sql  (NUEVO)  *** REGLA 1, GARANTIA EJECUTABLE ***
-- ============================================================================
-- "Integra un mecanismo de mapeo/crosswalk estandarizado en F5b (Open Finance)
--  y F6 (Situacion Laboral) para mapear ObjectId e id_cliente hacia el
--  identificador unico de negocio (CI/NIT). Sin esta clave de cruce, estas
--  fuentes no se procesan."
--
-- Este test convierte esa frase en algo ejecutable: si una identidad de F5b, F5
-- o F6 no resuelve a un CI/NIT por el crosswalk, dbt FALLA el build.
--
-- Sin el, el fallo se manifestaria como "el dashboard muestra 0 productos
-- externos", que es indistinguible de un dato real en cero.
--
-- dbt falla si esta consulta devuelve filas.
-- ============================================================================

select
    'F5b'                     as origen_sistema,
    'MongoDB Open Finance'    as fuente,
    o.user_id_mongo           as id_nativo,
    count(*)                  as filas_huerfanas
from {{ ref('stg_mongo__clientes_asociados') }} o
left join {{ ref('stg_xwalk__cliente') }} x
       on x.origen_sistema = 'F5b'
      and x.clave_origen   = o.user_id_mongo
      and x.estado          = 'ACTIVO'
where x.xwalk_id is null
group by 1, 2, 3

union all

select
    'F5b',
    'MongoDB Open Finance (bancos)',
    b.user_id_mongo,
    count(*)
from {{ ref('stg_mongo__bancos') }} b
left join {{ ref('stg_xwalk__cliente') }} x
       on x.origen_sistema = 'F5b'
      and x.clave_origen   = b.user_id_mongo
      and x.estado          = 'ACTIVO'
where x.xwalk_id is null
group by 1, 2, 3

union all

select
    'F6',
    'CSV Situacion Laboral',
    s.id_cliente,
    count(*)
from {{ ref('stg_csv__situacion_laboral') }} s
left join {{ ref('stg_xwalk__cliente') }} x
       on x.origen_sistema = 'F6'
      and x.clave_origen   = s.id_cliente_norm
      and x.estado          = 'ACTIVO'
where x.xwalk_id is null
group by 1, 2, 3

union all

-- F5 tambien: un titular de derecho real que el nucleo no conoce es un dato que
-- no se puede atribuir a ningun cliente y no debe entrar al DW en silencio.
select
    'F5',
    'Derechos Reales (titular de inscripcion)',
    i.numero_identificacion_titular,
    count(*)
from {{ ref('stg_mysql__derecho_real_inscripcion') }} i
left join {{ ref('stg_xwalk__cliente') }} x
       on x.origen_sistema = 'F5'
      and x.clave_origen   = i.numero_identificacion_titular
      and x.estado          = 'ACTIVO'
where x.xwalk_id is null
group by 1, 2, 3
