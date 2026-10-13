{{ config(materialized='table', unique_key='entidad_key') }}

{#-
    dim_entidad.sql  (CORREGIDO)  *** REGLA 3 ***
    "Conecta dim_entidad a fact_riesgo o fact_cliente_360 mediante entidad_key"

    ANTES: existia, se materializaba, y NINGUNA fact la referenciaba. Era una
    dimension huerfana. La causa era que int_riesgo_central hacia GROUP BY
    numero_identificacion y descartaba entidad_financiera_id al agregar, tirando
    la granularidad mas fina (deudor x entidad acreedora).

    AHORA: el grano fino vive en int_riesgo_central -> fact_deuda_externa, que
    tiene una FK entidad_key REAL. Y ademas dim_cliente expone
    entidad_principal_id para el caso de "en que banco esta mas expuesto".

    Un tipo de entidad financiera no es el mismo concepto que una entidad
    concreta: "Banco" es una categoria, "Banco XYZ" es el acreedor. Por eso hay
    dos columnas y no una.
-#}

select
    {{ dbt_utils.generate_surrogate_key(['tipo_entidad_id']) }} as entidad_key,
    tipo_entidad_id                                       as entidad_id,
    {{ limpiar_texto('nombre_tipo') }}                    as nombre_entidad,
    descripcion,

    -- clasificacion de la institucion, derivada del catalogo
    case
        when upper(nombre_tipo) like '%COOPERATIVA%' then 'Cooperativa'
        when upper(nombre_tipo) like '%MUTUAL%'      then 'Mutual'
        when upper(nombre_tipo) like '%FINANCIERA%'  then 'Financiera'
        when upper(nombre_tipo) like '%BANCO%'       then 'Banco'
        else                                              'Otra'
    end                                                   as tipo_entidad,

    -- atributo de gobierno: una cooperativa o financiera micro no tiene la
    -- misma capacidad de cobro que un banco. El score pondera por esto.
    case
        when upper(nombre_tipo) like '%BANCO%'       then 1.00
        when upper(nombre_tipo) like '%FINANCIERA%'  then 0.85
        when upper(nombre_tipo) like '%COOPERATIVA%' then 0.70
        when upper(nombre_tipo) like '%MUTUAL%'      then 0.70
        else                                              0.50
    end                                                   as factor_prioridad_cobro
from {{ ref('stg_server__tipo_entidad_financiera') }}
