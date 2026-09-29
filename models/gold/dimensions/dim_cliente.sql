-- =============================================================================
-- dim_cliente
-- Fuentes: int_identidad_resuelta, int_riesgo_cliente
-- Destino: CGOLD (table)
-- -----------------------------------------------------------------------------
-- QUE HACE
-- Maestro de clientes: una fila por cliente, con su identidad canonica, sus
-- atributos personales y su riesgo consolidado.
--
-- GRAIN
-- cliente_id.
--
-- POR QUE DOS FUENTES
-- -------------------
-- int_identidad_resuelta trae QUIEN ES el cliente: nombre, estado, fecha de
-- creacion, si es persona juridica, su NIT. Es la fuente maestra de F1.
--
-- int_riesgo_cliente trae COMO SE COMPORTA: score, categoria de riesgo,
-- antecedentes penales, deuda externa, situacion tributaria. Es el resultado
-- del cruce con F2, F3 y F4.
--
-- Se unen por cliente_id, que es la llave maestra que ya resolvio
-- int_identidad_resuelta. No se une por identidad normalizada porque un
-- cliente puede tener varias identidades (una por fuente) y el cliente_id es
-- la que ya esta resuelta.
--
-- EL NOMBRE
-- ---------
-- nombre_completo viene de int_identidad_resuelta, que ya lo limpio con
-- limpiar_texto. Para persona juridica, el nombre es la razon social; para
-- persona natural, el nombre completo. Se conserva el nombre del representante
-- legal aparte, porque es una persona distinta que firma por la empresa.
-- =============================================================================

with identidad as (

    select * from {{ ref('int_identidad_resuelta') }}

),

riesgo as (

    select * from {{ ref('int_riesgo_cliente') }}

)

select
    i.cliente_id,
    i.ci_canonico,
    i.ci_como_llego,
    i.tipo_id,
    i.es_persona_juridica,
    i.nit_empresa,
    i.ci_representante_legal,
    i.nombre_completo,
    i.nombre_representante_legal,
    i.estado_cliente,
    i.fecha_creacion,
    i.fuentes_confirmantes,
    i.fuentes_vistas,
    i.identidad_confirmada,

    -- riesgo consolidado
    r.deudor_id_cr,
    r.tipo_persona_cr,
    r.instituciones_acreedoras,
    r.monto_deuda_cr,
    r.fecha_ultima_consulta,
    r.categoria_riesgo_origen,
    r.score_morosidad,
    r.fecha_score,
    r.categoria_riesgo,
    r.nivel_por_score,
    r.procesos_activos,
    r.sentencias_condenatorias,
    r.flag_antecedentes,
    r.delitos_distintos,
    r.delito_ejemplo,
    r.productos_externos,
    r.saldo_externo,
    r.saldo_externo_total,
    r.dias_mora_externo,
    r.calificacion_asfi,
    r.estado_tributario,
    r.impuestos_adeudados,

    -- banderas derivadas para el tablero
    case
        when r.flag_antecedentes = 1 then true
        else false
    end                                        as tiene_antecedentes_penales,
    case
        when r.estado_tributario is not null
         and upper(r.estado_tributario) not in ('AL DIA', 'SIN DEUDAS', 'OK')
        then true
        else false
    end                                        as tiene_problemas_tributarios,
    'F1+F2+F3+F4'                              as fuente
from identidad i
left join riesgo r
       on i.cliente_id = r.cliente_id
