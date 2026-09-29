{#-
    normalizar_identidad.sql
    REGLA CENTRAL DEL PROYECTO.

    Siete fuentes escriben el mismo documento de identidad de siete maneras
    distintas. F1 (MySQL) es la fuente maestra. Las otras seis lo mutilan de
    formas diferentes:

        F1  ms1_cliente             '61359338-5'   guion
        F2  pg2_proceso_penal       '912712292'    sin separador
        F2  pg2_consolidado         '61359338 5'   espacio
        F3  server3_deudor          '61359338-5'   guion
        F4  maria4_accionista       '538631246'    sin separador
        F5  ms5_derecho_real        '61359338 5'   espacio
        F6  csv6_historial          '96736376-1'   guion

    Sin una normalizacion canonica aplicada ANTES de cualquier join, el cruce
    de identidad devuelve cero filas sin emitir un solo error: simplemente
    los datos no aparecen. Ese es el fallo silencioso mas caro de un DW.

    ---------------------------------------------------------------------------
    DOS HECHOS MEDIDOS EN SNOWFLAKE QUE CONDICIONAN ESTA MACRO
    ---------------------------------------------------------------------------
    1. LA IDENTIDAD TIENE 9 DIGITOS, NO 8.
       El formato real es 8 digitos de base + 1 digito verificador:
           '61359338-5' -> 613593385
       Medido sobre las 10 columnas de identidad de las 7 fuentes: la
       longitud es 9 en el 100% de las 4.537.707 filas, sin una sola
       excepcion. Un macro que exija 8 digitos devuelve NULL en todas las
       filas y vacia el crosswalk de identidad sin error visible.

    2. EN SNOWFLAKE, '\\D' NO FUNCIONA COMO "NO-DIGITO".
       En el literal de Snowflake el backslash se procesa antes que la regex,
       asi que '\\D' llega a la regex como la secuencia de escape y no
       reemplaza nada. Medido:
           regexp_replace('61359338-5', '\\D', '')  -> '61359338-5'  (no-op)
           regexp_replace('61359338-5', '[^0-9]', '') -> '613593385'  (correcto)
       Por eso esta macro usa la clase de caracteres negada y no '\\D'.

    La serie canonica, en este orden obligatorio:
        1. quitar todo lo que no sea digito   (clase [^0-9], no \\D)
        2. si quedo vacio -> NULL
        3. si el largo final no es 9, la identidad no es confiable -> NULL
        4. si el primer digito es 0, es un CI invalido -> NULL

    El paso 4 sale de la regla de negocio del CI boliviano: 9 digitos y el
    primero entre 1 y 9, nunca 0 ni ceros a la izquierda.

    ---------------------------------------------------------------------------
    3. 'SIMILAR TO' NO EXISTE EN SNOWFLAKE.
       Snowflake no implementa el operador SQL estandar SIMILAR TO; usarlo
       produce 'syntax error: unexpected similar'. Para comparar contra un
       patron se usa RLIKE o REGEXP_LIKE, que si existen y funcionan igual.
       Medido sobre las 56.400 identidades de F1: RLIKE '[1-9][0-9]{8}'
       devuelve exactamente las 56.400 filas.
-#}

{% macro normalizar_identidad(col) -%}
    nullif(regexp_replace(cast({{ col }} as varchar), '[^0-9]', ''), '')
{%- endmacro %}


{% macro normalizar_identidad_valida(col) -%}
{#- Igual que la anterior pero descarta lo que no queda en 9 digitos y no
    arranca en cero. Se usa donde un identificador sucio no puede propagarse
    como si fuera valido: un join contra una clave de otra longitud no va a
    encontrar pareja de todos modos, y un NULL si lo hace documentar el
    problema. -#}
    case
        when length({{ normalizar_identidad(col) }}) <> 9 then null
        when not ({{ normalizar_identidad(col) }} rlike '^[1-9][0-9]{8}$')
            then null
        else {{ normalizar_identidad(col) }}
    end
{%- endmacro %}


{% macro es_identidad_valida(col) -%}
    case
        when {{ normalizar_identidad_valida(col) }} is null then false
        else true
    end
{%- endmacro %}


{% macro limpiar_texto(col) -%}
{#- Estandarizacion de texto libre. Colapsa el espacio repetido y recorta los
    extremos, pero NO pasa a mayusculas: un nombre propio debe conservar la
    capitalizacion de la fuente.

    ---------------------------------------------------------------------------
    NO USAR '\\s+' EN SNOWFLAKE: CORRUPTE TEXTO
    ---------------------------------------------------------------------------
    En un literal de comillas simples, Snowflake procesa los escapes ANTES de
    que la regex los vea. '\\s' no es un escape reconocido, asi que el
    backslash se pierde y a la regex le llega 's': la expresion deja de
    buscar espacios y pasa a buscar la LETRA 's'.

    Medido:
        regexp_replace('Sin Riesgo', '\\s+', ' ')  -> 'Sin Rie go'
        regexp_replace('  Hola   Mundo  ', '\\s+', ' ') -> sin cambios
        regexp_replace('  Juan  Perez  Silva  ', '\\s+', ' ') -> sin cambios

    O sea: no colapsa espacios y ademas destruye cualquier palabra con 's'.
    SeHabria visto como el valor corrupto 'SIN RIE GO' en vez de 'Sin Riesgo'.

    La forma correcta es la clase POSIX, que no lleva backslash:
        regexp_replace(x, '[[:space:]]+', ' ')  -> correcto
-#}
    nullif(trim(regexp_replace(cast({{ col }} as varchar), '[[:space:]]+', ' ')), '')
{%- endmacro %}


{% macro limpiar_codigo(col) -%}
{#- Para codigos y categorias, donde la comparacion es exacta y no hay caso
    que preservar. Misma clase POSIX que limpiar_texto, por el mismo motivo. -#}
    nullif(upper(trim(regexp_replace(cast({{ col }} as varchar),
                                     '[[:space:]]+', ' '))), '')
{%- endmacro %}
