-- =============================================================================
-- stg_f4__empresa_registro_mercantil
-- Fuente: CBRONZE.MARIA4_EMPRESA_REGISTRO_MERCANTIL
-- Familia: F4 (MariaDB - registro mercantil)
-- Destino: CSILVER (view)
--
-- Staging NO decide nada de negocio. Su unico trabajo es:
--   1. traer la tabla tal cual,
--   2. tipar las fechas de forma explicita (try_to_date),
--   3. tipar los montos y los identificadores de forma explicita,
--   4. limpiar el texto con limpiar_texto / limpiar_codigo.
--
-- IMPORTANTE: el staging NO normaliza la identidad. La identidad canonica de
-- 9 digitos se resuelve mas abajo, en los int_ y en el macro
-- normalizar_identidad, porque la regla de negocio (y no el simple formateo)
-- es lo que debe quedar en una sola decision del proyecto.
-- =============================================================================

{{ config(materialized='view') }}

with tipado as (

    select
        cast(empresa_id as number(38,0)) as empresa_id,
        nit_empresa as nit_empresa_origen,
        cast(tipo_empresa_id as number(38,0)) as tipo_empresa_id,
        {{ limpiar_texto('razon_social') }} as razon_social,
        try_to_date(fecha_constitucion) as fecha_constitucion,
        cast(capital_pagado_bs as number(18,2)) as capital_pagado_bs,
        {{ limpiar_codigo('departamento_inscripcion') }} as departamento_inscripcion,
        {{ limpiar_codigo('estado_empresa') }} as estado_empresa
    from {{ source('bronze', 'maria4_empresa_registro_mercantil') }}

)

select
        cast(empresa_id as number(38,0)) as empresa_id,
        nit_empresa_origen as nit_empresa_origen,
        {{ normalizar_identidad_valida('nit_empresa_origen') }} as nit_empresa,
        cast(tipo_empresa_id as number(38,0)) as tipo_empresa_id,
        {{ limpiar_texto('razon_social') }} as razon_social,
        try_to_date(fecha_constitucion) as fecha_constitucion,
        cast(capital_pagado_bs as number(18,2)) as capital_pagado_bs,
        {{ limpiar_codigo('departamento_inscripcion') }} as departamento_inscripcion,
        {{ limpiar_codigo('estado_empresa') }} as estado_empresa
from tipado
