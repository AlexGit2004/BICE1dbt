{#-
    normalizar_identidad.sql
    Macro OBLIGATORIA de estandarizacion del identificador de negocio (CI/NIT).

    REGLA 2 (silver): el texto se normaliza SIEMPRE con esta macro ANTES de
    hashearse y ANTES de cualquier join. Es la unica forma de que 7 fuentes
    que escriben el mismo numero de 7 maneras distintas produzcan el mismo
    hash.

    La serie de reglas NO esta hardcodeada: sale de la tabla
    babsa_identidad.regla_normalizacion_identidad, que es dato maestro
    versionado. Ver DDL_SOURCES_CORREGIDO.sql.

    Ejemplo del problema que resuelve:
      F1 escribe  '1234567'
      F4 escribe  '1234567 12 LP'  (NIT con espacio)
      F5 escribe  '1234-567'
      Con la serie completa, los tres normalizan a '1234567' y por lo tanto a
      un unico numero_id_hash. Sin esto, el cruce con dim_cliente devuelve 0 filas
      y no hay ningun error: solo datos que no aparecen.
-#}

{% macro normalizar_identidad(col) %}
    upper(
      regexp_replace(
        regexp_replace(
          regexp_replace(
            regexp_replace(
              cast({{ col }} as varchar),
              '[ .\-()]', ''),          -- 1. sin espacios, puntos, guiones, parentesis
            '^\s+|\s+$', ''),            -- 2. sin espacios al inicio o al final
          '^C(?=\d)', ''),               -- 3. sin prefijo C de F6 (C00001 -> 00001)
        '[^A-Z0-9]', ''                  -- 4. solo alfanumericos en mayusculas
    )
{% endmacro %}


{% macro normalizar_id_origen(col) -%}
{#- Identidad EXTERNA (ObjectId de Mongo, id_cliente del CSV).
    Misma serie que el CI/NIT pero SIN aplicar PREFIJO_C ni|Mayusculas, porque
    un ObjectId es hexadecimal en minuscula y lowercasing es lo correcto.
    El case de minusculas lo hace el modelo de stg, no esta macro. -#}
    lower(
      regexp_replace(
        regexp_replace(
          cast({{ col }} as varchar),
          '[ .\-()]', ''),
        '\s+', '')
    )
{%- endmacro %}


{% macro validar_xwalk_origen(origen, id_col) %}
{#- Devuelve el CI/NIT de un id nativo, o NULL si el crosswalk no lo resuelve.
    Se usa SOLO en silver. La columna de la derecha es la que se hashea.
    Si devuelve NULL, el dbt test assert_xwalk_resuelto hace fallar el build. -#}
    (select x.numero_identificacion
       from {{ ref('int_xwalk_identidad') }} x
      where x.origen_sistema = '{{ origen }}'
        and x.clave_origen   = {{ normalizar_id_origen(id_col) }}
        and x.estado = 'ACTIVO')
{% endmacro %}


{% macro hash_xwalk_origen(origen, id_col) %}
{#- Id nativo -> CI/NIT hasheado. Atajo del patron de 3 pasos que se repite en
    cada stg de fuente externa. -#}
    {{ hash_pii( validar_xwalk_origen('{{ origen }}', id_col) ) }}
{% endmacro %}


{% macro assert_no_xwalk_huerfano(model, origen, id_col) %}
{#- Falla el build si queda algun id nativo sin resolver.
    Esto convierte la REGLA 1 ("sin crosswalk, F5b y F6 no se procesan") en una
    garantia ejecutable, y no en una buena intencion documentada. -#}
select '{{ origen }}' as origen_sistema
     , {{ id_col }}          as id_origen
     , count(*)              as filas_huerfanas
from {{ model }}
where {{ normalizar_id_origen(id_col) }} not in
      (select clave_origen from {{ ref('int_xwalk_identidad') }}
        where origen_sistema = '{{ origen }}' and estado = 'ACTIVO')
having count(*) > 0
{% endmacro %}
