{{ config(materialized='table') }}

{#-
    int_prestamos_limpios.sql  (REESCRITO)
    QUE CAMBIA
      [1] fecha_vencimiento: la BD ahora la trae (NOT NULL). El dateadd() se
          queda SOLO como red de seguridad, porque si se dispara significa que
          la fuente no cumple su propio DDL y eso tiene que ser visible.
      [1] bucket_mora sale del macro nuevo de 5 segmentos, alineado con
          dias_atraso_umbral que usa la misma dimension de cliente.
      [1] se anade mora_es_vigente(), la MISMA regla que dim_cliente, para que
          "bucket Critica" y "tiene_atraso_vigente" no puedan desalinearse.
-#}

with p as (
    select * from {{ ref('stg_mysql__prestamo') }}
)

select
    p.prestamo_id,
    p.solicitud_id,
    p.cliente_id,
    p.agencia_id,
    p.fecha_originacion,
    p.estado_prestamo_tipo_id,

    coalesce(p.tasa_interes_aplicada, 0)               as tasa_interes_aplicada,
    coalesce(p.cuota_mensual_bs,
             round(p.monto_aprobado_bs
                   / nullif(p.plazo_aprobado_meses, 0), 2)) as cuota_mensual_bs,
    coalesce(p.saldo_actual_bs, 0)                     as saldo_actual_bs,
    coalesce(p.dias_atraso, 0)                         as dias_atraso,

    -- [1] la fuente trae la fecha; el dateadd es solo el fallback
    coalesce(p.fecha_vencimiento,
             dateadd(month, p.plazo_aprobado_meses, p.fecha_originacion))
                                                          as fecha_vencimiento,
    -- flag de calidad: si es true, la fuente no cumplio el DDL (ver P-01)
    p.fecha_vencimiento is null                         as vencimiento_calculado,

    -- [1] 5 segmentos, mismo umbral que la dimension de cliente
    {{ bucket_mora('p.dias_atraso') }}                  as bucket_mora,
    -- misma regla, para que no se puedan desalinear
    {{ mora_es_vigente('p.dias_atraso') }}              as mora_vigente,

    -- atributos de la solicitud, que el prestamo hereda por su 1:1
    s.producto_id,
    s.estado_solicitud,
    s.monto_solicitado_bs,
    s.plazo_solicitado_meses,
    s.tipo_rechazo_id
from p
left join {{ ref('stg_mysql__solicitud_credito') }} s
       on s.solicitud_id = p.solicitud_id
