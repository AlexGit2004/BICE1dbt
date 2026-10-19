-- =============================================================================
-- fact_social
-- Fuente: int_social
-- Destino: CGOLD (table)
-- -----------------------------------------------------------------------------
-- QUE HACE
-- Hecho de interacciones en redes sociales (comentarios y reacciones)
-- enriquecidas con datos de la publicacion y sentimiento.
--
-- GRAIN
-- tipo_interaccion + id_interaccion.
-- =============================================================================

select
    tipo_interaccion,
    id_interaccion,
    post_id,
    plataforma,
    usuario_id_red,
    nombre_usuario,
    fecha_interaccion,
    tipo_reaccion,
    sentimiento_score,
    sentimiento_etiqueta,
    texto_interaccion,
    publicacion_id,
    cuenta_propietaria,
    fecha_publicacion,
    descripcion_publicacion,
    total_reacciones_post,
    total_comentarios_post,
    total_compartidos_post,
    parent_comment_id,
    reacciones_comentario,
    trimestre_interaccion,
    fuente
from {{ ref('int_social') }}
