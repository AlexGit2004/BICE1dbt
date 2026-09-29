-- =============================================================================
-- fact_riesgo_cliente
-- Fuente: int_riesgo_cliente
-- Destino: CGOLD (table)
-- -----------------------------------------------------------------------------
-- QUE HACE
-- Hecho de riesgo consolidado por cliente: una fila por cliente, con su
-- score, categoria de riesgo, antecedentes penales, deuda externa y
-- situacion tributaria.
--
-- GRAIN
-- cliente_id.
--
-- LAS MEDIDAS
-- -----------
--   score_morosidad          -> puntaje ASFI (350-950, mas alto = mas riesgo)
--   procesos_activos         -> cantidad de procesos penales activos
--   sentencias_condenatorias -> cantidad de sentencias condenatorias
--   delitos_distintos        -> cantidad de tipos de delito distintos
--   instituciones_acreedoras -> cantidad de entidades que le prestan
--   monto_deuda_cr           -> deuda total reportada a la central
--   saldo_externo            -> saldo externo consolidado
--   dias_mora_externo        -> mora externa consolidada
--   impuestos_adeudados      -> impuestos adeudados
--
-- Son medidas aditivas: se pueden sumar y agrupar. Por eso viven en un hecho.
--
-- LA CATEGORIA DE RIESGO
-- ----------------------
-- categoria_riesgo es la estandarizada por el macro categoria_riesgo, que
-- respeta la categoria del proveedor. nivel_por_score es la derivada del
-- score, con los cortes de la escala ASFI. Son dos columnas distintas porque
-- miden cosas distintas: la primera es la etiqueta del proveedor, la segunda
-- es la posicion en la escala de score.
--
-- EL SCORE
-- --------
-- score_morosidad se conserva en su escala real 350-950. No se normaliza a
-- 0-100 porque perderia la referencia a la escala ASFI, que es la que el
-- negocio usa para comparar con el regulador.
--
-- NO SE UNE CON dim_cliente AQUI
-- -------------------------------
-- dim_cliente ya trae el riesgo consolidado. Este hecho es la version
-- independiente, para cuando el tablero solo necesita el riesgo y no los
-- atributos del cliente. Unir ambos duplicaria las columnas de riesgo.
-- =============================================================================

select
    cliente_id,
    ci_canonico,
    es_persona_juridica,
    deudor_id_cr,
    tipo_persona_cr,
    instituciones_acreedoras,
    monto_deuda_cr,
    fecha_ultima_consulta,
    categoria_riesgo_origen,
    score_morosidad,
    fecha_score,
    categoria_riesgo,
    nivel_por_score,
    procesos_activos,
    sentencias_condenatorias,
    flag_antecedentes,
    delitos_distintos,
    delito_ejemplo,
    productos_externos,
    saldo_externo,
    saldo_externo_total,
    dias_mora_externo,
    calificacion_asfi,
    estado_tributario,
    impuestos_adeudados,
    'F2+F3+F4'                                 as fuente
from {{ ref('int_riesgo_cliente') }}
