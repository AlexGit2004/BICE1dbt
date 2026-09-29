{#-
    fechas.sql
    Manejo de fechas y de la dimension tiempo.

    Snowflake es mas permisivo que otros motores: convierte 'texto' a DATE sin
    avisar, y una fecha invalida queda con un valor inventado en lugar de
    fallar. En un historico de pagos eso significa que un pago cae en un mes
    equivocado y el reporte de cobranza de ese mes no cuadra con el banco,
    sin ningun error visible. Por eso toda fecha se pasa por una conversion
    explicita y verificada.
-#}

{% macro fecha_segura(col) -%}
    try_to_date({{ col }})
{%- endmacro %}


{% macro fecha_ingreso(col) -%}
{#- Marca si la fecha estaba presente y era convertible. Permite distinguir
    'no tenemos el dato' de 'el dato es el dia 0', que en un hecho significa
    cosas muy distintas. -#}
    case when try_to_date({{ col }}) is null then false else true end
{%- endmacro %}


{% macro antiguedad_dias(fecha_col) -%}
    datediff('day', {{ fecha_col }}, '{{ var("fecha_corte") }}')
{%- endmacro %}


{% macro antiguedad_meses(fecha_col) -%}
    datediff('month', {{ fecha_col }}, '{{ var("fecha_corte") }}')
{%- endmacro %}


{% macro antiguedad_anios(fecha_col) -%}
    datediff('year', {{ fecha_col }}, '{{ var("fecha_corte") }}')
{%- endmacro %}


{% macro en_rango(fecha_col, desde, hasta) -%}
    case
        when {{ fecha_col }} is null                          then false
        when {{ fecha_col }} <  '{{ desde }}'                 then false
        when {{ fecha_col }} >  '{{ hasta }}'                 then false
        else true
    end
{%- endmacro %}


{% macro clasificar_vencimiento(fecha_vencimiento) -%}
{#- Estado contractual de un prestamo derivado SOLO de su fecha de vencimiento
    y la fecha de corte. No consulta ninguna otra tabla: es una regla pura, y
    por eso puede calcularse en la vista de staging sin depender del orden de
    construccion.

    Ojo con el nombre del argumento: se llama fecha_vencimiento, no col. Un
    macro con {{ col }} sin parametro declarado se renderiza como cadena
    vacia y el SQL resultante queda invalido. -#}
    case
        when {{ fecha_vencimiento }} is null                then 'Sin fecha'
        when {{ fecha_vencimiento }} <  '{{ var("fecha_corte") }}'
                                                            then 'Vencido'
        when datediff('day', '{{ var("fecha_corte") }}',
                             {{ fecha_vencimiento }}) <= 30
                                                            then 'Por vencer'
        else                                                    'Vigente'
    end
{%- endmacro %}


{% macro trimestre(fecha_col) -%}
    'Q' || quarter({{ fecha_col }})
{%- endmacro %}


{% macro nombre_mes(fecha_col) -%}
    date_part('month', {{ fecha_col }})
{%- endmacro %}
