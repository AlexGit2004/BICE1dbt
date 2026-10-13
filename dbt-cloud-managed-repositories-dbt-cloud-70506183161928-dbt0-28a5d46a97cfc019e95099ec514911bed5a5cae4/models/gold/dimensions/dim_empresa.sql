{{ config(materialized='table', unique_key='empresa_key') }}

{#-
    dim_empresa.sql  (CORREGIDO)  *** REGLA 3 ***
    "Integra dim_empresa como una dimension vinculada a dim_cliente mediante
     una tabla puente o relacion directa NIT <-> CI/NIT"

    ANTES: huerfana Y sin puente. El puente existia en los datos (el NIT de una
    juridica es su CI/NIT con tipo_id = 2) pero ninguna fact lo usaba, asi que
    no se podia responder "el cliente juridico que nos debe es accionista de
    una empresa que tambien nos debe?".

    AHORA: el puente se materializa en bridge_cliente_empresa, que tiene FK a
    ESTA dimension y a dim_cliente. Los identificadores se distinguen:
      empresa_id  = el autoincremental de MariaDB. No sirve para cruzar.
      nit         = el NIT, que ES el CI/NIT. Este es el que se usa.
-#}

select
    {{ dbt_utils.generate_surrogate_key(['t.empresa_id']) }} as empresa_key,
    t.empresa_id,
    t.numero_id_hash,                                          -- el puente al nucleo
    t.nit,
    t.razon_social,
    t.tipo_empresa_id,
    coalesce(te.nombre_tipo_empresa, 'OTROS')                 as tipo_empresa,
    t.categoria_comercial,
    t.fecha_registro,
    t.estado_empresa,

    -- ===== CONTROL SOCIETARIO (lo que hace la dimension util) =====
    t.cantidad_accionistas,
    t.pct_total_accionistas,
    t.numero_controladores,
    t.pct_controlador,
    case
        when t.pct_controlador > 50  then 'Control total'
        when t.pct_controlador > 20  then 'Control compartido'
        when t.pct_controlador > 0   then 'Participacion minoritaria'
        else                                'Sin control'
    end                                                        as nivel_control,
    case when t.cantidad_accionistas = 0 then 'Sin datos'
         when t.cantidad_accionistas = 1 then 'Unipersonal'
         else                                  'Pluripersonal'
    end                                                        as tipo_sociedad,

    -- ===== SALUD TRIBUTARIA =====
    t.deuda_tributaria_actual_bs,
    t.estado_tributario_actual,
    t.deuda_tributaria_total_bs,
    t.anio_fiscal_vigente,
    t.anios_con_registro,
    t.es_moroso_tributario
from {{ ref('int_riesgo_tributario') }} t
left join {{ ref('stg_maria__tipo_empresa_rm') }} te
    on te.tipo_empresa_id = t.tipo_empresa_id
