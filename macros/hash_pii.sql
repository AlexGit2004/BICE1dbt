{% macro hash_pii(col) %}
  {%- if target.type == 'postgres' -%}
    encode(digest(cast({{ col }} as varchar), 'sha256'), 'hex')
  {%- elif target.type == 'snowflake' -%}
    sha2(cast({{ col }} as varchar), 256)
  {%- elif target.type == 'bigquery' -%}
    to_hex(sha256(cast({{ col }} as string)))
  {%- elif target.type == 'sqlserver' -%}
    lower(convert(varchar(64),
      hashbytes('sha2_256', cast({{ col }} as varchar(50))), 2))
  {%- else -%}
    md5(cast({{ col }} as varchar))
  {%- endif -%}
{% endmacro %}