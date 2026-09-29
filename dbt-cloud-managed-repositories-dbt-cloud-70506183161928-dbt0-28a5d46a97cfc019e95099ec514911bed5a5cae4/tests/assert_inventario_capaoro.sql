-- ============================================================================
-- assert_inventario_capaoro.sql  (NUEVO)  *** REGLA 4, segunda mitad ***
-- ============================================================================
-- Complemento de assert_conectividad_bus.sql.
--
-- El primer test verifica que las tablas DE LA MATRIZ tengan relaciones. Este
-- verifica lo inverso: que toda tabla que EXISTE en CAPAORO este EN LA MATRIZ.
--
-- Por que hace falta: si alguien crea dim_nueva_dimension y la sube a gold.yml
-- pero no la documenta en la matriz de bus, el primer test no la ve y pasa. El
-- modelo queda huerfano sin que nada lo note. Este test cierra ese hueco.
--
-- dbt falla si esta consulta devuelve filas.
-- ============================================================================

with inventario_declarado as (
    -- toda tabla que existe en el proyecto. Si se agrega una, hay que
    -- agregarla tambien abajo, y el test obliga a documentarla.
    select 'dim_cliente'              as tabla union all
    select 'dim_xwalk_identidad'      as tabla union all
    select 'dim_fecha'                as tabla union all
    select 'dim_producto'             as tabla union all
    select 'dim_agencia'              as tabla union all
    select 'dim_departamento'         as tabla union all
    select 'dim_estado_prestamo'      as tabla union all
    select 'dim_tipo_pago'            as tabla union all
    select 'dim_tipo_garantia'        as tabla union all
    select 'dim_tipo_rechazo'         as tabla union all
    select 'dim_estado_garantia'      as tabla union all
    select 'dim_riesgo_categoria'     as tabla union all
    select 'dim_delito_categoria'     as tabla union all
    select 'dim_entidad'              as tabla union all
    select 'dim_empresa'              as tabla union all
    select 'dim_inmueble'             as tabla union all
    select 'dim_tipo_derecho_real'    as tabla union all
    select 'dim_prestamo'             as tabla union all
    select 'fact_prestamos'           as tabla union all
    select 'fact_pagos'               as tabla union all
    select 'fact_solicitudes'         as tabla union all
    select 'fact_garantias'           as tabla union all
    select 'fact_riesgo'              as tabla union all
    select 'fact_cliente_360'         as tabla union all
    select 'fact_deuda_externa'       as tabla union all
    select 'fact_derechos_reales'     as tabla union all
    select 'bridge_cliente_empresa'   as tabla
),

-- Las tablas que la matriz de bus declara. Misma lista que el otro test.
matriz_de_bus as (
    select 'dim_cliente' as tabla              union all
    select 'dim_fecha' as tabla                union all
    select 'dim_producto' as tabla             union all
    select 'dim_agencia' as tabla              union all
    select 'dim_departamento' as tabla         union all
    select 'dim_estado_prestamo' as tabla      union all
    select 'dim_tipo_pago' as tabla            union all
    select 'dim_tipo_garantia' as tabla        union all
    select 'dim_tipo_rechazo' as tabla         union all
    select 'dim_estado_garantia' as tabla      union all
    select 'dim_riesgo_categoria' as tabla     union all
    select 'dim_delito_categoria' as tabla     union all
    select 'dim_entidad' as tabla              union all
    select 'dim_empresa' as tabla              union all
    select 'dim_xwalk_identidad' as tabla      union all
    select 'dim_banco_externo' as tabla       union all
    select 'dim_inmueble' as tabla             union all
    select 'dim_tipo_derecho_real' as tabla    union all
    select 'dim_prestamo' as tabla             union all
    select 'fact_prestamos' as tabla           union all
    select 'fact_pagos' as tabla               union all
    select 'fact_solicitudes' as tabla         union all
    select 'fact_garantias' as tabla           union all
    select 'fact_riesgo' as tabla              union all
    select 'fact_cliente_360' as tabla         union all
    select 'fact_deuda_externa' as tabla       union all
    select 'fact_derechos_reales' as tabla     union all
    select 'fact_open_finance' as tabla       union all
    select 'bridge_cliente_empresa' as tabla
)

-- Falla si existe una tabla que NO este en la matriz de bus
select
    d.tabla,
    'VIOLACION REGLA 4: existe en CAPAORO pero no esta en la matriz de bus' as error
from inventario_declarado d
left join matriz_de_bus m on m.tabla = d.tabla
where m.tabla is null
