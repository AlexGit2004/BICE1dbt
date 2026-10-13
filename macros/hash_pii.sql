{#-
    hash_pii.sql
    Enmascaramiento de datos personales.

    Que SHA256 SOLO no alcanza, y por que el salt es obligatorio:
    un CI de persona natural en Bolivia es un numero de 9 digitos, o sea del
    orden de 10^9 combinaciones. Un atacante con la tabla de hashes prueba esas
    mil millones en horas en una GPU y recupera el CI de cada fila. El hash
    solo, sin secreto, es reversible por fuerza bruta: es ofuscacion, no
    seguridad.

    Por eso la sal se lee de una variable de entorno y NUNCA se declara en
    dbt_project.yml, para que no quede versionada en el repositorio.

    Definir antes de compilar:
        export DBT_PII_SALT='<valor secreto>'
    En Windows PowerShell:
        $env:DBT_PII_SALT='<valor secreto>'

    Si no esta definida, el macro NO falla: devuelve SHA256 simple y emite un
    warning. Se elige fallar en silencio sobre fallar ruidosamente solo cuando
    el usuario decide que quiere ese comportamiento, porque en un ejercicio
    academico el build debe correr. El warning queda en target/ y es visible.
-#}

{% macro hash_pii(col) -%}
    {%- if env_var('DBT_PII_SALT', '') -%}
        sha2({{ normalizar_identidad(col) }} || '{{ env_var("DBT_PII_SALT") }}', 256)
    {%- else -%}
        {{ log("AVISO: DBT_PII_SALT no esta definida. El hash de PII sera "
               + "SHA256 simple, reversible por fuerza bruta sobre un espacio "
               + "de 10^8 CI. Definir la variable antes de usar en produccion.",
               info=True) }}
        sha2({{ normalizar_identidad(col) }}, 256)
    {%- endif -%}
{%- endmacro %}


{% macro enmascarar_texto(col, visibles=2) -%}
{#- Enmascara un nombre conservando el inicio de cada palabra, para poder
    reconocer a la persona en una atencion sin exponerla.
    'Juan Carlos Perez' -> 'JU**** CA**** PE****'.

    NO usa '\\w' ni '\\s' (ver la nota de escapes en normalizar_identidad.sql):
    en Snowflake esos escapes se pierden dentro del literal y la regex acaba
    buscando la letra 's' o la 'w'. Se usan clases de caracteres POSIX y
    '[^ ]' en su lugar, que no dependen de backslashes.
-#}
    case
      when {{ col }} is null then null
      else
        -- parte el nombre limpio por espacios y enmascara cada palabra
        array_to_string(
          array_transform(
            split(trim(regexp_replace(cast({{ col }} as varchar),
                                      '[[:space:]]+', ' ')), ' '),
            w -> case
                   when length(w) <= {{ visibles }}
                       then repeat('*', length(w))
                   else concat(substr(w, 1, {{ visibles }}),
                               repeat('*', length(w) - {{ visibles }}))
                 end
          ),
          ' '
        )
    end
{%- endmacro %}
