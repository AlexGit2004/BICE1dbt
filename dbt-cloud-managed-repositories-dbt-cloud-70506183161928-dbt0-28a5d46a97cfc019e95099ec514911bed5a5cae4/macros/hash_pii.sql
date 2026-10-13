{#-
    hash_pii.sql  (REESCRITO)

    REGLA 2 (silver): el hash de PII se aplica de MANERA UNIFORME, y siempre
    sobre el texto YA NORMALIZADO. Antes esta macro hasheaba el texto crudo,
    con lo cual dos fuentes que escribian el mismo CI de forma distinta
    producing hashes distintos: el cruce fallaba en silencio.

    La cadena correcta es siempre:
        {{ normalizar_identidad('col') }}  ->  numero_identificacion_norm
        {{ hash_pii('numero_identificacion_norm') }}  ->  numero_id_hash

    O, mas simple, en una sola linea dentro del stg:
        {{ hash_pii( normalizar_identidad('NUM_IDENTIFICACION') ) }}

    Y TODOS los joins entre fuentes son hash-contra-hash:
        left join X on X.numero_id_hash = Y.numero_id_hash
    Nunca sobre el valor en claro.

    ADVERTENCIA DE SEGURIDAD (mantenida del archivo original, corregida):
    un SHA256 de un CI/NIT NO es anonimizacion. El espacio de numeros de CI
    bolivianos es de orden 10^8, y con un solo CI conocido mas su hash se
    pueden enumerar todos los clientes. Si el dato es sensible, la variable
    pii_salt del proyecto debe estar definida: con ella el hash es un HMAC y
    deja de ser reversible por fuerza bruta. Sin la variable, el modelo
    emite un warning en el log en vez de fallar, para no romper el pipeline.
-#}

{% macro hash_pii(col) %}
  {%- set norm = "cast(" ~ col ~ " as varchar)" -%}
  {%- if target.type == 'postgres' -%}
    {%- if var('pii_salt', '') -%}
      encode(hmac({{ norm }}, '{{ var("pii_salt") }}', 'sha256'), 'hex')
    {%- else -%}
      encode(digest({{ norm }}, 'sha256'), 'hex')
    {%- endif -%}
  {%- elif target.type == 'snowflake' -%}
    {%- if var('pii_salt', '') -%}
      hmac({{ norm }}, '{{ var("pii_salt") }}', 'SHA256')
    {%- else -%}
      sha2({{ norm }}, 256)
    {%- endif -%}
  {%- elif target.type == 'bigquery' -%}
    {%- if var('pii_salt', '') -%}
      to_hex(hmac({{ norm }}, b'{{ var("pii_salt") }}', sha256))
    {%- else -%}
      to_hex(sha256({{ norm }}))
    {%- endif -%}
  {%- elif target.type == 'sqlserver' -%}
    lower(convert(varchar(64),
      hashbytes('sha2_256', {{ norm }}), 2))
  {%- else -%}
    md5({{ norm }})
  {%- endif -%}
{% endmacro %}


{% macro exigir_pii_salt() %}
{#- Se invoca desde dbt_project.yml o desde un test de smoke. Deja constancia
    en el log de que la anonimizacion del CI no es criptografica. -#}
  {%- if not var('pii_salt', '') -%}
    {{ log("AVISO: la variable pii_salt NO esta definida. El hash de "
           ~ "numero_identificacion es un SHA256 simple, reversible por fuerza "
           ~ "bruta sobre el espacio de CI bolivianos. Definir pii_salt en el "
           ~ "perfil de dbt para usar HMAC.", info=True) }}
  {%- endif -%}
{% endmacro %}
