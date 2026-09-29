{{ config(materialized='table', unique_key='gravamen_id') }}

{#-
    fact_derechos_reales.sql  (NUEVO)  *** FUENTE F5 ***

    ESTA ES LA FACT QUE CIERRA LA HISTORIA DE LA GARANTIA
    ---------------------------------------------------------------------------
    Antes, la cobertura de una garantia era un porcentaje que escribia el
    analista en el origination, sin ninguna evidencia. Este hecho trae el
    respaldo real: un inmueble con matricula, un avaluo y una inscripcion en el
    Registro de Derechos Reales.

    Grano: 1 fila = 1 gravamen inscrito a favor de un prestamo.
    Eso significa que una garantia de tercero (titular distinto del deudor) y
    una garantia propia se pueden distinguir por titular_es_deudor, que antes
    no se podia ni siquiera calcular.
-#}

select
    g.gravamen_id,

    -- ===== FKs =====
    {{ dbt_utils.generate_surrogate_key(['g.prestamo_id']) }}           as prestamo_key,
    -- el cliente: el DEUDOR del prestamo, no el titular del inmueble
    {{ dbt_utils.generate_surrogate_key(['g.cliente_numero_id_hash']) }}
                                                                      as cliente_key,
    {{ dbt_utils.generate_surrogate_key(['g.inmueble_id']) }}          as inmueble_key,
    {{ dbt_utils.generate_surrogate_key(['g.tipo_derecho_real_id']) }} as tipo_derecho_real_key,

    -- ===== ROLES DE FECHA: 2 FKs distintas a la MISMA dimension =====
    cast(to_char(g.fecha_inscripcion_gravamen, 'YYYYMMDD') as integer) as fecha_inscripcion_key,
    cast(to_char(g.fecha_liberacion, 'YYYYMMDD') as integer)           as fecha_liberacion_key,

    -- ===== business keys =====
    g.prestamo_id,
    g.inscripcion_id,
    g.inmueble_id,
    g.tipo_derecho_real_id,
    g.cliente_id_legacy,
    g.cliente_numero_identificacion                                     as cliente_id,
    g.cliente_numero_id_hash,
    g.matricula_inmueble,
    g.numero_inscripcion,
    g.derecho_real_codigo,
    g.derecho_real_nombre,
    g.tipo_inmueble,
    g.inmueble_departamento,
    g.estado_gravamen,
    g.estado_inscripcion,
    g.estado_inmueble,
    g.notario,

    -- ===== MEDIDAS: lo declarado vs lo verificado =====
    g.monto_garantizado_bs,
    g.cobertura_declarada_bd,
    g.cobertura_real,
    g.valor_avaluo_bs,
    g.valor_comercial_bs,
    g.superficie_m2,
    g.saldo_actual_bs,
    g.monto_aprobado_bs,
    g.cuota_mensual_bs,
    g.plazo_aprobado_meses,

    -- ===== MEDIDAS DERIVADAS =====
    g.ltv_pct,
    g.nivel_garantia,
    g.brecha_cobertura,
    g.dias_gravamen_vigente,
    g.dias_atraso,
    g.bucket_mora,
    g.estado_prestamo_tipo_id,

    -- garantia de tercero: el inmueble respalda un credito de otra persona
    g.titular_es_deudor,
    case when g.titular_es_deudor then 'PROPIA' else 'DE TERCERO' end  as tipo_titularidad,

    -- valor de mercado vs valor legal: la diferencia es el margen de cobertura
    -- que el avaluo oficial subestima frente al valor de mercado
    case when g.valor_avaluo_bs > 0
         then round((g.valor_comercial_bs - g.valor_avaluo_bs) / g.valor_avaluo_bs, 4)
    end                                                                 as brecha_avaluo_comercial,

    g.fecha_inscripcion_gravamen,
    g.fecha_liberacion
from {{ ref('int_derechos_reales_garantia') }} g
