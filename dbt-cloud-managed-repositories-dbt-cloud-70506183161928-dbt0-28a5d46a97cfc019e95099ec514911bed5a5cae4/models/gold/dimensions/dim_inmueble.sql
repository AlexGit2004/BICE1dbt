{{ config(materialized='table', unique_key='inmueble_key') }}

{#-
    dim_inmueble.sql  (NUEVO)  *** REGLA 1, fuente F5 ***
    Cierra la garantia INMUEBLE que el catalogo tipo_garantia declaraba sin
    ningun respaldo documental.

    LA PK DE NEGOCIO ES matriCULA_INMUEBLE, no inmueble_id. inmueble_id es el
    autoincremental de babsa_derechos_reales y no sirve para cruzar con nada.
    Es exactamente el problema de cliente_id, resuelto al reves: aqui la clave
    natural manda.
-#}

select
    {{ dbt_utils.generate_surrogate_key(['b.inmueble_id']) }} as inmueble_key,
    b.inmueble_id,
    b.matricula_inmueble,                        -- PK de negocio
    b.tipo_inmueble,
    b.descripcion,
    b.direccion,
    b.zona,
    b.departamento,
    b.superficie_m2,
    b.valor_comercial_bs,
    b.valor_avaluo_bs,                            -- base legal de la cobertura
    b.fecha_avaluo,
    b.estado_inmueble,

    -- ===== AGREGADOS DERIVADOS DE LA FACT =====
    -- Se calculan aqui para que el BI no los tenga que recalcular, y para que
    -- "cuanto vale el respaldo de mi cartera immobiliaria" sea una fila y no
    -- un CROSSJOIN de 10.000 gravamenes.
    count(distinct g.gravamen_id)                             as gravamenes_inscritos,
    count(distinct case when g.estado_gravamen = 'Vigente'
                        then g.gravamen_id end)               as gravamenes_vigentes,
    count(distinct g.prestamo_id)                             as prestamos_garantizados,
    count(distinct g.cliente_numero_id_hash)                  as titulares,
    coalesce(sum(case when g.estado_gravamen = 'Vigente'
                      then g.monto_garantizado_bs else 0 end), 0) as monto_garantizado_vigente_bs,
    coalesce(max(case when g.estado_gravamen = 'Vigente'
                      then g.ltv_pct end), null)               as ltv_pct_maximo,

    -- antiguedad del avaluo: un avaluo de hace 5 anos no sirve para decidir
    -- cobertura hoy. Este es un dato de calidad que el BI debe ver.
    datediff('year', b.fecha_avaluo, current_date)            as antiguedad_avaluo_anios,
    case when datediff('year', b.fecha_avaluo, current_date) > 3
         then 'Avaluo desactualizado (>3 anios)'
         when datediff('year', b.fecha_avaluo, current_date) > 1
         then 'Avaluo con antiguedad mayor a 1 anio'
         else 'Aval vigente'
    end                                                      as vigencia_avaluo
from {{ ref('stg_mysql__bien_inmueble') }} b
left join {{ ref('int_derechos_reales_garantia') }} g
       on g.inmueble_id = b.inmueble_id
group by 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12
