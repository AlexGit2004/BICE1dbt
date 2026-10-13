{{ config(materialized='table', unique_key='asignacion_id') }}

{#-
    fact_open_finance.sql  (NUEVO)  *** F5b, REGLA 2 ***

    LA ESTRELLA DE LA EXPOSICION EXTERNA
    ---------------------------------------------------------------------------
    Antes, Open Finance se reducia a 3 columnas agregadas dentro de
    fact_cliente_360 (productos_externos, bancos_externos,
    tasa_promedio_externa). Eso no es un modelo: es un resumen. No permitia
    responder "en que institucion esta el cliente y por cuanto monto", que es
    literalmente lo que significa Open Finance.

    Grano: 1 fila = 1 producto externo asignado a 1 cliente.
    Con eso, la exposicion externa se descompone igual que la interna:
      cliente x banco x producto x fecha.

    Y ahi aparece el dato de verdad que hace util la fuente: la tasa mas ALTA
    que el cliente esta pagando afuera. Ese numero es la referencia contra la
    cual se mide si el banco le esta competitionndiendo con la misma tasa.
-#}

with a as (
    select * from {{ ref('int_open_finance_asignaciones') }}
),

cli as (
    select numero_id_hash, cliente_id, cliente_key
    from {{ ref('dim_cliente') }}
),

banco as (
    select banco_externo_key, banco_nombre, tipo_institucion,
           factor_prioridad_cobro
    from {{ ref('dim_banco_externo') }}
),

-- El mejor Rate del cliente en-productos externos: el benchmark para el
-- origination interno. Si una institucion ya paga 18% afuera, Prestarle al
-- 24% es perder el cliente.
benchmark as (
    select
        numero_id_hash,
        max(tasa_interes)                                        as tasa_maxima_externa,
        min(tasa_interes)                                        as tasa_minima_externa,
        count(distinct producto_id)                              as productos_totales,
        count(distinct case when es_producto_activo
                           then producto_id end)                 as productos_activos,
        sum(case when es_producto_activo
                 then monto_producto else 0 end)                 as monto_productos_activos
    from a
    where numero_id_hash is not null
    group by 1
)

select
    {{ dbt_utils.generate_surrogate_key(['a.documento_id', 'a.producto_id']) }} as asignacion_id,

    -- ===== FKs =====
    c.cliente_key,                                        -- FK a dim_cliente
    b.banco_externo_key,                                  -- FK a dim_banco_externo
    cast(to_char(a.fecha_apertura, 'YYYYMMDD') as integer) as fecha_apertura_key,

    -- ===== business keys =====
    a.documento_id,
    a.user_id_mongo,
    a.producto_id,
    c.cliente_id,
    a.numero_id_hash,
    a.nombre_banco,
    a.producto_id                                          as producto_codigo,

    -- ===== MEDIDAS =====
    a.monto_producto,
    a.tasa_interes,
    a.plazo_max,
    a.es_producto_activo,
    bm.productos_activos,
    bm.productos_totales,
    bm.monto_productos_activos,

    -- ===== EL INDICADOR DE OPEN FINANCE =====
    -- dispersi&#243;n de tasas del cliente: si tiene 4% y 40% afuera, su
    -- situaci&#243;n financiera es heterogenea y el score no la refleja
    case when bm.productos_activos > 1
         then round(bm.tasa_maxima_externa - bm.tasa_minima_externa, 4)
    end                                                     as dispersion_tasa,
    bm.tasa_maxima_externa,
    bm.tasa_minima_externa,
    b.tipo_institucion,
    b.factor_prioridad_cobro,

    -- Cada a&#241;o de plazo cuesta m&#225;s al prestatario: 36 meses a 30% es
    -- una situaci&#243;n de sobreendeudamiento por horizonte, no por cuota.
    case when a.tasa_interes is not null and a.plazo_max is not null
              and a.plazo_max > 0
         then round(a.tasa_interes * (a.plazo_max / 12.0), 4)
    end                                                     as costo_teorico_anual_pct,

    a.fecha_apertura
from a
join cli c   on c.numero_id_hash = a.numero_id_hash
join banco b on upper(trim(b.banco_nombre)) = upper(trim(a.nombre_banco))
join benchmark bm on bm.numero_id_hash = a.numero_id_hash
