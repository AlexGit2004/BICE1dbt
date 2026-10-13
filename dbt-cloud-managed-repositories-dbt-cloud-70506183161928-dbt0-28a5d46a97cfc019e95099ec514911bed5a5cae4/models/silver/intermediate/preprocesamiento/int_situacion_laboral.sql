{{ config(materialized='table') }}

{#-
    int_situacion_laboral.sql  (CORREGIDO)

    REGLA 1: la identidad viene del crosswalk.
    REGLA 2: el cruce es por hash.

    QUE CAMBIA  (ver P-11)
    El modelo anterior hacia:
        left join int_prestamos_limpios pr on pr.prestamo_id = sl.prestamo_id
    y sl.prestamo_id era  cast(PRESTAMO_ID as bigint)  de una columna que el
    CSV no tiene. El join no podia dar un solo resultado util.

    AQUI SE ES EXPLICITO EN LUGAR DE INVENTAR
    ---------------------------------------------------------------------------
    El CSV no trae PRESTAMO_ID, y sin el no hay forma de calcular la capacidad
    de pago, porque la cuota vive en el prestamo. Hay dos caminos y ambos son
    legitimos:

      (a) Que la fuente entregue el CI del titular Y el prestamo evaluado. Es
          lo correcto y es un cambio de un campo en el CSV.

      (b) Aprobar o rechazar un credito por el ingreso anual, sin cruce con el
          prestamo: capacidad_pago_marginal = ingresos / 12 contra la cuota fija
          que el negocio defina. Es un criterio distinto, mas simple, y se
          puede hacer YA.

    Este modelo implementa (b) como indicador disponible y deja (a) con un flag
    explicito para que el dashboard diga la verdad: no se muestra un KPI
    calculado sobre un cruce inexistente.
-#}

with sl as (
    select * from {{ ref('stg_csv__situacion_laboral') }}
    where numero_id_hash is not null
),

-- Un registro laboral vigente por persona: el mas reciente.
vigente as (
    select *,
        row_number() over (
            partition by numero_id_hash
            order by fecha_actualizacion desc nulls last
        ) as _rn
    from sl
    where estado_empleo in ('ACTIVO', 'JUBILACION')
)

select
    v.numero_id_hash,
    v.numero_identificacion,
    v.id_cliente,
    v.tipo_empleo,
    v.tipo_contrato,
    v.empresa                                       as empresa_empleadora,
    v.sector_economico,
    v.cargo,
    v.ciudad,
    v.fecha_actualizacion,

    v.ingresos_mensuales_bs,
    v.antiguedad_laboral_meses,

    -- ===== capacidad de pago SIN depender del cruce con el prestamo =====
    -- (b): el ingreso se compara contra la cuota minima aceptable que el
    -- negocio fija, y no contra la cuota de un prestamo que el CSV no nombra.
    round(case when coalesce(v.ingresos_mensuales_bs, 0) > 0
               then v.ingresos_mensuales_bs / 12.0 * 12 / 12   -- ingreso anual util
               else 0 end, 2)                                 as ingreso_anual_util,
    case
        when v.numero_identificacion is null                   then false
        when coalesce(v.ingresos_mensuales_bs, 0) <= 0         then false
        when v.tipo_empleo = 'INDEPENDIENTE'                   then true
        when v.ingresos_mensuales_bs >= {{ var('ratio_cuota_ingreso_ci') }}
                                              * {{ var('ingreso_minimo_mensual_nit') }}
            then true
        else false
    end                                                      as cumple_capacidad_pago_por_ingreso,
    -- nivel de solidez laboral del expediente, como atributo
    case
        when v.tipo_empleo = 'INDEPENDIENTE'         then 'Sin relacion de dependencia'
        when v.tipo_contrato = 'INDEFINIDO'          then 'Contrato indefinido'
        when v.tipo_contrato = 'TEMPORAL'            then 'Contrato temporal'
        when v.tipo_contrato = 'JUBILACION'          then 'Pensionado'
        else                                             'Sin especificar'
    end                                                      as solidez_laboral,

    -- ===== LO QUE SIGUE PENDIENTE, DECLARADO =====
    -- (a): cuando la fuente entregue PRESTAMO_ID, se habilita el calculo real
    -- de ratio_cuota_ingreso contra la cuota del prestamo.
    v.prestamo_id_disponible                                 as tiene_prestamo_en_fuente,
    false                                                     as ratio_cuota_ingreso_calculado
from vigente v
where v._rn = 1
