{{ config(materialized='table', unique_key='xwalk_key') }}

{#-
    dim_xwalk_identidad.sql  (NUEVO)
    REGLA 1: el crosswalk es un bien de datos, no un script.
    REGLA 2: muestra, en el propio DW, que TODAS las fuentes convergen.

    QUE HACE ESTA DIMENSION Y POR QUE NO ES OPCIONAL
    ---------------------------------------------------------------------------
    Sin ella, el cruce de F5b y F6 con el nucleo es un CASE invisible dentro de
    un .sql: nadie lo audita, nadie lo versiona y nadie sabe cuantos registros
    quedaron sin identificar. Con ella:

      1. La resolucion de identidades es una TABLA del DW, consultable desde
         Power BI. Se puede responder "de las 8.000 identidades, cuantas
         vienen de una sola fuente y no estan confirmadas".
      2. La REGLA 2 se vuelve auditable: cobertura_identidad y
         num_fuentes_distintas dicen, cliente por cliente, cuantas fuentes
         independientes lo respaldan.
      3. Es la dimension que hace que el crosswalk tenga al menos una
         relacion activa, como exige la regla de conectividad.

    Grano: 1 fila por CI/NIT. Es 1:1 con dim_cliente, y por eso se declara
    explicitamente en el bus matrix.
-#}

select
    x.xwalk_key,
    -- la misma clave natural que dim_cliente. Es la que hace posible el 1:1
    x.numero_id_hash,
    x.numero_identificacion,
    x.tipo_id,
    case x.tipo_id when 1 then 'Natural' when 2 then 'Juridica' else 'Desconocido' end
                                                        as tipo_persona,

    -- ===== LA TRAZA DE LA RESOLUCION =====
    x.metodo_match,
    x.confianza_ponderada,
    x.num_fuentes,
    x.num_fuentes_distintas,
    x.cobertura_identidad,
    x.identidad_confirmada,
    x.tipo_identidad,
    x.fecha_alta_minima,
    x.fecha_alta_maxima,

    -- ===== EL ID NATIVO DE CADA FUENTE, UNA COLUMNA POR FUENTE =====
    -- Esto es lo que hace que el problema sea depurable: si un cliente no
    -- entra, se ve en que columna falta su id.
    x.id_origen_f1,
    x.id_origen_f2,
    x.id_origen_f3,
    x.id_origen_f4,
    x.id_origen_f5,
    x.id_origen_f5b,
    x.id_origen_f6,

    -- banderas de presencia, para usarlas como filtro en el BI
    x.id_origen_f1  is not null as viene_de_f1,
    x.id_origen_f2  is not null as viene_de_f2,
    x.id_origen_f3  is not null as viene_de_f3,
    x.id_origen_f4  is not null as viene_de_f4,
    x.id_origen_f5  is not null as viene_de_f5,
    x.id_origen_f5b is not null as viene_de_f5b,
    x.id_origen_f6  is not null as viene_de_f6,

    -- ===== CALIDAD DE LA NORMALIZACION =====
    x.reglas_de_la_fuente,
    x.tiene_mayusculas,
    case when x.metodo_match = 'DIRECTO'    then 'Identificador nativo ya es el CI/NIT'
         when x.metodo_match = 'NORMALIZADO' then 'Se normalizo el texto antes de comparar'
         when x.metodo_match = 'APROXIMADO'  then 'Coincidencia aproximada, requiere revision'
         when x.metodo_match = 'MANUAL'      then 'Resuelto a mano por el comite de datos'
    end                                                    as descripcion_metodo
from {{ ref('int_xwalk_identidad') }} x
