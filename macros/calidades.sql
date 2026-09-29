{#-
    calidades.sql
    Helpers de calidad de datos reutilizables en los tests.

    Sirven para responder una sola pregunta con SQL: cuantas filas de este
    modelo violan la regla. Se usan desde los tests singulares.
-#}

{% macro contar_no_nulos(model, columna) -%}
    select
        count(*)                                            as filas_totales,
        count(*) - count({{ columna }})                     as filas_nulas
    from {{ model }}
    having count(*) - count({{ columna }}) > 0
{%- endmacro %}


{% macro contar_duplicados(model, columna) -%}
    select
        {{ columna }}   as clave,
        count(*)        as filas_duplicadas
    from {{ model }}
    group by 1
    having count(*) > 1
{%- endmacro %}


{% macro contar_valores_fuera_de_rango(model, columna, minimo, maximo) -%}
    select
        {{ columna }}   as valor,
        count(*)        as filas
    from {{ model }}
    where {{ columna }} is not null
      and ({{ columna }} < {{ minimo }} or {{ columna }} > {{ maximo }})
    group by 1
{%- endmacro %}


{% macro contar_sentinel(model, columna, valor=-1) -%}
{#- Detecta el centinela -1, que en estas fuentes significa "sin dato" y no
    un valor real. Si se filtra por WHERE monto > 0 sin quitarlo antes, ese
    prestamo cuenta como Exposure. -#}
    select
        '{{ columna }}'  as columna,
        count(*)        as filas_con_sentinel
    from {{ model }}
    where {{ columna }} = {{ valor }}
    having count(*) > 0
{%- endmacro %}


{% macro contar_nulos_semanticos(model, columna) -%}
{#- Columnas que usan cadena vacia como "sin dato" en vez de NULL. -#}
    select
        '{{ columna }}'  as columna,
        count(*)        as filas_vacias
    from {{ model }}
    where {{ columna }} is not null
      and trim({{ columna }}) = ''
    having count(*) > 0
{%- endmacro %}
