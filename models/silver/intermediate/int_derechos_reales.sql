-- =============================================================================
-- int_derechos_reales
-- Fuentes: stg_f5__derecho_real_inscripcion, stg_f5__bien_inmueble,
--          stg_f5__tipo_derecho_real, stg_f5__gravamen_garantia_prestamo
-- Destino: CSILVER (table)
-- -----------------------------------------------------------------------------
-- QUE HACE
-- Un hecho de inscripcion de derecho real, con el inmueble resuelto, el tipo de
-- derecho y, cuando la inscripcion respalda un credito, el gravamen que la
-- vincula a un prestamo.
--
-- GRAIN
-- inscripcion_id.
--
-- LA CADENA DE LAS TRES FUENTES DE F5
-- ----------------------------------
--     bien_inmueble  <-  derecho_real_inscripcion  <-  gravamen_garantia_prestamo
--     (el cosa)          (la inscripcion)              (el vinculo con el credito)
--
-- El inmueble dice QUE se garantiza; la inscripcion dice QUE derecho se
-- inscribio; el gravamen dice PARA QUE prestamo. Sin las tres, el dato esta
-- incompleto: un inmueble sin inscripcion no tiene respaldo registral, y una
-- inscripcion sin gravamen no respalda ningun credito de este portafolio.
--
-- POR QUE EL TITULAR VA COMO IDENTIDAD, NO COMO cliente_id
-- -------------------------------------------------------
-- La inscripcion trae la identidad del titular del derecho. Esa identidad se
-- cruza con el maestro por identidad normalizada, que es la unica via
-- confiable entre fuentes. Si no cruza, la fila se conserva con
-- identidad_encontrada = false: perder una inscripcion porque su titular no
-- esta en el nucleo seria peor que registrarla como no cruzada. Se marca para
-- que el tablero pueda distinguir "sin titular" de "titular no reconciliado".
-- =============================================================================

with inscripcion as (

    select * from {{ ref('stg_f5__derecho_real_inscripcion') }}

),

inmueble as (

    select * from {{ ref('stg_f5__bien_inmueble') }}

),

tipo_derecho as (

    select * from {{ ref('stg_f5__tipo_derecho_real') }}

),

gravamen as (

    select * from {{ ref('stg_f5__gravamen_garantia_prestamo') }}

),

-- El titular se busca en el maestro por identidad canonica. Se usa
-- int_riesgo_cliente porque ya tiene la identidad resuelta con su
-- cliente_id y su riesgo, sin rehacer el cruce.
--
-- La identidad normalizada de una persona juridica es su NIT, no su CI, y en
-- el maestro el NIT vive en stg_f1__cliente, no en int_riesgo_cliente. Por eso
-- el maestro de busqueda se arma con las dos fuentes.
maestro as (

    select cliente_id, identidad
    from (
        select
            cliente_id,
            identidad,
            row_number() over (partition by identidad order by cliente_id) as rn
        from (
            select
                cliente_id,
                {{ normalizar_identidad('c.numero_identificacion') }} as identidad
            from {{ ref('stg_f1__cliente') }} c
            where c.numero_identificacion is not null

            union all

            select
                cliente_id,
                {{ normalizar_identidad('c.ci_representante_legal') }} as identidad
            from {{ ref('stg_f1__cliente') }} c
            where c.ci_representante_legal is not null
        ) u
    ) r
    where rn = 1

),

-- un gravamen por inscripcion: se toma el mas reciente si hubiera mas de uno
gravamen_ultimo as (

    select
        g.inscripcion_id,
        g.gravamen_id,
        g.prestamo_id,
        g.fecha_inscripcion_gravamen,
        g.monto_garantizado_bs,
        g.fecha_liberacion,
        {{ limpiar_texto('g.estado_gravamen') }} as estado_gravamen,
        row_number() over (partition by g.inscripcion_id
                           order by g.fecha_inscripcion_gravamen desc) as rn
    from gravamen g

),

enriquecida as (

    select
        i.inscripcion_id,
        i.numero_inscripcion,
        i.inmueble_id,

        -- el derecho inscrito
        i.tipo_derecho_real_id                     as tipo_derecho_real_id,
        {{ limpiar_texto('td.nombre_tipo') }}      as nombre_tipo_derecho,
        {{ limpiar_texto('td.codigo') }}           as codigo_tipo_derecho,
        td.es_garantia                             as es_garantia,
        td.es_transmision                          as es_transmision,
        td.requiere_valuacion                      as requiere_valuacion,

        -- fechas
        i.fecha_inscripcion                        as fecha_inscripcion,
        i.fecha_vencimiento                        as fecha_vencimiento,
        {{ antiguedad_meses('i.fecha_inscripcion') }} as antiguedad_inscripcion_meses,
        {{ clasificar_vencimiento('i.fecha_vencimiento') }} as estado_vencimiento,
        {{ trimestre('i.fecha_inscripcion') }}     as trimestre_inscripcion,

        -- el inmueble
        {{ limpiar_texto('im.matricula_inmueble') }} as matricula_inmueble,
        {{ limpiar_texto('im.tipo_inmueble') }}   as tipo_inmueble,
        {{ limpiar_texto('im.departamento') }}     as departamento_inmueble,
        {{ limpiar_texto('im.zona') }}             as zona_inmueble,
        im.superficie_m2                           as superficie_m2,
        im.valor_comercial_bs                       as valor_comercial_bs,
        im.valor_avaluo_bs                         as valor_avaluo_inmueble_bs,
        im.fecha_avaluo                            as fecha_avaluo_inmueble,
        {{ avaluo_vigente('im.fecha_avaluo') }}    as vigencia_avaluo_inmueble,
        {{ limpiar_texto('im.estado_inmueble') }}  as estado_inmueble,

        -- montos
        i.monto_base_bs                            as monto_base_bs,
        {{ limpiar_texto('i.notario') }}           as notario,
        {{ limpiar_texto('i.estado_inscripcion') }} as estado_inscripcion,

        -- el vinculo con el credito, si existe
        g.prestamo_id                              as prestamo_id,
        g.monto_garantizado_bs                     as monto_garantizado_bs,
        g.fecha_inscripcion_gravamen               as fecha_inscripcion_gravamen,
        g.fecha_liberacion                         as fecha_liberacion_gravamen,
        g.estado_gravamen                          as estado_gravamen,
        case
            when g.prestamo_id is not null then true
            else false
        end                                        as respalda_credito,

        -- el titular, por identidad
        i.numero_identificacion_titular_origen      as titular_identificacion_origen,
        {{ normalizar_identidad('i.numero_identificacion_titular') }}
                                                   as titular_identidad,
        m.cliente_id                               as cliente_id,
        case
            when m.cliente_id is not null then true
            else false
        end                                         as titular_reconciliado,
        'F5'                                       as fuente
    from inscripcion i
    left join inmueble     im  on i.inmueble_id = im.inmueble_id
    left join tipo_derecho td  on i.tipo_derecho_real_id = td.tipo_derecho_real_id
    left join gravamen_ultimo g on i.inscripcion_id = g.inscripcion_id
                              and g.rn = 1
    left join maestro m
           on {{ normalizar_identidad('i.numero_identificacion_titular') }}
              = m.identidad

)

select * from enriquecida
