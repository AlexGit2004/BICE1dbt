-- =============================================================================
-- dim_inmueble
-- Fuente: int_derechos_reales
-- Destino: CGOLD (table)
-- -----------------------------------------------------------------------------
-- QUE HACE
-- Dimension de inmuebles: una fila por inmueble, con sus atributos fisicos y
-- registrales.
--
-- GRAIN
-- inmueble_id.
--
-- POR QUE DESDE int_derechos_reales
-- --------------------------------
-- int_derechos_reales trae los atributos del inmueble repetidos en cada
-- inscripcion (80.001 filas). La dimension los resume a una fila por
-- inmueble. Si se construyera desde staging habria que unir bien_inmueble con
-- derecho_real_inscripcion, y esa union ya esta hecha en el intermediario.
--
-- EL AVALUO
-- ---------
-- valor_avaluo_inmueble_bs es el valor que el registro le asigno al bien.
-- vigencia_avaluo_inmueble dice si ese avaluo sigue siendo utilizable (menos
-- de 3 anos). Un avaluo viejo no describe el mercado actual, por eso se
-- marca aparte en vez de descartarlo: el dato historico sigue siendo valido
-- para entender que se declaro en su momento.
--
-- LA MATRICULA
-- ------------
-- matricula_inmueble es el identificador registral del bien. Es la llave que
-- permite cruzar con el registro publico si en el futuro se carga.
-- =============================================================================

with inmuebles as (

    select
        inmueble_id,
        matricula_inmueble,
        tipo_inmueble,
        departamento_inmueble,
        zona_inmueble,
        superficie_m2,
        valor_comercial_bs,
        valor_avaluo_inmueble_bs,
        fecha_avaluo_inmueble,
        vigencia_avaluo_inmueble,
        estado_inmueble
    from {{ ref('int_derechos_reales') }}

)

select
    inmueble_id,
    matricula_inmueble,
    tipo_inmueble,
    departamento_inmueble,
    zona_inmueble,
    superficie_m2,
    valor_comercial_bs,
    valor_avaluo_inmueble_bs,
    fecha_avaluo_inmueble,
    vigencia_avaluo_inmueble,
    estado_inmueble,
    'F5'                                       as fuente
from inmuebles
group by
    inmueble_id,
    matricula_inmueble,
    tipo_inmueble,
    departamento_inmueble,
    zona_inmueble,
    superficie_m2,
    valor_comercial_bs,
    valor_avaluo_inmueble_bs,
    fecha_avaluo_inmueble,
    vigencia_avaluo_inmueble,
    estado_inmueble
