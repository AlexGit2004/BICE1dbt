{{ config(materialized='table', unique_key='puente_key') }}

{#-
    bridge_cliente_empresa.sql  (NUEVO)  *** REGLA 3 RESUELTA ***

    "Integra dim_empresa como una dimension vinculada a dim_cliente mediante
     una tabla puente o relacion directa NIT <-> CI/NIT"

    POR QUE UNA TABLA PUENTE Y NO UNA FK DIM_EMPRESA.CLIENTE_ID
    ---------------------------------------------------------------------------
    Hay TRES relaciones distintas entre un cliente y una empresa registrada, y
    ninguna se puede expresar con una FK simple porque todas tienen atributos:

      1. LA_EMPRESA         : nit_empresa = cliente.numero_identificacion, 1:1
      2. ES_ACCIONISTA      : la persona es socia de la empresa, N:1, con % de
                              participacion
      3. ES_REPRESENTANTE   : la persona representa legalmente a la empresa
      4. ES_ACREEDORA       : la "empresa" es un banco acreedor con deuda
                              registrada del cliente

    Juntas dan N:M con atributos, que es lo que una tabla puente modela. Con
    FK directa, la 2 y la 3 se perderian, y con ellas el 80% del valor.

    LA PREGUNTA QUE ESTA TABLA RESPONDE
    ---------------------------------------------------------------------------
    "El cliente juridico que nos debe es accionista o controlador de una empresa
     que TAMBIEN nos debe?" Eso es concentracion de riesgo en un grupo
    economico, y no se podia responder porque dim_empresa era huerfana.
    Con es_la_misma_entidad y tiene_control, ahora sale en un filtro.

    Grano: 1 fila = 1 cliente x 1 empresa x 1 tipo de vinculo.
-#}

select
    b.puente_key,

    -- ===== LAS DOS FKs DE LA TABLA PUENTE: una a cada lado =====
    b.cliente_hash,                                                        -- FK a dim_cliente
    {{ dbt_utils.generate_surrogate_key(['b.cliente_hash']) }} as cliente_key,
    b.empresa_id,
    {{ dbt_utils.generate_surrogate_key(['b.empresa_id']) }}  as empresa_key,

    -- ===== EL VINCULO =====
    b.tipo_vinculo,
    b.nota_vinculo,
    b.porcentaje_participacion,
    b.es_controlador,
    b.tiene_control,

    -- ===== MEDIDAS DE EXPOSICION DEL VINCULO =====
    case when b.tipo_vinculo in ('LA_EMPRESA','ES_ACREEDORA')
         then 1 else 0 end                                    as genera_exposicion_directa,
    -- indice de concentracion: % de participacion x si es controlador.
    -- 0.6 significa que el cliente controla el 60% de esa empresa.
    round(coalesce(b.porcentaje_participacion, 0) / 100.0, 4) as indice_control,
    -- La empresa ES el cliente: no hay doble exposicion, es la misma deuda
    b.es_la_misma_entidad,

    -- ===== datos que se pueden leer sin recorrer las dimensiones =====
    b.numero_identificacion,
    b.nombre_completo,
    b.tipo_id,
    b.razon_social,
    b.tipo_empresa_id,
    b.categoria_comercial,
    b.estado_empresa,
    b.deuda_tributaria_actual_bs,
    b.estado_tributario_actual,
    b.cantidad_accionistas,
    b.pct_controlador,
    b.anio_fiscal_vigente
from {{ ref('int_exposicion_empresa') }} b
