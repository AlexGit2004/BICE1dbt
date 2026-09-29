-- =============================================================================
-- int_deuda
-- Fuentes: stg_f3__deuda_cr, stg_f3__deudor_central_riesgos,
--          stg_f3__tipo_entidad_financiera, int_riesgo_cliente
-- Destino: CSILVER (table)
-- -----------------------------------------------------------------------------
-- QUE HACE
-- Un hecho de deuda reportada por la central de riesgos, a nivel de fila de
-- deuda, con el deudor identificado contra el maestro de clientes.
--
-- GRAIN
-- deuda_id.
--
-- LA IDENTIDAD COMO PUENTE
-- ------------------------
-- F3 no trae la identidad del cliente, sino un deudor_id propio de la central.
-- Para colgar la deuda de una persona del nucleo hay que pasar por la
-- identidad. Ese cruce YA esta resuelto en int_riesgo_cliente, que tiene
-- deudor_id_cr, cliente_id y ci_canonico de los 40.000 deudores. Aca se
-- reutiliza ese puente, en vez de rehacerlo.
--
-- (int_identidad_resuelta NO sirve para esto: tiene un cliente_id por fila, sin
-- deudor_id. El puente deudor<->cliente es int_riesgo_cliente.)
--
-- MEDIDAS QUE NO SE MEZCLAN
-- -------------------------
--   monto_deuda_actual_bs: lo que se debe hoy en esa obligacion
--   dias_atraso_actual:    dias de atraso de esa obligacion
--
-- Aparte, el deudor trae un monto total y una cantidad de instituciones, que
-- son medidas del DEUDOR COMPLETO, no de esta obligacion. Se conservan como
-- columnas separadas (con el prefijo deudor_) y no se suman ni se mezclan con
-- monto_deuda_actual_bs: sumarlos seria sumar un saldo individual con un
-- agregado del deudor y obtener un numero que no corresponde a nada.
-- =============================================================================

with deuda as (

    select * from {{ ref('stg_f3__deuda_cr') }}

),

deudor as (

    select * from {{ ref('stg_f3__deudor_central_riesgos') }}

),

tipo_entidad as (

    select * from {{ ref('stg_f3__tipo_entidad_financiera') }}

),

-- puente deudor_id_cr -> cliente_id, ya resuelto por identidad
riesgo as (

    select
        cliente_id,
        deudor_id_cr,
        ci_canonico,
        categoria_riesgo,
        score_morosidad
    from {{ ref('int_riesgo_cliente') }}

),

enriquecida as (

    select
        d.deuda_id,
        d.deudor_id,
        r.cliente_id                            as cliente_id,
        r.ci_canonico                           as identidad_cliente,
        r.categoria_riesgo                      as categoria_riesgo_cliente,
        r.score_morosidad                       as score_morosidad_cliente,

        -- la obligacion
        {{ limpiar_texto('d.tipo_obligacion') }} as tipo_obligacion,
        d.monto_deuda_actual_bs                   as monto_deuda_actual_bs,
        d.dias_atraso_actual                      as dias_atraso_actual,
        d.fecha_originacion                      as fecha_origenacion_deuda,
        d.fecha_consulta                          as fecha_consulta,

        -- mora
        {{ bucket_mora('d.dias_atraso_actual') }} as bucket_mora,
        case
            when coalesce(d.dias_atraso_actual, 0) > 0 then true
            else false
        end                                      as en_mora,

        -- entidad financiera acreedora
        d.entidad_financiera_id                   as entidad_financiera_id,
        {{ limpiar_texto('te.nombre_tipo') }}    as nombre_entidad,
        {{ limpiar_texto('te.descripcion') }}     as descripcion_entidad,

        -- medidas del DEUDOR COMPLETO, no de esta obligacion. Llevan prefijo
        -- deudor_ para que nunca se sumen con las columnas de la obligacion.
        de.cantidad_instituciones_acreedor         as deudor_cantidad_instituciones,
        de.monto_total_deuda_bs                   as deudor_monto_total_bs,
        de.fecha_ultima_consulta                  as deudor_fecha_ultima_consulta,

        -- ventana temporal
        {{ trimestre('d.fecha_consulta') }}       as trimestre_consulta,
        'F3'                                      as fuente
    from deuda d
    left join riesgo r
           on d.deudor_id = r.deudor_id_cr
    left join deudor de
           on d.deudor_id = de.deudor_id
    left join tipo_entidad te
           on d.entidad_financiera_id = te.tipo_entidad_id

)

select * from enriquecida
