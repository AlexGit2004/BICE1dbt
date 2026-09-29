{#-
    int_identidad_fuente.sql
    conformance de identidad: una fila por (identidad canonica, fuente).

    Este es el modelo que resuelve el problema central del proyecto. Las 6
    fuentes no maestras traen el CI de 7 maneras distintas; aca se apilan todas
    en una sola tabla con la identidad ya en 8 digitos canonicos, de modo que
    cualquier modelado posterior solo tiene que hacer join contra esta tabla.

    Grano: una fila por combinacion (identidad, fuente). Un mismo CI puede
    aparecer en hasta 7 filas si las 7 fuentes lo confirman.

    Por que se hace con UNION ALL y no con 7 selects unidos por join: porque un
    join entre fuentes de identidad cruzaria todas las combinaciones
    (56.400 x 46.248 = 2.6 mil millones de filas) para terminar
    descartandolas. Apilar es la operacion correcta y es la barato.
-#}

{{ config(materialized='table') }}

-- F1 es la fuente maestra: define el padron de identidad del proyecto.
select
    'F1'                                    as fuente,
    numero_identificacion                   as ci_canonico,
    'numero_identificacion'                 as columna_origen,
    cast(cliente_id as varchar)                              as id_nativo,
    count(*)                                as filas_fuente
from {{ ref('stg_f1__cliente') }}
where numero_identificacion is not null
group by 1, 2, 3, 4

union all

-- F2: PostgreSQL, antecedentes penales. 21.200 procesos y 46.248 consolidados.
select
    'F2'                                    as fuente,
    numero_identificacion                   as ci_canonico,
    'numero_identificacion'                 as columna_origen,
    cast(proceso_id as varchar)                     as id_nativo,
    count(*)                                as filas_fuente
from {{ ref('stg_f2__proceso_penal') }}
where numero_identificacion is not null
group by 1, 2, 3, 4

union all

select
    'F2'                                    as fuente,
    numero_identificacion                   as ci_canonico,
    'numero_identificacion'                 as columna_origen,
    cast(antecedente_id as varchar)                 as id_nativo,
    count(*)                                as filas_fuente
from {{ ref('stg_f2__consolidado_antecedentes') }}
where numero_identificacion is not null
group by 1, 2, 3, 4

union all

-- F3: central de riesgos. El CI llega punteado ('1.234.567-8').
select
    'F3'                                    as fuente,
    numero_identificacion                   as ci_canonico,
    'numero_identificacion'                 as columna_origen,
    cast(deudor_id as varchar)                      as id_nativo,
    count(*)                                as filas_fuente
from {{ ref('stg_f3__deudor_central_riesgos') }}
where numero_identificacion is not null
group by 1, 2, 3, 4

union all

-- F4: registro mercantil. OJO: la identidad aca es el NIT de la EMPRESA, no
-- el CI de una persona. Por eso no se mezcla en el mismo conteo de personas:
-- una juridica se une a dim_cliente por nit_empresa, no por CI.
select
    'F4_empresa'                            as fuente,
    nit_empresa                             as ci_canonico,
    'nit_empresa'                           as columna_origen,
    cast(empresa_id as varchar)                     as id_nativo,
    count(*)                                as filas_fuente
from {{ ref('stg_f4__empresa_registro_mercantil') }}
where nit_empresa is not null
group by 1, 2, 3, 4

union all

-- F5: derechos reales. El titular de la inscripcion.
select
    'F5'                                    as fuente,
    numero_identificacion_titular           as ci_canonico,
    'numero_identificacion_titular'         as columna_origen,
    cast(inscripcion_id as varchar)                 as id_nativo,
    count(*)                                as filas_fuente
from {{ ref('stg_f5__derecho_real_inscripcion') }}
where numero_identificacion_titular is not null
group by 1, 2, 3, 4

union all

-- F6: historial financiero externo. Es la unica fuente con cobertura
-- parcial: 33.840 de 56.400 clientes = 60% exacto.
select
    'F6'                                    as fuente,
    numero_identificacion                   as ci_canonico,
    'numero_identificacion'                 as columna_origen,
    -- banco_acreedor NO es un numero: trae codigos alfanumericos como
    -- 'BMSC' y 'BNB'. Por eso va como texto, sin castear.
    cast(banco_acreedor as varchar)         as id_nativo,
    count(*)                                as filas_fuente
from {{ ref('stg_f6__historial_financiero_externo') }}
where numero_identificacion is not null
group by 1, 2, 3, 4

-- ---------------------------------------------------------------------------
-- F4_accionista NO ENTRA AQUI, y su ausencia es una decision medida.
--
-- maria4_accionista_representante_rm aporta 25.400 identificadores de 9
-- digitos bien formados, en el mismo rango que el maestro. Pero solo 1 de
-- 25.400 coincide con un CI de MS1_CLIENTE. Tampoco son los NIT de sus
-- propias empresas (0 de 25.400). Si se incluyera, este modelo reportaria
-- 25.400 identidades "confirmadas" que en realidad no se relacionan con
-- ningun cliente, y todos los hechos aguas abajo sumarian huerfanos como si
-- fueran clientes reales.
--
-- Se modela aparte en int_participantes_empresa, unido a las juridicas por
-- empresa_id, que si es clave verificable (25.400 participantes sobre 10.150
-- empresas, sin huerfanos). Ver la nota completa en macros/identidad.sql.
-- ---------------------------------------------------------------------------
