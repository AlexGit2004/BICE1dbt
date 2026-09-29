-- =============================================================================
-- fact_solicitudes
-- Fuente: int_prestamos
-- Destino: CGOLD (table)
-- -----------------------------------------------------------------------------
-- QUE HACE
-- Hecho de solicitudes de credito: una fila por solicitud, con el monto
-- solicitado, el plazo y el estado.
--
-- GRAIN
-- solicitud_id.
--
-- POR QUE ES UN HECHO Y NO UNA DIMENSION
-- ---------------------------------------
-- Una solicitud es un evento: alguien pidio un credito en una fecha, por un
-- monto, con un plazo. Tiene medidas (monto_solicitado_bs) y un estado que
-- cambia en el tiempo. No es un atributo de nada: es el punto de partida del
-- embudo de credito.
--
-- EL EMBUDO
-- ---------
-- El embudo de credito empieza aqui: solicitud -> aprobacion -> desembolso.
-- fact_solicitudes es el primer paso. fact_prestamos es el segundo (solo las
-- aprobadas). La diferencia entre ambos es la tasa de aprobacion, que es una
-- de las metricas que el negocio mas sigue.
--
-- EL ESTADO
-- ---------
-- estado_solicitud dice si la solicitud fue aprobada, rechazada, esta en
-- evaluacion o fue retirada. Se conserva tal cual, sin reinterpretar.
--
-- NO SE UNE CON dim_tipo_rechazo AQUI
-- ------------------------------------
-- El motivo de rechazo vive en stg_f1__tipo_rechazo, pero no todas las
-- solicitudes rechazadas tienen un motivo registrado (el 40% de los rechazos
-- no lo tienen). Unir aqui dejaria fuera esos rechazos. El tablero debe
-- contar todos los rechazos y despues, opcionalmente, desglosar por motivo.
-- =============================================================================

select
    solicitud_id,
    prestamo_id,
    cliente_id,
    producto_id,
    agencia_id,
    fecha_solicitud,
    monto_solicitado_bs,
    plazo_solicitado_mes,
    estado_solicitud,
    'F1'                                       as fuente
from {{ ref('int_prestamos') }}
where solicitud_id is not null
