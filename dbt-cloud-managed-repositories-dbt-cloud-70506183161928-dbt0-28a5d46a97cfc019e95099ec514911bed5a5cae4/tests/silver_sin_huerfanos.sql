-- ============================================================================
-- silver_sin_huerfanos.sql  (REESCRITO)
-- ============================================================================
-- Verifica que no existan FKs rotas tras la limpieza silver.
--
-- QUE SE ANADIO
--   - Las 3 FKs que el DDL original NO declaraba y que el stg ponia en NULL.
--     Ahora, si se rompe, se rompe en la BASE y no se descubre en el DW.
--   - El cruce de pagos con clientes, que era el P-05: un pago que no
--     encuentra su cliente es un dato que no se puede atribuir.
--   - El cruce del crosswalk: si una fuente externa no resuelve, aqui se ve.
-- ============================================================================

select 'pago_huerfano' as tipo, p.pago_id as id
from {{ ref('stg_mysql__pago') }} p
left join {{ ref('stg_mysql__prestamo') }} pr on pr.prestamo_id = p.prestamo_id
where pr.prestamo_id is null

union all

-- P-05: el pago tiene su propia FK a cliente, y se usa. Si no coincide con la
-- del prestamo, el pago se registro contra un cliente equivocado.
select 'pago_cliente_incoherente', p.pago_id
from {{ ref('stg_mysql__pago') }} p
join {{ ref('stg_mysql__prestamo') }} pr on pr.prestamo_id = p.prestamo_id
where p.cliente_id <> pr.cliente_id

union all

select 'prestamo_huerfano', pr.prestamo_id
from {{ ref('stg_mysql__prestamo') }} pr
left join {{ ref('stg_mysql__cliente') }} c on c.cliente_id = pr.cliente_id
where c.cliente_id is null

union all

-- P-01: el estado del prestamo TIENE que resolver contra su catalogo.
-- Antes esta columna era NULL y el test no lo detectaba porque la columna
-- estaba en la base con valor NULL.
select 'prestamo_estado_invalido', pr.prestamo_id
from {{ ref('stg_mysql__prestamo') }} pr
left join {{ ref('stg_mysql__estado_prestamo_tipo') }} e
       on e.estado_id = pr.estado_prestamo_tipo_id
where e.estado_id is null

union all

-- P-01: la fecha de vencimiento tiene que venir de la fuente. Si el stg la
-- calculo, el DDL no se esta cumpliendo y hay que saberlo.
select 'prestamo_vencimiento_calculado', p.prestamo_id
from {{ ref('int_prestamos_limpios') }} p
where p.vencimiento_calculado

union all

-- P-02: toda solicitud rechazada tiene que tener motivo, por el CHECK del DDL.
select 'solicitud_rechazada_sin_motivo', s.solicitud_id
from {{ ref('stg_mysql__solicitud_credito') }} s
where s.fue_rechazada and s.tipo_rechazo_id is null

union all

-- P-02: el motivo tiene que existir en su catalogo.
select 'solicitud_motivo_invalido', s.solicitud_id
from {{ ref('stg_mysql__solicitud_credito') }} s
left join {{ ref('stg_mysql__tipo_rechazo') }} t
       on t.tipo_rechazo_id = s.tipo_rechazo_id
where s.tipo_rechazo_id is not null and t.tipo_rechazo_id is null

union all

select 'garantia_huerfana', g.garantia_id
from {{ ref('stg_mysql__garantia') }} g
left join {{ ref('stg_mysql__prestamo') }} pr on pr.prestamo_id = g.prestamo_id
where pr.prestamo_id is null

union all

-- P-06: el estado de la garantia tiene que resolver.
select 'garantia_estado_invalido', g.garantia_id
from {{ ref('stg_mysql__garantia') }} g
left join {{ ref('stg_mysql__estado_garantia_tipo') }} e
       on e.estado_garantia_id = g.estado_garantia_id
where e.estado_garantia_id is null

union all

-- P-03 / P-04: la entidad financiera tiene que resolver, o dim_entidad queda
-- huerfana otra vez.
select 'deuda_entidad_invalida', d.deuda_id
from {{ ref('stg_server__deuda_cr') }} d
left join {{ ref('stg_server__tipo_entidad_financiera') }} t
       on t.tipo_entidad_id = d.tipo_entidad_financiera_id
where t.tipo_entidad_id is null

-- F5: un gravamen tiene que apuntar a un prestamo que exista.
select 'gravamen_prestamo_invalido', g.gravamen_id
from {{ ref('stg_mysql__gravamen_garantia_prestamo') }} g
left join {{ ref('stg_mysql__prestamo') }} pr on pr.prestamo_id = g.prestamo_id
where pr.prestamo_id is null

-- F5: un gravamen solo puede insure un derecho real que sirva para garantizar.
-- El trigger de MySQL lo impide, pero se verifica tambien en silver, porque
-- un trigger se puede deshabilitar.
select 'gravamen_derecho_no_garantizable', g.gravamen_id
from {{ ref('stg_mysql__gravamen_garantia_prestamo') }} g
join {{ ref('stg_mysql__tipo_derecho_real') }} t
  on t.tipo_derecho_real_id = g.tipo_derecho_real_id
where t.es_garantia = false
