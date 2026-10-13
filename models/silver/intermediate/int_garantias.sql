-- =============================================================================
-- int_garantias
-- Fuentes: stg_f1__garantia, int_prestamos
-- Destino: CSILVER (table)
-- -----------------------------------------------------------------------------
-- QUE HACE
-- Un hecho de garantia a nivel de fila de garantia, con el prestamo resuelto y
-- el LTV y la cobertura de garantia ya calculados y clasificados.
--
-- GRAIN
-- garantia_id.
--
-- QUE SIGNIFICA EL LTV AQUI
-- -------------------------
-- En una garantia sobre un inmueble, el LTV (loan to value) es el peso que
-- representa el credito frente al valor del bien:
--
--     LTV = saldo del prestamo / valor de avalio * 100
--
-- Un LTV alto significa que el prestamo representa mucho del valor del bien:
-- el bien respalda poco y, si el mercado cae, la garantia no alcanza. Por eso
-- se acompana de un nivel (baja, media, alta) con el macro nivel_cobertura.
--
-- OJO: esto es el LTV DE LA GARANTIA sobre el inmueble. NO es el ratio entre
-- el saldo y el monto aprobado que calcula int_prestamos: ese mide saldo vivo
-- contra saldo original. Son dos ratios distintos y no se deben amalgamar en
-- un tablero, porque uno mide respaldo patrimonial y el otro, desgaste del
-- credito.
--
-- COBERTURA
-- cobertura_prestamo_porcentaje viene de la fuente y se conserva tal cual: es
-- el porcentaje que el garante cubre. Podria recalcularse con el saldo actual
-- y el valor del bien, pero el avaluio del inmuebleavalio de la garantia no esta
-- en esta tabla: el avaluio del inmueble esta en el derecho real de F5, que se
-- une en int_derechos_reales. Aqui se mantiene el dato de la fuente.
-- =============================================================================

with garantia as (

    select * from {{ ref('stg_f1__garantia') }}

),

prestamo as (

    select * from {{ ref('int_prestamos') }}

),

enriquecida as (

    select
        g.garantia_id,
        g.prestamo_id,

        -- tipo y estado de la garantia
        {{ limpiar_texto('g.tipo_garantia') }}    as tipo_garantia,
        {{ limpiar_texto('g.descripcion_bien') }} as descripcion_bien,
        {{ limpiar_texto('g.estado_garantia') }}  as estado_garantia,

        -- fecha y vigencia de la garantia
        g.fecha_avaluo                            as fecha_avaluo,
        {{ avaluo_vigente('g.fecha_avaluo') }}    as vigencia_avaluo,
        {{ antiguedad_meses('g.fecha_avaluo') }}  as antiguedad_avaluo_meses,

        -- el prestamo, que aporta el saldo contra el que se mide el LTV
        p.cliente_id                              as cliente_id,
        p.saldo_actual_bs                         as saldo_prestamo_bs,
        p.monto_aprobado_bs                       as monto_aprobado_bs,
        p.estado_prestamo                         as estado_prestamo,
        p.bucket_mora                             as bucket_mora_prestamo,
        p.fecha_vencimiento                       as fecha_vencimiento_prestamo,

        -- montos de la garantia
        g.valor_avaluo_bs                         as valor_avaluo_bs,
        g.cobertura_prestamo_porcentaje           as cobertura_prestamo_pct,

        -- LTV = saldo / avalio: el peso que tiene el credito sobre el bien.
        -- El macro ya trae la guarda contra division por cero.
        {{ ltv_pct('p.saldo_actual_bs', 'g.valor_avaluo_bs') }} as ltv_pct,

        -- el nivel depende del LTV, asi que se calcula en un CTE aparte: en el
        -- mismo SELECT no se puede referenciar un alias de la misma lista
        'F1'                                      as fuente
    from garantia g
    left join prestamo p
           on g.prestamo_id = p.prestamo_id

),

-- segundo paso: el nivel se deriva del LTV ya calculado
con_nivel as (

    select
        e.*,
        {{ nivel_cobertura('e.ltv_pct') }}         as nivel_ltv,
        {{ trimestre('e.fecha_avaluo') }}         as trimestre_avaluo
    from enriquecida e

)

select * from con_nivel
