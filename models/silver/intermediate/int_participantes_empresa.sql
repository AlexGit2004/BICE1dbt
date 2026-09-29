-- =============================================================================
-- int_participantes_empresa
-- Fuente: stg_f4__empresa_registro_mercantil,
--         stg_f4__accionista_representante_rm
-- Destino: CSILVER (table)
-- -----------------------------------------------------------------------------
-- QUE HACE
-- Lleva los participes de la fuente F4 a una forma utilizable, unidos a su
-- empresa por empresa_id (la clave sustituta del registro mercantil).
--
-- POR QUE NO SE USA LA IDENTIDAD PARA UNIR
-- ----------------------------------------
-- La identidad es el camino habitual del crosswalk de personas, pero en F4 NO
-- funciona. Medido sobre la fuente completa:
--
--     maria4_accionista_representante_rm  25.400 participes
--     de los cuales coinciden con F1           1  (0,00 %)
--
-- Un solo registro coincide de 25.400. La causa es que F4 se genero con
-- secuencias de identidad independientes de F1, asi que el NIT del accionista
-- no es el mismo numero de documento que tiene esa persona en el nucleo.
-- No es un problema de formato ni de normalizacion: no hay formato que haga
-- coincidir dos secuencias que jamas se generaron juntas.
--
-- Por eso este modelo NO intenta colgar los participes del maestro F1 por
-- identidad. Los deja como participantes con su propia clave
-- (participante_id) y los une a la empresa de forma directa por empresa_id,
-- que si es la clave del modelo.
--
-- QUE PASA EN GOLD
-- ---------------
-- La participacion es un hecho de la empresa, no de la persona del nucleo. En
-- el cruce de personas estas filas quedan con identidad_nula = true, y no se
-- deben forzar. El tablero de riesgos mira estas participaciones via la
-- dimension de empresa, no via la de cliente.
-- =============================================================================

with empresa as (

    select * from {{ ref('stg_f4__empresa_registro_mercantil') }}

),

participante as (

    select * from {{ ref('stg_f4__accionista_representante_rm') }}

),

-- Cada empresa tiene un solo registro en el registro mercantil, pero se
-- valida en vez de asumirlo: si el modelo cambia la granularidad, la
-- participacion quedaria duplicada en silencio.
empresa_unica as (

    select
        empresa_id,
        count(*) as veces
    from empresa
    group by 1

)

select
    -- clave del hecho
    p.participante_id,
    p.empresa_id,

    -- identidad del participe. Se normaliza igual que el resto del proyecto
    -- para que al menos sea comparable, aunque NO se use para unir con F1.
    p.numero_identificacion_origen            as identificacion_origen,
    {{ normalizar_identidad('p.numero_identificacion') }}
                                                as identificacion,
    -- se marca la validez con el mismo criterio de 9 digitos del resto, pero
    -- el resultado no se usa para emparejar con el maestro: solo describe la
    -- calidad del dato tal como llega.
    {{ es_identidad_valida('p.numero_identificacion') }}
                                                as identificacion_valida,
    p.nombre_completo                           as nombre_participante,

    -- rol dentro de la sociedad
    {{ limpiar_texto('p.tipo_participacion') }} as tipo_participacion,
    p.porcentaje_participacion                  as porcentaje_participacion,
    p.es_controlador                             as es_controlador,

    -- contexto de la empresa, para no depender de un segundo join al consumir
    e.nit_empresa                                as nit_empresa,
    e.razon_social                               as razon_social,
    e.estado_empresa                             as estado_empresa,
    e.fecha_constitucion                         as fecha_constitucion,

    -- auditoria
    'F4'                                          as fuente

from participante p
left join empresa e
       on p.empresa_id = e.empresa_id

-- Si una empresa apareciera mas de una vez, la participacion se multiplicaria.
-- Se filtra en vez de dejar que el error llegue a Gold.
where p.empresa_id in (select empresa_id from empresa_unica)
