{{ config(materialized='table', unique_key='tipo_rechazo_key') }}

{#-
    dim_tipo_rechazo.sql  (NUEVO)
    REGLA 1 + REGLA 3: este catalogo existia desde el DDL original (15 motivos)
    y NINGUNA tabla lo referenciaba. Era el catalogo huerfano por excelencia:
    sin el, el analisis de "por que se rechaza un credito" es imposible, y es
    la pregunta que hace el area de riesgo todas las semanas.

    Con solicitud_credito.tipo_rechazo_id (FK) y fact_solicitudes.tipo_rechazo_key,
    el catalogo pasa a tener dimension propia y la fact pasa a tener su FK.
-#}

select
    {{ dbt_utils.generate_surrogate_key(['tr.tipo_rechazo_id']) }} as tipo_rechazo_key,
    tr.tipo_rechazo_id                                   as tipo_rechazo_id,
    tr.nombre_motivo,
    tr.categoria,
    tr.descripcion,
    -- dimensiones derivadas del catalogo, para no recalcular en el BI
    case
        when upper(tr.categoria) = 'RIESGO CREDITICIO' then 'Riesgo'
        when upper(tr.categoria) = 'CAPACIDAD PAGO'    then 'Capacidad de pago'
        when upper(tr.categoria) = 'DOCUMENTACION'     then 'Documentacion'
        when upper(tr.categoria) = 'FRAUDE'            then 'Fraude'
        when upper(tr.categoria) = 'POLITICA INTERNA'  then 'Politica interna'
        else                                                'Sin clasificar'
    end                                                  as familia_motivo,
    --.True si el motivo es atribuible al riesgo del solicitante (y por lo tanto
    -- el area de riesgo puede actuar), y False si es un motivo administrativo
    case when upper(tr.categoria) in ('RIESGO CREDITICIO','CAPACIDAD PAGO','FRAUDE')
         then true else false end                        as es_motivo_de_riesgo
from {{ ref('stg_mysql__tipo_rechazo') }} tr
