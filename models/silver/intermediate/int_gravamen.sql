-- =============================================================================
-- int_gravamen
-- Fuentes: stg_f5__gravamen_garantia_prestamo, stg_f1__garantia,
--          int_prestamos
-- Destino: CSILVER (table)
-- -----------------------------------------------------------------------------
-- QUE HACE
-- El vinculo registral entre una garantia de F1 y un prestamo, con el estado
-- del gravamen ya clasificado por vigencia.
--
-- GRAIN
-- gravamen_id.
--
-- POR QUE ESTE MODELO EXISTE APARTE DE int_garantias
-- ---------------------------------------------------
-- int_garantias responde "que respalda este credito" desde el lado del negocio:
-- el tipo de garantia, el avaluio, el LTV. Esta es la foto contractual.
--
-- El gravamen es el ACTO REGISTRAL: lo que se inscribio en el Registro de
-- Derechos Reales para que el acreedor tenga prioridad. Son cosas distintas que
-- se contradicen seguido: una garantia puede existir en el papel del banco y
-- no estar inscrita, o estar inscrita y ya liberada.
--
-- Un tablero que solo mire int_garantias dira que hay respaldo cuando en
-- realidad el bien ya se liberó. Por eso el estado de vigencia se calcula
-- acá, y la garantia de F1 se trae para poder comparar ambas caras.
--
-- LA FECHA QUE DEFINE EL ESTADO
-- -----------------------------
-- Se usa fecha_liberacion, no una bandera de estado, porque la fecha es el
-- dato duro: si el gravamen se libero, el bien ya esta libre. Se conserva
-- estado_gravamen de la fuente tal cual, sin reinterpretar, para no perder la
-- informacion original del registro.
--
-- NOTA SOBRE prestamo_id
-- ---------------------
-- El prestamo_id de F5 es el prestamo_id de F1: ambas fuentes comparten la
-- numeracion de prestamos. Por eso se une directo con int_prestamos y no hace
-- falta pasar por identidad. Se verificó que el cruce es 1:1.
-- =============================================================================

with gravamen as (

    select * from {{ ref('stg_f5__gravamen_garantia_prestamo') }}

),

garantia as (

    select * from {{ ref('stg_f1__garantia') }}

),

prestamo as (

    select * from {{ ref('int_prestamos') }}

),

-- la garantia de F1 se une por el prestamo: puede haber varias garantias por
-- prestamo, y se agrega el detalle de cada una
enriquecido as (

    select
        g.gravamen_id,
        g.inscripcion_id,
        g.prestamo_id,

        -- fechas del gravamen
        g.fecha_inscripcion_gravamen               as fecha_inscripcion_gravamen,
        g.fecha_liberacion                         as fecha_liberacion,
        {{ antiguedad_meses('g.fecha_inscripcion_gravamen') }}
                                                  as antiguedad_inscripcion_meses,

        -- estado del gravamen. La fecha manda: si hay liberacion, esta libre.
        case
            when g.fecha_liberacion is not null then 'Liberado'
            when g.fecha_inscripcion_gravamen is null then 'Sin fecha'
            when g.fecha_inscripcion_gravamen > {{ var("fecha_corte") }}::date then 'No inscrito'
            else 'Vigente'
        end                                        as estado_gravamen_calculado,

        -- bandera para el tablero: el bien respalda al credito hoy o no
        case
            when g.fecha_liberacion is null
             and g.fecha_inscripcion_gravamen <= {{ var("fecha_corte") }}::date
            then true
            else false
        end                                        as gravamen_vigente,

        -- el monto que respalda el registro
        g.monto_garantizado_bs                     as monto_garantizado_bs,
        {{ limpiar_texto('g.estado_gravamen') }}   as estado_gravamen_origen,

        -- la garantia de negocio, para comparar ambas caras
        ga.garantia_id                             as garantia_id,
        {{ limpiar_texto('ga.tipo_garantia') }}    as tipo_garantia,
        {{ limpiar_texto('ga.descripcion_bien') }} as descripcion_bien,
        ga.valor_avaluo_bs                         as valor_avaluo_garantia_bs,

        -- el credito que se respalda
        p.cliente_id                              as cliente_id,
        p.saldo_actual_bs                         as saldo_prestamo_bs,
        p.monto_aprobado_bs                       as monto_aprobado_bs,
        p.estado_prestamo                         as estado_prestamo,
        p.bucket_mora                             as bucket_mora_prestamo,

        -- ventana temporal
        {{ trimestre('g.fecha_inscripcion_gravamen') }} as trimestre_inscripcion,
        'F5'                                       as fuente_gravamen,
        'F1'                                       as fuente_garantia
    from gravamen g
    left join garantia ga
           on g.prestamo_id = ga.prestamo_id
    left join prestamo p
           on g.prestamo_id = p.prestamo_id

)

select * from enriquecido
