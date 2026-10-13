{{ config(materialized='table', unique_key='tipo_derecho_real_key') }}

{#-
    dim_tipo_derecho_real.sql  (NUEVO)  *** F5 ***
    Catalogo del Codigo Civil: derechos reales y cargas sobre bienes inmuebles.

    CONVIVE CON dim_tipo_garantia, no lo reemplaza, y la diferencia es de
    concepto, no de redundancia:
      dim_tipo_garantia    -> el USO del bien como respaldo de un credito
                              (Prenda, Aval, Hipoteca, Giro, Usufructo)
      dim_tipo_derecho_real-> el DERECHO PATRIMONIAL sobre el bien, inscrito
                              en un registro publico (Compraventa, Donacion,
                              Hipoteca, Cesion, Usufructo, Servidumbre, Pledge)
    El primero es del banco. El segundo es del Estado. Se necesitan los dos, y
    la union de ambos es lo que permite distinguir una hipoteca INSCRITA de
    una mera declaracion de garantia.
-#}

select
    {{ dbt_utils.generate_surrogate_key(['t.tipo_derecho_real_id']) }} as tipo_derecho_real_key,
    t.tipo_derecho_real_id                                      as tipo_derecho_real_id,
    t.codigo,
    t.nombre_tipo,
    t.descripcion,
    t.es_garantia,
    t.es_transmision,
    t.requiere_valuacion,

    -- agrupacion para el BI
    case when t.es_transmision then 'Transmision de dominio'
         when t.es_garantia    then 'Carga / garantia'
         else                       'Goce'
    end                                                          as clase_derecho,
    -- un derecho real garantia y transferible a la vez no existe; la BD lo
    -- permite, asi que se marca para que datos lo detecte
    case when t.es_garantia and t.es_transmision
         then true else false end                                as definicion_inconsistente
from {{ ref('stg_mysql__tipo_derecho_real') }} t
