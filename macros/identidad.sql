{#-
    identidad.sql
    Conformance de identidad entre las 7 fuentes.

    El problema concreto que resuelve: 5 de las 7 fuentes se unen a F1 por
    numero de identificacion, pero cada una lo escribe distinto (ver
    normalizar_identidad.sql). La solucion NO es escribir la normalizacion
    5 veces, una por fuente, en cada join: es que se calcule UNA vez, en un
    modelo de conformance, y que todos los demas hechos joineen contra esa
    tabla ya normalizada.

    int_identidad_fuente guarda, por cada CI canonico, cuantas fuentes lo
    confirman. Una identidad vista en una sola fuente puede ser un error de
    tipeo; vista en dos o mas fuentes independientes es confirmada. Ese es el
    criterio de identidad_confirmada.

    ---------------------------------------------------------------------------
    MEDIDO EN SNOWFLAKE: cruce de cada fuente contra el maestro F1
    ---------------------------------------------------------------------------
        F2_consolidado   46.248/46.248  100.00%   cobertura  82.00%
        F2_proceso       21.200/21.200  100.00%   cobertura  37.59%
        F3_deudor        40.000/40.000  100.00%   cobertura  70.92%
        F5_titular       56.400/56.400  100.00%   cobertura 100.00%
        F6_externo       33.840/33.840  100.00%   cobertura  60.00%
        F4_accionista     1/25.400         0.00%   cobertura   0.00%

    ---------------------------------------------------------------------------
    HALLAZGO: F4_ACCIONISTA NO ES EL MISMO ESPACIO DE IDENTIDAD
    ---------------------------------------------------------------------------
    maria4_accionista_representante_rm trae 25.400 identificadores de 9
    digitos, todos bien formados, y el rango coincide con el del maestro
    (100.027.366 a 999.992.227 contra 100.000.815 a 999.996.578). La forma es
    correcta y el espacio de valores es el mismo.

    Y aun asi, solo 1 de los 25.400 coincide con el maestro F1. Tampoco son
    los NIT de las 10.150 empresas de F4, ni los NIT de las 10.152 juridicas
    de F1, ni el NIT de su propia empresa (0 de 25.400).

    Conclusion: la fuente no documenta con que documento identifica a sus
    personas, y ese documento NO es el CI del maestro del banco. Unir
    F4_accionista al maestro por numero de identificacion deja 1 fila de
    25.400: un 99.996% de perdida que el modelo reporta como dato valido,
    sin una sola fila de error.

    Decision de diseno: F4_accionista NO entra en el crosswalk de personas.
    Se carga como poblacion propia y se une a las juridicas por empresa_id,
    que si es clave real y verificada (25.400 participantes sobre 10.150
    empresas, sin huerfanos). El test assert_crosswalk_sin_perdidas deja
    constancia del 0% para que, si el proveedor alguna vez corrige la fuente,
    el test avise en vez de que el dato siga faltando en silencio.
-#}

{% macro contar_fuentes_confirmantes(ubicacion_col) -%}
    (select count(distinct fuente)
       from {{ ref('int_identidad_fuente') }}
      where ci_canonico = {{ ubicacion_col }})
{%- endmacro %}


{% macro identidad_confirmada(ci_col) -%}
{#- Una identidad se considera confirmada cuando aparece en al menos N fuentes
    independientes. Se materializa una vez por cliente para que el flag no se
    recalcule en cada hecho. -#}
    case
        when {{ contar_fuentes_confirmantes(ci_col) }}
             >= {{ var('identidad_fuentes_minimas') }}
            then true
        else false
    end
{%- endmacro %}


{% macro es_ci_valido(ci_col) -%}
    case
        when {{ ci_col }} is null                            then false
        when length({{ ci_col }}) <> 8                       then false
        when {{ ci_col }} not similar to '[1-9][0-9]{7}'      then false
        else true
    end
{%- endmacro %}


{% macro ci_valida_para_join(ci_col) -%}
{#- Predicado de seguridad para usar en un WHERE de join. Evita arrastrar
    identificadores imposibles que ensucian el resultado sin aportar nada. -#}
    {{ normalizar_identidad_valida(ci_col) }} is not null
{%- endmacro %}
