{{ config(materialized='table') }}

{#-
    int_exposicion_empresa.sql  (NUEVO)

    REGLA 3: "Integra dim_empresa como una dimension vinculada a dim_cliente
    mediante una tabla puente o relacion directa NIT <-> CI/NIT".

    POR QUE UNA TABLA PUENTE Y NO UNA FK DIRECTA
    ---------------------------------------------------------------------------
    Hay DOS relaciones distintas entre una persona/empresa y una empresa del
    registro mercantil, y ninguna se puede expresar con una FK simple:

      (a) la empresa ES el cliente juridico:
          empresa_registro_mercantil.nit_empresa = cliente.numero_identificacion
          (tipo_id = 2). Es 1:1. La empresa registrada Y el cliente.

      (b) la persona es ACCIONISTA o representante de la empresa:
          accionista_representante_rm.numero_identificacion = cliente.numero_identificacion
          N:1 -> un cliente puede ser accionista de varias empresas.
          Y con es_controlador + porcentaje se puede medir el control.

    Juntas dan una relacion N:M con atributos, que es exactamente lo que una
    tabla puente modela. Ademas permite responder la pregunta de gestion de
    riesgos mas valiosa que el modelo no podia:
    "el cliente juridico que nos debe es accionista de una empresa que tambien
     nos debe?" Es concentracion de riesgo en un grupo economico.

    El cruce es por hash-contra-hash en los DOS lados.
-#}

with cli as (
    select
        numero_id_hash,
        numero_identificacion,
        tipo_id,
        nombre_completo
    from {{ ref('int_clientes_unificados') }}
),

emp as (
    select * from {{ ref('int_riesgo_tributario') }}
),

acc as (
    select
        ar.empresa_id,
        {{ hash_pii( normalizar_identidad('ar.numero_identificacion') ) }} as accionista_hash,
        {{ normalizar_identidad('ar.numero_identificacion') }}             as accionista_id_norm,
        ar.nombre_completo            as accionista_nombre,
        ar.tipo_participacion,
        ar.porcentaje_participacion,
        ar.es_controlador
    from {{ ref('stg_maria__accionista_representante_rm') }} ar
),

-- (a) la empresa ES el cliente juridico
via_nit as (
    select
        e.numero_id_hash                as cliente_hash,
        e.empresa_id,
        'LA_EMPRESA'                    as tipo_vinculo,
        100.00                          as porcentaje_participacion,
        true                            as es_controlador,
        'NIT coincide con el CI/NIT del cliente' as nota_vinculo
    from emp e
),

-- (b) el cliente es accionista o representante
via_accionista as (
    select
        a.accionista_hash                as cliente_hash,
        a.empresa_id,
        case when a.tipo_participacion = 'Accionista'
             then 'ES_ACCIONISTA' else 'ES_REPRESENTANTE' end as tipo_vinculo,
        a.porcentaje_participacion,
        a.es_controlador,
        a.accionista_nombre || ' como ' || lower(a.tipo_participacion) as nota_vinculo
    from acc a
),

-- (c) el cliente tiene la calidad de proveedor/acreedor nuestro, no accionista
via_deuda as (
    select
        f.numero_id_hash                as cliente_hash,
        f.entidad_id                    as empresa_id,
        'ES_ACREEDORA'                  as tipo_vinculo,
        null                            as porcentaje_participacion,
        false                           as es_controlador,
        'Banco acreedor con deuda registrada' as nota_vinculo
    from {{ ref('int_riesgo_central') }} f
    group by 1, 2, 3, 4, 5, 6
),

puente as (
    select * from via_nit
    union all
    select * from via_accionista
    union all
    select * from via_deuda
)

select
    {{ dbt_utils.generate_surrogate_key(['p.cliente_hash', 'p.empresa_id', 'p.tipo_vinculo']) }}
                                                                  as puente_key,
    p.cliente_hash,
    p.empresa_id,
    p.tipo_vinculo,
    p.porcentaje_participacion,
    p.es_controlador,
    p.nota_vinculo,

    -- datos de la empresa, para que la vista puente no necesite otro join
    e.razon_social,
    e.tipo_empresa_id,
    e.categoria_comercial,
    e.estado_empresa,
    e.deuda_tributaria_actual_bs,
    e.estado_tributario_actual,
    e.cantidad_accionistas,
    e.pct_controlador,
    e.anio_fiscal_vigente,

    -- el identificador del cliente, para leer la vista sin pasar por el hash
    c.numero_identificacion,
    c.nombre_completo,
    c.tipo_id,

    -- ===== MEDIDAS DE EXPOSICION DEL GRUPO ECONOMICO =====
    -- Si el cliente debe y su empresa tambien debe, hay doble exposicion.
    case when c.numero_id_hash is not null and e.numero_id_hash is not null
              and c.numero_id_hash = e.numero_id_hash
         then true else false end                                  as es_la_misma_entidad,
    -- control real: >50% del capital
    case when coalesce(p.porcentaje_participacion, 0) > 50
         then true else false end                                  as tiene_control
from puente p
join emp e on e.empresa_id = p.empresa_id
left join cli c on c.numero_id_hash = p.cliente_hash   -- REGLA 2: hash-contra-hash
