-- =============================================================================
-- int_pagos
-- Fuentes: stg_f1__pago, stg_f1__prestamo
-- Destino: CSILVER (table)
-- -----------------------------------------------------------------------------
-- QUE HACE
-- Un hecho de pago a nivel de fila de pago, con el contexto del prestamo al que
-- se aplica y los indicadores de mora ya clasificados.
--
-- GRAIN
-- pago_id.
--
-- POR QUE SE DISTINGUEN DOS MEDIDAS DE MORA
-- ------------------------------------------
-- El prestamo trae dias_atraso: cuantos dias lleva el credito en mora hoy, un
-- estado actual que se repite en cada pago hasta que se regulariza.
--
-- El pago trae dias_atraso_al_pago: los dias de atraso que tenia ESE pago
-- cuando se registro. Es la foto del incumplimiento en el momento del pago.
--
-- Se guardan las dos porque contestan preguntas distintas: "cuanto lleva el
-- cliente en mora" usa dias_atraso; "que tan severo era cada pago" usa
-- dias_atraso_al_pago. Promediarlas seria mezclar un estado con un historico.
--
-- NOTA SOBRE EL SALDO
-- No se recalcula el saldo del prestamo aqui. Se mantiene el saldo vigente
-- tal como viene de la fuente. Los pagos son el historico de movimientos, no
-- el estado del saldo.
-- =============================================================================

with pago as (

    select * from {{ ref('stg_f1__pago') }}

),

prestamo as (

    select * from {{ ref('int_prestamos') }}

),

enriquecido as (

    select
        g.pago_id,
        g.prestamo_id,
        g.cliente_id,

        -- el pago en si
        g.fecha_pago                             as fecha_pago,
        g.monto_pagado_bs                        as monto_pagado_bs,
        g.numero_cuota                           as numero_cuota,
        {{ limpiar_texto('g.tipo_pago') }}       as tipo_pago,
        {{ limpiar_texto('g.estado_pago') }}     as estado_pago,

        -- mora EN EL MOMENTO del pago
        g.dias_atraso_al_pago                    as dias_atraso_al_pago,
        {{ bucket_mora('g.dias_atraso_al_pago') }}
                                                as bucket_mora_al_pago,
        case
            when coalesce(g.dias_atraso_al_pago, 0) > 0 then true
            else false
        end                                      as pago_en_mora,

        -- contexto del prestamo. La mora VIGENTE se trae del prestamo, que ya
        -- la calculo y clasifico, para que el tablero no tenga que decidir otra
        -- vez si un pago cae en un bucket u otro.
        p.estado_prestamo                        as estado_prestamo,
        p.bucket_mora                            as bucket_mora_actual,
        p.dias_atraso                            as dias_atraso_actual,
        p.fecha_vencimiento                      as fecha_vencimiento_prestamo,
        p.saldo_actual_bs                        as saldo_actual_prestamo,
        p.monto_aprobado_bs                      as monto_aprobado_prestamo,
        p.tasa_interes_aplicada                  as tasa_interes,

        -- ventana temporal, para que los reportes por mes no tengan que
        -- recalcularla
        {{ trimestre('g.fecha_pago') }}          as trimestre_pago,
        {{ nombre_mes('g.fecha_pago') }}         as mes_pago,

        -- referencia al riesgo del titular, que ya quedo resuelto por
        -- identidad en int_riesgo_cliente
        p.cliente_id                             as cliente_id_ref,
        'F1'                                     as fuente
    from pago g
    left join prestamo p
           on g.prestamo_id = p.prestamo_id

)

select * from enriquecido
