-- =============================================================================
-- int_social
-- Fuentes: stg_f7__usuarios_redes, stg_f7__publicaciones,
--          stg_f7__reacciones, stg_f7__comentarios
-- Destino: CSILVER (table)
-- -----------------------------------------------------------------------------
-- QUE HACE
-- Un hecho de interaccion en redes, a nivel de fila de reaccion o comentario,
-- con la publicacion a la que pertenece y los indicadores de sentimiento.
--
-- GRAIN
-- una fila por reaccion, mas una fila por comentario. La clave es la union de
-- (tipo_interaccion, id_interaccion), porque un _id de reaccion y un _id de
-- comentario pueden coincidir y no deben mezclarse.
--
-- POR QUE SE UNEN LAS DOS TABLAS
-- -----------------------------
-- Reacciones y comentarios son el mismo hecho desde dos puntos de vista: una
-- persona que interactua con una publicacion. Se unen para que el tablero
-- pueda medir la interaccion completa de una persona, no solo lo que le gusto
-- o solo lo que escribio.
--
-- LA LLAVE DE UNION
-- -----------------
-- Las reacciones y los comentarios se enganchan a las publicaciones por:
--
--     reacciones.post_id  =  publicaciones.post_id_red
--     comentarios.post_id =  publicaciones.post_id_red
--
-- OJO, no es post_id contra post_id. La publicacion tiene DOS identificadores:
-- _id (el de Mongo, que no se usa como llave de negocio) y post_id_red (el de
-- la plataforma). Las otras dos tablas traen post_id, que corresponde a
-- post_id_red. Unir por _id daria 0 filas. Se verificó que este cruce
-- empareja el 100% de las reacciones y de los comentarios.
--
-- EL SENTIMIENTO
-- --------------
-- El sentimiento viene del comentario, no de la publicacion. Por eso una
-- reaccion no tiene sentimiento: es un "me gusta" sin texto. Se deja en null
-- en lugar de poner 0, porque 0 seria "neutral" y no es lo mismo que "no
-- medido". Promediar sin distinguir esos dos casos baja el sentimiento real.
--
-- ESTADO DE LA RED
-- ----------------
-- F7 no se une con el nucleo de clientes: no hay llave que conecte un usuario
-- de red social con un cliente_id. Por eso este modelo es autonomo y NO se
-- une con int_prestamos ni con int_riesgo_cliente. Un tablero que quiera
-- decir "este cliente tuvo esta conversacion" necesita un cruce adicional que
-- hoy no existe en los datos.
-- =============================================================================

with usuario as (

    select * from {{ ref('stg_f7__usuarios_redes') }}

),

publicacion as (

    select * from {{ ref('stg_f7__publicaciones') }}

),

reaccion as (

    select * from {{ ref('stg_f7__reacciones') }}

),

comentario as (

    select * from {{ ref('stg_f7__comentarios') }}

),

-- las reacciones, con la publicacion y el usuario
reacciones_enriquecidas as (

    select
        'reaccion'                                as tipo_interaccion,
        r._id                                     as id_interaccion,
        r.post_id                                 as post_id,
        r.plataforma                              as plataforma,
        r.usuario_id_red                          as usuario_id_red,
        {{ limpiar_texto('r.nombre_usuario') }}  as nombre_usuario,
        r.fecha_reaccion                          as fecha_interaccion,
        {{ limpiar_texto('r.tipo_reaccion') }}    as tipo_reaccion,

        -- una reaccion no tiene texto, asi que no tiene sentimiento medido
        cast(null as number)                      as sentimiento_score,
        cast(null as varchar)                     as sentimiento_etiqueta,
        cast(null as varchar)                     as texto_interaccion,

        -- datos de la publicacion
        pub.post_id_red                           as publicacion_id,
        pub.cuenta_propietaria                    as cuenta_propietaria,
        pub.fecha_publicacion                     as fecha_publicacion,
        {{ limpiar_texto('pub.descripcion') }}    as descripcion_publicacion,
        pub.total_reacciones                      as total_reacciones_post,
        pub.total_comentarios                     as total_comentarios_post,
        pub.total_compartidos                     as total_compartidos_post,

        -- una reaccion no responde a otra reaccion
        cast(null as varchar)                     as parent_comment_id,
        cast(null as number)                      as reacciones_comentario,

        -- ventana temporal
        {{ trimestre('r.fecha_reaccion') }}       as trimestre_interaccion,
        'F7'                                      as fuente
    from reaccion r
    left join publicacion pub
           on r.post_id = pub.post_id_red
    left join usuario usr
           on r.usuario_id_red = usr.usuario_id_red

),

-- los comentarios, con la publicacion y el usuario
comentarios_enriquecidos as (

    select
        'comentario'                              as tipo_interaccion,
        c._id                                     as id_interaccion,
        c.post_id                                 as post_id,
        c.plataforma                              as plataforma,
        c.usuario_id_red                          as usuario_id_red,
        {{ limpiar_texto('c.nombre_usuario') }}  as nombre_usuario,
        c.fecha_comentario                        as fecha_interaccion,
        cast(null as varchar)                     as tipo_reaccion,

        -- aqui si hay sentimiento medido
        c.sentimiento_score                       as sentimiento_score,
        {{ limpiar_codigo('c.sentimiento_etiqueta') }} as sentimiento_etiqueta,
        {{ limpiar_texto('c.texto_comentario') }} as texto_interaccion,

        -- datos de la publicacion
        pub.post_id_red                           as publicacion_id,
        pub.cuenta_propietaria                    as cuenta_propietaria,
        pub.fecha_publicacion                     as fecha_publicacion,
        {{ limpiar_texto('pub.descripcion') }}    as descripcion_publicacion,
        pub.total_reacciones                      as total_reacciones_post,
        pub.total_comentarios                     as total_comentarios_post,
        pub.total_compartidos                     as total_compartidos_post,

        -- el hilo: un comentario puede responder a otro
        c.parent_comment_id                       as parent_comment_id,
        c.reacciones_comentario                   as reacciones_comentario,

        -- ventana temporal
        {{ trimestre('c.fecha_comentario') }}     as trimestre_interaccion,
        'F7'                                      as fuente
    from comentario c
    left join publicacion pub
           on c.post_id = pub.post_id_red
    left join usuario usr
           on c.usuario_id_red = usr.usuario_id_red

),

-- la interaccion completa es la union de las dos
interacciones as (

    select * from reacciones_enriquecidas
    union all
    select * from comentarios_enriquecidos

)

select * from interacciones
