-- =============================================================================
-- int_prestamos
-- Fuentes: stg_f1__prestamo, stg_f1__producto_crediticio, stg_f1__agencia,
--          stg_f1__solicitud_credito, stg_f1__caracteristica_cliente
-- Destino: CSILVER (table)
-- -----------------------------------------------------------------------------
-- QUE HACE
-- Un hecho de prestamo a nivel de fila de prestamo, con el producto, la agencia
-- y la solicitud resueltos, y los indicadores de mora calculados UNA vez aqui
-- para que todos los consumidores los usen igual.
--
-- GRAIN
-- prestamo_id. Se valida al final: si el count por prestamo_id != count de
-- filas, el modelo esta duplicando y hay que saberlo antes de que llegue a
-- Gold.
--
-- NOTA SOBRE EL SALDO
-- saldo_actual_bs viene de la fuente y se usa tal cual. NO se recalcula
-- restando pagos: el saldo de la fuente es el saldo contable del dia de la
-- extraccion, y los pagos registrados en F1 no cubren toda la historia del
-- prestamo (no arrancan desde el origen para todos los casos). Recalcularlo
-- daria un saldo que no cuadra con el sistema que lo emitio.
-- =============================================================================

with prestamo as (

    select * from {{ ref('stg_f1__prestamo') }}

),

producto as (

    select * from {{ ref('stg_f1__producto_crediticio') }}

),

agencia as (

    select * from {{ ref('stg_f1__agencia') }}

),

solicitud as (

    select * from {{ ref('stg_f1__solicitud_credito') }}

),

-- caracteristicas del cliente al momento de solicitar. Trae la fecha de
-- nacimiento y el sexo, que no estan en stg_f1__cliente: alli hay tipo de
-- persona juridica, no demografia.
caracteristica as (

    select * from {{ ref('stg_f1__caracteristica_cliente') }}

),

enriquecido as (

    select
        p.prestamo_id,
        p.solicitud_id,
        p.cliente_id,
        p.producto_id,
        p.agencia_id,

        -- fechas del credito
        p.fecha_originacion                        as fecha_originacion,
        p.fecha_vencimiento                       as fecha_vencimiento,
        {{ antiguedad_dias('p.fecha_originacion') }} as antiguedad_dias,
        {{ antiguedad_meses('p.fecha_originacion') }} as antiguedad_meses,

        -- estado y clasificacion del credito
        {{ limpiar_texto('p.estado_prestamo') }}   as estado_prestamo,
        {{ limpiar_texto('pr.tipo_producto') }}    as tipo_producto,
        {{ limpiar_texto('pr.nombre_producto') }}  as nombre_producto,
        {{ limpiar_texto('pr.estado_producto') }}  as estado_producto,

        -- montos
        p.monto_aprobado_bs                        as monto_aprobado_bs,
        p.cuota_mensual_bs                         as cuota_mensual_bs,
        p.saldo_actual_bs                          as saldo_actual_bs,
        p.tasa_interes_aplicada                    as tasa_interes_aplicada,
        p.plazo_aprobado_meses                     as plazo_aprobado_meses,
        pr.tasa_interes_base                       as tasa_interes_base,
        pr.plazo_minimo_meses                      as plazo_minimo_mes,
        pr.plazo_maximo_meses                      as plazo_maximo_mes,

        -- mora. DIAS_ATRASO y DIAS_MORA_AL_ULTIMO_PAGO son dos cosas
        -- distintas y se conservan separadas:
        --   - dias_atraso: cuantos dias lleva el prestamo en mora hoy
        --   - dias_mora_ultimo_pago: dias entre el vencimiento del ultimo pago
        --     esperado y el pago effective. Sirve para medir que tan
        --     reciente es el incumplimiento, no el estado actual.
        p.dias_atraso                              as dias_atraso,
        p.dias_mora_al_ultimo_pago                 as dias_mora_ultimo_pago,
        {{ bucket_mora('p.dias_atraso') }}         as bucket_mora,
        {{ mora_es_vigente('p.dias_atraso') }}     as mora_vigente,

        -- vigente a la fecha de corte
        {{ clasificar_vencimiento('p.fecha_vencimiento') }}
                                                as estado_vencimiento,

        -- agencia
        ag.nombre_agencia                          as nombre_agencia,
        {{ limpiar_texto('ag.departamento') }}     as departamento_agencia,
        {{ limpiar_texto('ag.tipo_agencia') }}     as tipo_agencia,
        {{ limpiar_texto('ag.estado_agencia') }}   as estado_agencia,

        -- solicitud de origen
        s.fecha_solicitud                          as fecha_solicitud,
        s.monto_solicitado_bs                      as monto_solicitado_bs,
        s.plazo_solicitado_meses                    as plazo_solicitado_mes,
        {{ limpiar_texto('s.estado_solicitud') }}  as estado_solicitud,

        -- caracteristicas del titular al momento de la solicitud
        c.fecha_nacimiento                         as fecha_nacimiento,
        {{ limpiar_texto('c.sexo') }}              as sexo,
        {{ limpiar_texto('c.estado_civil') }}      as estado_civil,
        {{ limpiar_texto('c.nacionalidad') }}     as nacionalidad,
        {{ limpiar_texto('c.profesion') }}        as profesion,
        {{ antiguedad_anios('c.fecha_nacimiento') }} as edad_anios,

        'F1'                                       as fuente
    from prestamo p
    left join producto     pr on p.producto_id = pr.producto_id
    left join agencia      ag on p.agencia_id  = ag.agencia_id
    left join solicitud   s   on p.solicitud_id = s.solicitud_id
    left join caracteristica c on p.cliente_id = c.cliente_id

),

-- el porcentaje de cobertura del avalio es un ratio: se calcula aqui con
-- guarda contra division por cero, no en el tablero.
con_ratio as (

    select
        e.*,
        case
            when e.monto_aprobado_bs is null or e.monto_aprobado_bs = 0 then null
            else round(100.0 * e.saldo_actual_bs / e.monto_aprobado_bs, 2)
        end as saldo_sobre_aprobado_pct,
        case
            when e.tasa_interes_aplicada is null
              or e.tasa_interes_base is null then null
            else round(e.tasa_interes_aplicada - e.tasa_interes_base, 4)
        end as spread_sobre_base_pct
    from enriquecido e

)

select * from con_ratio
