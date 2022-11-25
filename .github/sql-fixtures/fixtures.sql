PGDMP  	    ;    2                z            taiga    12.3 (Debian 12.3-1.pgdg100+1)    13.6 �   5           0    0    ENCODING    ENCODING        SET client_encoding = 'UTF8';
                      false            6           0    0 
   STDSTRINGS 
   STDSTRINGS     (   SET standard_conforming_strings = 'on';
                      false            7           0    0 
   SEARCHPATH 
   SEARCHPATH     8   SELECT pg_catalog.set_config('search_path', '', false);
                      false            8           1262    7501813    taiga    DATABASE     Y   CREATE DATABASE taiga WITH TEMPLATE = template0 ENCODING = 'UTF8' LOCALE = 'en_US.utf8';
    DROP DATABASE taiga;
                taiga    false                        3079    7501940    unaccent 	   EXTENSION     <   CREATE EXTENSION IF NOT EXISTS unaccent WITH SCHEMA public;
    DROP EXTENSION unaccent;
                   false            9           0    0    EXTENSION unaccent    COMMENT     P   COMMENT ON EXTENSION unaccent IS 'text search dictionary that removes accents';
                        false    2            j           1247    7502304    procrastinate_job_event_type    TYPE     �   CREATE TYPE public.procrastinate_job_event_type AS ENUM (
    'deferred',
    'started',
    'deferred_for_retry',
    'failed',
    'succeeded',
    'cancelled',
    'scheduled'
);
 /   DROP TYPE public.procrastinate_job_event_type;
       public          taiga    false            g           1247    7502294    procrastinate_job_status    TYPE     p   CREATE TYPE public.procrastinate_job_status AS ENUM (
    'todo',
    'doing',
    'succeeded',
    'failed'
);
 +   DROP TYPE public.procrastinate_job_status;
       public          taiga    false            W           1255    7502369 j   procrastinate_defer_job(character varying, character varying, text, text, jsonb, timestamp with time zone)    FUNCTION     �  CREATE FUNCTION public.procrastinate_defer_job(queue_name character varying, task_name character varying, lock text, queueing_lock text, args jsonb, scheduled_at timestamp with time zone) RETURNS bigint
    LANGUAGE plpgsql
    AS $$
DECLARE
	job_id bigint;
BEGIN
    INSERT INTO procrastinate_jobs (queue_name, task_name, lock, queueing_lock, args, scheduled_at)
    VALUES (queue_name, task_name, lock, queueing_lock, args, scheduled_at)
    RETURNING id INTO job_id;

    RETURN job_id;
END;
$$;
 �   DROP FUNCTION public.procrastinate_defer_job(queue_name character varying, task_name character varying, lock text, queueing_lock text, args jsonb, scheduled_at timestamp with time zone);
       public          taiga    false            o           1255    7502386 t   procrastinate_defer_periodic_job(character varying, character varying, character varying, character varying, bigint)    FUNCTION     �  CREATE FUNCTION public.procrastinate_defer_periodic_job(_queue_name character varying, _lock character varying, _queueing_lock character varying, _task_name character varying, _defer_timestamp bigint) RETURNS bigint
    LANGUAGE plpgsql
    AS $$
DECLARE
	_job_id bigint;
	_defer_id bigint;
BEGIN

    INSERT
        INTO procrastinate_periodic_defers (task_name, queue_name, defer_timestamp)
        VALUES (_task_name, _queue_name, _defer_timestamp)
        ON CONFLICT DO NOTHING
        RETURNING id into _defer_id;

    IF _defer_id IS NULL THEN
        RETURN NULL;
    END IF;

    UPDATE procrastinate_periodic_defers
        SET job_id = procrastinate_defer_job(
                _queue_name,
                _task_name,
                _lock,
                _queueing_lock,
                ('{"timestamp": ' || _defer_timestamp || '}')::jsonb,
                NULL
            )
        WHERE id = _defer_id
        RETURNING job_id INTO _job_id;

    DELETE
        FROM procrastinate_periodic_defers
        USING (
            SELECT id
            FROM procrastinate_periodic_defers
            WHERE procrastinate_periodic_defers.task_name = _task_name
            AND procrastinate_periodic_defers.queue_name = _queue_name
            AND procrastinate_periodic_defers.defer_timestamp < _defer_timestamp
            ORDER BY id
            FOR UPDATE
        ) to_delete
        WHERE procrastinate_periodic_defers.id = to_delete.id;

    RETURN _job_id;
END;
$$;
 �   DROP FUNCTION public.procrastinate_defer_periodic_job(_queue_name character varying, _lock character varying, _queueing_lock character varying, _task_name character varying, _defer_timestamp bigint);
       public          taiga    false            X           1255    7502370 �   procrastinate_defer_periodic_job(character varying, character varying, character varying, character varying, character varying, bigint, jsonb)    FUNCTION     �  CREATE FUNCTION public.procrastinate_defer_periodic_job(_queue_name character varying, _lock character varying, _queueing_lock character varying, _task_name character varying, _periodic_id character varying, _defer_timestamp bigint, _args jsonb) RETURNS bigint
    LANGUAGE plpgsql
    AS $$
DECLARE
	_job_id bigint;
	_defer_id bigint;
BEGIN

    INSERT
        INTO procrastinate_periodic_defers (task_name, periodic_id, defer_timestamp)
        VALUES (_task_name, _periodic_id, _defer_timestamp)
        ON CONFLICT DO NOTHING
        RETURNING id into _defer_id;

    IF _defer_id IS NULL THEN
        RETURN NULL;
    END IF;

    UPDATE procrastinate_periodic_defers
        SET job_id = procrastinate_defer_job(
                _queue_name,
                _task_name,
                _lock,
                _queueing_lock,
                _args,
                NULL
            )
        WHERE id = _defer_id
        RETURNING job_id INTO _job_id;

    DELETE
        FROM procrastinate_periodic_defers
        USING (
            SELECT id
            FROM procrastinate_periodic_defers
            WHERE procrastinate_periodic_defers.task_name = _task_name
            AND procrastinate_periodic_defers.periodic_id = _periodic_id
            AND procrastinate_periodic_defers.defer_timestamp < _defer_timestamp
            ORDER BY id
            FOR UPDATE
        ) to_delete
        WHERE procrastinate_periodic_defers.id = to_delete.id;

    RETURN _job_id;
END;
$$;
 �   DROP FUNCTION public.procrastinate_defer_periodic_job(_queue_name character varying, _lock character varying, _queueing_lock character varying, _task_name character varying, _periodic_id character varying, _defer_timestamp bigint, _args jsonb);
       public          taiga    false            �            1259    7502321    procrastinate_jobs    TABLE     �  CREATE TABLE public.procrastinate_jobs (
    id bigint NOT NULL,
    queue_name character varying(128) NOT NULL,
    task_name character varying(128) NOT NULL,
    lock text,
    queueing_lock text,
    args jsonb DEFAULT '{}'::jsonb NOT NULL,
    status public.procrastinate_job_status DEFAULT 'todo'::public.procrastinate_job_status NOT NULL,
    scheduled_at timestamp with time zone,
    attempts integer DEFAULT 0 NOT NULL
);
 &   DROP TABLE public.procrastinate_jobs;
       public         heap    taiga    false    871    871            Y           1255    7502371 ,   procrastinate_fetch_job(character varying[])    FUNCTION     	  CREATE FUNCTION public.procrastinate_fetch_job(target_queue_names character varying[]) RETURNS public.procrastinate_jobs
    LANGUAGE plpgsql
    AS $$
DECLARE
	found_jobs procrastinate_jobs;
BEGIN
    WITH candidate AS (
        SELECT jobs.*
            FROM procrastinate_jobs AS jobs
            WHERE
                -- reject the job if its lock has earlier jobs
                NOT EXISTS (
                    SELECT 1
                        FROM procrastinate_jobs AS earlier_jobs
                        WHERE
                            jobs.lock IS NOT NULL
                            AND earlier_jobs.lock = jobs.lock
                            AND earlier_jobs.status IN ('todo', 'doing')
                            AND earlier_jobs.id < jobs.id)
                AND jobs.status = 'todo'
                AND (target_queue_names IS NULL OR jobs.queue_name = ANY( target_queue_names ))
                AND (jobs.scheduled_at IS NULL OR jobs.scheduled_at <= now())
            ORDER BY jobs.id ASC LIMIT 1
            FOR UPDATE OF jobs SKIP LOCKED
    )
    UPDATE procrastinate_jobs
        SET status = 'doing'
        FROM candidate
        WHERE procrastinate_jobs.id = candidate.id
        RETURNING procrastinate_jobs.* INTO found_jobs;

	RETURN found_jobs;
END;
$$;
 V   DROP FUNCTION public.procrastinate_fetch_job(target_queue_names character varying[]);
       public          taiga    false    238            n           1255    7502385 B   procrastinate_finish_job(integer, public.procrastinate_job_status)    FUNCTION       CREATE FUNCTION public.procrastinate_finish_job(job_id integer, end_status public.procrastinate_job_status) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    UPDATE procrastinate_jobs
    SET status = end_status,
        attempts = attempts + 1
    WHERE id = job_id;
END;
$$;
 k   DROP FUNCTION public.procrastinate_finish_job(job_id integer, end_status public.procrastinate_job_status);
       public          taiga    false    871            m           1255    7502384 \   procrastinate_finish_job(integer, public.procrastinate_job_status, timestamp with time zone)    FUNCTION     �  CREATE FUNCTION public.procrastinate_finish_job(job_id integer, end_status public.procrastinate_job_status, next_scheduled_at timestamp with time zone) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    UPDATE procrastinate_jobs
    SET status = end_status,
        attempts = attempts + 1,
        scheduled_at = COALESCE(next_scheduled_at, scheduled_at)
    WHERE id = job_id;
END;
$$;
 �   DROP FUNCTION public.procrastinate_finish_job(job_id integer, end_status public.procrastinate_job_status, next_scheduled_at timestamp with time zone);
       public          taiga    false    871            Z           1255    7502372 e   procrastinate_finish_job(integer, public.procrastinate_job_status, timestamp with time zone, boolean)    FUNCTION       CREATE FUNCTION public.procrastinate_finish_job(job_id integer, end_status public.procrastinate_job_status, next_scheduled_at timestamp with time zone, delete_job boolean) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
    _job_id bigint;
BEGIN
    IF end_status NOT IN ('succeeded', 'failed') THEN
        RAISE 'End status should be either "succeeded" or "failed" (job id: %)', job_id;
    END IF;
    IF delete_job THEN
        DELETE FROM procrastinate_jobs
        WHERE id = job_id AND status IN ('todo', 'doing')
        RETURNING id INTO _job_id;
    ELSE
        UPDATE procrastinate_jobs
        SET status = end_status,
            attempts =
                CASE
                    WHEN status = 'doing' THEN attempts + 1
                    ELSE attempts
                END
        WHERE id = job_id AND status IN ('todo', 'doing')
        RETURNING id INTO _job_id;
    END IF;
    IF _job_id IS NULL THEN
        RAISE 'Job was not found or not in "doing" or "todo" status (job id: %)', job_id;
    END IF;
END;
$$;
 �   DROP FUNCTION public.procrastinate_finish_job(job_id integer, end_status public.procrastinate_job_status, next_scheduled_at timestamp with time zone, delete_job boolean);
       public          taiga    false    871            \           1255    7502374    procrastinate_notify_queue()    FUNCTION     
  CREATE FUNCTION public.procrastinate_notify_queue() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
	PERFORM pg_notify('procrastinate_queue#' || NEW.queue_name, NEW.task_name);
	PERFORM pg_notify('procrastinate_any_queue', NEW.task_name);
	RETURN NEW;
END;
$$;
 3   DROP FUNCTION public.procrastinate_notify_queue();
       public          taiga    false            [           1255    7502373 :   procrastinate_retry_job(integer, timestamp with time zone)    FUNCTION     �  CREATE FUNCTION public.procrastinate_retry_job(job_id integer, retry_at timestamp with time zone) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
    _job_id bigint;
BEGIN
    UPDATE procrastinate_jobs
    SET status = 'todo',
        attempts = attempts + 1,
        scheduled_at = retry_at
    WHERE id = job_id AND status = 'doing'
    RETURNING id INTO _job_id;
    IF _job_id IS NULL THEN
        RAISE 'Job was not found or not in "doing" status (job id: %)', job_id;
    END IF;
END;
$$;
 a   DROP FUNCTION public.procrastinate_retry_job(job_id integer, retry_at timestamp with time zone);
       public          taiga    false            k           1255    7502377 2   procrastinate_trigger_scheduled_events_procedure()    FUNCTION     #  CREATE FUNCTION public.procrastinate_trigger_scheduled_events_procedure() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO procrastinate_events(job_id, type, at)
        VALUES (NEW.id, 'scheduled'::procrastinate_job_event_type, NEW.scheduled_at);

	RETURN NEW;
END;
$$;
 I   DROP FUNCTION public.procrastinate_trigger_scheduled_events_procedure();
       public          taiga    false            i           1255    7502375 6   procrastinate_trigger_status_events_procedure_insert()    FUNCTION       CREATE FUNCTION public.procrastinate_trigger_status_events_procedure_insert() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO procrastinate_events(job_id, type)
        VALUES (NEW.id, 'deferred'::procrastinate_job_event_type);
	RETURN NEW;
END;
$$;
 M   DROP FUNCTION public.procrastinate_trigger_status_events_procedure_insert();
       public          taiga    false            j           1255    7502376 6   procrastinate_trigger_status_events_procedure_update()    FUNCTION     �  CREATE FUNCTION public.procrastinate_trigger_status_events_procedure_update() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    WITH t AS (
        SELECT CASE
            WHEN OLD.status = 'todo'::procrastinate_job_status
                AND NEW.status = 'doing'::procrastinate_job_status
                THEN 'started'::procrastinate_job_event_type
            WHEN OLD.status = 'doing'::procrastinate_job_status
                AND NEW.status = 'todo'::procrastinate_job_status
                THEN 'deferred_for_retry'::procrastinate_job_event_type
            WHEN OLD.status = 'doing'::procrastinate_job_status
                AND NEW.status = 'failed'::procrastinate_job_status
                THEN 'failed'::procrastinate_job_event_type
            WHEN OLD.status = 'doing'::procrastinate_job_status
                AND NEW.status = 'succeeded'::procrastinate_job_status
                THEN 'succeeded'::procrastinate_job_event_type
            WHEN OLD.status = 'todo'::procrastinate_job_status
                AND (
                    NEW.status = 'failed'::procrastinate_job_status
                    OR NEW.status = 'succeeded'::procrastinate_job_status
                )
                THEN 'cancelled'::procrastinate_job_event_type
            ELSE NULL
        END as event_type
    )
    INSERT INTO procrastinate_events(job_id, type)
        SELECT NEW.id, t.event_type
        FROM t
        WHERE t.event_type IS NOT NULL;
	RETURN NEW;
END;
$$;
 M   DROP FUNCTION public.procrastinate_trigger_status_events_procedure_update();
       public          taiga    false            l           1255    7502378 &   procrastinate_unlink_periodic_defers()    FUNCTION     �   CREATE FUNCTION public.procrastinate_unlink_periodic_defers() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    UPDATE procrastinate_periodic_defers
    SET job_id = NULL
    WHERE job_id = OLD.id;
    RETURN OLD;
END;
$$;
 =   DROP FUNCTION public.procrastinate_unlink_periodic_defers();
       public          taiga    false                       3602    7501947    simple_unaccent    TEXT SEARCH CONFIGURATION     �  CREATE TEXT SEARCH CONFIGURATION public.simple_unaccent (
    PARSER = pg_catalog."default" );

ALTER TEXT SEARCH CONFIGURATION public.simple_unaccent
    ADD MAPPING FOR asciiword WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_unaccent
    ADD MAPPING FOR word WITH public.unaccent, simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_unaccent
    ADD MAPPING FOR numword WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_unaccent
    ADD MAPPING FOR email WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_unaccent
    ADD MAPPING FOR url WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_unaccent
    ADD MAPPING FOR host WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_unaccent
    ADD MAPPING FOR sfloat WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_unaccent
    ADD MAPPING FOR version WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_unaccent
    ADD MAPPING FOR hword_numpart WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_unaccent
    ADD MAPPING FOR hword_part WITH public.unaccent, simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_unaccent
    ADD MAPPING FOR hword_asciipart WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_unaccent
    ADD MAPPING FOR numhword WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_unaccent
    ADD MAPPING FOR asciihword WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_unaccent
    ADD MAPPING FOR hword WITH public.unaccent, simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_unaccent
    ADD MAPPING FOR url_path WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_unaccent
    ADD MAPPING FOR file WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_unaccent
    ADD MAPPING FOR "float" WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_unaccent
    ADD MAPPING FOR "int" WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_unaccent
    ADD MAPPING FOR uint WITH simple;
 7   DROP TEXT SEARCH CONFIGURATION public.simple_unaccent;
       public          taiga    false    2    2    2    2            �            1259    7501900 
   auth_group    TABLE     f   CREATE TABLE public.auth_group (
    id integer NOT NULL,
    name character varying(150) NOT NULL
);
    DROP TABLE public.auth_group;
       public         heap    taiga    false            �            1259    7501898    auth_group_id_seq    SEQUENCE     �   ALTER TABLE public.auth_group ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.auth_group_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public          taiga    false    214            �            1259    7501909    auth_group_permissions    TABLE     �   CREATE TABLE public.auth_group_permissions (
    id bigint NOT NULL,
    group_id integer NOT NULL,
    permission_id integer NOT NULL
);
 *   DROP TABLE public.auth_group_permissions;
       public         heap    taiga    false            �            1259    7501907    auth_group_permissions_id_seq    SEQUENCE     �   ALTER TABLE public.auth_group_permissions ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.auth_group_permissions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public          taiga    false    216            �            1259    7501893    auth_permission    TABLE     �   CREATE TABLE public.auth_permission (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    content_type_id integer NOT NULL,
    codename character varying(100) NOT NULL
);
 #   DROP TABLE public.auth_permission;
       public         heap    taiga    false            �            1259    7501891    auth_permission_id_seq    SEQUENCE     �   ALTER TABLE public.auth_permission ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.auth_permission_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public          taiga    false    212            �            1259    7501870    django_admin_log    TABLE     �  CREATE TABLE public.django_admin_log (
    id integer NOT NULL,
    action_time timestamp with time zone NOT NULL,
    object_id text,
    object_repr character varying(200) NOT NULL,
    action_flag smallint NOT NULL,
    change_message text NOT NULL,
    content_type_id integer,
    user_id uuid NOT NULL,
    CONSTRAINT django_admin_log_action_flag_check CHECK ((action_flag >= 0))
);
 $   DROP TABLE public.django_admin_log;
       public         heap    taiga    false            �            1259    7501868    django_admin_log_id_seq    SEQUENCE     �   ALTER TABLE public.django_admin_log ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.django_admin_log_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public          taiga    false    210            �            1259    7501861    django_content_type    TABLE     �   CREATE TABLE public.django_content_type (
    id integer NOT NULL,
    app_label character varying(100) NOT NULL,
    model character varying(100) NOT NULL
);
 '   DROP TABLE public.django_content_type;
       public         heap    taiga    false            �            1259    7501859    django_content_type_id_seq    SEQUENCE     �   ALTER TABLE public.django_content_type ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.django_content_type_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public          taiga    false    208            �            1259    7501816    django_migrations    TABLE     �   CREATE TABLE public.django_migrations (
    id bigint NOT NULL,
    app character varying(255) NOT NULL,
    name character varying(255) NOT NULL,
    applied timestamp with time zone NOT NULL
);
 %   DROP TABLE public.django_migrations;
       public         heap    taiga    false            �            1259    7501814    django_migrations_id_seq    SEQUENCE     �   ALTER TABLE public.django_migrations ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.django_migrations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public          taiga    false    204            �            1259    7502127    django_session    TABLE     �   CREATE TABLE public.django_session (
    session_key character varying(40) NOT NULL,
    session_data text NOT NULL,
    expire_date timestamp with time zone NOT NULL
);
 "   DROP TABLE public.django_session;
       public         heap    taiga    false            �            1259    7501950    easy_thumbnails_source    TABLE     �   CREATE TABLE public.easy_thumbnails_source (
    id integer NOT NULL,
    storage_hash character varying(40) NOT NULL,
    name character varying(255) NOT NULL,
    modified timestamp with time zone NOT NULL
);
 *   DROP TABLE public.easy_thumbnails_source;
       public         heap    taiga    false            �            1259    7501948    easy_thumbnails_source_id_seq    SEQUENCE     �   ALTER TABLE public.easy_thumbnails_source ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.easy_thumbnails_source_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public          taiga    false    218            �            1259    7501957    easy_thumbnails_thumbnail    TABLE     �   CREATE TABLE public.easy_thumbnails_thumbnail (
    id integer NOT NULL,
    storage_hash character varying(40) NOT NULL,
    name character varying(255) NOT NULL,
    modified timestamp with time zone NOT NULL,
    source_id integer NOT NULL
);
 -   DROP TABLE public.easy_thumbnails_thumbnail;
       public         heap    taiga    false            �            1259    7501955     easy_thumbnails_thumbnail_id_seq    SEQUENCE     �   ALTER TABLE public.easy_thumbnails_thumbnail ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.easy_thumbnails_thumbnail_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public          taiga    false    220            �            1259    7501982 #   easy_thumbnails_thumbnaildimensions    TABLE     K  CREATE TABLE public.easy_thumbnails_thumbnaildimensions (
    id integer NOT NULL,
    thumbnail_id integer NOT NULL,
    width integer,
    height integer,
    CONSTRAINT easy_thumbnails_thumbnaildimensions_height_check CHECK ((height >= 0)),
    CONSTRAINT easy_thumbnails_thumbnaildimensions_width_check CHECK ((width >= 0))
);
 7   DROP TABLE public.easy_thumbnails_thumbnaildimensions;
       public         heap    taiga    false            �            1259    7501980 *   easy_thumbnails_thumbnaildimensions_id_seq    SEQUENCE       ALTER TABLE public.easy_thumbnails_thumbnaildimensions ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.easy_thumbnails_thumbnaildimensions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public          taiga    false    222            �            1259    7502351    procrastinate_events    TABLE     �   CREATE TABLE public.procrastinate_events (
    id bigint NOT NULL,
    job_id integer NOT NULL,
    type public.procrastinate_job_event_type,
    at timestamp with time zone DEFAULT now()
);
 (   DROP TABLE public.procrastinate_events;
       public         heap    taiga    false    874            �            1259    7502349    procrastinate_events_id_seq    SEQUENCE     �   CREATE SEQUENCE public.procrastinate_events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 2   DROP SEQUENCE public.procrastinate_events_id_seq;
       public          taiga    false    242            :           0    0    procrastinate_events_id_seq    SEQUENCE OWNED BY     [   ALTER SEQUENCE public.procrastinate_events_id_seq OWNED BY public.procrastinate_events.id;
          public          taiga    false    241            �            1259    7502319    procrastinate_jobs_id_seq    SEQUENCE     �   CREATE SEQUENCE public.procrastinate_jobs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 0   DROP SEQUENCE public.procrastinate_jobs_id_seq;
       public          taiga    false    238            ;           0    0    procrastinate_jobs_id_seq    SEQUENCE OWNED BY     W   ALTER SEQUENCE public.procrastinate_jobs_id_seq OWNED BY public.procrastinate_jobs.id;
          public          taiga    false    237            �            1259    7502335    procrastinate_periodic_defers    TABLE     "  CREATE TABLE public.procrastinate_periodic_defers (
    id bigint NOT NULL,
    task_name character varying(128) NOT NULL,
    defer_timestamp bigint,
    job_id bigint,
    queue_name character varying(128),
    periodic_id character varying(128) DEFAULT ''::character varying NOT NULL
);
 1   DROP TABLE public.procrastinate_periodic_defers;
       public         heap    taiga    false            �            1259    7502333 $   procrastinate_periodic_defers_id_seq    SEQUENCE     �   CREATE SEQUENCE public.procrastinate_periodic_defers_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 ;   DROP SEQUENCE public.procrastinate_periodic_defers_id_seq;
       public          taiga    false    240            <           0    0 $   procrastinate_periodic_defers_id_seq    SEQUENCE OWNED BY     m   ALTER SEQUENCE public.procrastinate_periodic_defers_id_seq OWNED BY public.procrastinate_periodic_defers.id;
          public          taiga    false    239            @           1259    7502555 3   project_references_051ce47a709811ed89af4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_051ce47a709811ed89af4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_051ce47a709811ed89af4074e0238e3a;
       public          taiga    false            A           1259    7502557 3   project_references_06d677d6709811ed89af4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_06d677d6709811ed89af4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_06d677d6709811ed89af4074e0238e3a;
       public          taiga    false            B           1259    7502559 3   project_references_077bc646709811ed89af4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_077bc646709811ed89af4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_077bc646709811ed89af4074e0238e3a;
       public          taiga    false            C           1259    7502561 3   project_references_089e65d8709811ed89af4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_089e65d8709811ed89af4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_089e65d8709811ed89af4074e0238e3a;
       public          taiga    false            D           1259    7502563 3   project_references_0a4fc19c709811ed89af4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_0a4fc19c709811ed89af4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_0a4fc19c709811ed89af4074e0238e3a;
       public          taiga    false            E           1259    7502565 3   project_references_0b294b4c709811ed89af4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_0b294b4c709811ed89af4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_0b294b4c709811ed89af4074e0238e3a;
       public          taiga    false            F           1259    7502568 3   project_references_3a39715a709811ed89af4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_3a39715a709811ed89af4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_3a39715a709811ed89af4074e0238e3a;
       public          taiga    false            G           1259    7502570 3   project_references_3be8f9a8709811ed89af4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_3be8f9a8709811ed89af4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_3be8f9a8709811ed89af4074e0238e3a;
       public          taiga    false            H           1259    7502572 3   project_references_3c9886ac709811ed89af4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_3c9886ac709811ed89af4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_3c9886ac709811ed89af4074e0238e3a;
       public          taiga    false            I           1259    7502574 3   project_references_3dadf19e709811ed89af4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_3dadf19e709811ed89af4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_3dadf19e709811ed89af4074e0238e3a;
       public          taiga    false            J           1259    7502576 3   project_references_3f68ead4709811ed89af4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_3f68ead4709811ed89af4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_3f68ead4709811ed89af4074e0238e3a;
       public          taiga    false            K           1259    7502578 3   project_references_40480b38709811ed89af4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_40480b38709811ed89af4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_40480b38709811ed89af4074e0238e3a;
       public          taiga    false            -           1259    7502512 3   project_references_4b0a0368709411ed89af4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_4b0a0368709411ed89af4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_4b0a0368709411ed89af4074e0238e3a;
       public          taiga    false            L           1259    7614119 3   project_references_65c9dfce714911edb9e84074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_65c9dfce714911edb9e84074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_65c9dfce714911edb9e84074e0238e3a;
       public          taiga    false            M           1259    7614141 3   project_references_679b4306714911edb9e84074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_679b4306714911edb9e84074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_679b4306714911edb9e84074e0238e3a;
       public          taiga    false            N           1259    7614149 3   project_references_684aab02714911edb9e84074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_684aab02714911edb9e84074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_684aab02714911edb9e84074e0238e3a;
       public          taiga    false            O           1259    7614157 3   project_references_69757746714911edb9e84074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_69757746714911edb9e84074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_69757746714911edb9e84074e0238e3a;
       public          taiga    false            P           1259    7614165 3   project_references_6b5533c6714911edb9e84074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_6b5533c6714911edb9e84074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_6b5533c6714911edb9e84074e0238e3a;
       public          taiga    false            Q           1259    7614171 3   project_references_6c3dbf24714911edb9e84074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_6c3dbf24714911edb9e84074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_6c3dbf24714911edb9e84074e0238e3a;
       public          taiga    false            �            1259    7502388 3   project_references_6cfa12c66fb611ed887e4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_6cfa12c66fb611ed887e4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_6cfa12c66fb611ed887e4074e0238e3a;
       public          taiga    false            �            1259    7502390 3   project_references_6d2c39e06fb611ed887e4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_6d2c39e06fb611ed887e4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_6d2c39e06fb611ed887e4074e0238e3a;
       public          taiga    false            �            1259    7502392 3   project_references_6d5b1f1c6fb611ed887e4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_6d5b1f1c6fb611ed887e4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_6d5b1f1c6fb611ed887e4074e0238e3a;
       public          taiga    false            �            1259    7502394 3   project_references_6d78f37a6fb611ed887e4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_6d78f37a6fb611ed887e4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_6d78f37a6fb611ed887e4074e0238e3a;
       public          taiga    false            �            1259    7502396 3   project_references_6d9a36fc6fb611ed887e4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_6d9a36fc6fb611ed887e4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_6d9a36fc6fb611ed887e4074e0238e3a;
       public          taiga    false            �            1259    7502398 3   project_references_6dc2e1e26fb611ed887e4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_6dc2e1e26fb611ed887e4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_6dc2e1e26fb611ed887e4074e0238e3a;
       public          taiga    false            �            1259    7502400 3   project_references_6de5443a6fb611ed887e4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_6de5443a6fb611ed887e4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_6de5443a6fb611ed887e4074e0238e3a;
       public          taiga    false            �            1259    7502402 3   project_references_6e07ee366fb611ed887e4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_6e07ee366fb611ed887e4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_6e07ee366fb611ed887e4074e0238e3a;
       public          taiga    false            �            1259    7502404 3   project_references_6e2020146fb611ed887e4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_6e2020146fb611ed887e4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_6e2020146fb611ed887e4074e0238e3a;
       public          taiga    false            �            1259    7502406 3   project_references_6e50f00e6fb611ed887e4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_6e50f00e6fb611ed887e4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_6e50f00e6fb611ed887e4074e0238e3a;
       public          taiga    false            �            1259    7502408 3   project_references_6e7e6ce66fb611ed887e4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_6e7e6ce66fb611ed887e4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_6e7e6ce66fb611ed887e4074e0238e3a;
       public          taiga    false            �            1259    7502410 3   project_references_6eaef1b86fb611ed887e4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_6eaef1b86fb611ed887e4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_6eaef1b86fb611ed887e4074e0238e3a;
       public          taiga    false            �            1259    7502412 3   project_references_6ec9d30c6fb611ed887e4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_6ec9d30c6fb611ed887e4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_6ec9d30c6fb611ed887e4074e0238e3a;
       public          taiga    false                        1259    7502414 3   project_references_6eeb875e6fb611ed887e4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_6eeb875e6fb611ed887e4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_6eeb875e6fb611ed887e4074e0238e3a;
       public          taiga    false                       1259    7502416 3   project_references_6f05b9c66fb611ed887e4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_6f05b9c66fb611ed887e4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_6f05b9c66fb611ed887e4074e0238e3a;
       public          taiga    false                       1259    7502418 3   project_references_6f2263aa6fb611ed887e4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_6f2263aa6fb611ed887e4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_6f2263aa6fb611ed887e4074e0238e3a;
       public          taiga    false                       1259    7502420 3   project_references_6f474f946fb611ed887e4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_6f474f946fb611ed887e4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_6f474f946fb611ed887e4074e0238e3a;
       public          taiga    false                       1259    7502422 3   project_references_6f67aa6e6fb611ed887e4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_6f67aa6e6fb611ed887e4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_6f67aa6e6fb611ed887e4074e0238e3a;
       public          taiga    false                       1259    7502424 3   project_references_6f7fe57a6fb611ed887e4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_6f7fe57a6fb611ed887e4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_6f7fe57a6fb611ed887e4074e0238e3a;
       public          taiga    false                       1259    7502426 3   project_references_6fa5fbe86fb611ed887e4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_6fa5fbe86fb611ed887e4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_6fa5fbe86fb611ed887e4074e0238e3a;
       public          taiga    false                       1259    7502428 3   project_references_7c8998886fb611ed887e4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_7c8998886fb611ed887e4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_7c8998886fb611ed887e4074e0238e3a;
       public          taiga    false                       1259    7502430 3   project_references_7c9fe9766fb611ed887e4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_7c9fe9766fb611ed887e4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_7c9fe9766fb611ed887e4074e0238e3a;
       public          taiga    false            	           1259    7502432 3   project_references_7cbb2b506fb611ed887e4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_7cbb2b506fb611ed887e4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_7cbb2b506fb611ed887e4074e0238e3a;
       public          taiga    false            
           1259    7502434 3   project_references_7fa420606fb611ed887e4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_7fa420606fb611ed887e4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_7fa420606fb611ed887e4074e0238e3a;
       public          taiga    false                       1259    7502436 3   project_references_7fbaa9b66fb611ed887e4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_7fbaa9b66fb611ed887e4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_7fbaa9b66fb611ed887e4074e0238e3a;
       public          taiga    false                       1259    7502438 3   project_references_7fd49e666fb611ed887e4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_7fd49e666fb611ed887e4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_7fd49e666fb611ed887e4074e0238e3a;
       public          taiga    false                       1259    7502440 3   project_references_7feadb546fb611ed887e4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_7feadb546fb611ed887e4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_7feadb546fb611ed887e4074e0238e3a;
       public          taiga    false                       1259    7502442 3   project_references_8001e3446fb611ed887e4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_8001e3446fb611ed887e4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_8001e3446fb611ed887e4074e0238e3a;
       public          taiga    false                       1259    7502444 3   project_references_8016adce6fb611ed887e4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_8016adce6fb611ed887e4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_8016adce6fb611ed887e4074e0238e3a;
       public          taiga    false                       1259    7502446 3   project_references_80307e986fb611ed887e4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_80307e986fb611ed887e4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_80307e986fb611ed887e4074e0238e3a;
       public          taiga    false                       1259    7502448 3   project_references_804bf13c6fb611ed887e4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_804bf13c6fb611ed887e4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_804bf13c6fb611ed887e4074e0238e3a;
       public          taiga    false                       1259    7502450 3   project_references_8067d3a26fb611ed887e4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_8067d3a26fb611ed887e4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_8067d3a26fb611ed887e4074e0238e3a;
       public          taiga    false                       1259    7502452 3   project_references_80818d606fb611ed887e4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_80818d606fb611ed887e4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_80818d606fb611ed887e4074e0238e3a;
       public          taiga    false                       1259    7502454 3   project_references_80a038be6fb611ed887e4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_80a038be6fb611ed887e4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_80a038be6fb611ed887e4074e0238e3a;
       public          taiga    false                       1259    7502456 3   project_references_80b404e86fb611ed887e4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_80b404e86fb611ed887e4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_80b404e86fb611ed887e4074e0238e3a;
       public          taiga    false                       1259    7502458 3   project_references_80f05ed46fb611ed887e4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_80f05ed46fb611ed887e4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_80f05ed46fb611ed887e4074e0238e3a;
       public          taiga    false                       1259    7502460 3   project_references_8110d8586fb611ed887e4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_8110d8586fb611ed887e4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_8110d8586fb611ed887e4074e0238e3a;
       public          taiga    false                       1259    7502462 3   project_references_812c66046fb611ed887e4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_812c66046fb611ed887e4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_812c66046fb611ed887e4074e0238e3a;
       public          taiga    false                       1259    7502464 3   project_references_8142c2aa6fb611ed887e4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_8142c2aa6fb611ed887e4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_8142c2aa6fb611ed887e4074e0238e3a;
       public          taiga    false                       1259    7502466 3   project_references_8166cd626fb611ed887e4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_8166cd626fb611ed887e4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_8166cd626fb611ed887e4074e0238e3a;
       public          taiga    false                       1259    7502468 3   project_references_8184887a6fb611ed887e4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_8184887a6fb611ed887e4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_8184887a6fb611ed887e4074e0238e3a;
       public          taiga    false                       1259    7502470 3   project_references_81a08a846fb611ed887e4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_81a08a846fb611ed887e4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_81a08a846fb611ed887e4074e0238e3a;
       public          taiga    false                       1259    7502472 3   project_references_81c5626e6fb611ed887e4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_81c5626e6fb611ed887e4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_81c5626e6fb611ed887e4074e0238e3a;
       public          taiga    false                       1259    7502474 3   project_references_81ecd66e6fb611ed887e4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_81ecd66e6fb611ed887e4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_81ecd66e6fb611ed887e4074e0238e3a;
       public          taiga    false                       1259    7502476 3   project_references_839717906fb611ed887e4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_839717906fb611ed887e4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_839717906fb611ed887e4074e0238e3a;
       public          taiga    false                        1259    7502478 3   project_references_83ac0b786fb611ed887e4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_83ac0b786fb611ed887e4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_83ac0b786fb611ed887e4074e0238e3a;
       public          taiga    false            !           1259    7502480 3   project_references_83c660686fb611ed887e4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_83c660686fb611ed887e4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_83c660686fb611ed887e4074e0238e3a;
       public          taiga    false            "           1259    7502482 3   project_references_83d9e2826fb611ed887e4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_83d9e2826fb611ed887e4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_83d9e2826fb611ed887e4074e0238e3a;
       public          taiga    false            #           1259    7502484 3   project_references_83ef177e6fb611ed887e4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_83ef177e6fb611ed887e4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_83ef177e6fb611ed887e4074e0238e3a;
       public          taiga    false            $           1259    7502486 3   project_references_8404d7806fb611ed887e4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_8404d7806fb611ed887e4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_8404d7806fb611ed887e4074e0238e3a;
       public          taiga    false            %           1259    7502488 3   project_references_841c01f86fb611ed887e4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_841c01f86fb611ed887e4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_841c01f86fb611ed887e4074e0238e3a;
       public          taiga    false            &           1259    7502490 3   project_references_8432193e6fb611ed887e4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_8432193e6fb611ed887e4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_8432193e6fb611ed887e4074e0238e3a;
       public          taiga    false            '           1259    7502492 3   project_references_844665606fb611ed887e4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_844665606fb611ed887e4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_844665606fb611ed887e4074e0238e3a;
       public          taiga    false            (           1259    7502494 3   project_references_845dd1786fb611ed887e4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_845dd1786fb611ed887e4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_845dd1786fb611ed887e4074e0238e3a;
       public          taiga    false            )           1259    7502496 3   project_references_88cb1ec86fb611ed887e4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_88cb1ec86fb611ed887e4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_88cb1ec86fb611ed887e4074e0238e3a;
       public          taiga    false            *           1259    7502502 3   project_references_8c005c7a6fb611ed887e4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_8c005c7a6fb611ed887e4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_8c005c7a6fb611ed887e4074e0238e3a;
       public          taiga    false            +           1259    7502504 3   project_references_8c1866586fb611ed887e4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_8c1866586fb611ed887e4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_8c1866586fb611ed887e4074e0238e3a;
       public          taiga    false            R           1259    7633019 3   project_references_8c7ce66a714a11edb9e84074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_8c7ce66a714a11edb9e84074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_8c7ce66a714a11edb9e84074e0238e3a;
       public          taiga    false            ,           1259    7502506 3   project_references_a78694466fb611ed887e4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_a78694466fb611ed887e4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_a78694466fb611ed887e4074e0238e3a;
       public          taiga    false            .           1259    7502514 3   project_references_ae4eca48709511ed89af4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_ae4eca48709511ed89af4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_ae4eca48709511ed89af4074e0238e3a;
       public          taiga    false            /           1259    7502516 3   project_references_b010c30e709511ed89af4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_b010c30e709511ed89af4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_b010c30e709511ed89af4074e0238e3a;
       public          taiga    false            0           1259    7502518 3   project_references_b0b8cbf8709511ed89af4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_b0b8cbf8709511ed89af4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_b0b8cbf8709511ed89af4074e0238e3a;
       public          taiga    false            1           1259    7502520 3   project_references_b1d036ac709511ed89af4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_b1d036ac709511ed89af4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_b1d036ac709511ed89af4074e0238e3a;
       public          taiga    false            2           1259    7502522 3   project_references_b3981680709511ed89af4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_b3981680709511ed89af4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_b3981680709511ed89af4074e0238e3a;
       public          taiga    false            3           1259    7502524 3   project_references_b45dcd62709511ed89af4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_b45dcd62709511ed89af4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_b45dcd62709511ed89af4074e0238e3a;
       public          taiga    false            4           1259    7502527 3   project_references_c0e8a0d2709711ed89af4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_c0e8a0d2709711ed89af4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_c0e8a0d2709711ed89af4074e0238e3a;
       public          taiga    false            5           1259    7502529 3   project_references_c298170a709711ed89af4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_c298170a709711ed89af4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_c298170a709711ed89af4074e0238e3a;
       public          taiga    false            6           1259    7502531 3   project_references_c3441776709711ed89af4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_c3441776709711ed89af4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_c3441776709711ed89af4074e0238e3a;
       public          taiga    false            7           1259    7502533 3   project_references_c4643348709711ed89af4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_c4643348709711ed89af4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_c4643348709711ed89af4074e0238e3a;
       public          taiga    false            8           1259    7502535 3   project_references_c6244cae709711ed89af4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_c6244cae709711ed89af4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_c6244cae709711ed89af4074e0238e3a;
       public          taiga    false            9           1259    7502537 3   project_references_c6f51be0709711ed89af4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_c6f51be0709711ed89af4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_c6f51be0709711ed89af4074e0238e3a;
       public          taiga    false            :           1259    7502542 3   project_references_ef0e0ea2709711ed89af4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_ef0e0ea2709711ed89af4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_ef0e0ea2709711ed89af4074e0238e3a;
       public          taiga    false            ;           1259    7502544 3   project_references_f0bcc9b4709711ed89af4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_f0bcc9b4709711ed89af4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_f0bcc9b4709711ed89af4074e0238e3a;
       public          taiga    false            <           1259    7502546 3   project_references_f1686224709711ed89af4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_f1686224709711ed89af4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_f1686224709711ed89af4074e0238e3a;
       public          taiga    false            =           1259    7502548 3   project_references_f2863ab4709711ed89af4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_f2863ab4709711ed89af4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_f2863ab4709711ed89af4074e0238e3a;
       public          taiga    false            >           1259    7502550 3   project_references_f448c380709711ed89af4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_f448c380709711ed89af4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_f448c380709711ed89af4074e0238e3a;
       public          taiga    false            ?           1259    7502552 3   project_references_f52801f8709711ed89af4074e0238e3a    SEQUENCE     �   CREATE SEQUENCE public.project_references_f52801f8709711ed89af4074e0238e3a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_f52801f8709711ed89af4074e0238e3a;
       public          taiga    false            �            1259    7502081 &   projects_invitations_projectinvitation    TABLE     �  CREATE TABLE public.projects_invitations_projectinvitation (
    id uuid NOT NULL,
    email character varying(255) NOT NULL,
    status character varying(50) NOT NULL,
    created_at timestamp with time zone NOT NULL,
    num_emails_sent integer NOT NULL,
    resent_at timestamp with time zone,
    revoked_at timestamp with time zone,
    invited_by_id uuid,
    project_id uuid NOT NULL,
    resent_by_id uuid,
    revoked_by_id uuid,
    role_id uuid NOT NULL,
    user_id uuid
);
 :   DROP TABLE public.projects_invitations_projectinvitation;
       public         heap    taiga    false            �            1259    7502042 &   projects_memberships_projectmembership    TABLE     �   CREATE TABLE public.projects_memberships_projectmembership (
    id uuid NOT NULL,
    created_at timestamp with time zone NOT NULL,
    project_id uuid NOT NULL,
    role_id uuid NOT NULL,
    user_id uuid NOT NULL
);
 :   DROP TABLE public.projects_memberships_projectmembership;
       public         heap    taiga    false            �            1259    7502001    projects_project    TABLE     �  CREATE TABLE public.projects_project (
    id uuid NOT NULL,
    name character varying(80) NOT NULL,
    description character varying(220),
    color integer NOT NULL,
    logo character varying(500),
    created_at timestamp with time zone NOT NULL,
    modified_at timestamp with time zone NOT NULL,
    public_permissions text[],
    workspace_member_permissions text[],
    owner_id uuid NOT NULL,
    workspace_id uuid NOT NULL
);
 $   DROP TABLE public.projects_project;
       public         heap    taiga    false            �            1259    7502009    projects_projecttemplate    TABLE     ]  CREATE TABLE public.projects_projecttemplate (
    id uuid NOT NULL,
    name character varying(250) NOT NULL,
    slug character varying(250) NOT NULL,
    created_at timestamp with time zone NOT NULL,
    modified_at timestamp with time zone NOT NULL,
    default_owner_role character varying(50) NOT NULL,
    roles jsonb,
    workflows jsonb
);
 ,   DROP TABLE public.projects_projecttemplate;
       public         heap    taiga    false            �            1259    7502021    projects_roles_projectrole    TABLE       CREATE TABLE public.projects_roles_projectrole (
    id uuid NOT NULL,
    name character varying(200) NOT NULL,
    slug character varying(250) NOT NULL,
    permissions text[],
    "order" bigint NOT NULL,
    is_admin boolean NOT NULL,
    project_id uuid NOT NULL
);
 .   DROP TABLE public.projects_roles_projectrole;
       public         heap    taiga    false            �            1259    7502171    stories_story    TABLE     R  CREATE TABLE public.stories_story (
    id uuid NOT NULL,
    created_at timestamp with time zone NOT NULL,
    ref bigint NOT NULL,
    title character varying(500) NOT NULL,
    "order" numeric(16,10) NOT NULL,
    created_by_id uuid NOT NULL,
    project_id uuid NOT NULL,
    status_id uuid NOT NULL,
    workflow_id uuid NOT NULL
);
 !   DROP TABLE public.stories_story;
       public         heap    taiga    false            �            1259    7502217    tokens_denylistedtoken    TABLE     �   CREATE TABLE public.tokens_denylistedtoken (
    id uuid NOT NULL,
    denylisted_at timestamp with time zone NOT NULL,
    token_id uuid NOT NULL
);
 *   DROP TABLE public.tokens_denylistedtoken;
       public         heap    taiga    false            �            1259    7502207    tokens_outstandingtoken    TABLE     2  CREATE TABLE public.tokens_outstandingtoken (
    id uuid NOT NULL,
    object_id uuid,
    jti character varying(255) NOT NULL,
    token_type text NOT NULL,
    token text NOT NULL,
    created_at timestamp with time zone,
    expires_at timestamp with time zone NOT NULL,
    content_type_id integer
);
 +   DROP TABLE public.tokens_outstandingtoken;
       public         heap    taiga    false            �            1259    7501836    users_authdata    TABLE     �   CREATE TABLE public.users_authdata (
    id uuid NOT NULL,
    key character varying(50) NOT NULL,
    value character varying(300) NOT NULL,
    extra jsonb,
    user_id uuid NOT NULL
);
 "   DROP TABLE public.users_authdata;
       public         heap    taiga    false            �            1259    7501824 
   users_user    TABLE       CREATE TABLE public.users_user (
    password character varying(128) NOT NULL,
    last_login timestamp with time zone,
    id uuid NOT NULL,
    username character varying(255) NOT NULL,
    email character varying(255) NOT NULL,
    is_active boolean NOT NULL,
    is_superuser boolean NOT NULL,
    full_name character varying(256),
    accepted_terms boolean NOT NULL,
    lang character varying(20) NOT NULL,
    date_joined timestamp with time zone NOT NULL,
    date_verification timestamp with time zone
);
    DROP TABLE public.users_user;
       public         heap    taiga    false            �            1259    7502137    workflows_workflow    TABLE     �   CREATE TABLE public.workflows_workflow (
    id uuid NOT NULL,
    name character varying(250) NOT NULL,
    slug character varying(250) NOT NULL,
    "order" bigint NOT NULL,
    project_id uuid NOT NULL
);
 &   DROP TABLE public.workflows_workflow;
       public         heap    taiga    false            �            1259    7502145    workflows_workflowstatus    TABLE     �   CREATE TABLE public.workflows_workflowstatus (
    id uuid NOT NULL,
    name character varying(250) NOT NULL,
    slug character varying(250) NOT NULL,
    color integer NOT NULL,
    "order" bigint NOT NULL,
    workflow_id uuid NOT NULL
);
 ,   DROP TABLE public.workflows_workflowstatus;
       public         heap    taiga    false            �            1259    7502261 *   workspaces_memberships_workspacemembership    TABLE     �   CREATE TABLE public.workspaces_memberships_workspacemembership (
    id uuid NOT NULL,
    created_at timestamp with time zone NOT NULL,
    role_id uuid NOT NULL,
    user_id uuid NOT NULL,
    workspace_id uuid NOT NULL
);
 >   DROP TABLE public.workspaces_memberships_workspacemembership;
       public         heap    taiga    false            �            1259    7502240    workspaces_roles_workspacerole    TABLE       CREATE TABLE public.workspaces_roles_workspacerole (
    id uuid NOT NULL,
    name character varying(200) NOT NULL,
    slug character varying(250) NOT NULL,
    permissions text[],
    "order" bigint NOT NULL,
    is_admin boolean NOT NULL,
    workspace_id uuid NOT NULL
);
 2   DROP TABLE public.workspaces_roles_workspacerole;
       public         heap    taiga    false            �            1259    7501996    workspaces_workspace    TABLE     *  CREATE TABLE public.workspaces_workspace (
    id uuid NOT NULL,
    name character varying(40) NOT NULL,
    color integer NOT NULL,
    created_at timestamp with time zone NOT NULL,
    modified_at timestamp with time zone NOT NULL,
    is_premium boolean NOT NULL,
    owner_id uuid NOT NULL
);
 (   DROP TABLE public.workspaces_workspace;
       public         heap    taiga    false            M           2604    7502354    procrastinate_events id    DEFAULT     �   ALTER TABLE ONLY public.procrastinate_events ALTER COLUMN id SET DEFAULT nextval('public.procrastinate_events_id_seq'::regclass);
 F   ALTER TABLE public.procrastinate_events ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    241    242    242            G           2604    7502324    procrastinate_jobs id    DEFAULT     ~   ALTER TABLE ONLY public.procrastinate_jobs ALTER COLUMN id SET DEFAULT nextval('public.procrastinate_jobs_id_seq'::regclass);
 D   ALTER TABLE public.procrastinate_jobs ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    237    238    238            K           2604    7502338     procrastinate_periodic_defers id    DEFAULT     �   ALTER TABLE ONLY public.procrastinate_periodic_defers ALTER COLUMN id SET DEFAULT nextval('public.procrastinate_periodic_defers_id_seq'::regclass);
 O   ALTER TABLE public.procrastinate_periodic_defers ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    239    240    240            �          0    7501900 
   auth_group 
   TABLE DATA           .   COPY public.auth_group (id, name) FROM stdin;
    public          taiga    false    214   ��      �          0    7501909    auth_group_permissions 
   TABLE DATA           M   COPY public.auth_group_permissions (id, group_id, permission_id) FROM stdin;
    public          taiga    false    216   �      �          0    7501893    auth_permission 
   TABLE DATA           N   COPY public.auth_permission (id, name, content_type_id, codename) FROM stdin;
    public          taiga    false    212   4�      �          0    7501870    django_admin_log 
   TABLE DATA           �   COPY public.django_admin_log (id, action_time, object_id, object_repr, action_flag, change_message, content_type_id, user_id) FROM stdin;
    public          taiga    false    210   ��      �          0    7501861    django_content_type 
   TABLE DATA           C   COPY public.django_content_type (id, app_label, model) FROM stdin;
    public          taiga    false    208   ��      �          0    7501816    django_migrations 
   TABLE DATA           C   COPY public.django_migrations (id, app, name, applied) FROM stdin;
    public          taiga    false    204   �      �          0    7502127    django_session 
   TABLE DATA           P   COPY public.django_session (session_key, session_data, expire_date) FROM stdin;
    public          taiga    false    229   ��      �          0    7501950    easy_thumbnails_source 
   TABLE DATA           R   COPY public.easy_thumbnails_source (id, storage_hash, name, modified) FROM stdin;
    public          taiga    false    218   ��      �          0    7501957    easy_thumbnails_thumbnail 
   TABLE DATA           `   COPY public.easy_thumbnails_thumbnail (id, storage_hash, name, modified, source_id) FROM stdin;
    public          taiga    false    220   ��      �          0    7501982 #   easy_thumbnails_thumbnaildimensions 
   TABLE DATA           ^   COPY public.easy_thumbnails_thumbnaildimensions (id, thumbnail_id, width, height) FROM stdin;
    public          taiga    false    222   Q�      �          0    7502351    procrastinate_events 
   TABLE DATA           D   COPY public.procrastinate_events (id, job_id, type, at) FROM stdin;
    public          taiga    false    242   n�      �          0    7502321    procrastinate_jobs 
   TABLE DATA           �   COPY public.procrastinate_jobs (id, queue_name, task_name, lock, queueing_lock, args, status, scheduled_at, attempts) FROM stdin;
    public          taiga    false    238   4�      �          0    7502335    procrastinate_periodic_defers 
   TABLE DATA           x   COPY public.procrastinate_periodic_defers (id, task_name, defer_timestamp, job_id, queue_name, periodic_id) FROM stdin;
    public          taiga    false    240   �      �          0    7502081 &   projects_invitations_projectinvitation 
   TABLE DATA           �   COPY public.projects_invitations_projectinvitation (id, email, status, created_at, num_emails_sent, resent_at, revoked_at, invited_by_id, project_id, resent_by_id, revoked_by_id, role_id, user_id) FROM stdin;
    public          taiga    false    228         �          0    7502042 &   projects_memberships_projectmembership 
   TABLE DATA           n   COPY public.projects_memberships_projectmembership (id, created_at, project_id, role_id, user_id) FROM stdin;
    public          taiga    false    227   �&      �          0    7502001    projects_project 
   TABLE DATA           �   COPY public.projects_project (id, name, description, color, logo, created_at, modified_at, public_permissions, workspace_member_permissions, owner_id, workspace_id) FROM stdin;
    public          taiga    false    224   �:      �          0    7502009    projects_projecttemplate 
   TABLE DATA           �   COPY public.projects_projecttemplate (id, name, slug, created_at, modified_at, default_owner_role, roles, workflows) FROM stdin;
    public          taiga    false    225   �R      �          0    7502021    projects_roles_projectrole 
   TABLE DATA           p   COPY public.projects_roles_projectrole (id, name, slug, permissions, "order", is_admin, project_id) FROM stdin;
    public          taiga    false    226   �S      �          0    7502171    stories_story 
   TABLE DATA              COPY public.stories_story (id, created_at, ref, title, "order", created_by_id, project_id, status_id, workflow_id) FROM stdin;
    public          taiga    false    232   �\      �          0    7502217    tokens_denylistedtoken 
   TABLE DATA           M   COPY public.tokens_denylistedtoken (id, denylisted_at, token_id) FROM stdin;
    public          taiga    false    234   ��      �          0    7502207    tokens_outstandingtoken 
   TABLE DATA           �   COPY public.tokens_outstandingtoken (id, object_id, jti, token_type, token, created_at, expires_at, content_type_id) FROM stdin;
    public          taiga    false    233   ��      �          0    7501836    users_authdata 
   TABLE DATA           H   COPY public.users_authdata (id, key, value, extra, user_id) FROM stdin;
    public          taiga    false    206   �I      �          0    7501824 
   users_user 
   TABLE DATA           �   COPY public.users_user (password, last_login, id, username, email, is_active, is_superuser, full_name, accepted_terms, lang, date_joined, date_verification) FROM stdin;
    public          taiga    false    205   �I      �          0    7502137    workflows_workflow 
   TABLE DATA           Q   COPY public.workflows_workflow (id, name, slug, "order", project_id) FROM stdin;
    public          taiga    false    230   X      �          0    7502145    workflows_workflowstatus 
   TABLE DATA           _   COPY public.workflows_workflowstatus (id, name, slug, color, "order", workflow_id) FROM stdin;
    public          taiga    false    231   �\      �          0    7502261 *   workspaces_memberships_workspacemembership 
   TABLE DATA           t   COPY public.workspaces_memberships_workspacemembership (id, created_at, role_id, user_id, workspace_id) FROM stdin;
    public          taiga    false    236   [n      �          0    7502240    workspaces_roles_workspacerole 
   TABLE DATA           v   COPY public.workspaces_roles_workspacerole (id, name, slug, permissions, "order", is_admin, workspace_id) FROM stdin;
    public          taiga    false    235   �y      �          0    7501996    workspaces_workspace 
   TABLE DATA           n   COPY public.workspaces_workspace (id, name, color, created_at, modified_at, is_premium, owner_id) FROM stdin;
    public          taiga    false    223   '      =           0    0    auth_group_id_seq    SEQUENCE SET     @   SELECT pg_catalog.setval('public.auth_group_id_seq', 1, false);
          public          taiga    false    213            >           0    0    auth_group_permissions_id_seq    SEQUENCE SET     L   SELECT pg_catalog.setval('public.auth_group_permissions_id_seq', 1, false);
          public          taiga    false    215            ?           0    0    auth_permission_id_seq    SEQUENCE SET     E   SELECT pg_catalog.setval('public.auth_permission_id_seq', 92, true);
          public          taiga    false    211            @           0    0    django_admin_log_id_seq    SEQUENCE SET     F   SELECT pg_catalog.setval('public.django_admin_log_id_seq', 1, false);
          public          taiga    false    209            A           0    0    django_content_type_id_seq    SEQUENCE SET     I   SELECT pg_catalog.setval('public.django_content_type_id_seq', 23, true);
          public          taiga    false    207            B           0    0    django_migrations_id_seq    SEQUENCE SET     G   SELECT pg_catalog.setval('public.django_migrations_id_seq', 35, true);
          public          taiga    false    203            C           0    0    easy_thumbnails_source_id_seq    SEQUENCE SET     L   SELECT pg_catalog.setval('public.easy_thumbnails_source_id_seq', 24, true);
          public          taiga    false    217            D           0    0     easy_thumbnails_thumbnail_id_seq    SEQUENCE SET     O   SELECT pg_catalog.setval('public.easy_thumbnails_thumbnail_id_seq', 48, true);
          public          taiga    false    219            E           0    0 *   easy_thumbnails_thumbnaildimensions_id_seq    SEQUENCE SET     Y   SELECT pg_catalog.setval('public.easy_thumbnails_thumbnaildimensions_id_seq', 1, false);
          public          taiga    false    221            F           0    0    procrastinate_events_id_seq    SEQUENCE SET     K   SELECT pg_catalog.setval('public.procrastinate_events_id_seq', 279, true);
          public          taiga    false    241            G           0    0    procrastinate_jobs_id_seq    SEQUENCE SET     H   SELECT pg_catalog.setval('public.procrastinate_jobs_id_seq', 93, true);
          public          taiga    false    237            H           0    0 $   procrastinate_periodic_defers_id_seq    SEQUENCE SET     S   SELECT pg_catalog.setval('public.procrastinate_periodic_defers_id_seq', 1, false);
          public          taiga    false    239            I           0    0 3   project_references_051ce47a709811ed89af4074e0238e3a    SEQUENCE SET     a   SELECT pg_catalog.setval('public.project_references_051ce47a709811ed89af4074e0238e3a', 2, true);
          public          taiga    false    320            J           0    0 3   project_references_06d677d6709811ed89af4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_06d677d6709811ed89af4074e0238e3a', 1, false);
          public          taiga    false    321            K           0    0 3   project_references_077bc646709811ed89af4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_077bc646709811ed89af4074e0238e3a', 1, false);
          public          taiga    false    322            L           0    0 3   project_references_089e65d8709811ed89af4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_089e65d8709811ed89af4074e0238e3a', 1, false);
          public          taiga    false    323            M           0    0 3   project_references_0a4fc19c709811ed89af4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_0a4fc19c709811ed89af4074e0238e3a', 1, false);
          public          taiga    false    324            N           0    0 3   project_references_0b294b4c709811ed89af4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_0b294b4c709811ed89af4074e0238e3a', 1, false);
          public          taiga    false    325            O           0    0 3   project_references_3a39715a709811ed89af4074e0238e3a    SEQUENCE SET     a   SELECT pg_catalog.setval('public.project_references_3a39715a709811ed89af4074e0238e3a', 2, true);
          public          taiga    false    326            P           0    0 3   project_references_3be8f9a8709811ed89af4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_3be8f9a8709811ed89af4074e0238e3a', 1, false);
          public          taiga    false    327            Q           0    0 3   project_references_3c9886ac709811ed89af4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_3c9886ac709811ed89af4074e0238e3a', 1, false);
          public          taiga    false    328            R           0    0 3   project_references_3dadf19e709811ed89af4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_3dadf19e709811ed89af4074e0238e3a', 1, false);
          public          taiga    false    329            S           0    0 3   project_references_3f68ead4709811ed89af4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_3f68ead4709811ed89af4074e0238e3a', 1, false);
          public          taiga    false    330            T           0    0 3   project_references_40480b38709811ed89af4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_40480b38709811ed89af4074e0238e3a', 1, false);
          public          taiga    false    331            U           0    0 3   project_references_4b0a0368709411ed89af4074e0238e3a    SEQUENCE SET     a   SELECT pg_catalog.setval('public.project_references_4b0a0368709411ed89af4074e0238e3a', 1, true);
          public          taiga    false    301            V           0    0 3   project_references_65c9dfce714911edb9e84074e0238e3a    SEQUENCE SET     a   SELECT pg_catalog.setval('public.project_references_65c9dfce714911edb9e84074e0238e3a', 2, true);
          public          taiga    false    332            W           0    0 3   project_references_679b4306714911edb9e84074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_679b4306714911edb9e84074e0238e3a', 1, false);
          public          taiga    false    333            X           0    0 3   project_references_684aab02714911edb9e84074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_684aab02714911edb9e84074e0238e3a', 1, false);
          public          taiga    false    334            Y           0    0 3   project_references_69757746714911edb9e84074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_69757746714911edb9e84074e0238e3a', 1, false);
          public          taiga    false    335            Z           0    0 3   project_references_6b5533c6714911edb9e84074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_6b5533c6714911edb9e84074e0238e3a', 1, false);
          public          taiga    false    336            [           0    0 3   project_references_6c3dbf24714911edb9e84074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_6c3dbf24714911edb9e84074e0238e3a', 1, false);
          public          taiga    false    337            \           0    0 3   project_references_6cfa12c66fb611ed887e4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_6cfa12c66fb611ed887e4074e0238e3a', 19, true);
          public          taiga    false    243            ]           0    0 3   project_references_6d2c39e06fb611ed887e4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_6d2c39e06fb611ed887e4074e0238e3a', 23, true);
          public          taiga    false    244            ^           0    0 3   project_references_6d5b1f1c6fb611ed887e4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_6d5b1f1c6fb611ed887e4074e0238e3a', 28, true);
          public          taiga    false    245            _           0    0 3   project_references_6d78f37a6fb611ed887e4074e0238e3a    SEQUENCE SET     a   SELECT pg_catalog.setval('public.project_references_6d78f37a6fb611ed887e4074e0238e3a', 8, true);
          public          taiga    false    246            `           0    0 3   project_references_6d9a36fc6fb611ed887e4074e0238e3a    SEQUENCE SET     a   SELECT pg_catalog.setval('public.project_references_6d9a36fc6fb611ed887e4074e0238e3a', 6, true);
          public          taiga    false    247            a           0    0 3   project_references_6dc2e1e26fb611ed887e4074e0238e3a    SEQUENCE SET     a   SELECT pg_catalog.setval('public.project_references_6dc2e1e26fb611ed887e4074e0238e3a', 3, true);
          public          taiga    false    248            b           0    0 3   project_references_6de5443a6fb611ed887e4074e0238e3a    SEQUENCE SET     a   SELECT pg_catalog.setval('public.project_references_6de5443a6fb611ed887e4074e0238e3a', 9, true);
          public          taiga    false    249            c           0    0 3   project_references_6e07ee366fb611ed887e4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_6e07ee366fb611ed887e4074e0238e3a', 27, true);
          public          taiga    false    250            d           0    0 3   project_references_6e2020146fb611ed887e4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_6e2020146fb611ed887e4074e0238e3a', 14, true);
          public          taiga    false    251            e           0    0 3   project_references_6e50f00e6fb611ed887e4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_6e50f00e6fb611ed887e4074e0238e3a', 10, true);
          public          taiga    false    252            f           0    0 3   project_references_6e7e6ce66fb611ed887e4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_6e7e6ce66fb611ed887e4074e0238e3a', 15, true);
          public          taiga    false    253            g           0    0 3   project_references_6eaef1b86fb611ed887e4074e0238e3a    SEQUENCE SET     a   SELECT pg_catalog.setval('public.project_references_6eaef1b86fb611ed887e4074e0238e3a', 6, true);
          public          taiga    false    254            h           0    0 3   project_references_6ec9d30c6fb611ed887e4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_6ec9d30c6fb611ed887e4074e0238e3a', 27, true);
          public          taiga    false    255            i           0    0 3   project_references_6eeb875e6fb611ed887e4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_6eeb875e6fb611ed887e4074e0238e3a', 21, true);
          public          taiga    false    256            j           0    0 3   project_references_6f05b9c66fb611ed887e4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_6f05b9c66fb611ed887e4074e0238e3a', 16, true);
          public          taiga    false    257            k           0    0 3   project_references_6f2263aa6fb611ed887e4074e0238e3a    SEQUENCE SET     a   SELECT pg_catalog.setval('public.project_references_6f2263aa6fb611ed887e4074e0238e3a', 2, true);
          public          taiga    false    258            l           0    0 3   project_references_6f474f946fb611ed887e4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_6f474f946fb611ed887e4074e0238e3a', 25, true);
          public          taiga    false    259            m           0    0 3   project_references_6f67aa6e6fb611ed887e4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_6f67aa6e6fb611ed887e4074e0238e3a', 29, true);
          public          taiga    false    260            n           0    0 3   project_references_6f7fe57a6fb611ed887e4074e0238e3a    SEQUENCE SET     a   SELECT pg_catalog.setval('public.project_references_6f7fe57a6fb611ed887e4074e0238e3a', 1, true);
          public          taiga    false    261            o           0    0 3   project_references_6fa5fbe86fb611ed887e4074e0238e3a    SEQUENCE SET     a   SELECT pg_catalog.setval('public.project_references_6fa5fbe86fb611ed887e4074e0238e3a', 2, true);
          public          taiga    false    262            p           0    0 3   project_references_7c8998886fb611ed887e4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_7c8998886fb611ed887e4074e0238e3a', 1, false);
          public          taiga    false    263            q           0    0 3   project_references_7c9fe9766fb611ed887e4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_7c9fe9766fb611ed887e4074e0238e3a', 1, false);
          public          taiga    false    264            r           0    0 3   project_references_7cbb2b506fb611ed887e4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_7cbb2b506fb611ed887e4074e0238e3a', 1, false);
          public          taiga    false    265            s           0    0 3   project_references_7fa420606fb611ed887e4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_7fa420606fb611ed887e4074e0238e3a', 1, false);
          public          taiga    false    266            t           0    0 3   project_references_7fbaa9b66fb611ed887e4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_7fbaa9b66fb611ed887e4074e0238e3a', 1, false);
          public          taiga    false    267            u           0    0 3   project_references_7fd49e666fb611ed887e4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_7fd49e666fb611ed887e4074e0238e3a', 1, false);
          public          taiga    false    268            v           0    0 3   project_references_7feadb546fb611ed887e4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_7feadb546fb611ed887e4074e0238e3a', 1, false);
          public          taiga    false    269            w           0    0 3   project_references_8001e3446fb611ed887e4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_8001e3446fb611ed887e4074e0238e3a', 1, false);
          public          taiga    false    270            x           0    0 3   project_references_8016adce6fb611ed887e4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_8016adce6fb611ed887e4074e0238e3a', 1, false);
          public          taiga    false    271            y           0    0 3   project_references_80307e986fb611ed887e4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_80307e986fb611ed887e4074e0238e3a', 1, false);
          public          taiga    false    272            z           0    0 3   project_references_804bf13c6fb611ed887e4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_804bf13c6fb611ed887e4074e0238e3a', 1, false);
          public          taiga    false    273            {           0    0 3   project_references_8067d3a26fb611ed887e4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_8067d3a26fb611ed887e4074e0238e3a', 1, false);
          public          taiga    false    274            |           0    0 3   project_references_80818d606fb611ed887e4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_80818d606fb611ed887e4074e0238e3a', 1, false);
          public          taiga    false    275            }           0    0 3   project_references_80a038be6fb611ed887e4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_80a038be6fb611ed887e4074e0238e3a', 1, false);
          public          taiga    false    276            ~           0    0 3   project_references_80b404e86fb611ed887e4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_80b404e86fb611ed887e4074e0238e3a', 1, false);
          public          taiga    false    277                       0    0 3   project_references_80f05ed46fb611ed887e4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_80f05ed46fb611ed887e4074e0238e3a', 1, false);
          public          taiga    false    278            �           0    0 3   project_references_8110d8586fb611ed887e4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_8110d8586fb611ed887e4074e0238e3a', 1, false);
          public          taiga    false    279            �           0    0 3   project_references_812c66046fb611ed887e4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_812c66046fb611ed887e4074e0238e3a', 1, false);
          public          taiga    false    280            �           0    0 3   project_references_8142c2aa6fb611ed887e4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_8142c2aa6fb611ed887e4074e0238e3a', 1, false);
          public          taiga    false    281            �           0    0 3   project_references_8166cd626fb611ed887e4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_8166cd626fb611ed887e4074e0238e3a', 1, false);
          public          taiga    false    282            �           0    0 3   project_references_8184887a6fb611ed887e4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_8184887a6fb611ed887e4074e0238e3a', 1, false);
          public          taiga    false    283            �           0    0 3   project_references_81a08a846fb611ed887e4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_81a08a846fb611ed887e4074e0238e3a', 1, false);
          public          taiga    false    284            �           0    0 3   project_references_81c5626e6fb611ed887e4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_81c5626e6fb611ed887e4074e0238e3a', 1, false);
          public          taiga    false    285            �           0    0 3   project_references_81ecd66e6fb611ed887e4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_81ecd66e6fb611ed887e4074e0238e3a', 1, false);
          public          taiga    false    286            �           0    0 3   project_references_839717906fb611ed887e4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_839717906fb611ed887e4074e0238e3a', 1, false);
          public          taiga    false    287            �           0    0 3   project_references_83ac0b786fb611ed887e4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_83ac0b786fb611ed887e4074e0238e3a', 1, false);
          public          taiga    false    288            �           0    0 3   project_references_83c660686fb611ed887e4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_83c660686fb611ed887e4074e0238e3a', 1, false);
          public          taiga    false    289            �           0    0 3   project_references_83d9e2826fb611ed887e4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_83d9e2826fb611ed887e4074e0238e3a', 1, false);
          public          taiga    false    290            �           0    0 3   project_references_83ef177e6fb611ed887e4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_83ef177e6fb611ed887e4074e0238e3a', 1, false);
          public          taiga    false    291            �           0    0 3   project_references_8404d7806fb611ed887e4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_8404d7806fb611ed887e4074e0238e3a', 1, false);
          public          taiga    false    292            �           0    0 3   project_references_841c01f86fb611ed887e4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_841c01f86fb611ed887e4074e0238e3a', 1, false);
          public          taiga    false    293            �           0    0 3   project_references_8432193e6fb611ed887e4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_8432193e6fb611ed887e4074e0238e3a', 1, false);
          public          taiga    false    294            �           0    0 3   project_references_844665606fb611ed887e4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_844665606fb611ed887e4074e0238e3a', 1, false);
          public          taiga    false    295            �           0    0 3   project_references_845dd1786fb611ed887e4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_845dd1786fb611ed887e4074e0238e3a', 1, false);
          public          taiga    false    296            �           0    0 3   project_references_88cb1ec86fb611ed887e4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_88cb1ec86fb611ed887e4074e0238e3a', 1, false);
          public          taiga    false    297            �           0    0 3   project_references_8c005c7a6fb611ed887e4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_8c005c7a6fb611ed887e4074e0238e3a', 1, false);
          public          taiga    false    298            �           0    0 3   project_references_8c1866586fb611ed887e4074e0238e3a    SEQUENCE SET     d   SELECT pg_catalog.setval('public.project_references_8c1866586fb611ed887e4074e0238e3a', 1000, true);
          public          taiga    false    299            �           0    0 3   project_references_8c7ce66a714a11edb9e84074e0238e3a    SEQUENCE SET     a   SELECT pg_catalog.setval('public.project_references_8c7ce66a714a11edb9e84074e0238e3a', 1, true);
          public          taiga    false    338            �           0    0 3   project_references_a78694466fb611ed887e4074e0238e3a    SEQUENCE SET     d   SELECT pg_catalog.setval('public.project_references_a78694466fb611ed887e4074e0238e3a', 2000, true);
          public          taiga    false    300            �           0    0 3   project_references_ae4eca48709511ed89af4074e0238e3a    SEQUENCE SET     a   SELECT pg_catalog.setval('public.project_references_ae4eca48709511ed89af4074e0238e3a', 2, true);
          public          taiga    false    302            �           0    0 3   project_references_b010c30e709511ed89af4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_b010c30e709511ed89af4074e0238e3a', 1, false);
          public          taiga    false    303            �           0    0 3   project_references_b0b8cbf8709511ed89af4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_b0b8cbf8709511ed89af4074e0238e3a', 1, false);
          public          taiga    false    304            �           0    0 3   project_references_b1d036ac709511ed89af4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_b1d036ac709511ed89af4074e0238e3a', 1, false);
          public          taiga    false    305            �           0    0 3   project_references_b3981680709511ed89af4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_b3981680709511ed89af4074e0238e3a', 1, false);
          public          taiga    false    306            �           0    0 3   project_references_b45dcd62709511ed89af4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_b45dcd62709511ed89af4074e0238e3a', 1, false);
          public          taiga    false    307            �           0    0 3   project_references_c0e8a0d2709711ed89af4074e0238e3a    SEQUENCE SET     a   SELECT pg_catalog.setval('public.project_references_c0e8a0d2709711ed89af4074e0238e3a', 2, true);
          public          taiga    false    308            �           0    0 3   project_references_c298170a709711ed89af4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_c298170a709711ed89af4074e0238e3a', 1, false);
          public          taiga    false    309            �           0    0 3   project_references_c3441776709711ed89af4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_c3441776709711ed89af4074e0238e3a', 1, false);
          public          taiga    false    310            �           0    0 3   project_references_c4643348709711ed89af4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_c4643348709711ed89af4074e0238e3a', 1, false);
          public          taiga    false    311            �           0    0 3   project_references_c6244cae709711ed89af4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_c6244cae709711ed89af4074e0238e3a', 1, false);
          public          taiga    false    312            �           0    0 3   project_references_c6f51be0709711ed89af4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_c6f51be0709711ed89af4074e0238e3a', 1, false);
          public          taiga    false    313            �           0    0 3   project_references_ef0e0ea2709711ed89af4074e0238e3a    SEQUENCE SET     a   SELECT pg_catalog.setval('public.project_references_ef0e0ea2709711ed89af4074e0238e3a', 2, true);
          public          taiga    false    314            �           0    0 3   project_references_f0bcc9b4709711ed89af4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_f0bcc9b4709711ed89af4074e0238e3a', 1, false);
          public          taiga    false    315            �           0    0 3   project_references_f1686224709711ed89af4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_f1686224709711ed89af4074e0238e3a', 1, false);
          public          taiga    false    316            �           0    0 3   project_references_f2863ab4709711ed89af4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_f2863ab4709711ed89af4074e0238e3a', 1, false);
          public          taiga    false    317            �           0    0 3   project_references_f448c380709711ed89af4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_f448c380709711ed89af4074e0238e3a', 1, false);
          public          taiga    false    318            �           0    0 3   project_references_f52801f8709711ed89af4074e0238e3a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_f52801f8709711ed89af4074e0238e3a', 1, false);
          public          taiga    false    319            r           2606    7501938    auth_group auth_group_name_key 
   CONSTRAINT     Y   ALTER TABLE ONLY public.auth_group
    ADD CONSTRAINT auth_group_name_key UNIQUE (name);
 H   ALTER TABLE ONLY public.auth_group DROP CONSTRAINT auth_group_name_key;
       public            taiga    false    214            w           2606    7501924 R   auth_group_permissions auth_group_permissions_group_id_permission_id_0cd325b0_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.auth_group_permissions
    ADD CONSTRAINT auth_group_permissions_group_id_permission_id_0cd325b0_uniq UNIQUE (group_id, permission_id);
 |   ALTER TABLE ONLY public.auth_group_permissions DROP CONSTRAINT auth_group_permissions_group_id_permission_id_0cd325b0_uniq;
       public            taiga    false    216    216            z           2606    7501913 2   auth_group_permissions auth_group_permissions_pkey 
   CONSTRAINT     p   ALTER TABLE ONLY public.auth_group_permissions
    ADD CONSTRAINT auth_group_permissions_pkey PRIMARY KEY (id);
 \   ALTER TABLE ONLY public.auth_group_permissions DROP CONSTRAINT auth_group_permissions_pkey;
       public            taiga    false    216            t           2606    7501904    auth_group auth_group_pkey 
   CONSTRAINT     X   ALTER TABLE ONLY public.auth_group
    ADD CONSTRAINT auth_group_pkey PRIMARY KEY (id);
 D   ALTER TABLE ONLY public.auth_group DROP CONSTRAINT auth_group_pkey;
       public            taiga    false    214            m           2606    7501915 F   auth_permission auth_permission_content_type_id_codename_01ab375a_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.auth_permission
    ADD CONSTRAINT auth_permission_content_type_id_codename_01ab375a_uniq UNIQUE (content_type_id, codename);
 p   ALTER TABLE ONLY public.auth_permission DROP CONSTRAINT auth_permission_content_type_id_codename_01ab375a_uniq;
       public            taiga    false    212    212            o           2606    7501897 $   auth_permission auth_permission_pkey 
   CONSTRAINT     b   ALTER TABLE ONLY public.auth_permission
    ADD CONSTRAINT auth_permission_pkey PRIMARY KEY (id);
 N   ALTER TABLE ONLY public.auth_permission DROP CONSTRAINT auth_permission_pkey;
       public            taiga    false    212            i           2606    7501878 &   django_admin_log django_admin_log_pkey 
   CONSTRAINT     d   ALTER TABLE ONLY public.django_admin_log
    ADD CONSTRAINT django_admin_log_pkey PRIMARY KEY (id);
 P   ALTER TABLE ONLY public.django_admin_log DROP CONSTRAINT django_admin_log_pkey;
       public            taiga    false    210            d           2606    7501867 E   django_content_type django_content_type_app_label_model_76bd3d3b_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.django_content_type
    ADD CONSTRAINT django_content_type_app_label_model_76bd3d3b_uniq UNIQUE (app_label, model);
 o   ALTER TABLE ONLY public.django_content_type DROP CONSTRAINT django_content_type_app_label_model_76bd3d3b_uniq;
       public            taiga    false    208    208            f           2606    7501865 ,   django_content_type django_content_type_pkey 
   CONSTRAINT     j   ALTER TABLE ONLY public.django_content_type
    ADD CONSTRAINT django_content_type_pkey PRIMARY KEY (id);
 V   ALTER TABLE ONLY public.django_content_type DROP CONSTRAINT django_content_type_pkey;
       public            taiga    false    208            P           2606    7501823 (   django_migrations django_migrations_pkey 
   CONSTRAINT     f   ALTER TABLE ONLY public.django_migrations
    ADD CONSTRAINT django_migrations_pkey PRIMARY KEY (id);
 R   ALTER TABLE ONLY public.django_migrations DROP CONSTRAINT django_migrations_pkey;
       public            taiga    false    204            �           2606    7502134 "   django_session django_session_pkey 
   CONSTRAINT     i   ALTER TABLE ONLY public.django_session
    ADD CONSTRAINT django_session_pkey PRIMARY KEY (session_key);
 L   ALTER TABLE ONLY public.django_session DROP CONSTRAINT django_session_pkey;
       public            taiga    false    229            ~           2606    7501954 2   easy_thumbnails_source easy_thumbnails_source_pkey 
   CONSTRAINT     p   ALTER TABLE ONLY public.easy_thumbnails_source
    ADD CONSTRAINT easy_thumbnails_source_pkey PRIMARY KEY (id);
 \   ALTER TABLE ONLY public.easy_thumbnails_source DROP CONSTRAINT easy_thumbnails_source_pkey;
       public            taiga    false    218            �           2606    7501965 M   easy_thumbnails_source easy_thumbnails_source_storage_hash_name_481ce32d_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.easy_thumbnails_source
    ADD CONSTRAINT easy_thumbnails_source_storage_hash_name_481ce32d_uniq UNIQUE (storage_hash, name);
 w   ALTER TABLE ONLY public.easy_thumbnails_source DROP CONSTRAINT easy_thumbnails_source_storage_hash_name_481ce32d_uniq;
       public            taiga    false    218    218            �           2606    7501963 Y   easy_thumbnails_thumbnail easy_thumbnails_thumbnai_storage_hash_name_source_fb375270_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.easy_thumbnails_thumbnail
    ADD CONSTRAINT easy_thumbnails_thumbnai_storage_hash_name_source_fb375270_uniq UNIQUE (storage_hash, name, source_id);
 �   ALTER TABLE ONLY public.easy_thumbnails_thumbnail DROP CONSTRAINT easy_thumbnails_thumbnai_storage_hash_name_source_fb375270_uniq;
       public            taiga    false    220    220    220            �           2606    7501961 8   easy_thumbnails_thumbnail easy_thumbnails_thumbnail_pkey 
   CONSTRAINT     v   ALTER TABLE ONLY public.easy_thumbnails_thumbnail
    ADD CONSTRAINT easy_thumbnails_thumbnail_pkey PRIMARY KEY (id);
 b   ALTER TABLE ONLY public.easy_thumbnails_thumbnail DROP CONSTRAINT easy_thumbnails_thumbnail_pkey;
       public            taiga    false    220            �           2606    7501988 L   easy_thumbnails_thumbnaildimensions easy_thumbnails_thumbnaildimensions_pkey 
   CONSTRAINT     �   ALTER TABLE ONLY public.easy_thumbnails_thumbnaildimensions
    ADD CONSTRAINT easy_thumbnails_thumbnaildimensions_pkey PRIMARY KEY (id);
 v   ALTER TABLE ONLY public.easy_thumbnails_thumbnaildimensions DROP CONSTRAINT easy_thumbnails_thumbnaildimensions_pkey;
       public            taiga    false    222            �           2606    7501990 X   easy_thumbnails_thumbnaildimensions easy_thumbnails_thumbnaildimensions_thumbnail_id_key 
   CONSTRAINT     �   ALTER TABLE ONLY public.easy_thumbnails_thumbnaildimensions
    ADD CONSTRAINT easy_thumbnails_thumbnaildimensions_thumbnail_id_key UNIQUE (thumbnail_id);
 �   ALTER TABLE ONLY public.easy_thumbnails_thumbnaildimensions DROP CONSTRAINT easy_thumbnails_thumbnaildimensions_thumbnail_id_key;
       public            taiga    false    222                       2606    7502357 .   procrastinate_events procrastinate_events_pkey 
   CONSTRAINT     l   ALTER TABLE ONLY public.procrastinate_events
    ADD CONSTRAINT procrastinate_events_pkey PRIMARY KEY (id);
 X   ALTER TABLE ONLY public.procrastinate_events DROP CONSTRAINT procrastinate_events_pkey;
       public            taiga    false    242            �           2606    7502332 *   procrastinate_jobs procrastinate_jobs_pkey 
   CONSTRAINT     h   ALTER TABLE ONLY public.procrastinate_jobs
    ADD CONSTRAINT procrastinate_jobs_pkey PRIMARY KEY (id);
 T   ALTER TABLE ONLY public.procrastinate_jobs DROP CONSTRAINT procrastinate_jobs_pkey;
       public            taiga    false    238            �           2606    7502341 @   procrastinate_periodic_defers procrastinate_periodic_defers_pkey 
   CONSTRAINT     ~   ALTER TABLE ONLY public.procrastinate_periodic_defers
    ADD CONSTRAINT procrastinate_periodic_defers_pkey PRIMARY KEY (id);
 j   ALTER TABLE ONLY public.procrastinate_periodic_defers DROP CONSTRAINT procrastinate_periodic_defers_pkey;
       public            taiga    false    240                       2606    7502343 B   procrastinate_periodic_defers procrastinate_periodic_defers_unique 
   CONSTRAINT     �   ALTER TABLE ONLY public.procrastinate_periodic_defers
    ADD CONSTRAINT procrastinate_periodic_defers_unique UNIQUE (task_name, periodic_id, defer_timestamp);
 l   ALTER TABLE ONLY public.procrastinate_periodic_defers DROP CONSTRAINT procrastinate_periodic_defers_unique;
       public            taiga    false    240    240    240            �           2606    7502085 R   projects_invitations_projectinvitation projects_invitations_projectinvitation_pkey 
   CONSTRAINT     �   ALTER TABLE ONLY public.projects_invitations_projectinvitation
    ADD CONSTRAINT projects_invitations_projectinvitation_pkey PRIMARY KEY (id);
 |   ALTER TABLE ONLY public.projects_invitations_projectinvitation DROP CONSTRAINT projects_invitations_projectinvitation_pkey;
       public            taiga    false    228            �           2606    7502090 b   projects_invitations_projectinvitation projects_invitations_projectinvitation_unique_project_email 
   CONSTRAINT     �   ALTER TABLE ONLY public.projects_invitations_projectinvitation
    ADD CONSTRAINT projects_invitations_projectinvitation_unique_project_email UNIQUE (project_id, email);
 �   ALTER TABLE ONLY public.projects_invitations_projectinvitation DROP CONSTRAINT projects_invitations_projectinvitation_unique_project_email;
       public            taiga    false    228    228            �           2606    7502046 R   projects_memberships_projectmembership projects_memberships_projectmembership_pkey 
   CONSTRAINT     �   ALTER TABLE ONLY public.projects_memberships_projectmembership
    ADD CONSTRAINT projects_memberships_projectmembership_pkey PRIMARY KEY (id);
 |   ALTER TABLE ONLY public.projects_memberships_projectmembership DROP CONSTRAINT projects_memberships_projectmembership_pkey;
       public            taiga    false    227            �           2606    7502049 a   projects_memberships_projectmembership projects_memberships_projectmembership_unique_project_user 
   CONSTRAINT     �   ALTER TABLE ONLY public.projects_memberships_projectmembership
    ADD CONSTRAINT projects_memberships_projectmembership_unique_project_user UNIQUE (project_id, user_id);
 �   ALTER TABLE ONLY public.projects_memberships_projectmembership DROP CONSTRAINT projects_memberships_projectmembership_unique_project_user;
       public            taiga    false    227    227            �           2606    7502008 &   projects_project projects_project_pkey 
   CONSTRAINT     d   ALTER TABLE ONLY public.projects_project
    ADD CONSTRAINT projects_project_pkey PRIMARY KEY (id);
 P   ALTER TABLE ONLY public.projects_project DROP CONSTRAINT projects_project_pkey;
       public            taiga    false    224            �           2606    7502016 6   projects_projecttemplate projects_projecttemplate_pkey 
   CONSTRAINT     t   ALTER TABLE ONLY public.projects_projecttemplate
    ADD CONSTRAINT projects_projecttemplate_pkey PRIMARY KEY (id);
 `   ALTER TABLE ONLY public.projects_projecttemplate DROP CONSTRAINT projects_projecttemplate_pkey;
       public            taiga    false    225            �           2606    7502018 :   projects_projecttemplate projects_projecttemplate_slug_key 
   CONSTRAINT     u   ALTER TABLE ONLY public.projects_projecttemplate
    ADD CONSTRAINT projects_projecttemplate_slug_key UNIQUE (slug);
 d   ALTER TABLE ONLY public.projects_projecttemplate DROP CONSTRAINT projects_projecttemplate_slug_key;
       public            taiga    false    225            �           2606    7502028 :   projects_roles_projectrole projects_roles_projectrole_pkey 
   CONSTRAINT     x   ALTER TABLE ONLY public.projects_roles_projectrole
    ADD CONSTRAINT projects_roles_projectrole_pkey PRIMARY KEY (id);
 d   ALTER TABLE ONLY public.projects_roles_projectrole DROP CONSTRAINT projects_roles_projectrole_pkey;
       public            taiga    false    226            �           2606    7502033 I   projects_roles_projectrole projects_roles_projectrole_unique_project_name 
   CONSTRAINT     �   ALTER TABLE ONLY public.projects_roles_projectrole
    ADD CONSTRAINT projects_roles_projectrole_unique_project_name UNIQUE (project_id, name);
 s   ALTER TABLE ONLY public.projects_roles_projectrole DROP CONSTRAINT projects_roles_projectrole_unique_project_name;
       public            taiga    false    226    226            �           2606    7502031 I   projects_roles_projectrole projects_roles_projectrole_unique_project_slug 
   CONSTRAINT     �   ALTER TABLE ONLY public.projects_roles_projectrole
    ADD CONSTRAINT projects_roles_projectrole_unique_project_slug UNIQUE (project_id, slug);
 s   ALTER TABLE ONLY public.projects_roles_projectrole DROP CONSTRAINT projects_roles_projectrole_unique_project_slug;
       public            taiga    false    226    226            �           2606    7502181 "   stories_story projects_unique_refs 
   CONSTRAINT     h   ALTER TABLE ONLY public.stories_story
    ADD CONSTRAINT projects_unique_refs UNIQUE (project_id, ref);
 L   ALTER TABLE ONLY public.stories_story DROP CONSTRAINT projects_unique_refs;
       public            taiga    false    232    232            �           2606    7502178     stories_story stories_story_pkey 
   CONSTRAINT     ^   ALTER TABLE ONLY public.stories_story
    ADD CONSTRAINT stories_story_pkey PRIMARY KEY (id);
 J   ALTER TABLE ONLY public.stories_story DROP CONSTRAINT stories_story_pkey;
       public            taiga    false    232            �           2606    7502221 2   tokens_denylistedtoken tokens_denylistedtoken_pkey 
   CONSTRAINT     p   ALTER TABLE ONLY public.tokens_denylistedtoken
    ADD CONSTRAINT tokens_denylistedtoken_pkey PRIMARY KEY (id);
 \   ALTER TABLE ONLY public.tokens_denylistedtoken DROP CONSTRAINT tokens_denylistedtoken_pkey;
       public            taiga    false    234            �           2606    7502223 :   tokens_denylistedtoken tokens_denylistedtoken_token_id_key 
   CONSTRAINT     y   ALTER TABLE ONLY public.tokens_denylistedtoken
    ADD CONSTRAINT tokens_denylistedtoken_token_id_key UNIQUE (token_id);
 d   ALTER TABLE ONLY public.tokens_denylistedtoken DROP CONSTRAINT tokens_denylistedtoken_token_id_key;
       public            taiga    false    234            �           2606    7502216 7   tokens_outstandingtoken tokens_outstandingtoken_jti_key 
   CONSTRAINT     q   ALTER TABLE ONLY public.tokens_outstandingtoken
    ADD CONSTRAINT tokens_outstandingtoken_jti_key UNIQUE (jti);
 a   ALTER TABLE ONLY public.tokens_outstandingtoken DROP CONSTRAINT tokens_outstandingtoken_jti_key;
       public            taiga    false    233            �           2606    7502214 4   tokens_outstandingtoken tokens_outstandingtoken_pkey 
   CONSTRAINT     r   ALTER TABLE ONLY public.tokens_outstandingtoken
    ADD CONSTRAINT tokens_outstandingtoken_pkey PRIMARY KEY (id);
 ^   ALTER TABLE ONLY public.tokens_outstandingtoken DROP CONSTRAINT tokens_outstandingtoken_pkey;
       public            taiga    false    233            _           2606    7501843 "   users_authdata users_authdata_pkey 
   CONSTRAINT     `   ALTER TABLE ONLY public.users_authdata
    ADD CONSTRAINT users_authdata_pkey PRIMARY KEY (id);
 L   ALTER TABLE ONLY public.users_authdata DROP CONSTRAINT users_authdata_pkey;
       public            taiga    false    206            a           2606    7501848 -   users_authdata users_authdata_unique_user_key 
   CONSTRAINT     p   ALTER TABLE ONLY public.users_authdata
    ADD CONSTRAINT users_authdata_unique_user_key UNIQUE (user_id, key);
 W   ALTER TABLE ONLY public.users_authdata DROP CONSTRAINT users_authdata_unique_user_key;
       public            taiga    false    206    206            T           2606    7501835    users_user users_user_email_key 
   CONSTRAINT     [   ALTER TABLE ONLY public.users_user
    ADD CONSTRAINT users_user_email_key UNIQUE (email);
 I   ALTER TABLE ONLY public.users_user DROP CONSTRAINT users_user_email_key;
       public            taiga    false    205            V           2606    7501831    users_user users_user_pkey 
   CONSTRAINT     X   ALTER TABLE ONLY public.users_user
    ADD CONSTRAINT users_user_pkey PRIMARY KEY (id);
 D   ALTER TABLE ONLY public.users_user DROP CONSTRAINT users_user_pkey;
       public            taiga    false    205            Z           2606    7501833 "   users_user users_user_username_key 
   CONSTRAINT     a   ALTER TABLE ONLY public.users_user
    ADD CONSTRAINT users_user_username_key UNIQUE (username);
 L   ALTER TABLE ONLY public.users_user DROP CONSTRAINT users_user_username_key;
       public            taiga    false    205            �           2606    7502144 *   workflows_workflow workflows_workflow_pkey 
   CONSTRAINT     h   ALTER TABLE ONLY public.workflows_workflow
    ADD CONSTRAINT workflows_workflow_pkey PRIMARY KEY (id);
 T   ALTER TABLE ONLY public.workflows_workflow DROP CONSTRAINT workflows_workflow_pkey;
       public            taiga    false    230            �           2606    7502158 9   workflows_workflow workflows_workflow_unique_project_name 
   CONSTRAINT     �   ALTER TABLE ONLY public.workflows_workflow
    ADD CONSTRAINT workflows_workflow_unique_project_name UNIQUE (project_id, name);
 c   ALTER TABLE ONLY public.workflows_workflow DROP CONSTRAINT workflows_workflow_unique_project_name;
       public            taiga    false    230    230            �           2606    7502156 9   workflows_workflow workflows_workflow_unique_project_slug 
   CONSTRAINT     �   ALTER TABLE ONLY public.workflows_workflow
    ADD CONSTRAINT workflows_workflow_unique_project_slug UNIQUE (project_id, slug);
 c   ALTER TABLE ONLY public.workflows_workflow DROP CONSTRAINT workflows_workflow_unique_project_slug;
       public            taiga    false    230    230            �           2606    7502152 6   workflows_workflowstatus workflows_workflowstatus_pkey 
   CONSTRAINT     t   ALTER TABLE ONLY public.workflows_workflowstatus
    ADD CONSTRAINT workflows_workflowstatus_pkey PRIMARY KEY (id);
 `   ALTER TABLE ONLY public.workflows_workflowstatus DROP CONSTRAINT workflows_workflowstatus_pkey;
       public            taiga    false    231            �           2606    7502265 Z   workspaces_memberships_workspacemembership workspaces_memberships_workspacemembership_pkey 
   CONSTRAINT     �   ALTER TABLE ONLY public.workspaces_memberships_workspacemembership
    ADD CONSTRAINT workspaces_memberships_workspacemembership_pkey PRIMARY KEY (id);
 �   ALTER TABLE ONLY public.workspaces_memberships_workspacemembership DROP CONSTRAINT workspaces_memberships_workspacemembership_pkey;
       public            taiga    false    236            �           2606    7502268 j   workspaces_memberships_workspacemembership workspaces_memberships_workspacemembership_unique_workspace_use 
   CONSTRAINT     �   ALTER TABLE ONLY public.workspaces_memberships_workspacemembership
    ADD CONSTRAINT workspaces_memberships_workspacemembership_unique_workspace_use UNIQUE (workspace_id, user_id);
 �   ALTER TABLE ONLY public.workspaces_memberships_workspacemembership DROP CONSTRAINT workspaces_memberships_workspacemembership_unique_workspace_use;
       public            taiga    false    236    236            �           2606    7502247 B   workspaces_roles_workspacerole workspaces_roles_workspacerole_pkey 
   CONSTRAINT     �   ALTER TABLE ONLY public.workspaces_roles_workspacerole
    ADD CONSTRAINT workspaces_roles_workspacerole_pkey PRIMARY KEY (id);
 l   ALTER TABLE ONLY public.workspaces_roles_workspacerole DROP CONSTRAINT workspaces_roles_workspacerole_pkey;
       public            taiga    false    235            �           2606    7502252 S   workspaces_roles_workspacerole workspaces_roles_workspacerole_unique_workspace_name 
   CONSTRAINT     �   ALTER TABLE ONLY public.workspaces_roles_workspacerole
    ADD CONSTRAINT workspaces_roles_workspacerole_unique_workspace_name UNIQUE (workspace_id, name);
 }   ALTER TABLE ONLY public.workspaces_roles_workspacerole DROP CONSTRAINT workspaces_roles_workspacerole_unique_workspace_name;
       public            taiga    false    235    235            �           2606    7502250 S   workspaces_roles_workspacerole workspaces_roles_workspacerole_unique_workspace_slug 
   CONSTRAINT     �   ALTER TABLE ONLY public.workspaces_roles_workspacerole
    ADD CONSTRAINT workspaces_roles_workspacerole_unique_workspace_slug UNIQUE (workspace_id, slug);
 }   ALTER TABLE ONLY public.workspaces_roles_workspacerole DROP CONSTRAINT workspaces_roles_workspacerole_unique_workspace_slug;
       public            taiga    false    235    235            �           2606    7502000 .   workspaces_workspace workspaces_workspace_pkey 
   CONSTRAINT     l   ALTER TABLE ONLY public.workspaces_workspace
    ADD CONSTRAINT workspaces_workspace_pkey PRIMARY KEY (id);
 X   ALTER TABLE ONLY public.workspaces_workspace DROP CONSTRAINT workspaces_workspace_pkey;
       public            taiga    false    223            p           1259    7501939    auth_group_name_a6ea08ec_like    INDEX     h   CREATE INDEX auth_group_name_a6ea08ec_like ON public.auth_group USING btree (name varchar_pattern_ops);
 1   DROP INDEX public.auth_group_name_a6ea08ec_like;
       public            taiga    false    214            u           1259    7501935 (   auth_group_permissions_group_id_b120cbf9    INDEX     o   CREATE INDEX auth_group_permissions_group_id_b120cbf9 ON public.auth_group_permissions USING btree (group_id);
 <   DROP INDEX public.auth_group_permissions_group_id_b120cbf9;
       public            taiga    false    216            x           1259    7501936 -   auth_group_permissions_permission_id_84c5c92e    INDEX     y   CREATE INDEX auth_group_permissions_permission_id_84c5c92e ON public.auth_group_permissions USING btree (permission_id);
 A   DROP INDEX public.auth_group_permissions_permission_id_84c5c92e;
       public            taiga    false    216            k           1259    7501921 (   auth_permission_content_type_id_2f476e4b    INDEX     o   CREATE INDEX auth_permission_content_type_id_2f476e4b ON public.auth_permission USING btree (content_type_id);
 <   DROP INDEX public.auth_permission_content_type_id_2f476e4b;
       public            taiga    false    212            g           1259    7501889 )   django_admin_log_content_type_id_c4bce8eb    INDEX     q   CREATE INDEX django_admin_log_content_type_id_c4bce8eb ON public.django_admin_log USING btree (content_type_id);
 =   DROP INDEX public.django_admin_log_content_type_id_c4bce8eb;
       public            taiga    false    210            j           1259    7501890 !   django_admin_log_user_id_c564eba6    INDEX     a   CREATE INDEX django_admin_log_user_id_c564eba6 ON public.django_admin_log USING btree (user_id);
 5   DROP INDEX public.django_admin_log_user_id_c564eba6;
       public            taiga    false    210            �           1259    7502136 #   django_session_expire_date_a5c62663    INDEX     e   CREATE INDEX django_session_expire_date_a5c62663 ON public.django_session USING btree (expire_date);
 7   DROP INDEX public.django_session_expire_date_a5c62663;
       public            taiga    false    229            �           1259    7502135 (   django_session_session_key_c0390e0f_like    INDEX     ~   CREATE INDEX django_session_session_key_c0390e0f_like ON public.django_session USING btree (session_key varchar_pattern_ops);
 <   DROP INDEX public.django_session_session_key_c0390e0f_like;
       public            taiga    false    229            {           1259    7501968 $   easy_thumbnails_source_name_5fe0edc6    INDEX     g   CREATE INDEX easy_thumbnails_source_name_5fe0edc6 ON public.easy_thumbnails_source USING btree (name);
 8   DROP INDEX public.easy_thumbnails_source_name_5fe0edc6;
       public            taiga    false    218            |           1259    7501969 )   easy_thumbnails_source_name_5fe0edc6_like    INDEX     �   CREATE INDEX easy_thumbnails_source_name_5fe0edc6_like ON public.easy_thumbnails_source USING btree (name varchar_pattern_ops);
 =   DROP INDEX public.easy_thumbnails_source_name_5fe0edc6_like;
       public            taiga    false    218                       1259    7501966 ,   easy_thumbnails_source_storage_hash_946cbcc9    INDEX     w   CREATE INDEX easy_thumbnails_source_storage_hash_946cbcc9 ON public.easy_thumbnails_source USING btree (storage_hash);
 @   DROP INDEX public.easy_thumbnails_source_storage_hash_946cbcc9;
       public            taiga    false    218            �           1259    7501967 1   easy_thumbnails_source_storage_hash_946cbcc9_like    INDEX     �   CREATE INDEX easy_thumbnails_source_storage_hash_946cbcc9_like ON public.easy_thumbnails_source USING btree (storage_hash varchar_pattern_ops);
 E   DROP INDEX public.easy_thumbnails_source_storage_hash_946cbcc9_like;
       public            taiga    false    218            �           1259    7501977 '   easy_thumbnails_thumbnail_name_b5882c31    INDEX     m   CREATE INDEX easy_thumbnails_thumbnail_name_b5882c31 ON public.easy_thumbnails_thumbnail USING btree (name);
 ;   DROP INDEX public.easy_thumbnails_thumbnail_name_b5882c31;
       public            taiga    false    220            �           1259    7501978 ,   easy_thumbnails_thumbnail_name_b5882c31_like    INDEX     �   CREATE INDEX easy_thumbnails_thumbnail_name_b5882c31_like ON public.easy_thumbnails_thumbnail USING btree (name varchar_pattern_ops);
 @   DROP INDEX public.easy_thumbnails_thumbnail_name_b5882c31_like;
       public            taiga    false    220            �           1259    7501979 ,   easy_thumbnails_thumbnail_source_id_5b57bc77    INDEX     w   CREATE INDEX easy_thumbnails_thumbnail_source_id_5b57bc77 ON public.easy_thumbnails_thumbnail USING btree (source_id);
 @   DROP INDEX public.easy_thumbnails_thumbnail_source_id_5b57bc77;
       public            taiga    false    220            �           1259    7501975 /   easy_thumbnails_thumbnail_storage_hash_f1435f49    INDEX     }   CREATE INDEX easy_thumbnails_thumbnail_storage_hash_f1435f49 ON public.easy_thumbnails_thumbnail USING btree (storage_hash);
 C   DROP INDEX public.easy_thumbnails_thumbnail_storage_hash_f1435f49;
       public            taiga    false    220            �           1259    7501976 4   easy_thumbnails_thumbnail_storage_hash_f1435f49_like    INDEX     �   CREATE INDEX easy_thumbnails_thumbnail_storage_hash_f1435f49_like ON public.easy_thumbnails_thumbnail USING btree (storage_hash varchar_pattern_ops);
 H   DROP INDEX public.easy_thumbnails_thumbnail_storage_hash_f1435f49_like;
       public            taiga    false    220                       1259    7502367     procrastinate_events_job_id_fkey    INDEX     c   CREATE INDEX procrastinate_events_job_id_fkey ON public.procrastinate_events USING btree (job_id);
 4   DROP INDEX public.procrastinate_events_job_id_fkey;
       public            taiga    false    242            �           1259    7502366    procrastinate_jobs_id_lock_idx    INDEX     �   CREATE INDEX procrastinate_jobs_id_lock_idx ON public.procrastinate_jobs USING btree (id, lock) WHERE (status = ANY (ARRAY['todo'::public.procrastinate_job_status, 'doing'::public.procrastinate_job_status]));
 2   DROP INDEX public.procrastinate_jobs_id_lock_idx;
       public            taiga    false    238    238    238    871            �           1259    7502364    procrastinate_jobs_lock_idx    INDEX     �   CREATE UNIQUE INDEX procrastinate_jobs_lock_idx ON public.procrastinate_jobs USING btree (lock) WHERE (status = 'doing'::public.procrastinate_job_status);
 /   DROP INDEX public.procrastinate_jobs_lock_idx;
       public            taiga    false    238    238    871            �           1259    7502365 !   procrastinate_jobs_queue_name_idx    INDEX     f   CREATE INDEX procrastinate_jobs_queue_name_idx ON public.procrastinate_jobs USING btree (queue_name);
 5   DROP INDEX public.procrastinate_jobs_queue_name_idx;
       public            taiga    false    238            �           1259    7502363 $   procrastinate_jobs_queueing_lock_idx    INDEX     �   CREATE UNIQUE INDEX procrastinate_jobs_queueing_lock_idx ON public.procrastinate_jobs USING btree (queueing_lock) WHERE (status = 'todo'::public.procrastinate_job_status);
 8   DROP INDEX public.procrastinate_jobs_queueing_lock_idx;
       public            taiga    false    238    238    871            �           1259    7502368 )   procrastinate_periodic_defers_job_id_fkey    INDEX     u   CREATE INDEX procrastinate_periodic_defers_job_id_fkey ON public.procrastinate_periodic_defers USING btree (job_id);
 =   DROP INDEX public.procrastinate_periodic_defers_job_id_fkey;
       public            taiga    false    240            �           1259    7502086    projects_in_email_07fdb9_idx    INDEX     p   CREATE INDEX projects_in_email_07fdb9_idx ON public.projects_invitations_projectinvitation USING btree (email);
 0   DROP INDEX public.projects_in_email_07fdb9_idx;
       public            taiga    false    228            �           1259    7502088    projects_in_project_ac92b3_idx    INDEX     �   CREATE INDEX projects_in_project_ac92b3_idx ON public.projects_invitations_projectinvitation USING btree (project_id, user_id);
 2   DROP INDEX public.projects_in_project_ac92b3_idx;
       public            taiga    false    228    228            �           1259    7502087    projects_in_project_d7d2d6_idx    INDEX     ~   CREATE INDEX projects_in_project_d7d2d6_idx ON public.projects_invitations_projectinvitation USING btree (project_id, email);
 2   DROP INDEX public.projects_in_project_d7d2d6_idx;
       public            taiga    false    228    228            �           1259    7502121 =   projects_invitations_projectinvitation_invited_by_id_e41218dc    INDEX     �   CREATE INDEX projects_invitations_projectinvitation_invited_by_id_e41218dc ON public.projects_invitations_projectinvitation USING btree (invited_by_id);
 Q   DROP INDEX public.projects_invitations_projectinvitation_invited_by_id_e41218dc;
       public            taiga    false    228            �           1259    7502122 :   projects_invitations_projectinvitation_project_id_8a729cae    INDEX     �   CREATE INDEX projects_invitations_projectinvitation_project_id_8a729cae ON public.projects_invitations_projectinvitation USING btree (project_id);
 N   DROP INDEX public.projects_invitations_projectinvitation_project_id_8a729cae;
       public            taiga    false    228            �           1259    7502123 <   projects_invitations_projectinvitation_resent_by_id_68c580e8    INDEX     �   CREATE INDEX projects_invitations_projectinvitation_resent_by_id_68c580e8 ON public.projects_invitations_projectinvitation USING btree (resent_by_id);
 P   DROP INDEX public.projects_invitations_projectinvitation_resent_by_id_68c580e8;
       public            taiga    false    228            �           1259    7502124 =   projects_invitations_projectinvitation_revoked_by_id_8a8e629a    INDEX     �   CREATE INDEX projects_invitations_projectinvitation_revoked_by_id_8a8e629a ON public.projects_invitations_projectinvitation USING btree (revoked_by_id);
 Q   DROP INDEX public.projects_invitations_projectinvitation_revoked_by_id_8a8e629a;
       public            taiga    false    228            �           1259    7502125 7   projects_invitations_projectinvitation_role_id_bb735b0e    INDEX     �   CREATE INDEX projects_invitations_projectinvitation_role_id_bb735b0e ON public.projects_invitations_projectinvitation USING btree (role_id);
 K   DROP INDEX public.projects_invitations_projectinvitation_role_id_bb735b0e;
       public            taiga    false    228            �           1259    7502126 7   projects_invitations_projectinvitation_user_id_995e9b1c    INDEX     �   CREATE INDEX projects_invitations_projectinvitation_user_id_995e9b1c ON public.projects_invitations_projectinvitation USING btree (user_id);
 K   DROP INDEX public.projects_invitations_projectinvitation_user_id_995e9b1c;
       public            taiga    false    228            �           1259    7502047    projects_me_project_3bd46e_idx    INDEX     �   CREATE INDEX projects_me_project_3bd46e_idx ON public.projects_memberships_projectmembership USING btree (project_id, user_id);
 2   DROP INDEX public.projects_me_project_3bd46e_idx;
       public            taiga    false    227    227            �           1259    7502065 :   projects_memberships_projectmembership_project_id_7592284f    INDEX     �   CREATE INDEX projects_memberships_projectmembership_project_id_7592284f ON public.projects_memberships_projectmembership USING btree (project_id);
 N   DROP INDEX public.projects_memberships_projectmembership_project_id_7592284f;
       public            taiga    false    227            �           1259    7502066 7   projects_memberships_projectmembership_role_id_43773f6c    INDEX     �   CREATE INDEX projects_memberships_projectmembership_role_id_43773f6c ON public.projects_memberships_projectmembership USING btree (role_id);
 K   DROP INDEX public.projects_memberships_projectmembership_role_id_43773f6c;
       public            taiga    false    227            �           1259    7502067 7   projects_memberships_projectmembership_user_id_8a613b51    INDEX     �   CREATE INDEX projects_memberships_projectmembership_user_id_8a613b51 ON public.projects_memberships_projectmembership USING btree (user_id);
 K   DROP INDEX public.projects_memberships_projectmembership_user_id_8a613b51;
       public            taiga    false    227            �           1259    7502019    projects_pr_slug_28d8d6_idx    INDEX     `   CREATE INDEX projects_pr_slug_28d8d6_idx ON public.projects_projecttemplate USING btree (slug);
 /   DROP INDEX public.projects_pr_slug_28d8d6_idx;
       public            taiga    false    225            �           1259    7502079    projects_pr_workspa_2e7a5b_idx    INDEX     g   CREATE INDEX projects_pr_workspa_2e7a5b_idx ON public.projects_project USING btree (workspace_id, id);
 2   DROP INDEX public.projects_pr_workspa_2e7a5b_idx;
       public            taiga    false    224    224            �           1259    7502073 "   projects_project_owner_id_b940de39    INDEX     c   CREATE INDEX projects_project_owner_id_b940de39 ON public.projects_project USING btree (owner_id);
 6   DROP INDEX public.projects_project_owner_id_b940de39;
       public            taiga    false    224            �           1259    7502080 &   projects_project_workspace_id_7ea54f67    INDEX     k   CREATE INDEX projects_project_workspace_id_7ea54f67 ON public.projects_project USING btree (workspace_id);
 :   DROP INDEX public.projects_project_workspace_id_7ea54f67;
       public            taiga    false    224            �           1259    7502020 +   projects_projecttemplate_slug_2731738e_like    INDEX     �   CREATE INDEX projects_projecttemplate_slug_2731738e_like ON public.projects_projecttemplate USING btree (slug varchar_pattern_ops);
 ?   DROP INDEX public.projects_projecttemplate_slug_2731738e_like;
       public            taiga    false    225            �           1259    7502029    projects_ro_project_63cac9_idx    INDEX     q   CREATE INDEX projects_ro_project_63cac9_idx ON public.projects_roles_projectrole USING btree (project_id, slug);
 2   DROP INDEX public.projects_ro_project_63cac9_idx;
       public            taiga    false    226    226            �           1259    7502041 .   projects_roles_projectrole_project_id_4efc0342    INDEX     {   CREATE INDEX projects_roles_projectrole_project_id_4efc0342 ON public.projects_roles_projectrole USING btree (project_id);
 B   DROP INDEX public.projects_roles_projectrole_project_id_4efc0342;
       public            taiga    false    226            �           1259    7502039 (   projects_roles_projectrole_slug_9eb663ce    INDEX     o   CREATE INDEX projects_roles_projectrole_slug_9eb663ce ON public.projects_roles_projectrole USING btree (slug);
 <   DROP INDEX public.projects_roles_projectrole_slug_9eb663ce;
       public            taiga    false    226            �           1259    7502040 -   projects_roles_projectrole_slug_9eb663ce_like    INDEX     �   CREATE INDEX projects_roles_projectrole_slug_9eb663ce_like ON public.projects_roles_projectrole USING btree (slug varchar_pattern_ops);
 A   DROP INDEX public.projects_roles_projectrole_slug_9eb663ce_like;
       public            taiga    false    226            �           1259    7502179    stories_sto_project_840ba5_idx    INDEX     c   CREATE INDEX stories_sto_project_840ba5_idx ON public.stories_story USING btree (project_id, ref);
 2   DROP INDEX public.stories_sto_project_840ba5_idx;
       public            taiga    false    232    232            �           1259    7502203 $   stories_story_created_by_id_052bf6c8    INDEX     g   CREATE INDEX stories_story_created_by_id_052bf6c8 ON public.stories_story USING btree (created_by_id);
 8   DROP INDEX public.stories_story_created_by_id_052bf6c8;
       public            taiga    false    232            �           1259    7502204 !   stories_story_project_id_c78d9ba8    INDEX     a   CREATE INDEX stories_story_project_id_c78d9ba8 ON public.stories_story USING btree (project_id);
 5   DROP INDEX public.stories_story_project_id_c78d9ba8;
       public            taiga    false    232            �           1259    7502202    stories_story_ref_07544f5a    INDEX     S   CREATE INDEX stories_story_ref_07544f5a ON public.stories_story USING btree (ref);
 .   DROP INDEX public.stories_story_ref_07544f5a;
       public            taiga    false    232            �           1259    7502205     stories_story_status_id_15c8b6c9    INDEX     _   CREATE INDEX stories_story_status_id_15c8b6c9 ON public.stories_story USING btree (status_id);
 4   DROP INDEX public.stories_story_status_id_15c8b6c9;
       public            taiga    false    232            �           1259    7502206 "   stories_story_workflow_id_448ab642    INDEX     c   CREATE INDEX stories_story_workflow_id_448ab642 ON public.stories_story USING btree (workflow_id);
 6   DROP INDEX public.stories_story_workflow_id_448ab642;
       public            taiga    false    232            �           1259    7502227    tokens_deny_token_i_25cc28_idx    INDEX     e   CREATE INDEX tokens_deny_token_i_25cc28_idx ON public.tokens_denylistedtoken USING btree (token_id);
 2   DROP INDEX public.tokens_deny_token_i_25cc28_idx;
       public            taiga    false    234            �           1259    7502224    tokens_outs_content_1b2775_idx    INDEX     �   CREATE INDEX tokens_outs_content_1b2775_idx ON public.tokens_outstandingtoken USING btree (content_type_id, object_id, token_type);
 2   DROP INDEX public.tokens_outs_content_1b2775_idx;
       public            taiga    false    233    233    233            �           1259    7502226    tokens_outs_expires_ce645d_idx    INDEX     h   CREATE INDEX tokens_outs_expires_ce645d_idx ON public.tokens_outstandingtoken USING btree (expires_at);
 2   DROP INDEX public.tokens_outs_expires_ce645d_idx;
       public            taiga    false    233            �           1259    7502225    tokens_outs_jti_766f39_idx    INDEX     ]   CREATE INDEX tokens_outs_jti_766f39_idx ON public.tokens_outstandingtoken USING btree (jti);
 .   DROP INDEX public.tokens_outs_jti_766f39_idx;
       public            taiga    false    233            �           1259    7502234 0   tokens_outstandingtoken_content_type_id_06cfd70a    INDEX        CREATE INDEX tokens_outstandingtoken_content_type_id_06cfd70a ON public.tokens_outstandingtoken USING btree (content_type_id);
 D   DROP INDEX public.tokens_outstandingtoken_content_type_id_06cfd70a;
       public            taiga    false    233            �           1259    7502233 )   tokens_outstandingtoken_jti_ac7232c7_like    INDEX     �   CREATE INDEX tokens_outstandingtoken_jti_ac7232c7_like ON public.tokens_outstandingtoken USING btree (jti varchar_pattern_ops);
 =   DROP INDEX public.tokens_outstandingtoken_jti_ac7232c7_like;
       public            taiga    false    233            [           1259    7501846    users_authd_user_id_d24d4c_idx    INDEX     a   CREATE INDEX users_authd_user_id_d24d4c_idx ON public.users_authdata USING btree (user_id, key);
 2   DROP INDEX public.users_authd_user_id_d24d4c_idx;
       public            taiga    false    206    206            \           1259    7501856    users_authdata_key_c3b89eef    INDEX     U   CREATE INDEX users_authdata_key_c3b89eef ON public.users_authdata USING btree (key);
 /   DROP INDEX public.users_authdata_key_c3b89eef;
       public            taiga    false    206            ]           1259    7501857     users_authdata_key_c3b89eef_like    INDEX     n   CREATE INDEX users_authdata_key_c3b89eef_like ON public.users_authdata USING btree (key varchar_pattern_ops);
 4   DROP INDEX public.users_authdata_key_c3b89eef_like;
       public            taiga    false    206            b           1259    7501858    users_authdata_user_id_9625853a    INDEX     ]   CREATE INDEX users_authdata_user_id_9625853a ON public.users_authdata USING btree (user_id);
 3   DROP INDEX public.users_authdata_user_id_9625853a;
       public            taiga    false    206            Q           1259    7501850    users_user_email_243f6e77_like    INDEX     j   CREATE INDEX users_user_email_243f6e77_like ON public.users_user USING btree (email varchar_pattern_ops);
 2   DROP INDEX public.users_user_email_243f6e77_like;
       public            taiga    false    205            R           1259    7501845    users_user_email_6f2530_idx    INDEX     S   CREATE INDEX users_user_email_6f2530_idx ON public.users_user USING btree (email);
 /   DROP INDEX public.users_user_email_6f2530_idx;
       public            taiga    false    205            W           1259    7501844    users_user_usernam_65d164_idx    INDEX     X   CREATE INDEX users_user_usernam_65d164_idx ON public.users_user USING btree (username);
 1   DROP INDEX public.users_user_usernam_65d164_idx;
       public            taiga    false    205            X           1259    7501849 !   users_user_username_06e46fe6_like    INDEX     p   CREATE INDEX users_user_username_06e46fe6_like ON public.users_user USING btree (username varchar_pattern_ops);
 5   DROP INDEX public.users_user_username_06e46fe6_like;
       public            taiga    false    205            �           1259    7502154    workflows_w_project_5a96f0_idx    INDEX     i   CREATE INDEX workflows_w_project_5a96f0_idx ON public.workflows_workflow USING btree (project_id, slug);
 2   DROP INDEX public.workflows_w_project_5a96f0_idx;
       public            taiga    false    230    230            �           1259    7502153    workflows_w_workflo_b8ac5c_idx    INDEX     p   CREATE INDEX workflows_w_workflo_b8ac5c_idx ON public.workflows_workflowstatus USING btree (workflow_id, slug);
 2   DROP INDEX public.workflows_w_workflo_b8ac5c_idx;
       public            taiga    false    231    231            �           1259    7502164 &   workflows_workflow_project_id_59dd45ec    INDEX     k   CREATE INDEX workflows_workflow_project_id_59dd45ec ON public.workflows_workflow USING btree (project_id);
 :   DROP INDEX public.workflows_workflow_project_id_59dd45ec;
       public            taiga    false    230            �           1259    7502170 -   workflows_workflowstatus_workflow_id_8efaaa04    INDEX     y   CREATE INDEX workflows_workflowstatus_workflow_id_8efaaa04 ON public.workflows_workflowstatus USING btree (workflow_id);
 A   DROP INDEX public.workflows_workflowstatus_workflow_id_8efaaa04;
       public            taiga    false    231            �           1259    7502248    workspaces__workspa_2769b6_idx    INDEX     w   CREATE INDEX workspaces__workspa_2769b6_idx ON public.workspaces_roles_workspacerole USING btree (workspace_id, slug);
 2   DROP INDEX public.workspaces__workspa_2769b6_idx;
       public            taiga    false    235    235            �           1259    7502266    workspaces__workspa_e36c45_idx    INDEX     �   CREATE INDEX workspaces__workspa_e36c45_idx ON public.workspaces_memberships_workspacemembership USING btree (workspace_id, user_id);
 2   DROP INDEX public.workspaces__workspa_e36c45_idx;
       public            taiga    false    236    236            �           1259    7502286 0   workspaces_memberships_wor_workspace_id_fd6f07d4    INDEX     �   CREATE INDEX workspaces_memberships_wor_workspace_id_fd6f07d4 ON public.workspaces_memberships_workspacemembership USING btree (workspace_id);
 D   DROP INDEX public.workspaces_memberships_wor_workspace_id_fd6f07d4;
       public            taiga    false    236            �           1259    7502284 ;   workspaces_memberships_workspacemembership_role_id_4ea4e76e    INDEX     �   CREATE INDEX workspaces_memberships_workspacemembership_role_id_4ea4e76e ON public.workspaces_memberships_workspacemembership USING btree (role_id);
 O   DROP INDEX public.workspaces_memberships_workspacemembership_role_id_4ea4e76e;
       public            taiga    false    236            �           1259    7502285 ;   workspaces_memberships_workspacemembership_user_id_89b29e02    INDEX     �   CREATE INDEX workspaces_memberships_workspacemembership_user_id_89b29e02 ON public.workspaces_memberships_workspacemembership USING btree (user_id);
 O   DROP INDEX public.workspaces_memberships_workspacemembership_user_id_89b29e02;
       public            taiga    false    236            �           1259    7502258 ,   workspaces_roles_workspacerole_slug_6d21c03e    INDEX     w   CREATE INDEX workspaces_roles_workspacerole_slug_6d21c03e ON public.workspaces_roles_workspacerole USING btree (slug);
 @   DROP INDEX public.workspaces_roles_workspacerole_slug_6d21c03e;
       public            taiga    false    235            �           1259    7502259 1   workspaces_roles_workspacerole_slug_6d21c03e_like    INDEX     �   CREATE INDEX workspaces_roles_workspacerole_slug_6d21c03e_like ON public.workspaces_roles_workspacerole USING btree (slug varchar_pattern_ops);
 E   DROP INDEX public.workspaces_roles_workspacerole_slug_6d21c03e_like;
       public            taiga    false    235            �           1259    7502260 4   workspaces_roles_workspacerole_workspace_id_1aebcc14    INDEX     �   CREATE INDEX workspaces_roles_workspacerole_workspace_id_1aebcc14 ON public.workspaces_roles_workspacerole USING btree (workspace_id);
 H   DROP INDEX public.workspaces_roles_workspacerole_workspace_id_1aebcc14;
       public            taiga    false    235            �           1259    7502292 &   workspaces_workspace_owner_id_d8b120c0    INDEX     k   CREATE INDEX workspaces_workspace_owner_id_d8b120c0 ON public.workspaces_workspace USING btree (owner_id);
 :   DROP INDEX public.workspaces_workspace_owner_id_d8b120c0;
       public            taiga    false    223            (           2620    7502379 2   procrastinate_jobs procrastinate_jobs_notify_queue    TRIGGER     �   CREATE TRIGGER procrastinate_jobs_notify_queue AFTER INSERT ON public.procrastinate_jobs FOR EACH ROW WHEN ((new.status = 'todo'::public.procrastinate_job_status)) EXECUTE FUNCTION public.procrastinate_notify_queue();
 K   DROP TRIGGER procrastinate_jobs_notify_queue ON public.procrastinate_jobs;
       public          taiga    false    238    871    238    348            ,           2620    7502383 4   procrastinate_jobs procrastinate_trigger_delete_jobs    TRIGGER     �   CREATE TRIGGER procrastinate_trigger_delete_jobs BEFORE DELETE ON public.procrastinate_jobs FOR EACH ROW EXECUTE FUNCTION public.procrastinate_unlink_periodic_defers();
 M   DROP TRIGGER procrastinate_trigger_delete_jobs ON public.procrastinate_jobs;
       public          taiga    false    364    238            +           2620    7502382 9   procrastinate_jobs procrastinate_trigger_scheduled_events    TRIGGER     &  CREATE TRIGGER procrastinate_trigger_scheduled_events AFTER INSERT OR UPDATE ON public.procrastinate_jobs FOR EACH ROW WHEN (((new.scheduled_at IS NOT NULL) AND (new.status = 'todo'::public.procrastinate_job_status))) EXECUTE FUNCTION public.procrastinate_trigger_scheduled_events_procedure();
 R   DROP TRIGGER procrastinate_trigger_scheduled_events ON public.procrastinate_jobs;
       public          taiga    false    238    871    238    238    363            *           2620    7502381 =   procrastinate_jobs procrastinate_trigger_status_events_insert    TRIGGER     �   CREATE TRIGGER procrastinate_trigger_status_events_insert AFTER INSERT ON public.procrastinate_jobs FOR EACH ROW WHEN ((new.status = 'todo'::public.procrastinate_job_status)) EXECUTE FUNCTION public.procrastinate_trigger_status_events_procedure_insert();
 V   DROP TRIGGER procrastinate_trigger_status_events_insert ON public.procrastinate_jobs;
       public          taiga    false    238    361    238    871            )           2620    7502380 =   procrastinate_jobs procrastinate_trigger_status_events_update    TRIGGER     �   CREATE TRIGGER procrastinate_trigger_status_events_update AFTER UPDATE OF status ON public.procrastinate_jobs FOR EACH ROW EXECUTE FUNCTION public.procrastinate_trigger_status_events_procedure_update();
 V   DROP TRIGGER procrastinate_trigger_status_events_update ON public.procrastinate_jobs;
       public          taiga    false    238    362    238            
           2606    7501930 O   auth_group_permissions auth_group_permissio_permission_id_84c5c92e_fk_auth_perm    FK CONSTRAINT     �   ALTER TABLE ONLY public.auth_group_permissions
    ADD CONSTRAINT auth_group_permissio_permission_id_84c5c92e_fk_auth_perm FOREIGN KEY (permission_id) REFERENCES public.auth_permission(id) DEFERRABLE INITIALLY DEFERRED;
 y   ALTER TABLE ONLY public.auth_group_permissions DROP CONSTRAINT auth_group_permissio_permission_id_84c5c92e_fk_auth_perm;
       public          taiga    false    216    212    3183            	           2606    7501925 P   auth_group_permissions auth_group_permissions_group_id_b120cbf9_fk_auth_group_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.auth_group_permissions
    ADD CONSTRAINT auth_group_permissions_group_id_b120cbf9_fk_auth_group_id FOREIGN KEY (group_id) REFERENCES public.auth_group(id) DEFERRABLE INITIALLY DEFERRED;
 z   ALTER TABLE ONLY public.auth_group_permissions DROP CONSTRAINT auth_group_permissions_group_id_b120cbf9_fk_auth_group_id;
       public          taiga    false    214    3188    216                       2606    7501916 E   auth_permission auth_permission_content_type_id_2f476e4b_fk_django_co    FK CONSTRAINT     �   ALTER TABLE ONLY public.auth_permission
    ADD CONSTRAINT auth_permission_content_type_id_2f476e4b_fk_django_co FOREIGN KEY (content_type_id) REFERENCES public.django_content_type(id) DEFERRABLE INITIALLY DEFERRED;
 o   ALTER TABLE ONLY public.auth_permission DROP CONSTRAINT auth_permission_content_type_id_2f476e4b_fk_django_co;
       public          taiga    false    208    212    3174                       2606    7501879 G   django_admin_log django_admin_log_content_type_id_c4bce8eb_fk_django_co    FK CONSTRAINT     �   ALTER TABLE ONLY public.django_admin_log
    ADD CONSTRAINT django_admin_log_content_type_id_c4bce8eb_fk_django_co FOREIGN KEY (content_type_id) REFERENCES public.django_content_type(id) DEFERRABLE INITIALLY DEFERRED;
 q   ALTER TABLE ONLY public.django_admin_log DROP CONSTRAINT django_admin_log_content_type_id_c4bce8eb_fk_django_co;
       public          taiga    false    210    3174    208                       2606    7501884 C   django_admin_log django_admin_log_user_id_c564eba6_fk_users_user_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.django_admin_log
    ADD CONSTRAINT django_admin_log_user_id_c564eba6_fk_users_user_id FOREIGN KEY (user_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 m   ALTER TABLE ONLY public.django_admin_log DROP CONSTRAINT django_admin_log_user_id_c564eba6_fk_users_user_id;
       public          taiga    false    205    210    3158                       2606    7501970 N   easy_thumbnails_thumbnail easy_thumbnails_thum_source_id_5b57bc77_fk_easy_thum    FK CONSTRAINT     �   ALTER TABLE ONLY public.easy_thumbnails_thumbnail
    ADD CONSTRAINT easy_thumbnails_thum_source_id_5b57bc77_fk_easy_thum FOREIGN KEY (source_id) REFERENCES public.easy_thumbnails_source(id) DEFERRABLE INITIALLY DEFERRED;
 x   ALTER TABLE ONLY public.easy_thumbnails_thumbnail DROP CONSTRAINT easy_thumbnails_thum_source_id_5b57bc77_fk_easy_thum;
       public          taiga    false    218    220    3198                       2606    7501991 [   easy_thumbnails_thumbnaildimensions easy_thumbnails_thum_thumbnail_id_c3a0c549_fk_easy_thum    FK CONSTRAINT     �   ALTER TABLE ONLY public.easy_thumbnails_thumbnaildimensions
    ADD CONSTRAINT easy_thumbnails_thum_thumbnail_id_c3a0c549_fk_easy_thum FOREIGN KEY (thumbnail_id) REFERENCES public.easy_thumbnails_thumbnail(id) DEFERRABLE INITIALLY DEFERRED;
 �   ALTER TABLE ONLY public.easy_thumbnails_thumbnaildimensions DROP CONSTRAINT easy_thumbnails_thum_thumbnail_id_c3a0c549_fk_easy_thum;
       public          taiga    false    222    3208    220            '           2606    7502358 5   procrastinate_events procrastinate_events_job_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.procrastinate_events
    ADD CONSTRAINT procrastinate_events_job_id_fkey FOREIGN KEY (job_id) REFERENCES public.procrastinate_jobs(id) ON DELETE CASCADE;
 _   ALTER TABLE ONLY public.procrastinate_events DROP CONSTRAINT procrastinate_events_job_id_fkey;
       public          taiga    false    238    242    3322            &           2606    7502344 G   procrastinate_periodic_defers procrastinate_periodic_defers_job_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.procrastinate_periodic_defers
    ADD CONSTRAINT procrastinate_periodic_defers_job_id_fkey FOREIGN KEY (job_id) REFERENCES public.procrastinate_jobs(id);
 q   ALTER TABLE ONLY public.procrastinate_periodic_defers DROP CONSTRAINT procrastinate_periodic_defers_job_id_fkey;
       public          taiga    false    3322    238    240                       2606    7502091 _   projects_invitations_projectinvitation projects_invitations_invited_by_id_e41218dc_fk_users_use    FK CONSTRAINT     �   ALTER TABLE ONLY public.projects_invitations_projectinvitation
    ADD CONSTRAINT projects_invitations_invited_by_id_e41218dc_fk_users_use FOREIGN KEY (invited_by_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 �   ALTER TABLE ONLY public.projects_invitations_projectinvitation DROP CONSTRAINT projects_invitations_invited_by_id_e41218dc_fk_users_use;
       public          taiga    false    3158    228    205                       2606    7502096 \   projects_invitations_projectinvitation projects_invitations_project_id_8a729cae_fk_projects_    FK CONSTRAINT     �   ALTER TABLE ONLY public.projects_invitations_projectinvitation
    ADD CONSTRAINT projects_invitations_project_id_8a729cae_fk_projects_ FOREIGN KEY (project_id) REFERENCES public.projects_project(id) DEFERRABLE INITIALLY DEFERRED;
 �   ALTER TABLE ONLY public.projects_invitations_projectinvitation DROP CONSTRAINT projects_invitations_project_id_8a729cae_fk_projects_;
       public          taiga    false    3222    224    228                       2606    7502101 ^   projects_invitations_projectinvitation projects_invitations_resent_by_id_68c580e8_fk_users_use    FK CONSTRAINT     �   ALTER TABLE ONLY public.projects_invitations_projectinvitation
    ADD CONSTRAINT projects_invitations_resent_by_id_68c580e8_fk_users_use FOREIGN KEY (resent_by_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 �   ALTER TABLE ONLY public.projects_invitations_projectinvitation DROP CONSTRAINT projects_invitations_resent_by_id_68c580e8_fk_users_use;
       public          taiga    false    3158    228    205                       2606    7502106 _   projects_invitations_projectinvitation projects_invitations_revoked_by_id_8a8e629a_fk_users_use    FK CONSTRAINT     �   ALTER TABLE ONLY public.projects_invitations_projectinvitation
    ADD CONSTRAINT projects_invitations_revoked_by_id_8a8e629a_fk_users_use FOREIGN KEY (revoked_by_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 �   ALTER TABLE ONLY public.projects_invitations_projectinvitation DROP CONSTRAINT projects_invitations_revoked_by_id_8a8e629a_fk_users_use;
       public          taiga    false    205    228    3158                       2606    7502111 Y   projects_invitations_projectinvitation projects_invitations_role_id_bb735b0e_fk_projects_    FK CONSTRAINT     �   ALTER TABLE ONLY public.projects_invitations_projectinvitation
    ADD CONSTRAINT projects_invitations_role_id_bb735b0e_fk_projects_ FOREIGN KEY (role_id) REFERENCES public.projects_roles_projectrole(id) DEFERRABLE INITIALLY DEFERRED;
 �   ALTER TABLE ONLY public.projects_invitations_projectinvitation DROP CONSTRAINT projects_invitations_role_id_bb735b0e_fk_projects_;
       public          taiga    false    226    3232    228                       2606    7502116 Y   projects_invitations_projectinvitation projects_invitations_user_id_995e9b1c_fk_users_use    FK CONSTRAINT     �   ALTER TABLE ONLY public.projects_invitations_projectinvitation
    ADD CONSTRAINT projects_invitations_user_id_995e9b1c_fk_users_use FOREIGN KEY (user_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 �   ALTER TABLE ONLY public.projects_invitations_projectinvitation DROP CONSTRAINT projects_invitations_user_id_995e9b1c_fk_users_use;
       public          taiga    false    228    205    3158                       2606    7502050 \   projects_memberships_projectmembership projects_memberships_project_id_7592284f_fk_projects_    FK CONSTRAINT     �   ALTER TABLE ONLY public.projects_memberships_projectmembership
    ADD CONSTRAINT projects_memberships_project_id_7592284f_fk_projects_ FOREIGN KEY (project_id) REFERENCES public.projects_project(id) DEFERRABLE INITIALLY DEFERRED;
 �   ALTER TABLE ONLY public.projects_memberships_projectmembership DROP CONSTRAINT projects_memberships_project_id_7592284f_fk_projects_;
       public          taiga    false    3222    227    224                       2606    7502055 Y   projects_memberships_projectmembership projects_memberships_role_id_43773f6c_fk_projects_    FK CONSTRAINT     �   ALTER TABLE ONLY public.projects_memberships_projectmembership
    ADD CONSTRAINT projects_memberships_role_id_43773f6c_fk_projects_ FOREIGN KEY (role_id) REFERENCES public.projects_roles_projectrole(id) DEFERRABLE INITIALLY DEFERRED;
 �   ALTER TABLE ONLY public.projects_memberships_projectmembership DROP CONSTRAINT projects_memberships_role_id_43773f6c_fk_projects_;
       public          taiga    false    226    3232    227                       2606    7502060 Y   projects_memberships_projectmembership projects_memberships_user_id_8a613b51_fk_users_use    FK CONSTRAINT     �   ALTER TABLE ONLY public.projects_memberships_projectmembership
    ADD CONSTRAINT projects_memberships_user_id_8a613b51_fk_users_use FOREIGN KEY (user_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 �   ALTER TABLE ONLY public.projects_memberships_projectmembership DROP CONSTRAINT projects_memberships_user_id_8a613b51_fk_users_use;
       public          taiga    false    3158    227    205                       2606    7502068 D   projects_project projects_project_owner_id_b940de39_fk_users_user_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.projects_project
    ADD CONSTRAINT projects_project_owner_id_b940de39_fk_users_user_id FOREIGN KEY (owner_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 n   ALTER TABLE ONLY public.projects_project DROP CONSTRAINT projects_project_owner_id_b940de39_fk_users_user_id;
       public          taiga    false    224    3158    205                       2606    7502074 D   projects_project projects_project_workspace_id_7ea54f67_fk_workspace    FK CONSTRAINT     �   ALTER TABLE ONLY public.projects_project
    ADD CONSTRAINT projects_project_workspace_id_7ea54f67_fk_workspace FOREIGN KEY (workspace_id) REFERENCES public.workspaces_workspace(id) DEFERRABLE INITIALLY DEFERRED;
 n   ALTER TABLE ONLY public.projects_project DROP CONSTRAINT projects_project_workspace_id_7ea54f67_fk_workspace;
       public          taiga    false    224    223    3218                       2606    7502034 P   projects_roles_projectrole projects_roles_proje_project_id_4efc0342_fk_projects_    FK CONSTRAINT     �   ALTER TABLE ONLY public.projects_roles_projectrole
    ADD CONSTRAINT projects_roles_proje_project_id_4efc0342_fk_projects_ FOREIGN KEY (project_id) REFERENCES public.projects_project(id) DEFERRABLE INITIALLY DEFERRED;
 z   ALTER TABLE ONLY public.projects_roles_projectrole DROP CONSTRAINT projects_roles_proje_project_id_4efc0342_fk_projects_;
       public          taiga    false    226    3222    224                       2606    7502182 C   stories_story stories_story_created_by_id_052bf6c8_fk_users_user_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.stories_story
    ADD CONSTRAINT stories_story_created_by_id_052bf6c8_fk_users_user_id FOREIGN KEY (created_by_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 m   ALTER TABLE ONLY public.stories_story DROP CONSTRAINT stories_story_created_by_id_052bf6c8_fk_users_user_id;
       public          taiga    false    232    3158    205                       2606    7502187 F   stories_story stories_story_project_id_c78d9ba8_fk_projects_project_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.stories_story
    ADD CONSTRAINT stories_story_project_id_c78d9ba8_fk_projects_project_id FOREIGN KEY (project_id) REFERENCES public.projects_project(id) DEFERRABLE INITIALLY DEFERRED;
 p   ALTER TABLE ONLY public.stories_story DROP CONSTRAINT stories_story_project_id_c78d9ba8_fk_projects_project_id;
       public          taiga    false    224    232    3222                       2606    7502192 M   stories_story stories_story_status_id_15c8b6c9_fk_workflows_workflowstatus_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.stories_story
    ADD CONSTRAINT stories_story_status_id_15c8b6c9_fk_workflows_workflowstatus_id FOREIGN KEY (status_id) REFERENCES public.workflows_workflowstatus(id) DEFERRABLE INITIALLY DEFERRED;
 w   ALTER TABLE ONLY public.stories_story DROP CONSTRAINT stories_story_status_id_15c8b6c9_fk_workflows_workflowstatus_id;
       public          taiga    false    232    3275    231                       2606    7502197 I   stories_story stories_story_workflow_id_448ab642_fk_workflows_workflow_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.stories_story
    ADD CONSTRAINT stories_story_workflow_id_448ab642_fk_workflows_workflow_id FOREIGN KEY (workflow_id) REFERENCES public.workflows_workflow(id) DEFERRABLE INITIALLY DEFERRED;
 s   ALTER TABLE ONLY public.stories_story DROP CONSTRAINT stories_story_workflow_id_448ab642_fk_workflows_workflow_id;
       public          taiga    false    232    3267    230            !           2606    7502235 J   tokens_denylistedtoken tokens_denylistedtok_token_id_43d24f6f_fk_tokens_ou    FK CONSTRAINT     �   ALTER TABLE ONLY public.tokens_denylistedtoken
    ADD CONSTRAINT tokens_denylistedtok_token_id_43d24f6f_fk_tokens_ou FOREIGN KEY (token_id) REFERENCES public.tokens_outstandingtoken(id) DEFERRABLE INITIALLY DEFERRED;
 t   ALTER TABLE ONLY public.tokens_denylistedtoken DROP CONSTRAINT tokens_denylistedtok_token_id_43d24f6f_fk_tokens_ou;
       public          taiga    false    3295    234    233                        2606    7502228 R   tokens_outstandingtoken tokens_outstandingto_content_type_id_06cfd70a_fk_django_co    FK CONSTRAINT     �   ALTER TABLE ONLY public.tokens_outstandingtoken
    ADD CONSTRAINT tokens_outstandingto_content_type_id_06cfd70a_fk_django_co FOREIGN KEY (content_type_id) REFERENCES public.django_content_type(id) DEFERRABLE INITIALLY DEFERRED;
 |   ALTER TABLE ONLY public.tokens_outstandingtoken DROP CONSTRAINT tokens_outstandingto_content_type_id_06cfd70a_fk_django_co;
       public          taiga    false    233    3174    208                       2606    7501851 ?   users_authdata users_authdata_user_id_9625853a_fk_users_user_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.users_authdata
    ADD CONSTRAINT users_authdata_user_id_9625853a_fk_users_user_id FOREIGN KEY (user_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 i   ALTER TABLE ONLY public.users_authdata DROP CONSTRAINT users_authdata_user_id_9625853a_fk_users_user_id;
       public          taiga    false    205    206    3158                       2606    7502159 P   workflows_workflow workflows_workflow_project_id_59dd45ec_fk_projects_project_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.workflows_workflow
    ADD CONSTRAINT workflows_workflow_project_id_59dd45ec_fk_projects_project_id FOREIGN KEY (project_id) REFERENCES public.projects_project(id) DEFERRABLE INITIALLY DEFERRED;
 z   ALTER TABLE ONLY public.workflows_workflow DROP CONSTRAINT workflows_workflow_project_id_59dd45ec_fk_projects_project_id;
       public          taiga    false    224    230    3222                       2606    7502165 O   workflows_workflowstatus workflows_workflowst_workflow_id_8efaaa04_fk_workflows    FK CONSTRAINT     �   ALTER TABLE ONLY public.workflows_workflowstatus
    ADD CONSTRAINT workflows_workflowst_workflow_id_8efaaa04_fk_workflows FOREIGN KEY (workflow_id) REFERENCES public.workflows_workflow(id) DEFERRABLE INITIALLY DEFERRED;
 y   ALTER TABLE ONLY public.workflows_workflowstatus DROP CONSTRAINT workflows_workflowst_workflow_id_8efaaa04_fk_workflows;
       public          taiga    false    3267    231    230            #           2606    7502269 ]   workspaces_memberships_workspacemembership workspaces_membershi_role_id_4ea4e76e_fk_workspace    FK CONSTRAINT     �   ALTER TABLE ONLY public.workspaces_memberships_workspacemembership
    ADD CONSTRAINT workspaces_membershi_role_id_4ea4e76e_fk_workspace FOREIGN KEY (role_id) REFERENCES public.workspaces_roles_workspacerole(id) DEFERRABLE INITIALLY DEFERRED;
 �   ALTER TABLE ONLY public.workspaces_memberships_workspacemembership DROP CONSTRAINT workspaces_membershi_role_id_4ea4e76e_fk_workspace;
       public          taiga    false    3303    236    235            $           2606    7502274 ]   workspaces_memberships_workspacemembership workspaces_membershi_user_id_89b29e02_fk_users_use    FK CONSTRAINT     �   ALTER TABLE ONLY public.workspaces_memberships_workspacemembership
    ADD CONSTRAINT workspaces_membershi_user_id_89b29e02_fk_users_use FOREIGN KEY (user_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 �   ALTER TABLE ONLY public.workspaces_memberships_workspacemembership DROP CONSTRAINT workspaces_membershi_user_id_89b29e02_fk_users_use;
       public          taiga    false    236    205    3158            %           2606    7502279 b   workspaces_memberships_workspacemembership workspaces_membershi_workspace_id_fd6f07d4_fk_workspace    FK CONSTRAINT     �   ALTER TABLE ONLY public.workspaces_memberships_workspacemembership
    ADD CONSTRAINT workspaces_membershi_workspace_id_fd6f07d4_fk_workspace FOREIGN KEY (workspace_id) REFERENCES public.workspaces_workspace(id) DEFERRABLE INITIALLY DEFERRED;
 �   ALTER TABLE ONLY public.workspaces_memberships_workspacemembership DROP CONSTRAINT workspaces_membershi_workspace_id_fd6f07d4_fk_workspace;
       public          taiga    false    236    3218    223            "           2606    7502253 V   workspaces_roles_workspacerole workspaces_roles_wor_workspace_id_1aebcc14_fk_workspace    FK CONSTRAINT     �   ALTER TABLE ONLY public.workspaces_roles_workspacerole
    ADD CONSTRAINT workspaces_roles_wor_workspace_id_1aebcc14_fk_workspace FOREIGN KEY (workspace_id) REFERENCES public.workspaces_workspace(id) DEFERRABLE INITIALLY DEFERRED;
 �   ALTER TABLE ONLY public.workspaces_roles_workspacerole DROP CONSTRAINT workspaces_roles_wor_workspace_id_1aebcc14_fk_workspace;
       public          taiga    false    235    223    3218                       2606    7502287 L   workspaces_workspace workspaces_workspace_owner_id_d8b120c0_fk_users_user_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.workspaces_workspace
    ADD CONSTRAINT workspaces_workspace_owner_id_d8b120c0_fk_users_user_id FOREIGN KEY (owner_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 v   ALTER TABLE ONLY public.workspaces_workspace DROP CONSTRAINT workspaces_workspace_owner_id_d8b120c0_fk_users_user_id;
       public          taiga    false    223    205    3158            �      xڋ���� � �      �      xڋ���� � �      �   �  x�m��r�0E��W��.5�u~#U)<(c���]���Ԣ�%�8���Q��0�8�e�f���~�ľ����x}曉Y����᣹��~���?'���C���i�Ǵm�2�|qA6T�� Kؖ�2L	ۡ(#�&����.��(���Y����E�:�hT	�����ip_n���[�E�,�kw)UEE(2H�ԇ���d�Z�sjH���f�߰vnp%UGՐ��b`0}A)��҉��赙U4N��Qj���]� {� ��n�_�o��7�؊�eߋq��h��q}\J��&Vhc�( ��i�;k��-_^v��<N�ˇ�E��ɺ[�%{�s1�&�L�P&M�Q��\�4�4���>m֌��]9\���L�%96]�Krd�2)W+���}-�����6{q}�Y��c t ,�AƂ7�DF:W©ԲX���*�z,�Jgu�D��Ce����>Te
����L��y��u{��Bi�oɪɷ��}@�o����rmy�w�a�����\�P��KY���@��|�9pd�	������Ua��y��/XQ��,�*��R��uƛy6I��0�&��{Y�V�\�@�6>�的 o��%mpj�a��O��d{Ԫ��xC6:ׂ'y.s�x����*mǣ�#�IS:M-mJF�irMy�7��6ה�yS�Ҧ<J��`������K����k�^�.`dS�w�@��˓�oY�;�)O��]�����	�3I�*�*�J2�q��9o��C�IK��"��.�'��g���-��@�����L��vLG?�ΰ�}��my��ٮ�y��d�F� �M��
Pd��2@�����m�����=dǆ���EX6K�9�a�S$\�Z��0���M��-�_��Q:nA��}����t�d�}I��O)�05��      �      xڋ���� � �      �     x�uQ�n� |f?�
8�T���6�إ����FJ��3�2,�����DC�X ��Գ��3�&xhf�K!G82���̆��H��ɇ+�3˨N+\�b�$I�2
O]�!����nb�*J��$�f��+�'Fٖ��+����ձ.j���Q��&V��ް�·n	W ��Ƒv�J*�O��ܾ����]5�ǐ�iL�S�/��θ�u���ˆn���̖2�80��L	7�δ��N}v/�-Bȩ�S�7e� ��Ee\���q�� ��݆      �   �  xڍ��r�0���S��F��ϳtF�؊�r�}�p�����g<p>����:.!��|򶩐 > <��A�#�G5Q~��j�五.�۠&	ף�V���n]�$�Q�n4M8��Ƌ�����s
��J���Ơ7F��O>t湱G�?��~Y���y������OLg[��b�
5�d��?��B2P��P��m���w���0z?hZ�n��[K(�(=��5������{���H�K3��v�J=�O�2�k�ha������i����M�HA"�*��)"�����y eRf��2��Ag��V�j�)ġ����i�0أ[6�BS�������f
R���I�K�6��0��
�u���o�0��t�a/�9��E��1�_���N@Ӓf��x���Ǎ�r
�.q]�֎��R��ǑT��N���ˡ�Պi�rt��x������
�U��[�/Co�nCZJ� �V�߿�>��T B�U&��mТ����Mܺ�)�'�o@p�������oe�R�`��$���4��WB��V��^}��Ld�`�W����wM�,�QL���2��&���ԄI����!/�6�W��Q�Rxq�����;�һ�m
B�
�4�����!2��r�����o�X�ՎӦ�U�v���^,      �      xڋ���� � �      �   �  xڕ��j�VD��~E�!V�v?�-��g n�R:�(�d0�li������N���;��s��	����������_?~���˯}�%W鐞����)�Xuω�S&NM��ʜ�>����Z�R�?~��㛐�/̿H�����n�b��3�w�:R��.�����c���G��sx��%>u�L��?��ut'����M�Fү#���@�j�����SufG��X+�Ømr�(o!A1�(�����J2����H�Q��	��g�iC�c�R9�l�d��Y+�X̻�Sm�Ι���H��"7R�:�]|�+.�@�x�T�g���7��`�1�Re:�N����	�PQO��iٍ�_Gj�R)!�� a<ym�&��Ψ��s.���Ŷ9�9���3y�Z�H�
R]
���JB�l-b�i_3DFդY��hu��h� /԰~����|�&Z��H�^]��~VZ�9�;Q�a}M��P�^��х�?A��c���HtT*���&����l�S��U���Ğ�m��	�ϐ��ۍ��u������,�;h
.���p���1��.�:(�i5j�3&S\&�:��d����=���x�9iTlq�@A�/W:ۇ�/����؀�OT�-�U�Z4�:�`��^���������\]�1�����X/Mm�Ż�ҡ9=�9��ZăI_�]�2aU��`N�׶lR�}�1��hn�]z�����=�ę�0�:=�_�pE��껙q�X�#�+�-߲[�`BW�z�)������1t<aJ0=,��+z��;���F�MQ��}T�9 #o�M�ӕ�0�n=;��י\�i�3ZG�d-����&9��#�[�a����V�������t�=b����2ջ�[ê�=��₋��a� Զi�ȕ�P}[yF��J�*���{�Y���r�O����1w���Np�J��FOf��֑�4�1�Alkɉ@<XM�c���39�燞�0ס�s�h�ْ��xw����F}=�%�  ���Ƨm��s����I󍛷�`�||>�>��Ǆ��Q���c�:�^Ӆ]BX(������0̳�]O����)¯h�pA���1Ub2a�{�Z?��(�S�1$��T�����$R�E^�s	E��@�ag���fh`����g$�JK�;B(IıȁOt��0�4���3��I�1_,ŒV8t����J"�� ��)s/L8���j���|��N.��v�;T]M��Yc��Snp̀��Y�l:��},�|Τbi�D�������4�      �   W  x�ř�n�F���S�X���=K�`~A�9��S���%&O�
�����3�ճ�i�����Z{�9�E�*QIj�1>}�������u�{켇4�nR�����ީ��=�7�9"kZ�h�h���������/o������_��/_߾���'N̟�>s�D��=ۛ���~N�m|��<��d'.ON9�Y���=�)���|6\UH�5�A���ܮ�\�,�?�Vc�X�r�s\�3>8y�wp��S!h~r��s_�.R���ʬ��(�4ץ6��Z&ʝ*Yh1�d����|D����$98e�;8O��x�>8�<�zT>��8�9��*M��L<9��^pEk��I�<W�fһ��/���qp����<�'
����y���SWE=��� ^�N*�� �:',,~YYU\-jMx����g!+zp����g�H��I�9
���3��pƔ��e�j1է���Z��d�5�q��ņ�7N݈��<�g$�P�� t�L�Ƴ��D0��ttcn=�0�F��i.�x���(�.	؉�pz�(�zV�LF�Z�d��ͤ{�jTIGӬkx.��Ƌe:j�r=�!48]���l���5E�?
���g�4d��z�'�������֖�JyŠT+�ƈ4)��p~We�I�NJ��#��kz>�������D���BWj�J�����*z#��\�e�C��]��(��*Ѣ�Eʁ�GZN�;H�J��"�И�:���-hi��	V$f)��4�� 7�%�Th��5�)�������I�O)ދ����I	��A�?�����
�H/����(j��%��t�:6EY�$��^���Y1��ǈe%�k��`=Hy�|�IM5��"-Wv�#=#��Å�sG�����V�&[�1Cd������h��'���wy�}�X� =�i��|�^hP��d(�%g��w��N���ȇ����0E�^�l���ց Ӥ]�T��Ӥ��~�YIݕ����z�RXP`�K����j�����g2�*4[V��z�آcu�C�K�q��*��;HOj�i6�J������{R�ټ�aD��}��$=+�3ZBj�T$�|To6�Au��������=I�t���ǒ>I��ȋ�B�b�.�2�Tf�X����	���j%�ƌ��Ik������vM�/R�$�AzVSSa}��+&��N��|��ѪaH.�`�F���mb	^f܀�N6��L��4W��o�w������;�]9ϭ0���g�	�*
ǂ[���5Y�8X�J�sP�U&Zy'�����o�Y��3�&~�MRML/��?:)F��+:�=��j�zʵΥ��Lw	#^6��p*�Q::,��k�:���	y�r������y�|�^�P/��TV4J��1l�N)|~����u4RtV\�\���o�%I�XGR�2�AzRS���\9�u���C�[��]3\ƞ�1qUVY�=�1���o��yñ��5I�qn� �-�;H�J
�����p�=��.u-� .����Rg?̼{Ad�x�s��f�E�i���9B�lY� =�i���H/4�x���8��0�p�������{�Ќm%*�gH)FY��6W�Η4E+�g8�e�������ŋ���m��?�a      �      xڋ���� � �      �   �
  xڅ�A%����٧�~�_�Y��p��Ǿ���[dԮ�+�K!!�|����������?{x0�J�������I$�3�/�p���Y�Q������߯$)(�|��|h�1�����ۍ"��A���E�� -�>�Ρ�!�FU]2��A�Q����G�k ?�>Ns��K��P�V�D9ЛÁ�gji>zu��>[�L	؋C��y%����b�	�g5,��M��ثP��I#��0�����cW����3ٍ2o<�^:MF>S�7�˲�9f~�wP���L��9� ��@[]�g}Y��;,�=s�x���b-]�uXvv���qW���{,x|u ��X3�a�����7Ѥ|7Nzo=�9B��#�+<g�}d��̅��w��Y8�t�5�F�~��\ͷ���<�!y�e9��D�|�����â��y�d$�ǵm�\/�md��<�9�>��̟ �-���/�L�H�w���P�m4���gV7AW��p�s��|�v�eO�ш�9*��Z����׹�G����Mn�Jɶ��8�I#�]�������]l�\fE�K�5��8��qm{�VEW�n5��I�Z�}d��Zg�I{j����k�u�빏�H��pTE�����K����chENh�O4��FÐ{c�d�L���V:�Œ����!��ri��N$Wn�d[�QW�B�9{����,��Ylb����d[�̈́�ή�Ƃ��<;�(ثE��,ҧoq�W�=3�]9h��sU�D�N�ͳ�M�m##%�"#���揑ʙ��k��Ȣ�kC��%0��tH���K�]�#-�=m����3
Z8'�V���h�sX�͑K�}d^��n5&��8��W�w�@Wu�n�6�i��N��,�$t�@��5�Ⱎ&t�dГ����[�r՗�wH��\�=�m-�>;cV�
(+��(�|� �a�X�gΗ��/	˸�2h�!�����P��;�>�q�	l��f�5������� N���8���W�y����M��Ǉ}9���k�7���]���՛l'?C#�3���֚x�~��ߗ���D?���oZc�s���%ܚF��H�w&�Alg1�LoL ��rcV��%4�əc1�d���cN8�����Q�
���؛1������Z����$�����J�^Bc@����Q���^+�OF���˷u��J�-SN�A�L�����T4���؁�O�'��^�J��ݚЇ7.�s�q��lD�����ޕي '��%�G��d�<W/�iE��uZ�"�"�9߬b#�]�F*�EK�w�:�e#���6�5L*42�X��T��z�LIS`v\hF"�-���y!�vi�q�S}�ݍc#֛L��΁�[l�tP�U�tVևi-/z}7̓kM�G�-�����zJ$�^�W�o����r�'��q�-J��o&Ǣh����3a����Aw&���m��M�5�iS�G�7�/��Aw&�7�	�&s��7_���rg�qҶ�A�M�Z�dt=:�Bo�Җ�o��f�xoMC�I����(�����dJ'n���{�/�R��=蔈����[=�B.WW{jIFn�����EZڝ�'Ɗ��cO�j	��w[p۔�'��V[�Oriݚ8���~hA�M �U0%ܘ �x�~p��;���3��Р}7	x���g�pc�M�"r�{�cV��tg�j2�Ě%ܚ��O����J,�X$g[��j���:�>�Eo�ݥ>nR��{�ꓜ#xk���
�	��'.��L�gu%���"�$������&+��$��I�+#ښg�+�E��&�zL�br`G]���$�1���G��L�L�GH�I榠�&��M�9��$~d���Sn$S{��Zޖ�;��p��	�&���;r�:��F�c�-ػF����f#��x�W6\U�����|��a�୉��$<(�>�����Ȥw�+�r�1������s`�q��^��:?���F/��c�H���v/�B��6���'��F���%��6��z��4ncϡ�4L�u�b�Y���]�`ƭ�3�F8ί.�q'⟁\�!�nx��>���pc܈�D���ٛ��ϐ�<�N�}x�F%~3_Dx����RٖW\��&��ǯp��
x�����ԗ�������n�έ�,�5Q�Vք��hL�b#�]}U�@�ӂ�� F��ځ�	�M���V���*��렿���C�մ��{4A���`Q�S�0��FM����d/�2�Aw&{-��0%��d;��8��;Ź��P�+�I�V/Q'nL����f ��i6x��"1���8����k�CS�n�cx�q^k���୉�ord&��^��,y���������ǢA_D캬r=>_B���k,�����]"�"��,\�|�J�]N��:nc+6w�z��b+�?�A9�>6�x��q��>K�h	�nx}?�0f~��������3alX��ebA�M86�}�i�Wk|���\Zo�C��Aѭ5A���UL~n/&���`���;���]�"&��"��yEF&�[d�*TD�[�	m�j�1�nMQuTh�}���y�	Z�=:���#z�����Ǌ��xzt�{�"�q����ضϾ��)��u,��>p��k�X�����6��&t�g��!��F/���g�kw��J^*+TZoF�-�>60�
z���E�v ��=�b��a䯟_~��Eِ      �      x��}ks�ȶ��s~EE:���H	2�@Bdƍ �$����t���ɤ����8��;��ttW`c����k��{%/�#��5����%��kXxI~��❳��p����?!���~����_~���|s�%�?����_�ח_ro�k�sG]�'�������rO�6�K�߭/�,�=.��x�����S�,L������P���Z����"f�]�M�g�� ��}��s�8]-k�ғ���ñ�����Z.�����zq`�y�(U��X�ZPd�y� ��F�UVO�Ɇ3�؅̊�3��k	0E<��y}VL	�e6�#�����s��`����u�o6��Yİr�^�b8�;�����6�D�S~u��o�v=����+B�֜�h��~������AЅ`��~��]��I�������݂�:�_�pڧ�Y'�D�0�K�N����N��m;�B��{!��W�??<��G��L�����^����_��k@�巧�~�����2G�;�~��޼���`
� ?:y��~c��%�/lܼb�C����C����_)4�*��kJ��w`[VI�w��� ��S�
ΰ�����蜩,sh)*`
]T;�0�e�~��9���_��p��|j�wӶ.�&�٘�������(zmjN��؟�}���C/��zt�K�B-bu7qǃk�u��q�߾�I�E��z��;�����/����| �8}��˿>�+N�x�?���B��&�������?��+y�������-��!�]� �� 6` ��D%���tu�@����G@E��ׁjI��F������f�ܱ�t�M�-w��}ޫd�)�
�l���k�MX�tu��H���Ԉ��Aӈ
	��!����"P`��Q���������	; �j��VG�Qn?���5
�WdOn��>�o����<��Mx����}pnQT4rB�P�8�B7$*f�i/sT�
T��T�9<���MA�����2��x&1�������$ŕ����mu_f�� g�鮸�����oĶ
���V�qP!�-�Xl�9�U���E�ĶQ�Tg���X�����ѹc����rS�f6Z�ט��o؉SA`'��l<��!��s�6�F_ ����X���F��!{�"۪Q�'��PqF�U�Yh�v�A��}|��>4�-�������P��{��P�$:�C�w�λI%&4J�L4�g���������g���{�T���F��7���/�%@�ȝ�&�/�����k��J\#"� Q6�Sc�ܝ�<}�l)�35@�\��'0�c��9O��GLܟ؇��x��]{[<��vh��VsGѦ�W�`���'���m���u������V�w"|{ߥ>O�WI�Iڌj�VeD�F�@�)�,�5P��(~��ȅDlXd����;6d�)Yt�bx�L�"��h�������AB��>>C}J���{��G5�g7`�+Gْ��	[FJ-r�Z"�����|5���Bͪ���uG6.p�"c���#����6��������ߡ�O���#��x���������e��~Eӑ,j4w�b
?=w���U��� �
�;����7�T�������]��BDIRČ�1$�X��%N0I;Qq�hk���y����6���]�GvxL���\�<M��!�P"���m����d�2߾|�|�n�B!�=����u;ܟ
��(9���i�a|JΗ�������NlR��D]�Q�*�jF�Ř����_]�Hȅ¥DU_S�#��7���{Վ�0*W��rW��]�'���\�w�v]�M�b�6zs4O���v��������%<_�����6]{}S#���T�T�@0�p$v�#1�ڱ�~S�3m�u��6�x���bt͋Q4�z����j�x�lq1��YU���������[.�|��r��[��GLd�Σ�`W�J$ W��?JDЈH, >ߒ���&��F�mI��ʥc�����>�� ����au���'WK���^�7�g��]�S��=um����7��n�W.�/v�}��L0	��a�´Qi�@$A�"L� NeLZCq��� &Y@�R��1t�ʈ���|e0��3�n+�@��j!���F�VR==��C����_���H���6h����aX�癰yq�
��h[��|@b�m��VEPX�*C�Ҝ�-g����<��:�P���w��m���:ٌo��{
³!h؍.�D���Pt�^�l�符��7&
[����70%0�G$o�*�D��ެiS!H7��/A�g�U�4H��/�x��i�q�8ެ�1��7��jV\^8a����]���`��d�oO��ç�S�����"�/�g�oI����a��q���$�������FJ5��d�8{. (Z���F������'���9�w���0���nJ/��N�ǣ�4�X&j
��7�U��nz�f��$�؟��˂�#���� �.�g�W׋v�K��m]�HT����Ԉ�U�]"O�%͢
�_R���h�${C��z��.����D�C�-o�ް;n.vU��"��Ө�|�n�)<\O��9�r��{%�K�Ivۓw�����z�VK*�� �ڀyۍ`�KU�
I�l���3�CiD�0�H�;-"}�JZh'l���ߩt>����wks�՝�U��nQ������LX��{���m���M$ܦ��?��Q�Z���#8vU��*�a��<���@	��O��Da�?��_�q�d��IZ�����x>��d���\>N�I(�qe�V�2�l����O ���	�����-��2/H��Â��1��(��5����
�e�k���r@x�^���Z�윍�e�F����LU��� Noǖ�q���W�l{�W*�:���V��
t{�g���;ϱbĦFV�VK��4�/�2����2_45�Ab��M�.b;z��o���FX����)����tP�O�[Wd�k1�4�7'[�B-P�o���%V�b�.��؆�3���5�%V�؈�r�Ok�/s�ɺ��)'�M�F�XnFË7���l��'��B�����̽6$��yC<$qN��.�6��	?�!�*l��c��,}�zm���ӭ���s̘ס�����u;���χ�,��tx��^�۷������X��|�|��+�̓<�~�����p�e�v��Ҵ�ގ��ҹB�9#��X��9����M?P�5m4m�z���u���N��]���fDx;_2������!n�4��j��,~�������e:�#��#dl�'�h��w*������b*��),�*��\$"{��G�nn<��,�`�Bܫm�w��m�謎�)�����U�����r�X�,��}t�T���fC{ڳ��n��.�Ѷ�a��v�*I�`��'��D��{>>F�`�m���mP�Z�k�Ѯ���|+;��S�U�r���1@�i;�-�1NC���D��Z�/��h��NwDA� %�`J�Z��FB���� Eu�>'#چ~��P�����E��%�oP�Oq�ߵ��6%�Ԝ�B����3��?��e�C�$�vT������������s$���T(�ُҼ�t�=��a�����~�X�l��x«>���*}˰'4�_�3a�c��(Ԫ�r�Tл�r��I��Alj$�����nMRc��z4@i*$S��/!�׋p���~Sz���=��1N��b����`#jI/)'sVj,��ՉZ�چ�D�iIX�$I� ��|�l����
�-?洠�g�4
�L��:Loc���dm:��1���2���~����S�C��n�u���M�Tj�;���=��xw�����,�k�\��
8���C�!�um�J� ��秭�B.�>�D'����Q���uĽlZ�?��r���y+,ڹ?�V�7�I�u��Զ�������*�GD�Kk�F��QF{؀Zp��<E��`J}���S�Y����ˆ�0&��k���;�\���ͪg����M���D��=|ڦ��;��"L!54��&%Y)`@���1�A��pb��0�Aj~��T&h�_ 3D�    X��>������0�� ��-�Y7�S�^C�U�eB&��έ�R�ow���oj*ɳT��ZuN5��K��,�a�bvY<L�{���a���<<\��0\���"on��.G����nE�4Ϛb�~M@>/l�+}�?uG1e�7�F���]:Ȇ��y�V%����.7�
A�s��a����|���Y��٭�_3e[�<cF���7���K+R���v�Oj�>|s�$������{����Xg%V�Ĵ�@�6�i՝~�<�)��G\��؅�������?���!���T���8X0v��u�f��3���7x����=�ۂ��yG�� #@�!'��M�L�2��_�`���4K$0�R�uQ�}��H�女
D�؋#GGvoY�4R���U���﵋f��|>Z���<;���0M�
#7]�\cI;��K�fg<PԚ</�ʠ��u��>�^x���=�g��uX��	��61:m��Ν/�]O��1�����6I��g��n�
q8Eܨ�JC:'��S�|�R#�����|��jl�,.�����8������J�Y��s�V��!��:�K��l>��I�I����Jݿ�3��b�-��		v�(�@�ȠZ�S��*QS�޾q���<�a�^����T�T;�8�ҡ���]�E;��R7�b�,Vכn�-Cqs>m�rT�[ �Xq*l��rE�u��Q
��'�Qj�����6`�b�zz��鎪;*���ʈߌ9�oD�ݠ��I���2H�;�e ���%N|/�$z�.q
b���2&)���;m�Ŋ�<���D;��PS�8�9|���A� �^�[C]�S-���UȂ�5��>�"�vs=^z�N�ᬼ���&�Ö�z�	�uߧl�;_J�
`��J���7�b��ꥭ1���H��#��a�F��˨N{�f.;~`9up_r�3��d����w��e�-�߲���7��x���Of;-���ɏl#���ԝ�T2����Ta.?j7e	ফ�6��?ہ,_Ŏ���Ӣ���rt'�=�ǁp�VpO�AO��?5E!4W�j���U��[�i#���C�!���Q*W�"(�s���|��1�!�x=#�$�����{ݦ{{-IF"���`��|!�8V�X�׈���<o�p�.+��Bw�{���T'd�ނ�N&��1<��j1@�D:��#���jE=I���)=�̯P��r-�����?>1�r��p�,u�ʧ������b��Xk��N����n�L���"k��e��������t.���:b�2D��@">8��?��F�"E�����ld���_�/ƽ�.���m�fP۫\%���y��ֲց^#&8R�+v���I2����_ٸ~w@u�aS���HB['lLRz:�˩"������)�&al�,ӗ�8��S̃Q�`&<��� )�`���&X����/Emcc��l��I���Mٟ}���޵q�����$bNM�1q�,NU�\T��+�|��
�p�ء�5�牻�K���Z�Gg�S&�T�/�}��5Kv�R��qqsm\m"�F3���0+NMzҝ�J�F�$SKP/^��BO��ʧ��vT��p��&�_����qvrG�*�i�@���a��UBsS5m���&��g�8��-�ғ��Anڣ�b�U�]&�� ��E��_g`~�7�hw-�$W��s��ռ�'�x�+7�n��rl[��g><�$��2�v��QG'p�S�V��ybj�X:I�j�<�_��/��4��M�'�A^q�m�c<�]>q�`Sަf$ꣃ���B���ʭ �|�����[��s�v^�2��J@��e@ꋏÞ�  ���aݟ7��V�ej����{��;^�����w�ϻ�����5M�6��L��e���*�ٰIQ�y����E�W���,*�c䔶9�bp�8���$7����͔SB�����a����wv��� �j��+�TS4��u�l5�����˅' .k�"����\�ݧ��Zk��в"Ne���DFFRꗍj@2�d�EKzL+�М�;�9l�i����W��-\�G����w��6;3��/�p=<����ޤ��䎠� ��1&�̴��K�3FaA`�TD�$-����X?J@��Yg#w:�	��$и!��b�K�^���o�ܐ������黒����~2�������U��麸@���Qij#��_���	EY�yI���@6}t���8U��s��$�z*��N,�y���Y�eo�`��e~:����q�k������}�$���:#���i'D���HG9���X]�����S:ѐ�?J�S%�(uE��Zm�/���y���+���|~Xw{PF����{oa��N�l>`�l��I��0m�e޷�J�J�<Pd�P)=9��Ր��X¨$Yh򴙖Rk���u����8nY������gJ[�]�~ƌ���L��J��߃BS.Ibs��!�拹o�T�q�إV������(35��mdt.�|̇9���6ED5�^gӁ'c�u�9�c�k�&���P
��[����y��е��V���)���@���Ͽ�s��oF�k�@aO�$�R�;aIq$��;��a����V��a��2M9u��a�G �Y��p��0�Xu=ޞa�w;�N'j�j���A_�v���~(I���'�|o��D��p�O��G'�7�U�G���/q8�PQ�8W��z	Ҩ��\A��v�d�)X�Ekj�������U���X)��6r7����
��l���eu��n�]:�oR�� �eU�𾦀�Jm`�V��!J��pgaQ8�ԟ����T��������TO��k��}���mn`\m���x��������h>�w��h�7Q��ܖ�ik�o��U:O˒x/��26�AQ )Ɏ�A�҈�) �!��o�bU��/cu\9od\�����/|w��Y�`p;�V���ͪ��	h��А7rkj[����T�d�$��r�	�1��~t%r�Ո�����G:U}���N���.��-�Z_�J꣋θ��!���bkv�]�MS�$5TP�=��eſ��1+�?9vae�����Q�}���j�d�i�ļ0?�OaLr�����f�b;<����je���Yv������:���@��{�TA�k�_�n#�����U��k���φ-st�zt��b�(��sD��y��_i������Qa���Vb6.٭f�I֗�a���ՊЈ<�����?��[�NfM�$������-��~�*8�itG���T��0ȩ��
� Y�0��?ܻR$�>j��zAV���Ԫu�N����5���dVJn=��FM�{B����Ӷx�?#�B���T g*:	��C6 (�*��ր 
���&��>� �Kۉ�[o�O�,O�~�d�u��v�z��2�pzS�ψRhmOvժ�%�md�&bU�G�)uFȨ�KM��|�z<N��Y��V `ͯh}q�ʞ,�qe.��n��պ/L�ݩ�<m������e2ͦ��n�L���%�h��݉��m �(�[XqD��Sh oڨĮ#�
=�������̛�('�~}ue-x9��m��f�2������<��%���E��-��-�C{�m���-�x����9=-�22����i��#��|*@�m,��xU��v:���>z�������Im
F;�I蝭������&��D����x�c����A�� ��Q�L�s�l�8�8��j�I���8Ƴ�U��x�M�~8�{�/*�5P�I/����p�p�,<$�1�뇒�>���� zoO����&|�	���K��� =vU��|�b�Ҷ�u�ڕ�ԓ�MxÒ��X$���~;��uû�8�o����k�m���џJFa*��;�vv��}�T��=���5���ya��g�򉽆}%Ww�ٹ#֐�jv8��;�x\�%�6��Ĺ56m�e ��d<a�}��������wЎ��F	5솵�@�N�-A�	���Nt��=��=j�)�⠮|��#Z��| �  �'����Q1N��؅�|��T���qJ�w�q�zY�>�>��>ƙ�I��ff/�FM����C���� �i��#���3@���8}:�Y�D�f����8w̯�l����V��w�M����L)�̪m�<C�Sh}f�R�{�����tꛥ[>&hɲU�%!i^����j�8�Z��bT�s?X�h�{���O����Yfg�4�$�j�����3s9N�sIV��m�B�ϡB��'p����D��p�mz�!b�v��sB�,�	�K ;�Q��T�U����LC���l�铭�bw���-�z�o�����PjM�M��O�6�@�_�i�JuՈEv�!��B�E�-��%a�oD\|b��t�.��W��qp�r����N�
����#���7��+����\C{��[������75KD�\c)��3�y�2�U@����A>�o�
�+��S]�]՚���߼a'��57�)9g��k�=���l�բ�k�_�߄�m���ݏ�׾u�a@8z�-TL]��JĚ6Q����Ha��6�)�*!g�ε���k_qR���$��ͻ�6Q4���(�nܝ�n�Mє��Ԝ-hk��I������I�XA�i]��+$�L3��L�b��p�~´
��S3:��(��#b-�Mك/y1��n�!��c$�K>�Myt�&:p�ç����3���%�SArgn^�vƐY Z���b���YN#���-E+8���;p�����83��o̺S��n�Jb�"#�gs1>N�YS�b]��M3���z���݁��oGrDP5�$�Q��JS{HS�Yh�4K�iG��xC�RT�:{����p�eo�(�M{&N�����p1֕K��\����-��S�Ar����$({�P�J�m 
 x�qjEϺ#�4���b���s�̀툠�DY�9JW-�U8���PPnC����ܻ滩�\ɸlٱ�F&x�D�-���3�y��֌����Υ�eD98�i�<�6j���8���\�u�����e���W^�G�h������h6gv������B#b"��-��������CR�$z��þ+%:VQˇ�X��+8�.��lL�@������ �O������oAq�����M�%D��-b�9���27g��&(�@N�o�26��0���5�e��qv^�:�N�����p�!�����K5�@��,�HPW���Q�NOq�m�c����v�Y�	9Ѧ�%��
��	�T���@ҷ���2�n�,���d�K����=�"ů{��h.nֶ�lݛq1�K�r֫�ژG�U�cٛ��~��Z�I֕��$�R/���N�7d�W�l�h��hb�.3��q=x<��^a����О��w�`aj�����U2ug������//��r>A>�o�t}컒wԋ�*;jÝd���?���� ��      �      xڋ���� � �      �      x�͝�n$9�����b��H��|�O0O��B��`������_E���ζ#����T�Z��ɟ:���0u�&=�7�Z����C�H�(}����?�?������~��K*���G�_�����/��=aX } ��/���]�.�^����ғ�"����WA�I��j,�w�� Rk�p���ȯ�#���+�L�D1Դ��������D>��[��;�{rR���=v��:�!>݂���ܱS9�[9��������.G���-��[�Ź�������%�4-�o����M�_�VC����^�/��=���q��[�� ?]�M���j���|����;5���O~ ��~�%�����ץ��˗�ۯ����=|u�{���Kw8/���3�H����xc�]w�'X�ꄔ�|�
�FA�~߮�ND���j��g� 4Iӆ���.������t�.p� �>�W8D�⏵���-����pA;�d�S���dC$\�`,����5�DF��(2��o�����2�)�-��]+����O/��Cߔ�0%�73�#	�k9fx�I�ŵ��G���0JȆȇ7�>�ifD=��gMB\��t�i�[��ĸi<���o��i���fU�|����=�	u8�J�yV���Qܟ���:32;�U�_�}||K��G�2O�DxϷhr͍�r���E��H�l��	�Ć:C�b)��7����F�;��$zC.0m�Ⴏ����x?��>aq�ˬ�������6��l�v��6z�x��7�=�@��6ѳO8�ޤy�S��fM�]����a�Q�i9�?����!��7n��l�|[`FN�ɰ��n�x��z
�i����ߴRn��z�Tʍ£{�i)m�W�� ���%� �*�?0��o��1sw�*�?�#��Rz.o��{?�m�!�[��(wP*�R��w�XO�_��� HkӒ�_�w¯�!�~�6�-pG�OH��K���+?����M���q����O � �oqm�Ő��|f9ߤ�F�>�i�+>�{ �7MSx(��N�t���}���Ή�2Mӭ��t>�I�yǌ�9J�_�B�I�y�:O[�X����ius
��i6|���Uԍ�鬭T\�p���\wg��� OS�a�?�:��~���!�	��g/8�L�_�����'��&Ŗ�'�i�mÏN�Ƿ)�\]1LD;�l����rv��ܼ���3�����U�	޸�������|>�M�ה����������&5� R�Ĥ�_m�3�C��L�T�J'�4�ѳ2qf�����>ajfa�x��9}�3��~KN"-�&����M9}Ԍ��$���W��O�7�u�"��[X���:ߴ�8d�&
�A�v���L�Nx=���&aV|��	�3z�4	#����[�%��[��E�o�t�����$�p�4of��ȧ��לo��fŦ��e�H�J���&����)�m� �ڴ���+���������P�8���_Hg��+u��{>�oW�!z�y��q~�ZoR�x�+�i_~+�����@��+56|�;ӏ�2���}޶��>:���M�F`j�ڴJc�竍٧��J��!�<o�{���i�;pV�i�¬�\��Rv�PQ���&�s�-�F���C.���i�$W�����?^ݛr�*i�8{�v.�݂.�G��e޶.�Q��XV���iG�Wz��7%5���:ez�/@o�iꇜ�i�X6|w��k>���w�5G�U�]���cti֒�⑇3��3�/���h���C��3�qh��̪�6|}�j>~N��8L���Ud�T�������o
���2m��/p��o�}ӢGty�'���6z�*D��|KΊ��:�M��{~��7ɵ�z.~^����ն�3�פ6j,a�Ӕ8-�}(�!
%�I���k�!�ch��-�\��gXN�7U�1��4�0�?^m;>��-�&�k��5u�� ��$ib�%��-_�Y������Cφ���-���8N��)�����7|| ׷i�!�i׭_�1<��	�iڶ����g�[��%5m���D�6�^d �z��tئsg.3Q& A����B/W�7��{�5θl?���Y~z��7I��˷n�|��/���ؗ�����4�n���A��M�s�����=F����X���b�c��{ѫ;O�l�q����m�*p�N��B�4���?��c���[���rP�v������t�����Z���7�pu3�)�����1g�mW�(���o��y胚q��_���qN�7���#̓t>�x>�I��^k��v�\𯯻:�R�W�Jy��[釠��G>��+��1���>^}<��_%]��5N��˺@�I����L;�{�x�#�t�
?o�}���IW��i���_O���ϡ��]��<I��+����&IWXrIӎY^�9���mq��v?m���z�)�ߤh�´��~��{�$�'?�S|�� �&I'�aL��d��{:蛪�"-{����BO����R�Km�ºQzk�����������S������ho���ǁ���_��P�Ԕ�7�p�u1@_������M[X�~ӯ��/��w���+6�^�_�~rnQ���lS�MO��J�}�IѴ�vh:��tW{QN�����趁���������3������S��/�ƭ$�o�	R��3z�MW@�c@7<h7�]��U�~>j��kJ����=J�-xU�����o���p\o��a����-јl��A!hG��>l�q���3x�j����8ȁ��Ů������g>��й�q4r:6N4��vy1�渊!^N?�aLZs��7�q\bcP�e�-|�����YK4�f_� �RfT�f��V�P�>����E��j�u�;���W·N��:d�+^d�� w��K��câȲk�yLS5�_�w���eW�*K�bW1�����|E������l6ק���8��������+BBwp�d���2?����\����.NcR}R���v���	aDﮆ�%�h��⋷y��i�!���+�Oǀ����j���XUw��$w���]dB�tv{6�P> ��7��j�����:8 @:���a�|���h���u�T�K�ȋ��o5� �0&�8Vq�-�uT˽��]���� ��Y/���}���r���<����lZ4�x��*��BKT"��/�K�]�u}F��x�Bĝ�3��t9�1�:և�o�JԂ��8*�-*���է���})�câ���zKSE�_���������aD��z.T����k�2��7�pu��p6�?s�c�?�����z�S�$�� sI��/����iݭ��[�8��Zw8��j|[RZ�Іش���x9�P��L���D�|�G��y�ݡ��y�6�O�sL��%��	�d���K���h�񰖳��Ѱ�my�8�a�gS�jB�§��S.G�t5�&eJ���.L�?�F�r���Ac�X�Ӡ�0'���v����f]���r�lJ�i��N���5�%��n�8�+
;�g4�?�݉Ʊ>��|�[!� �)�ۯw|8�(x��}��s��c���)I��ެJ;�P�&���Ck���ȐR���¹1�O���>_bm�$���e��z��$�;�R��3'y�>(��ga�6ɭSƷ+IJ��yn�4/��=��}=�y�t�#Z%�>�;��<����� -ixe�OI�a������ws�����kF�:�ʑm��Q�}�Y$��^�����~�i�~�!�g�/I׻��ZǢ��f��a�G<�6�IsC���z���t�Ut���
B�EX,Q)��eQ\?�xA�Jhi�_� =���3�(<_�2�:և�o�+E�c�Z�l~�Q�ūo�al@n�?6,�4��f��|$��.�M|U�	4�G�{��p��op?0�=���)8o�&�-��^�o��Ľ<o8�O��J���$�)U�=M�a�k�c�}���E���9�z8� ���4�����R�C�$�)��BN�Dw� �  
Kv���%[b�7컥ܴǤS��xXj�&����F������p��]��1�f��~�л
8v�SD�wø����Q���$��d�uN��<�ܫ��-�[��Σ��~S52|>�Ru>��~�x|�{k�Щ��s[�c}ر�V��$�L��5�z�<4R��>�����3�N�$���|�E�RM���,�y�~_�;���9���1�gs��C�I�;<y\gj�v�Pm�����ğW�"�bkÒ��Q���>������"�Os˺��K{�6M�<;�Kf惦+��� ������r	(�MM�[Bv=��;����	`���)��n�%D���nq9���a�¾�,�{X��ov��!�]�����b�n� �	��
��[�������l�}Ð��0&�-*�k��cKT�q�x�x���2�%*)��_��h�S.S�
�5��\�ER5Kn�u�;���W���8{`���g̞��slP?��&�-Qېee�(&�ū��]tK\���b1AA};�ި�W_���Gr>���s���xt����~����=Q1��%�mV;MM�;&�@���i�_�����}��-�4����O?�v� �MM����5\߻�ی�l�����|�-��ޥz__,{�VX���b���ׯ_�=~�[      �      xڵ�M��:Ά�}W��9�(����o���/�鲫G�%V��H!%�<�ȗ�(Ki�/�U~�0�/�4~$�W�:b�����C���7�'*(�����Y6y��t����I��A�H�4"�����0q�Q]�L�&��c�y�5I�1�^Nؘ4�$?1g�|�8�8��Jqi�?q z���2ъ�U��O�Ąb�A�� �gl+�a1m�H���&�67q肘��$����^�`-��8!�tXR
2eL�?���)���j���x,U��%�O W����?G'a���f��V&�߆���9��lW�.�c��)AM~7΂�0�^4�Y6'q�$8�i�̺B�L'l�%#��X��y�xo�e�5?qʉ�C&�#ʭ�ْ�+"��K�����a���ʃ���D*&�K U!�۰�$�G������71	����[m0h��e���{B��) ~b��m�W�ԩ2�э�9�i��*�Z��W���0�v����9��Oy��^��G� nZh1�7�q���^^������^��g�?�B
|�x/T� ���B�)Q=�y�Y�&�?TH
�a�=!4-T�SKx�E�`���n�Ymu�����������ͪb� �����
�<>F�%�����A4E~��D�1�H7U�1&ޚy,5�?k�8t�xKl�?n�����U�����X�V����q���CD�����Q�3���B�Y������bE�2������<�&$�Nx�~bU�x�x/VPĮ�M8���{񘘦[�q`�����A�M{��1�pxOVPN�^�2`
��M��@�m��1#�鉷%�u��N!��Wl�҃&�װ�8�@>m㽔'��_�n��&�-+[2?����ߏ1���{�-	��B-�a⽔g�(��B�H=�%�%���K�K�K7��}~�A�'�R���IZ���4�^��R�����B����4����W.X�	!d�LI~�(K"���r^3��+��[���{~\BH�y9\��K�9�DB���l��y�x�x/�����a��0�^�.)0���L����tі�_Wd��� ��})�5�>�V3Q8L��AJ+}��8�Wl��x[B����x�	��2���byjTaIyMu�����1⽔�4N�������c�{��Tܡ�?����b��#,Ɍf
/Yu���~#�:L�7�-�'&�#����DƻV��ߍ��6�V�s�{n<hDw4��s�^�:F��?Ƶ]�Ģ��9o�
�W���8��"������E�?�E+��O���7[i�oc���xTM�*�g��x.��'`��
#f����uȉ�i1��W��&�
�3\{��6���j��5�Z�&T+�O<ᝡU)�b��^:G��g�?��h~|��{3/LI�W�PA<�V�7����yɂ��&�Z��1N~k
�Ċi�9��r�G
�U��3$a�g�y��%����i�Xk���2j|�	��ͼ�eDt���0�V%=㌄�*/s��y堍w��$��A��-�'ޖ"4y��9az�xK�O"��N�Q �%i�چ?��L!�a�2orO3ym,����Ǐ-�����$�6ۉ7S,�q�g���{~l�\�6��5�̐{>��=S��8ƫ�&�Tʪ�2�ÉG 3��S�
~��4��6N�y�Z ��x9�����~;�1�=/���^�1ǧ��p˥�[1C�K<��m��O,@9&ޓ�q�q�x�x/G発���5ƨ����f	���9K�tڏ��q���"	ǉ��q����#}�q�YW��g���/�Ϛy�S^R�o=�xϏ��hw�甿�	��e�:VQH�<��$�Vן8�d6ӌ��߻���Ŋ�A�?o�^�8G���-�4��c���a�=�f��'z^I�y�~�x/�lE���%�x�xCY��C�+X��x-~yEj��.��ؠ)�^�-�Vc��O�(A�&�s���Aj�Ɲ�}L�����w�U�9=ĵb]����	�OȊd�������c���4�(Z�R�.�L��A�V�9�6�[�dp���A][/�Q��[k��b��~w?.�{.%/h�s���;� �O��=ġ��6��Wqpo��{�<dܛ,=g���F������8�E��s�u���>'��h~b+��|T�0�B�� ��e�-�P@m�+5��|����MK鋛�A-��ڴ1����.b	p?��%�|�	q�&fH�M!�ű>6H5<ac*A���"�;�7��+�b֦�DuK��1��j��6��?��^升�0/Z!6m|I���cM��y����޺���M[lG�G7�)p�[��#�"C	��y�����X��E�AV�0��q�I��.bd@�'�8Gr^E��M���,],��U)�<�f��V��N[���g��ݴ�:c�k��G2H�V�?q&U���p�� ����%ƾ�'����x�+�ܺ#��".�V�x��(��O�5[��"���+B�T��ܽ��,���]�<���y!�I�c+�8�A�9�z�,�w���TO3��m/5b|DE �p^��V��#�j3�o��z�s����M'N�&T71[ ��%DZ������x"}���~ۤ� m��!�[{_x7����ĸ�S�b�ԗVN�e�t$N�ְ���D�7�+�g�
9��X�%�����*��c�]��ksg�::z���^F�i��3��5�'�w����V[,�qh�W�(ڴq����'N!?u�&qk�O�1���Jh�����%���D�@`h�û.bJ���Z�'�q,Wˎ������P�/���b�窗��W0�gr#na87a}[4����X��kdZ-��4��+��͋�~ّ��u�芸�!��}�ģ�uu�u&�-�b��_^��g�ޠ]��Ύ���f����~,�T���j��9�ou�8�2=63����a�N�<�����8[�IbIq��lLW�J���2�^aҾ']L*���䄍��_��ML���������Uao	�Ϻ&�a���>'�>���:-�mc#V�'o��^ڳ1Y�X�M�S��,MC^��� �����6&�V(���+}�I�F&8ac����^ae)�K�M�̈́�̣��ؘ�t��'K��C��J�6N �W�����Sz�����n$T��	'S���hi:z���G;`c{��
�\'�<�X-7�Œ�jG^�����z�"l�Ě��x��tm^���{��?�,uRq�p���~ј6 n+!ـs��X��z�+b�����1=g��_�/���%�V6��cnb�w���ŶI}�8���pg��n\�g����nmF��C���O��@��c17���6���;;������Q���w�Ō�|g?1E�O�:H��fcĉ9����Ƨ�b�iň�U�����p��<9�6Z@����?�q�_:�x�]̈[^U^$V��&�i�()�\}G4ů%�(�+mJR�6k6hDX�Э|WRI������VB�y�wB��|���³el�x9qW�x�әt�x'�q+~@�����wtՀtm�K�y���\柉#��oʿc��ҽ�B���&�z	ԥ��ڥP�1ڸ��{Ĝc�R^xf�0YH_/a�qpy�+&��	��8������8G�� �Zđ4��x-T��gc��Kc�^��%�{W���	N�h�-�k�v���.�k邺 �Hy5@���N�k%?�v�+ۼz'����z1M��$�V����E��~	� Z��B���)ZLDq*c�;����K�B̏WĬA�}&� ��g��
a%�Q3:���:�~mP%�_{�^����ՁP�`����m�� &�#�zP�±]Bt|�����GF�8��>9�a�r-^Qp[1߽���%4$(�Ęs��8R�;�G�c��k*������G�ʭ-�72��w�����'0��Z�K,���e��q��b�^b� �H�ml$1һ�� �T�	b�U���ᜟΠ]b+������ MlJpnNb5AO���+��>�l�� �  �*�H�Y�u��82P������@83D&u�1���VB�׃Ƅa��=۠i���O�?Js�'��
>K��?&4�N�GL`�"��[sBm-��o��Z_垍��~q��O@~���*��`et���1C����&fE�;@��{����Vj�$�
�(o�J,+�@��>��Va^b��U��X|[�c������<��ִK������AE�"Go%����u����'��G��~mgz�+��P���-*tX���`�p=ڠT^/a�Fԝ���f��b���?)���{<G��@@z���I�>�8ӗ�%l���Kؠ�ѫ�q�P
'�~�9��X
)�&���A���@ �$uq�"���]Ĺ6}'�	Ǡ}�Ι��!�2�&�<��;X��)!.q>B�E"���������J P���-�A�p�-�wǲ�	�G|��@��і��I|m
x�J����҂�b�3��ǊX��e��"]B�:O�^��K\�W�_��1W^�El6��$����p�p�x+��:��(Nb�����̳K���ݱlPd���u�9���ګy?��K��,�06�d���3H4I@2�M�0ߕ�.p��\[��jر�R���C���Y�e��ֳA�\� ��D71(#���B� �@�1:;m��j��3�����g�����[	��8�����.e��l��B](t���m�r��@�T��?�/_��Ԍ`�>P�[��z�r	T[By�E,��4��X�^|}o�<G��@$Я%�}b���$�G���)W��0_�b�6V�}q�nf���n�R�<���Lծ�w^I�9ů��N�,����]�r5���:�9ׁ�q>�x�5����9q��m�`l8�ĩh�Ħ�����[�M�<6�:ʽr�<�6�k��}�v	�_{v�`*۔����A��^b+�1��޹f)x.`l�����c�6E���:�"��;�n!ݛ�6D��%l�h�6������!I�      �      x��\�r#Ǒ}���W �~��ؖ��eV�헍pԕl���rh����j�$fԍ&%`c-K3@� �T�ɓUYP!;ʂ���՜����4D�D7��ٷ�]�i�u���ƕ?]t�]jgߧ�ۥ�>�X�fմU�������[-ft�m��R�-��-�R/���RMU�S�1m�6)�L�"��C��'���&��35l�j�#��Ι���e����B(���Y�����)�W���;��*A̹ݨ����}�߶M�ͷ�*7���Wj�j׬R�6!U�nþ��~ع�T�U�]�P��Ō�����|��j�n_�d�|�W�i���;}�z]����ov�f=_���6qv�C�{��M�*��WxQ��A�kS�U�M�S�u�zsW<D|=�9�¡�5�������pd��Spd���d���w�ج\[�`Ĵv�8�m��6U�ߦ>�}�fvk@����Qw��|t�a�ľ�[#JBNxkW����ޅ4�5�?+�=m�}��wՑf���ʵ�:�R�JiU5�{ Q�)4m��n[�
s�!���Z�����y���g.��?	q�5�X��|�i����p�6��﷏��s��&�p.��r�fH��ꩊn���#��[�����;�,B��|��@-ff!�2rX���r��&p/?�?C����K�w�.m���P	!u��G���~W��u�V���H���qߔi�՟��9d
 {��P($�ͺT�A �Z�1x`=r��5U�	�����<<����w�/�^��&�; �0��?�>�M�U� h�k�>�Bԛ�m�G�c{,`�����k�-@���+�dP��2̑�u2p��Xf�Ť&Y:�B �1@��'��H�z��򅥊�Qha�ԼZ�P�'8��z���ڥv���@AYq��گ�3#A�����9�f/Zz"�+����P��ĉ��K	�LH�� m��RBAhƼ����$��� )s�ce�2�1łh����j	9�Q3�JS0���z�$r��~�w�+����VU�ޮ��c6��Z���6��s]}W�\��G|�U�!g�]u���Tkp�}�.u��d�XpK�A��X�d���#"���D'�� �������u���u�{��?\������us�1���	?��*_=�׽a��[��K�)$,�=�C�%^{�r4Bz�=Җ'}셋� �eD�̕9!}�v㱦�"B��
+���BG������RM�����ޜ�5>aK����~U!�@��O�X�A�L�=�#�aSm���b��E��}���<T�RO��5�i8����`�%���L�JJpn���9h����	�'I� 5�"���\(�)�jl� 9��{#7��X�3�i�`#'�K��{W
���o��,�g�B�T+�����&�i�4���]j�;X�8�P��J��;9���-�����C�@iV��T�T�cʦ��G�V�dO�r9#����6��)�*��  �G\��uW��s��Gy0��	.�l�WC|GJ��1#���.�k@R�!I�DsKx�XqA�#NYk�@F��h|?�;!^2��N��u	�v�d)�]t�S�i�<B����.�(K����$����*�]���d/��T�˶�,�uDr��E=�$��U��҆x�����4��,VXͣqʡ�&ʈw:0b8�0�ZfǍ��9���ڎ/uCc����)�VpÒ� }�nx�w��Fi�[�L�M���|�v��4OU�4������s�ZW;�y�����h���T��;�c�\:T(����ͦyp}��Z ��+�W4Kա}���J3 Qܡg8J�mJ�����ҁ��RBDz���@$1$i��}p�#�,eB9M'��!)�X�(�:ef�{��_DN�EUN���ga
L����@����hz�R�7�0D]�T匴tH�p�4E�5���iw���C��їyh��>=��#�N-E�5
���X2͓	�r)'6k�ڧ;fT��^um(J��[�G��%�ן�=�")���ç���v���4��w	�vU=�C3����<��|�t�?��D�L�3^)��`K!A�ɤ����V�i�$O�P�!���A�Ñ����qw�Q+�*H��N��d�,�m�@�]I�C�=u���Ыm��O��1��M��P�W�R��p�)��c.����]��κ�QS�1�]�v�Ey{��}�^��{頊HE��G4R5��D$���f�����{0*��-a�!�O�js�ZMPw(%+
F���u���3��lvM��V�R�����z��780}i%�B����ػljp.���ɂ),_Hm
ƈl�<P��UR3�'Λh�H� /A��vM�w:²M���g��?�]�>}�u鍏��3�.@v��������_��\���g����~�������]|9�g^����M�U�}�J��ouW�Ζ.6}�����aE�j������;�te[�lv.f�e1]�a9I&����dIU�x�+��L��AGa`ޡ8�	�s��	�f�hjH��_0���N0��c����t�G{K	!������z�Mu|����('{p�3�ˉ�(�EI�����q
A̓�O޲���
��v0�B���H>X9L��H�yS�cF.�`h���=�0�6����?�P�}�+D��V�����������ȹW�����_���V��1œn�#�4(T�h}BTԬD�Ys!"�Ի�����4���� QڴAX��.�i�����+��\���z0�/���a~8�^�&	*�l�3 fmV��J#���F����錒D8'ǁ�h8�7��X��%_K�%9���4���Ms��iZ��N~j�q���u!��r֤�M���`��̢Vh��E˯�0 ���~Բ����׈U�DM@�.�%U.��ٺ�cͫ�zcYP'Ym��r�|&�o p!�D�A�}2$4��i��F+�(*��1J�8ne���1�`��*e�Nt:y��~#nC*�Z>�&����)|��'n�7�)�ݔRj�܄�r~7!����:qӾ�M=�.�;�%����x	p��{���7zi���D�1'-1���n|���^@�Г�@ ]��hb�
���/����RS"	�Xa0Y֚y%3TG�Q�;�rA)'c��҃�`bE�"L���&&6I
��B�
���`xʸƎ� P'���㍈d"S�����CHOjRN61�E��y�C�-�ğDӠ8E礔�8���9P���!��ҌA�2��!�$Kv0JI�J����i���/����U�w��7�ǂB6��{���Kz��Y��[����&��!�e4�R�( �{�e.%�#��
��W"���H-�eґ�R���:��2�MH
���RAR\�k�|ւ
9�gtqmD�
����l+dﳟ��C�_n�~U<���F	��D�EtY�˿�^�;����Èr�j���ڳL#��EB����zNBN\� ��.Rt���A���x�
*!��F%�{���2Fr~��E�ى ��1�e9�t[M���>��t�"N
E+��[��C�JH���UK�m�JT� "iT�3���*K�a.�/������B��7]gY1�L0��#�R��2���nv�E���������k��:r�|�1rL˙8nu�2υaR���ڭ0?��4_@���uP$�a��N�`|�9��z㢚�tn5~�8�*s+�X��8v[.��Vu>��i�������-!bl����t��0R���/�)S�JO�_��y�q�����{�օr���-�2���nR�.<����M������G`��&sV
��:%�0!Q�i�V	hgM�x��H�T�`�OY�0|����ʣ��5���xNc��jȷ88Eg*3=S�1��\��- -f���6=��e�i����Nr^Z(M9�����zWH�Pv�'<���>�w�u?
�v��u?E�ش��+���2-�.4e�\я��P��v��˩�i�6��S�&�T�w#`���@ e�'����M?4>���$\�o��S�ˈ/ �  ���n=��l��é��~KT����qUn�.:y>U�nO��)�C9eF�X�����`LZ�U�.�2�k���{M�P,���Cp�T�9������+?�'rAtQ�Ɓ͗QB�y�j��#�����g����u�}y��,	$����`|��]%��&m��X�sj�� /��Yh�c4&Y2��!R
6�������O�yf�,S�m���y����2P��p�w�|x�+��ծ^�ӹJE��㎁���Ɛ%��23Z�$��P�$,zx�3z.|&E�8�V�<�a#S�:rF-�������sH��2�%�|t���@�~�a���X��*צּ^�M,���~��sX���+�+Ck1�G�s��t�(Ҷ�2W��.W����ǩ�T.������(�,�d�N�P�e�t(��)+�Đ���؄fT'2�Q��H�d��.WvL0�&B^ah{:�����B�Jh_ބM�Cz��Sq�ԃr�2�~��Q��ὅ{.k��l ���evPyϑ��@6#E��d�Y&�35�ӏ#�-9�:�X��N�5���#�]�hr��Z���e��˥ϻ֕����ez,�e���
#u����{D��s_���f�_�k�\�ݮ'���q�ݧ�o�`ߎ[o5�T���2(8ĉ	e���Ď�+��<��k��ai��29�|á��J�ih,��R� a:,V{:��i�w�E�`�ń�Ԁ��H?U�2y��ُ���=���)�AW��pwx�0QÉ�)��<䒽���4!�QV��&�����/���Qoى�U���9��TE����a4/<��̑r�B��[�)��)Z����>H�B,'�m?4jv��?%��ĝ��P�[�3>�Ⱥ�ե�ש[���z�W����"�V�[�B�_�!���2����֓��)Ϸ�� f�H�>��KX'z'�������_|��{j5� �&�|�J���;��o<�$p�.�$g8!t�h==޽�7�-_r���3ԗ�*_[�z�A�a��ӈ$s�ޔ;ler؛���w{����JW�1��Jn��|�����S+�\~�t�V�r�����h��B�}�%3n�WG�_[�Ua�ݟ�]�[��x�r���5�!�d��7�(n�]h�P�2ҏ@z� �6�Q�p���� ��]�I�Rh�尓�Ւ�^zy�7\����7`-	����]�σ(w���R�H��G��`4�*t��3��s՟�a6?�}g����y��+����ƙ�������L1!�K��3�֎r@o��]��%��\�me8��U^��R&�$w�"$o�^���	��� ��e�P���;�a7����t�.ʵ9����߻w�6g��c�tFPp��#��_vH��̌��K#ЧB�xs�^�E3�钼mD=�M/V.���RrP����y�̻�asB�] uK$�<���Uv��&pC.hra�t���j�r��%3������K��ʮ�hDҐ��\'���i�t�ﭒ2��ej\;�~����:�K:�DP%谓�7����>(qQô2I���`��E���5�\Л�k3+����W���#�K\��$������j��5�"^���|�tHJ��"wo���t��l��W��Y��n3h�3a���!N��$ᒑ��Xc��7Zv��p�^\��(ya��7�U2yJ�Y�K���M҅�\���`�S�oX�b���)� Q�v�`���Q2ؘC���2�\�H�B�С�p����7�~��\Tl�/�_f�Y�X!����p�vIo�B(΄��`���@YD�]^nS
9�6������)D5y�����x ��dPeN1Ey���r�I:b����JSN/�+_4hʷqx,-7���mz��[ĆW�ܓe��_q�M�:?�x�ߋ����#Czk      �   5  x�ՑQK�0���_��&i���	��胯s��rW�d�f�!��&m���?�ڞ�����Z��V1{�z��_%/�/�f�x�7��e�PR��_��y��`Hr�������p��cZ��[R��s���9�U�HM�\�O���ܺ�!j��s[�j7[t8je�ܝG�Ѯ*��>EE=��@Qv�Nl.s6�@�ڴw3Z�y9m����g�Mz����o,���}�w$����<�A�˭iM�]�i�"�s��ш�2��$���mc�(%H�H��Y&��so4� 1�\%��ŏ,{�Ͳ�9Q      �   �  x���������Y�I�,�G��90�dQ�,i��ڱ�������݃�,�f���o��ݜ ��w4݅�㎹�BA��X�\���|x���A�.r�����7��?>ܿ������������߿��O����G}z��~���?��~�����G����>{}������'���[�������;�^� V��ʿ�}�w��O�߂0^�U�R-C��8bOUa��)P���MHq��?���}�D��5G���֌�s,<S��2L�4G�P�eP�9VI4wG�Ĝ+:��$�,8�q�=jиSV��?����i�;�Q�*�w����;8��"TP��Q(��vʙ�k�cF�Q�;4B��;e�NϏ6a��v�c�	�ڡ�47����$�,Q<�X���F.Ijt��I�P������wJJ��z�M�W����h�#A�)g����h΀<׫ڸ���cFV�z~�'4	��8!���0a�`�9ڄ�!n*���1FJ";e�<��h�D�Ϗκ�]�U��α	I!������4k���$�5���뫳Lͻ�:�i@tz=�&�V��yǔ<��N9bn^�U��t�T���P+�NY���3G�P�����Zh��a�s����cӚv�Ú	��m-�;e, 贋؄:��}����������/o�^?�}{1�������<B�q^6�E�w���2�l�ɻ������!寰��͐��G�Y�7�������ן~�xk��Wd?Eb��ǭ)���F)�\�`v@Dv�c��v�0�k�PiF�F�M[�x3�J[�(����`�P<�2����CU���"d N���.@Є[e%�+B���K��q��dt�)�L*Ns4	)��8�E+��J�0G�Q�m��%؇c��4G��Tvk{o;G*#I�)W]����&!S�����c3I]o*:��$�\��o�,�:��] %L�:�����f�uNC@�UM
<�r�q�9$��aBֱ��L���66a\$:�!���;e����h�8��c'��њ�fu:}�	�a�ӷ���Ͳ�������b6!���������S*w�g����ǳ���~����=���u-_Դ+Ɉ�q�Xx7�
	L|i��v�[N���)n���7��ǋ�PӮf⁞���qm��ކ��A-�Ju�����\�J��rb(N�\؄-et�lNҡ�)3��4�	{S��8�cC[������$3��\��qN�
<�M)N��؄3gT��G���]0���?Z�-Vt<�A�Qv��Bt��M���a�&�)��6
�ΎϏ�b�i7ꤢ�i�&!����"���}�)9]�`J'�+Q0�v�+��J>���LB1o|q�9�`�o�I�:�`vȵ7��j�}wáM�u�M�Du|]n����cw�����/��R�o��;�*�O��Tr��'��w�x0��7U�~r\ �D|8�Z�g̜)Os�ܤ���fH��xS�ؤ�k��3�U�p�S����iWB���] �	t�L��s�ۏ5Fa�A���V�:wGkky��-�0"��`��ҷ�"�>s4	S]�E��c��a��r��I�y��8>?b�Ս;��i�a]�_G��1�`�� W�(UO���Ѷ�Xk_�~4��_@vJIY���;�M�0�ܻ�b(�vJZ��g�&!R����I	y��2�|�hR̚�͑"b�)WU��g�6�Y�ゃfMa�,��;�� �	SA����~~�e�L/-M��д5�;�-@��N9S��eǰ		U�~s\��q�m�,m��E���#S��U2i�9��	���	�pO[�^�U�0�Zsv|~̑�kr7J�N��Ey��Ӭ�=� ]���PNb�S�p��������A��*kE}F�~��a���4��c)�u���I��$��#W�<x����g�&��PG�~s�=ԾS�P"���$lQ�L�7��[��ʖqs��l�a�$:7#�-� ��,;e+a��
Gۮ��r�[8. �*�S6b��1l�^�+����+��ʱ3e���3G�pȔ�8։6T�(>�p�W�*wʆ�C�]�h"����o�� �|&zU
��	�IH��~�����Ԫ��9�:f�3���9<UnGۮJ���^�Ԇ	h�,t|���qi�����9G^cW��U���>�9����� WK.i��Ns4	[&��K�c�9��U�X}�h�Q5��~s�k�6�ī����d�9Z�܋v<�tP<� ]�N�r&.p���G���ӫW��ob'      �      x�ԽY��H�.���+�~mҰ/�%�R���n٘�% �h� Eq~������c�	��:�L����g��/ߒ6�u��Gڔ����#�3�������Ff�aH�a�������]�a�������[oi{ocvm�1+�Z��T;��y_���}SY�]�{��k����zk�9z�~o��[������Ǖ9�o׃]}���>�?4�~�}J��+�*ò�z����wާ��ԞYu�{��l�/��o�W��;�Y���ϟc�~���m�u{���7Cfv^E�����ҷ���߭�2=}�;[-7ݪ�?�y��+y+k�/����5}�պv^i����]�ٮڝ�^��mm�ҔG��P|����o���]��?���m���}�um7+�JMo7;����o<��J1�(&C��ߴÎ���݁��V���������;����oڦ�mG�-��E����v���/άmo<�ck��G�=�W6w����"���JM�oMZ5&���PM�|��/#?�����K�&�*���$�b�p����_����l�)n����E���EU]%U���"-���t��@���S�ە�]�6�Պ�4�po��	o�a��v��n�zt2��ߪ��	�4I2D'�cBwo����7���ە���n���V�!}7}��)��̻���m���Җ�U՞�S�SĲ����.E�(33�<�y�|������5']�i��tp�������P4wǭ����x��o�,~����R�aP 2��������vw�KCپ��^�:xfi����~���J�UGQ�����/�TE��J�R��x~�Ң��e��[��(JFG��n���:R���>�뺤õZӕ4ߏ�Z��O� "u��ګ�=es�i;�y��߼�j�|~�� �#��r�y\rl(FT��ՂW�������7t�,�<�Gw�}����-�_u���Ĺ� �QWf~�� 
�h�7��W���B����C3��Q�()�+��4�=��嶭�i!L'���n���I˸(�1�,���p�-E���I�]�o��=�Sq���|_���8�Ä#,�Z*�����xP9�У��jo���?훆"vhQNPkc@*1�ۿtQ�7��%��/].�RDpc�ah�JJS-��W+���H�EOB�SoP�~�P��w����V�g�]}��Y��jCřT����-ʲ�zdv(� �b	e�x�G�j�k�J��B3X�榏���k*�p���Lɭ��{���OIkOi����a�#���ڦ��>���qP�3��ϊ��/�腔־�;	��|�so8,)����8��b~S����d���v@�F�ĵ�����q�@o�k*H�t���+���Ň���
R����~���z��;R�D}uUu}�{M%-f�����;h����0C�o9�)2�E8��էa;QoI�n;,)����W��t�jKw��Tkn(Z��?	��� ZI�J�d��(��F�+�MÎ�AGO����g׷\p���6a�ZS7�a�/+����&�_���?��i��+_|���������9�g�e��mE���~o���YoW��Zo�/W�wZ��4�[�鱠��~I�4i�?by��zĊ��eσ�"**�s<t�<4�?D�Q�0���2��zni���~�r��H��vD����D="]�/K�mwj܇�acLP��#�~XE�}�����K�QZD�~�@�qd�����HG���[�nU��F�zC-ٿn>��`٢;Ĵ�G$��H�5��Q	&g��ֆ��~����s6<����n�}8k�¤���Ol�f�U[��N.8ay$�̚�vt��o-e�{Ԟ�:�$?�v=�g��&��g����?{�E��$�C?�3�IށO�N��x�he��:;�a���#�D� ��K����E���?��:d_J5=���ra����v
ό�[�S��<K����麶�cl���,�N���	�����E_/	���~��L����%�ߴ;�
z��F�OT���[a,����3k�E�臣圾`��Xn��o.��i\q&��w+�<�(ٍ�e[톁_7�-��T�#�������;��`�$�Hh�fI�3Y��1����:�a�SgI*��is�ĵ���,.do��A�(�r:�w���s�qo�w��B�~C5�}�f�pۭ5���X���G����~'{�i����-�G�,�xUB��j�}���w��ϲ�ܡC:���w������Na���B�>�ߨo��\lђ}��y��m�rY�
}�U���C��m�s�����i7X�c���������R��ރ��	�,�S�4���������e��wSl����Js/�#YP��l����!_7�tU�Gn�	��п��<��m=-6il2��fa�D��_�M���S,�����z���o��-)l+C)�O/�f_7/��7�	=�Fw�T�5����R�:Pq�pp�\z�P6u��k�Fi�k�t�1����<��K|OM9Zw��T���nɉW.�Eہ�P�a1�����>�n��l�7u�y�R]��i�n�Ö�b$����{A���1��c�H��lIp���z�*R������@��N0K��*
��b�<�Z:,�Ա�q[?��.
9O5�#��l!p��v����&��k���tf-^���ȐV�w�K\A�4���>�qw��it���aU�Ao�
�ď�tvЊ(��s�ߑ�]�M��F�
:FT �g�c�G%@���R��G�qmk>��t��϶��m~��-�*t[���Sb_u�BJ�!�)�"��.QvQ[��w��@�*nc증���;�]��k󍗄+�nZ.`��P��;��-���|,%�^ŧf��K�5�x�t#���z���v��}��I�e��t}�'��}/;��O L)Z�;�];𚒁���P�]s�DkO> �\���r!� ��S\��V�`�2<��!+�T�q@��,H1��}�*eKs�5��5�V�����A�\�� ]����=5��gP�:�2��Ţl�c�ǯ_K�;�&�¥�s_� +JsA����/��G�g04����#�ܫ����B��;t�Ζ�����ǻAP~�T�2��k�U�(h�om�֚[�/�2��-me��kWgۑ[,\�0��&�� ��4��Ȼnضx�dX�`;y�f�Q�é�-� )wp�����q��o ڒzY�c�ސ���k���x�_��lYS��IȨ��_���+���J�u��� Vr۰�7��|��h�A��J�,H���RZh�(0�#F������ s:�c�y͊������8���*EB	��{��N�l���8]�dEqQ��k�Q,�p�fL?mM��J��M�5fE���YKu�s����/��S����h�I�5�ݖ�9k�Zm��oK��7����r��m]St�ۖ�q�͏S� �����V��K)2M��P���`���&�M�=����7��,|�!LS��HL����9;M�8����1Վ2P��Wၰـ��k=���yc��d;\R�ũ����nOǋ�G7���v-&�Uw�i��R"î�W2�.h!�^�c�^:���ĕa��>��8�_w������b>q�^P�����q��VQ,������][j��*�=�<L�7fmϸK7yv?����"?�u������=��A*���@�Զ�^��i���,(��1������YDI$K�נ��R��դ+9@����v��^�{(��a��h��l��̷3/R�U�����X�ɯ�RST��Q�n�2lv̟l߂�+u���c&ú��s�j���7��
eSL�u��u�a�-ދ��t�zV�n�gH'��9�6�z���k!硕Ӎ���n�2���g�u���+���/˖>�A���(�Xٸ�o�A@;N?�������aya�����b�ό��n��u��8{�g�ɳS�@�?;q�$��������z��nXxV�-1��"ُ<�Ow���5��l�o2S	u���<��/�T7��P�0���@     ��#nC�-�Z��F�����2�e�`����<F�����3~QS��A�D�b�b�s�P�=f�0g���,z��kj�����m�ނ�N���Q�ڽ5A��+)�Н�'l)���=0ha���'k���ڶ�#������ڥ� ��'S��W+��1iu��HmJ���<�E���	m����XP�+'1�($������6P���N����o�A�L��F�_ݛ��PM,4ݷW���9��DNk/�/t)�Cw�1�Ƀ[�I>3��\`W;��K�ᐁ%u�va����+(J�j�a��^w���?���|JMn��l�|�Ov	p8?�iTH�D2  ���Yt�F���]�Y`s�D"L)7�-�o�E)3?
��q�[%�<~g�uF��Q*ܴ�Bc��ώeB,;Y:^�~梦�� ���(��a�,^�(�o,0���߬�[fsR�ӣ�������;�=o{�Z�4npk��Q���p��ɂ�
��H��6M�
+]|��Λ��QF�(7�W�Y�So����2�&sY���Dd�nC_2C�I)W���ue��n�DeΖ1�h������Z�+���~YtN2��a�Z����)�_�0��"�}�G��+%�Ds�.�~��0��-�M>uP���L�q�[R�WQa�$�֦Z�zP�����M��:/�`~:��<�s�l�W[+���ܤRQ�S� �a��),,0�����֏}3?EY��.0?�'H8ZN�Dqj��q>/�2�q�E>`�������l���3o3lY^W�3NdY��>�E]����p�. ��5cI>A����{���
S�#�3 FBLB�P�����M�����\�6b�fE��Se�Ww�;֙+�K�J��v���f�I�؟�,&A�	X*�E���vu��0l:+�D4�0���D�b�:+������<
�����RB���*`JAւ�D9%o�KZ�������?p���J,{�7�B?��f~K����0]��=
�Ǭ���+G����db0�q�ar�9>��83�k�4Mmf��td��m+���-CU�je�@mU�z��*����|I\p���<���K���3��[�-£�[#F,��5GM�Zj��:]���O`4���m�aؚ-�1���ƍ	˹�Xp�I���u�I�	� �9�KTɭ^�����(�o����~؃����4�~�7Q��yʳ܏�LyW�~3G�J����"ZI��^�V�Ҟ���wӮ�p�ۜb��*�u��P@�I��C��q6w�I�
���U@�7s��Y,pk;ܴ�o-���L��i*`�h�uձݖ[H'�Tc�rN����������t᤽_JyK��Rߌ����#�J�c��u<�S�X��b�����4*��!@�-�^�K���x��Qݍ�=��u�^�B�[�la+O%���,� ���T�g��)�ab�u�:j��+�:W���?#�H����]�&ND�>�� �{�+�A���d������}3��&~�*E�b{�*�O��5n����ns&>q�|W�y�_%$U^�p~H�,J
�i�cTh!�S���|t8T	�)=�D�u�^��"�F�� qv&	���a���H�3��+fȫ7������FQ�0m�x�Y���ms<�R�?%J|u�q;�1�7`lI�d���6+&ds˺]����Ei#?1��a|�`f�����E���WE���w�g��K%���C��w��I�M�Z|�M:;>q��r���[�8�P��t,Oi��/���a�
��;�3B(hx����;z���MZ7s�(�uI���x�rw��wU���g�!����
bx�BXa��y��0q=w�q�?-[daώV��Q&#��@�y�Z:%��XB�qA��C�^��5��[V�p�ߑ�9�P)�e�(�5��lEG,�R)�Y����{ 3U�v�W��~Z��V��Q�l���l/�T��p5E�'��X���E�9�VN�>�^mvf�U����v3Jg�H]���W)t�۶� ������?ivÇ���w׾�`>�*d=;v��;�q�����AN��X=�:ڲp軬e��������-WAߙE����� �*�
D�|����Y��<f{�T�j�-/f �R��M����N(�r�Ŷ[ְ}�z�������Hq6�y'�K���&����Ł�e�硓�!?,��F�zڡ��$��rh�$o���6.r?����U}#RN8��IP�N�h2(x���U�-F,�� ��#�j���?������bR�D����ˢ�y]����lԉ�^ҽ7��yLü�@r�2�x�d��X�L��{��;�Zh�B���;Դ���� W�{�ɏs"�T����`�
I�Q�t}�t�X�a��hH`���7�� H�>�'g+������'�
�O�)�=���~���I�-���>:oE2X|���bOх�'���*lW�<J�R����k��*d�jJ�G�*3�����U_VV��c�8x���J��}�����j����SQÍ���*jj���t��
�g��:��?л��I�G��ҶF\I+�G�C���Kv��.k�n}��߈�|��3�eѳ&0�5�W�����R?M�i��H��y�)0���
��1�>���@��{�D�S�5��Y#�4�+��cmkVͣѵ�)�cI�N�b�B ����Ɔ�/��ў��c�YVڲpN�uk&�8s��[A����sy��Af�e�u����>�yZ��ԟ�iq�L2q�e~����	��Y�p�4�� �pP3�z��MΟ9L6�j~�˒8	���d%�o�R���'gη�a�b"���B��� ��j����uT����m�ӊ��4���:5u��O|Y��Jo��2`��'�:��8`��&x[ᙪW5�=w�=o��=��>`"<�T2�����{�k�ë��&����gGT�HO�ڕ�R��;���r����b�f�+��0�'~����s��%���,�7*���1��V�O-?�am�����3��d����|��|����U����;��iL�dt�}����(�&K���*"?�c��v�Ų��y)ٸ>;`�"����,� ˻ȍ��a
������ϫ��v����Dȩ/Q�ul׳���i�x�r�M���|�&b�cJ����b��.�7J�?3�A~Hb}��y/j�C]�}U�;j�C�e��=6Pr����L�r�hZ+�o  �����;d~��HAй<,��T Z?�6z샂��|����I��Bj�`��#�û�X��'(nR7,$X[���q\c��,�E]� ��y��h�cc�ow�$�~k&\�o��e����~bL�|�����	����4*�"U�Ы�������u��x��ҥ�{?��o���6K"3;:qLš�ڿ)�bdF�>�(�&z�w8NG�h��!�&`.�b�=����B_4��3��~T�?sq��a�칥�Ce��O�V�e[1�D�m{l^@��������Ns�<��}|�'3��ҷ�c� *��Z�DsPTt� ���n�i8S�s�Nu���5��fu0���ުm0���<k1N������L~�S�������cF,�	����$��x�t�Nܳ2�u�?n�F�]V]�x=��Ց�PR9�S���۠򌃌_���� ����Kf�Mx �C�b�ep�qY'����c�#0T���1��q�Gn�!����'<lH�yA�M�qӸ����rRD��g�4��������y�Z� ��%�ދ�	�&p��+���>�;�N���kk�=�Vn3�e�4��F@�H��Vv�Ԋ8F����SXp�H�BTKM���H��f�z`�x���n�aos͠�Y��h�iA�C�n~P�,r�U�'��P:f�z�jQ)�w�eyة�����4���A�dT���?�>+�L@ry�:��)�8o�~��u���-G��C=�ی]S���g8Ks?�UO���n�]�K��>U��I�,B�7���ar��3���[���\F    
[������z �XL��sE5���{߼S�i��5�{���YT��9�.��`��h�Mւy����.%O�P�B!��"�.�rݰ��l��U%ˁ�j��%���������O�*���%�/6���D
���ß�r�����o��םҷ�D��%�|�3u��|]�2N�
#�qA�KU��8j��$���laBҙ,�M^F��� (E��E�.T�O�ؠ$Ԧ<J��%�!�i  �����kt8�E�p������9 䙤�M^]�7��f�~.�Y�*��
#U]��@�1��o]mG�k? ���g29���ȟ�,�����8E�t�܀e$�m-�Ƙ/S��n�ux5�����/iխ��&���n�H�	��d�+�"����A(,F�;1r�Uu �j80��f,;$G���{�G�P����@3b���u�{�<�Ш�����-�:����QE{���@@��Y���
FNЈ�F�F$SS�Sĉ|�'�sP�8�Q5;j�p�$�,�r4�e��lUV��!@��������Z�9D;k<}:��̶乯we�`���B��s-y۱�
��E��^�ܬEv�-�v战���"$�<ǉf��P�_b�-�k7��<w-T�yQ�?��隣���S����&o�h������p��B����/�)��*�#�Ll�w|g�	망�ǲ�7�D�T�C���<9�6��a&ډa�`#F�O��&����s�yò��y0��Q�o�-�@�СBf"a�%�?��R}�ں��.Ŧ����T&q��@_t���s8����K�O��m�;1&�|'��:����୽{���;��W�$���n�1���?I���a��%���ngչ�
�D�����.6��<�Qi+HЪe�qX�W+y��7rr������OhG~5ש.��+	�y��^�ҥ)�k�^u���?"�LԤ�c�5�Q�����E%�����3��y㨊nL<�K���������EvMO�L��ax��$~����?#C��#'u��
�9Ѿ^��������V�����P|��'��">�s��$M�r�y
���.Z���'����ͽ�oD�rL?'�*��ūѕ�K���xYE�*��o�&�J벞�O��0N�^�,>�ޱv,��O$�ދ˯�5�0ڕܩ�]����.��t��+��,��xϟ��(�h��R�Cl�R;(j��J>$O4���P�y��k�����l�Qs�/�'��bSI����iU����ߪ�9�ߨR�A�:�c�;I=,��>�V\gu6�(yxhT��n�!.`_�"��#C��.�ʧ���=�pa�]��7Չ��(��!��w Z�ѹ5ԓ`�������gw�)Ԣ�8��k�d1+�=���6`�1���-���^ZP�����"���Z�Yi�-K�P����nd��煥	�<�>j��<��A�� (,�d�N��(z�@UUͯ]�H�{z�%��u���E��\}�?��4�_�QT�9��x�d���2�LR��hW������9����\�"U�~2�F%a�G��G��WJ�Y�?�up�(yP�ieT��,��_�)T��Wa4�`%�d�y[i�g�]{���?#:�?�n@��
FߜL�F)�/�ޜ`T�!~UJ�^M[��翃i�;E�H�? �lղ*?��vbʪ�pS���ףM�1��E��mE�ġm.�R���F�d��M�-�3rS@�'��#�K�e� ��2H���YQ��F����_��6Z��ߦu�^.z �J�^��4��{�ȊPL.S�+c���O;YUA/�c��㺨� �G��zv��� �3qF�XE���O��9XBv� ��5����J5<�.F�� Ꞻ�c�OmJ�^�e��PaF$�7�{��v��.��g����n7~;�y�K�[�Y9Y4U5T*�G&�s�:�:�g����߃Vң�-�ɍ���kdP������@��U[v/<`��'����2��� kS]h[�c��q�#�-��vr$�)��2+�]4|�yZ�Ӄ��f��ؔ���5��ȋK^��o|���+��l3��&�=Ϧ,S�y��Q���(��{��y��C��8�31���{	�:�����L����ќ=�8�s�Mx���>�z>�_}R\���&�F\���d��R��k^e�k'��tR.��Ɨk�	E�U{t�<��]����p٠z�3=)\q�7vv�b.���G�7g��;�w$���=EJ�Q,��sH^<{|L����X)/e��0M������q�i)�g�'��a��+�)R���H�U��y2�!A+�XD��h`xdy~����^k����c5Ayh7��4�eZ�俺��C0�{�I�b��\\`���!͚0Mg�4��(*�<6��Y����tc�Ɣ��:xF�=~B6c3�EYĈ��x��������Ft��N�~]�f�Ŏ2�&2�<MOC�f�����*â�0������h"�[��WU�7�ܒ�	[�X0@����T9f�e-�=�թ:^E�̱�a�dy���G�j�[P���?;q�き-�n�H�\O�R�M}Q�xa�MZ����AP�M����8�&�-�bIY{�?*��i��V��+��ѝ���2O+u���C�'u��M+�ب �mR<�� 2㱀eu>�Z��ea��P�gV6U��i�_��
L���O/�he[I!d�}��j��Pl��t+��ݾ���Ti�_%f��g���]��$�g�s']���L�0xs�;��2�g>Ny\D��IH7^�rCY�2�j��5�UL�-���r������5e��(�VFe<?aE牔�?!��]ZB�M� TθJY��dɆJ��h՗���LA������� Ӆ8D��H)|u�	�KYs u5i�P�U��1�(��kXY���a��E.ź8MC�ޫN��"=[m���h�;lw&�x�;��]] A���Aο�Q9M�?Ж`Fo5H��C1��E��)����*�w��b�nQ�4��;���k&A�[r&��ϊ���L>�a4t}��oBT���Kq�6X���B��w�|��$�U �E�3���b�/S�/�.�QULR���7��K��|�і��D��7�f}_�j�E&�����%���&��T2|���
,Ƨ�;q�}��q��j��kR��������^Z�������OJ��v�{55����4��m� �z�CS�iM_�8��89�N	_g�����v��@!
M���qZѰ�4Sᰑ}�i]��^��3Mi���7��0(@��P��g,��"R=r�|�]]3G^�&���󟕸�i�`�:��y�\�	t��aJ�LBu2�R	2#�>Le؄u^��fp�H0aA�{�x���s�8e�����EIQ��A8}�>Y��0(e2"�'�DJQ�Ja�������뾮v�̷�5!r�X�:����֙7��Q�@"�����9��Ǿ����y8����[H��.T�x�<Vч͞��w��
U������h�d�ȤGe�)��;/V��tЗ���.�`l��g�N����<�}'��7v_���a
A����rf����?���!f�lHĿ�i��(�Ƒ�����|6���D����{��z*xDn׳a�Ί�����8�3$|�{�\6n3�	��[��D�}�2+�K�}��̏YD�-�Y͘�U��"���I
�S��8(���LE��8k{�!{Z�
�x�$>)`A��Y:;`��J!��Y6NӊE.Du0Tˮ���"�~��}�u�'���x�k{P�i!+�"˯�*1v���V����޵ҍ�<q$�𾵵k��ͮ����ݤ�5"1'Z�`i�1�t�ۏf&E6��E�T��p��)�x`W���׹t2k��^��U�&9�	�1&�e�J��b���0y8;naT�l\�p�������F�G� �w�A�MDH�.\rA+���B�6�g��Ha�������5���;�X�~����Z�.�:H���_7�Gu!��{�s�7������f1�Dd���ō��~���:F    !�))�|���e�]-�w'�p�.G)���0�JN�8��N�MwM[#�h��j��+	p+��'���'�<;ގR��]`�X�SgŤS,��҄��b���$�lͲ�jf�S��ˣT��p�zLSt��v�>1�����&�U�Y�.�OC�9�'�7-� �������8�M����Iq̍	��q���E�x��;UlFh�ę�ؽ��]����x�C/	9N{����TDq9�rU�Q��Ӕ"��$$ɀX�{��X���������n�hݺ���^�>-tAS��	���U+(tY��k{isp����w�(�>C�2��M�t2G��آ�,�kD��M6%S��4
d������d	���n��0<�m��1�����4m�x%�E¬�1��	�y���	t�ZrS[�d�*� �?1�WI�K���}z�g���A�$t�4����(v�&;��c��v��/;KW��eR�a5?,I��8���֢�#R\�U؞� ^)i���/�D>0�j�U����t�	������@6c]�7��<C��zD��O�t��9� �q��	*���SU��j�	���QH�YV+-�9l�̔gG����7"��ɹө�d�NY���݂�s�ꔲ�[9:��0ll{�fs+7PË�c�ʂ�e�s3�^�,
�nfrx�L���su�����' 5���:��m�����I� �;��eb�*�[�����/��F
^�q8�R]3^�;���/��3�_����#�_�o�T~p�O-('��ND�馴t��Q��F_�h������Q�*<��	����������?�N�e���}f�yq�� E*��뜱G���
��7G�mv+��z�VF�)gl��7"H9q�Fʺ_��o���� ��e�:�Wf��ZH-[ 9�Vl�X��3�,hԒ}8;x���W1U�sW�8�yP��.��������Eu���~���.���аM�O�d���gP�]��γ�Ӗ����WM��Ĉ��(��+e��c���I�`���:����C�K<�L���D�e)����(��:i�z�Ɍ�<R��d��ޣ�e�?��a��iM��$Tj�FVNc^G[j��&�z�m�y����U��E{R,c���LE�����VK-'�W<;1�M�2�4�q�ߙ/�)�uҟ�����W;v6��b~�'�����v��Q�d��k��B�a��&�Bc��Sr�J����4F6���N��Y{���\}a�?��-����2k�E��Q�։��i���X_L��Rw1��>�
o���#��x��{�� �
 �H���8i��G�T݇����AΗK�'���"�'�%�v,l6A�a���OI��O��a����$wUжD,�ά�9�ڕ�ţ˸��Q8���<�g@�,�d�#���Lw����9�)�;�.��r�5M��QBOH����m���&B���K�e+����=w�L���j��V�=��snIpͨ]�"l��7�gI��E���	�����Ρ�Y��.����1�B��܂k/���+�V��<�&��{�T����G� ��7�A�q&��ڃ��Kw�:SFÐ�-I���<����-.�r?������q���D����'/q�����s5t%6X��iy��{Q6Є*�SAoW'*X��R*K����Ѳ�%x��ֻ�Nw�a��1b�p�9���~�T��{韬��M�y֛Y9*�ļ�;�J�1�z~G)��]��ŽY�F��
q����4(f�m�V���ϩ>/f�
	�p?�M��ܟY7��&����+�B�1�3U�#��`���ae�� <��f���n��x�o��N��;U� zh�p�Tx�a�y����$L��Y<���-ώ���N-A��2��M��gNOC�>�s�Y9�� ��+����^�Kޒ�|��x�H�A}����-����Y�\�5U~A�'A"�\�R��"t� (����z<�"y���_p�O7AE�+�SA]�J�g��^-ՅYh��_��y�\>���T%�9�U��\r[hf��-�ѓ�j<0f���FI��}�������T"\���;g�^Q��֠xN��Nr���?�A=��e�%���&I���S���#�f�����Vy(Ww���Ԗ�.�V��)�V���>oFM����a{�tzڌ�i�ʲ2��,̲�P�U�*�-+���kB5G+U��#��
�"���wS�$��z�ʾ��J�����bV���f�,��iPa�����WP���_�<9y�X���(�~L���(���/��8��� �y�Q��b�&e���Q^��T%+ X=D�=��x�L�'M�̿~IP�fK����$OgYm��+oi���[j:���ƍ*q>D��˫0��?~IRQ/�/Qv�l�A9UQb�-X�@YJ����� 욱��5,¬���ؤ~I%�/ăm/K��������z�}hGu�z�Je	!e�Ԕ���!H�W�j��(�(� �q
��X����\S&�7��ia��$����*�%�kTD���5���2W�P��W�j=�/�aDi�����*��`"�Z)}�����M�"����O�Y������+l��%�J�����g]C`a�0[3l����+/#=��1M�%�ˇ��x�њj���.�d�
x[q���r]�Z:�la7��C�e�f��8mt"��[X�{���j^�?�n>���Yu�4��^ܽ�i�kT7ᱹ���,6+�~�3��@Na�j��C�a��!���,��2��i1�����Q��L'��QL��kX�8Ɖ�h����`�X�D��A?��ޏLBj�ͷ3|�M��2¹F�t8�8�}'L�B/��*��ɐ��������x��C
wnjN���E�0�����W������T�y�n/��FQ�'\��5xAQ��ƻ���O&�wއ��VS�5��ԝ�6t5�K�M�e��g>�UT����S?/��[�8fp�ʡ>Tb��fj��������0���G�f��6�Lg�ۈ"� P<�?8��Q�Wd���If3���Ǒz�"һV�2t�q2~i��n�Q�۝�0������_-�uИf�Q���I8Ӳg�h����iw�Iw"������^_�"<i��k��kn�׹�.ɂ4V`�k�}�c�3�9C�ư#큁PN�\���u�1���b�'/���d�ӭZ�C8������ U�
U�o�^8"N�A82@n���V\&�������JCy{ЮI1Fb��x��i�ȍ�/Tl�bܪ
��,����牢ͭ�YL�Ώh�L�C�u�6�\J?�@��33�d2��X`%�/{��w*m��.��TE��
fbg�3��^`V<q`���yŜ4�j7ߩ���J�l��;��t��+U�l�\xDq�
m:,Ux�aN;���C=�=�dB���&�6o¨��4�"`��֥ݱ�h�:�5�նZ
*��t���M���x$E�E��w���ԤwΆNb��^t�TzÍ���^#��7~O�&7~R�l胚��� �>2��pE~����X~����0G�L�Ͱ�cP(ܱ���-�ٴ�4Ew��������O��G*-�,R�wt��������sa���BSק�{�h�4 H�=j�n�6��떶P�K��T0��>���/�$�W	lS����]��nċ�"L+��XX1��������U��5������8g��"8yZ���	�b�P�L���r�,je�^rt�p{Վ\v]��'��nu�H�#�y_%b6�t6;by���-}���
@���߮F�i���3�`��&I�<�����}����@���K����PFtG���S��m����E�DO�_'�U�^R�"�_���K�Tv���;6��MUj��ɸ�uh���֡=/.�W`����6@>/��
��aۺ3���e�u2�A/�(�b��DK0�NK�w�`_�����*���J����zFj���;�0�	"�'��� ���&̱�T��ٮ3+�[�N    ��&sŶ�4O��	������	#�eќI{����jg<���eP.�ū��f0BD���6䷘��G����+�B� �p�~f���=�R���|��MJ���akk�t,���Y�x.��~��G=�%QK�P� ��OM�G19+ã�k�^R����>u4��l8�u#n
#�Nx�±���|b_���M扌�bId�걯�'<�n�1�?'�M֏�L�,���=8cGFF�r2�|u�s��FKY�%�R�T��z/_: ��e�(u�Ù#f<�qQ�aXR.Y���7Nhil����J�/�|�gg~ѹs�k��]�<���CW䉒���;�9M�næ��e�7V��)`l.�ڈS������z]Q^��\� �Pc*�[;Y�X��&2.��Ğ���v�Wv�$����$�nz��X�ٳ�6{�� 2���6|7��(�B~X�8�w�.>�.Ȏ��ZTj�d����Dy@�)Q�;J�
�a2������s׶6��ٍUt��y�z!�ג�v�����e���qZιZ��nx-�ɵ�[s��z�?c���ţ�ɘ�xD3�h�:j��A�j$ӑ#�u�x�����7U߁���5��`�3&8�T��L���.�A>o�L����y/����Ž��L���vGa/J;��s�㍥�x��[���ʦx,�If*�ؕLB?���U����*2e�-^��}�}Q{]}Qڳ��L4���'��=1DQFW	Q�Q��QF�ةSe˲��֙R�����\����@�I��쉁ȳ&� i�:Vח{n2���qi{
�ċX��t5�d~0���3�U1?��A\����j�ˆLDF`�Թ�N�o��ĩ_gD$��L	(�F7:���][O�	�ӝ����஍[�I,5����~�O�I���rPN��~��责�vC%&�qҁqA�`�9���<Tqm���J��7f~�R?��C�xI�:9Nٟ��J��o������~2}��b���tUU[M��R�-%9�s�3�ͧ��=�U��쀦~�ǁL�a%1��{����б
ם��n�jk�hD`ʶf��&���FU^�?�i�R���O���B2�C�*H��IT:�,��Q�ã�I#C�t�21��s��C���5�{����6��ˎ�O��YH�aٙ�f���+N��XBf�w�c|�w�P�}�������f�����M^o���t~(�"M�m���O� �̂h����&�Y�y
�;h��Ί�4��}�UD9DJeYw*���5Gxe&豬\z Xv�4V-��h��#�=dM���%^��8�oT�2��7r��b����E�kzza(���aYXˊe��|X�+V�R!@�u���uq��`�־�_���*H�2V�yH�|�z6����QD��z��M�-����X��~G]�HU˓��:�,pS�R�����ٗ�-h�8\��;���b B��`왿/@i�Bd�
���� s��u���T�IL���D�+L��I\A>P�f$}�]-����$��J��U�_t�&��_7�T.�Iq��$���E�t0q�a�8�^�����Jn�����]�_��e/��一Xk�T(�J�}Ҫ�y'L��-��a���T^4|  ��ߚ
��$��fz�Z����#��}��G�y�9���d����r��u�*;?��s����
�.���[ݬP;�!^Nb����r1�3P����I7���� T}[Z+ B#/��׋��ʹ_Z�\���B��i�C�-!nr4S$u̯Ջ\fXA�x��1��'QDw����(C���tͲ�z!�����&p=*�TIA/!
2y�9�:�}Զ�b�%��3b�MLX��a�4�D=,(
����[�k���,��Ⱥ�O�οs��$� ힻ3b�5_��/:_~�b��J��nx!?��N����֪l���8c��d>*�0,�� M1hA��5cI7�ڗ�.�#���� �4K$�%hg�f8Q����Aģ�ʅ{=�0}�Vz/�o�����D�m-��x>0�֗u��Ll��[� ���?e<��梳���`��)�Yū�Uw�bh4�p��'E*�..�\�HD[��}��X@�`*!|���V�81z�C3Q�e����,B�o�x�L��`@3Ĩ�G��.���I��@7��yY�?'w�_$�m�a�TH8���l:�&+�Mډ�K6d}��{��B�d&����$����Q,l�����svυ�*2����޲��<��WQ��Ê��x�.�����M�U��KV�(�����[Q(�=�N':�������5+4PɻE�ˎ<b���a�YP��[�AZ�=-x8˺�n�u��s�er��c�&AQ�*�;�z����I��g�=�.������\��̸��֗K�3��[�s�0�|ov$���,�3[R05�
�B���)�X�b3�(���>S�7�L��:���ٯ��Xv���9oL�,'���Q/Č���xa�Ͳ�=�mwPV�f1Po�,Ub����������ΰ�r3ۋT(K��/�;p�O� �O�����kUz9j�0
Y����&}|Uv��W31X�����*�X'`��/�"�l��Tt�>���!R%��Neim��h��\��ģ~�q{MBԹE:��nR��*莌HD���`_�<�I��5Nf�l�/y�=M�D�:u,�&n"�Eϰ�@5��-b|<��}`�z�'�b�� ��U���|�
E+Nø<l/%�u���i�A��4#��zRAb����e��G��I`>������2t�P'��YW�u��
zY7QB81�W�?��N\�>��k�����X�c�1!�8V�����tĄkˡ����_d��NL�3M'��$��K̸+|]gbWvǟ6�>���y"��B��.���+�R!ߘ��.u͓�aQ]�$Zc.��y���>j�c����ʱ�f��-�J��^�֮m_7��[���ٽ�b����ّ¨�x�x��ʦ�v��g�@޷�F<\=.2m[n��4��t�-�k��v�:g(�[L�qQ�aLr���3+衮���\S<2v�����"_��0­�o��o2d�ifwp�"�s���S6Pt�iY���Wvq[Q��ޘa��C��e6�2��3��$�����.��8Q�x�ծ�ڗ5�]��m�T���ԍy��Ǎ^JK�w �?3���`�z�`+�$S�՗ֵ^B�=S`��
z�<��~o1&�o��miz1���,o'�E�3Q<�����rC0���Tr���GU��}l�E��_uDI����e+���{����=�� �w���s�b`#�u*C���hܲ�"f��0$��y4A�qo��kG���C(�j�&@\@���Н��}�Է��M���l�T��{��ȪL�+TQA�^�_��1U�q>���C���c�@j�\P�C��'v#Q����S�}3����w���QH�r��|�:�}���L����������R��ʴk�9��h{Ӻ̣��a�X�������(�-�q^��kmq0`�g�7Ξ�6���y��;�>fx��H�M3�-��(+���g���҇�N�=����Q̤@$n�ȓ�I�%����ܟBJ �Ɔ��k����^���m^VI2?��i���c��d9���t�����X�1�Y������}Ǜ>K����;�Z��]Ϛ���3I?������x��(���5m�t���@6'��T�����
�W)�)�̝h�wg
Ӊ(9}��d�
M6X�#6/�93su��W��g� �v��������}O�=�$�V0��-����Dc~���T�ݎ*�oGi�U�F�����riĮ�� �m��\�}����HV�:��!,�5�$�#����jT���q�gЪ���y�'��I���-~�N��J|c�@7��('"�q�1h֕�H�� �F��`jF���7�׾���'����/�h=wh˲�`B�A�N�b�q]�ۜ��SaP�68	�H��@5�+�#�xG��9��O+� ���x�a��Sư���    �����]�j5�w���ǎ/�������쯉�}ם#�n�*Ҫ.�_�4M%x��"	�X��v��-�YR���1H����b�n������L=z�`�d28.��Eۉ��N�Ip���Ӊk
��Uٿ���(H/��eq��3`�J�=z��n0�i2A��Ҍ�dܣ�a�n2s�2i�"T�b�r����Qy,rפl �V�2u3U���A���r)�7K����׍�8�2�l�A�睸��o��^(.�%���L�ұ�k|�6��>s9�VVkK^�����'�Dٟ�yot���\@q��R���BoY���?�����@�FESQN%.�qDH o,t:�X�d0��ޕ/"�@�ى������u�G�� Og�<N����S�)��-��F(�A��˼�����</�e�yi�m���^��zֈ���.�UV�J�����G��2D����{���ţE!���٭�G�:������-]nEAu5x�z�c~��ꪈL3��*�4R`n�xCٵ[���0q�`W*FC���t?蠶�x_�
G�H���(W9�u���s�ʳ|�0���8�rId�c�
���;N��k������؋��Na�K(71���Z�:��8��"P�ϰX|\����0�ፊGI�0J��B�M���k�*4����-�p��CT��s'F��zӌ�
j<9NP�Qc��{~g�=�nI�
�!�4��*.��f�M�ǎTn��|���A�?��VeE�΀�]��
0�2��:�4f:� @V������rE�XN7�R�5./��I��Q\sD壐ecM��-�5�5�����Y�˺��s�3�(��9��F�
;s)ǜj �<e�J�2����O|?-zQU�W�^^�Yf�^���wi��0�'nx�S*�3�:xx���	�G����4���0��$~���������O�<5�F�I�(�W�#\���	�Xv8a`Z��⪂��~̆���!���<���_����!{���SÚ�#G�a͚8��ê�T�bT=S~n����e��j'Cu�p����Ϯt�?��Ƙ���;�66��[�i,26�S�U4�D�q �-BPcp�{^9*z�\@�`�\��}���iE��X��Ӝ	��%C8�y���`��sx��敋�&ʯ۔Y:;EH�=T9�%c�]e�2	-�>c�XOg0+�3wá�[�lXȢo`�����/{��,�j��PP0e����(KUD��f���E�I�E�����&U`�����!n�)����'1���B�.��B-���(ts���'���SD��i��<V�1E7�h6Ԋ�Tx��%A�bSQ��̦l�x�p�u��cuLpD�A�J@�R|�[V�37t1)�i���lF�+h}}�'rM�Ӕ�>n�a:J0������`nU���3��@�	�M�|k�K��l۝t����ѼT�7��K�w�f���֠�;��uˑi��6��)��Qg�Ѯf帅�V+y����J�w��F�hY(��3�Tܺ��ꀪsbc!+=d�Ꝫ-y�u;(VF�$z������B�z���tSfz�nB��vc�����)�곟�<�M��?�IV$� �-J��>�l:-�]܄M������J��hC{��j�,(�?|���fU|�G87�̿끟D���z�ݜ`�X� ���ay�>L�8y_&ɮZsw��W9�eo�aXE��=��h=�9,���D2	���h�f��S`; �T�x���h�L>.�)b�/���A��`p�"�o��.�?���?w2����KȪ�nx���K�P%S����Q%׫�-f5��	�����I�>�|��&�Ǭ�h�Qꬵ>(1H&u�f]�U�����b�~O�$C<g�||a�"5��Zei<;j���S#e>z<f%����EæR��m勤~�ľ���A�U�_�(�S�P$�	Y���d,�GO�.���0$GG�|�&:�,����D��|�	l���`����G7��b�ы!�)F{��)E��u�����#���gT�J����i�H�9_3�W{CX�{~֋A�L��@G���HN:v����<;y�Q����gh�k�uW;`�KzAl�̗�.��^���yf��O�l�������:��Cd�5�����Yif�&	�4r��߹���"� ��R<��T;��߭�C:������1'���8k�P��XWBr'.w�y�0g0�I�F����5c�O�p5��X��7a/L�m��px�lb�(O�7�m�V,+���s�`̂��m|�X�����yl�E�s����!��,N�,@�0R5�-
6�q������=KG��6.���/��_�|־��j��L�P��_�0�]a3A�u���l��c���-۝�8e;�*�Y?DP_�6_���e�3]Rdi(����������e9�өe�k��j�����|�1ވ��a!5r2�QڨQ4�3aM>�Z_s�|�6���(��)�8H�\�֯\`��bdQ*���ѥ=GV�b�O�"Ͽ�i��l->���jt�E�bkzt��!)#�r�@�Ez3+�a�����0��<LA��W��67I3���B?�r��.���Wi���1i�39�g�Ӕ�N�&k7[��!g�ā��d�V@$�<"��^�{M�j,���y�ُRE5�}��"�#�p�K�KW��b �,��K�u�r�cg�Aiw���j�����!pƁtM!V�b�\w'��9��{����w/���dcc���E�L$��0_|�C�(F3	GZޕ`{wv����B�΁E��}�م_�.�~��v~Z/�(L"��t��]�p��%w@�j�{��f�^\L��x��*M��X/#6�`%��tx���|����9�B�QcN���qj^�㬏5�V�N#�����W�mDi5�.-�4�$��b��æ�{A暍�0G��V�k��mQ�G���%Ҽ��)�;佌����"K�� F�����uP�0� 
i�蕌w��Jo�dn��b%3��ku�g��n���TP�������0�{v̂ �(^� ��qr��b�w��T`�^=5v~���O*lR(v�͗ZuX�YzA쒢+�(Y�8��Ezm�S��1���b��*�����h2Yad,n�n��@��o��JW;�Q�����~T�\�F�Q��Q���H����Q`�1�GK�%7?߮��(L<?Fq�k����@����&��t��;*����3�}�D�_��(WXM���0�f�%�mz��EԄ�?����i�/^(���Z��0.��c�v%)8yN���V,�(=�+ �	B�J�aJ��%�a݉\1���;cc��n���ݎUѱ����YEkk���=A��n�5-
�?baO}rYZS�h���"'C=��T8b������ ��r�@�M�~*zUq���� �!V�� 4�@; �����ްn%��엽��û�&��|�k���URn���4M�Ѷ�2d�F�PIn�Ɇ��䗅�J3����"��Â�(4J��-��z>e�..�'�ǈ<=-�E�H��r�4�&h��4�i�w�X�ۦ*�Q����|arK�R߳m�\�j��+���צ�5��<�$��U"%����U����c�	��5��k���
�}#ߎ8�ݳ?Q��j"���B'��;�,O�X�{�u��P���p&��9ce�6*pyƭ�U�����ƺyx&���y�!F�&G��O�aDр	����@f��m���y/(��YujELԮ��&�ށ~n4-���q:�e^�|��M�$�=M�S�}J!d�6��QCc(p�� ��8� �����7�b�;.��tO~�H�j!M�'�A������#�Td�2!WcR�T�.�N�n��8(~�_�I7�4t\+�lpQ��LƯe�Г�|������w���<	�5��f����+��1��20�ڪ7���v����R����T����X��[?�ؒAT�n��� L��u�?�i�Ȅ��%3��W�P	BlH�ڍ    �v�YĶ�N�q����p��DC���(�5Q>Z}"�)��wtQnlW'�)��t�,���w��y�^ݛ�Cձx'J���y�T�����IU6u8?>�%\���%?��		�OY�:޶�+�e�4
B����4��d����h����D�dZ#��̉ѽ@_)$��/|�IL��οUI��$Y��R�hSBw��i��dK:O'�:�4lF!~;,�;"p~z�e�2��:�PB��1q������g�L���q2q��K��\�;^��֐m�NJ \E~i����B�]�_I1+�a׬��k�v�m��9��S�� K
0pTb��I����Έ�J������)W��f���{�IlxNK�0�y�D�ڨ��'�����q��Ģ����h��d�i����S�Q����v�>�p���i��w��<)���
�5��H�:q���4=ՎG-"Ty�Ř89
`ux:
X�ˀaW{�����c�4�CQ��A��"�-[��<@��D�rgn�`#(k����!s�DI}g��'���翮Y�b,�$;W�R��V��� �j�̥OG:䤷l���1_��2�����~2��e��X��_�T9}!8ˠC�A�́Ι5�n8��@E���{������wV�����x�È����9��:M/Xrf�w��&��J�x��E��/,o�Jx�*WsV̢���r�`��_-�Q&̉$\�*R��K�:���s�hH�J:��
���;Yv!�mY��cflW,ǋ߄p´�]�4���������+�~�Iٴ��A�aٍ�{ewt�<�&�7Ө'�?\��,��C���Ɓ=E��O&Z}bw��Z�:�5��o���c�c��='�.(`���l�$^���04����I���a%���E^����Sa#�5Z��;�q���J�Ʌ�z:�����д�`#UT�}ws#.�6ߘOg����6�H��^`1L���:�
�+F�����Z��0^�ߢ9��~7�M��v�F�H�@H&I2n���'oD�|�Y)���ҥge���(��DHď���f�6����Gߥ���$]���N�T����86�@�d�7Scv�0����wN��9�&��w�)�٪�T��Q���D��Al��t�}��C��9NKԷ�ޮ
�(���D`fDH�|�5�}Vl]ƵI��@&E*X�$_��	��'����Ӭ/��2������b�v��T�)�b�ˆ�WK�e����rv�a��R�kפ�t=�,y/�[���\E���M�k�Zg���hyٮOV��x�G���_T��ȟ�ZI���$�K�/N�X�Xv3ɚ�!��U��:�d�FE�s���a����������q�E�-n^Ϣ��2K���-��=G�_�F�%A�"3ϫYޒ9����m����Q�5�<	���r��;�+��8�7;'Z�P@�5�����	�9�sU�Q��Wt8����������>��N�*���������<�]WD��n��Zr2\o��jf"�A!�u��녨��|�ka"�ui��$�����u��5ŠO��)0���Wl��i5?0I����N��pH�k*�Q�{��Q��hO��DzI��J�9{����U{�Z�����p)��͋�ֶ��z~���eO���������۟�5~���UE,:0i�xխ��W��bq�3���R����m6�(�*�^^�7�xҪ;C��޼�P��Q�O��2{O��G��A�b�������1st��
Q��&%WK�MS�!J�p��CIUP�{��JQ�#�EN����GE$~agv�ax��Y���P���6�]�w��͋�~�����;t��PfJnTb)ۚb~ՙ��/��_�` ɤ$X,UL5�tHG,݀�����=�y+c˥ҹ���πZf[,�ȭ����((�b1�� �P`�fD3*20���p���ٝ��H�j<�;ß��5ws�Yg�7���X�jD&� �������D����J+&a`&
�̭`=`e�t�'�8�}ݼ��KiJ�ϣ�2d*9��z��U@���B�
C�2-n�=��_t8�{,�,˂����y�O.W�.~،��`���T&k��ń��a�te�&�]-k!��u�7�d�>�/�h@ �<R�R����v�]�6�2��;/b����Z�@u�l4�u�����H����U��o3��ʋj�hәT�t���,��n����k��B�����wG�=���
>��l���.t�&_�,8_�2\w9�'��I�ͨ�L��$�
���m�3d�#F����X�y3MZgˣ�M�"�YQe��*��7���.J��d�BH��3����e4CH�ʈܐ+d���r+�$t�se���v�1�oh@c�a!���O��6��哊�(Į/o��HB
�2��ȻM�4f�:A��=������Q��"��Lb�,���8]z�P��,��K�ވ����"��
q�,>~ǆ�l������!P�Gv�	�Y��T�� �d�T �D 2!A=�t��� �B�Z�D���ǚe��AV�<l��p��%�FVs�hVOeꊼ�Y�8�Y���+W	r�<(���*1�/�("�}0L�"�'T!G.��(ρ���P�%�Ç���HW�����P�EY1�>M>R����@�'�W}�+�C�@�����ݑBZ7�A�%���0���m���]i;[/��l^��Tb3�j��� 7Q�}��&G����s �S�G5����@����
��ꍠ�r�^��*x� K''j�h�{,� �V7���9�d�S�N� qb��31��+�!���+!��۲[˪*DI�����W{"΁�s�yP�t8�� �/�����UA�i6C�M���A�޴�d(�E�ۄ��J8[�@�����B�(���
�_=��y��˫C��Jd,|���t�yI��Ƨ���K�SL"��d%��TBћ"�{�;��7�1/�+�,S}�� �=Է�q��q��Y�=�J\��I`��O�Tę�P���^�V��*ۗ�������.�	��~G� �>l��
�tI�{��<��aIMQ٘�F�¹�
�\o��Y�_�L���d�^0��q�+8��@�߀����J��}�r���n�j	��=\Yp�������G`� G�;`����a��WQ��w]4���笉=�?���ϫ�t"�
c�� e�k�	u7M�_C4���T%�k��R��^���K���G��˰�6�j�ƾ���Pz�3���h x�7�P0BI&s6�Ǣ]����h�����4�w�^�§K�B���[!��*�}yU����l��8�� Q�
^�@��-�;Ps��呚3��!�~�UL�6]�����WY��*]Ǧ*�~x��/�Ϻ�j��Rj#*F��	��ꁈ�6|G���+B����ʒהe�
��@���i1>K������#���R�cƻ��Hl�u2R�����m�	4�����_.�d=��h�&�s�4�������O�L�X�mZ��ۊ�H⊌��+�����n��ǤET��S�쫘��Exks�̃HNr�v,}�Ś�e�9ß?"�&��{�z��_f�N4�s`�Ua�������y�/?�>Ku2Y�䟪#y�7�ȁ���.:n�6�x���<�(E)g���%�Ed�M-R���~��S��o��k|^��;��?��S�*O>i����@�>A�Pv?��
U$)��ko�6JeB��k��o3����2�Ɇ����� ����-�Ed#��ځ���*TQH2��<�>��I�v��Y�/���كV�L��?H�a"&d��\���X��M}TX����g�]?.�K����H8�N�U&��ꛈ�ض{_4$�P�QB�6n�AV���p�Zf7��b��ʛՏ�k�nG�����"Nv�KtW&B�}@��F���I��ĥ�$�5Zz�+�E����_�,(_:���78VhOE-����o�w-�!���Y�~�;@u�=U��?�o��x�X��"�I�� �b���g�l    �g@��9�]����v��j�'���w�jB��Nt����+
�����kÛM�Hѽ��E��̶g���U�f�������D�K�4I�'�\�)����'63�	���ɯ���k
��$.�!n��Jﶙ_~m3�ԫ�7�K=^�h��9���(��Lh��_��ze�4�Kၦ�*�wR��'��>���4t�T�����e~ؤ廽�}�h��1yfE3/K���A�ja��ܥ�F=GS�$ØЫE%̥�A�p+D6��Ƀ���:�7�T$=�f�����&1� �,���_&�G����F��=�oŽ'�Sy�[������6|�"����=�����g��2مw����J�Q�}?E����:�|�����Q�\*aH�s`���,����Nb+n��8�U�:tO����]��\�^�O]Q8���:W=�Y�Y$j�-���A�e�[C�1q����Q\X�!��,��3��j����d�R����Q�G��#�1�eY�.�?��ýΘN�?��V4���KV�8;�j�')_?��X���Y�ՇW�7 ���9Q�ᳺ�]3s���o0, 0�`/D��]�u.�/)*�\ll^�����9Q
2f��� �����l��Pyr$(C*N礜>��GJ�V�z��><u���K[J���y�Η�'漣%��*����FF�(��Cp�nGu��u�]cBV����K)�Yc��/�_�k3�Fg��]��w8��ěvT�OŅ�"�)"ۣ�k�06�D�Z�� ����vz����B�����w�	ϭ)�Q^A����_�7����[��pe���b22��$#5=��*Nr��z�Mז�'��U�W��S�O*���uQ>
�O�i
GX�Փ��mv�<,>.��������E�"o�ב�97����N[�:���"hn���>o���e^u�I��7�c�0%'ѝ!c�"�M��F#c����I k���6��ne�uE�/?p.Mc-���p+�I|hHeāKǼQ�����
�4���ӟ��+�m���=��Et�ճ�{۷e�<��»���f���򘘈��(������57�X�+�w��L���b^��a�w;�E��/��|�;�҄���/�Z��2j�~f��&�,;oa��H"R��W��]�a�җ������R;�I�������=�E$���?3����ip��K�(�ǐ/;�DN;�en9ȑ�4»~Tr_�|�-yT�Sɭ��&�ص�b�1�Ϊtѥ�_$_��G_v�xA�YP����k����O=�ڂn��Ե���S� �O{��	������.�2���V���E_��� N���h�����h)1y�3V���v��Ka&����0���0�w��'j�Ju	ڑ��X�93� F&�v ���,[?/2�5ᛪ�Ǭ��\/����N���������Xc]��p0R�ϯ<cn��W}(U�%F�W(��TK�*���B����R��-f��쮸}��S�2�!�t������2��}��jf�e~@f��W��́%`���J<ʌ��M��R��D�W�˪�9���j�Ѿ�:��Ì �A�[�%�u
&�F3[&!#������c$LH�ۊ�����(҂#��֋��ϗ��gBp�ĄҨ>�Z?���f�/�`Q������tb�;�.c	��I,]^(����/���:-��&�t�D`N�� �E��Ӂ����Q�0H2`�JV�w��=��O�E�@�_��Vv�J�d�E���?��O�
	ta-(_t�;���K�|�,p��J�@d�$@/���s��)}"��	�}��{A8�45���	-:tak�� 섍S���� �[�ƙ�OJ���ND(��F,+�iV�F���W���9O+U@ʌM~Sב��T�s�P�,�����o�9��ֹ����v��tO}>|h?�~��n|�]n���V{XS$6����mYyY��q+S(:��Ar�C�.+�z@f��.w�����ԬVڵ��������p��[��
m�_���a����〨��>������ƖE�i������H1>L���+Rj#���[l���J��r�i�ɳ�^�"�\���y��n��gTU�kٞB4P��;�sꩄ �6�n��V]��Q-�"�i��F��}�B�N�+;픷�,���큕Ah���Em�t��Д��E0!�S�w�3nM)N�L�2ap��Lc�UI]ˉJv"|��]��	G�Gx��7@��u^�vy0�<�a@�%�B<�x�+�������]����NqNj�q�Oc�B<}���X&��8��M���V��dg%e��� �T�c�'���=t��B8@�e�]`���i�wn��fy��5I����S�������m�1���8*@�rPX��|�(�*M�zk�?��1��� r�����'�Oz���#��5W���z��%}�B{��M+0�Hc��,�ez ��H�Rv;�W/�V�Y֦��7o˖�rT�/�����S�y����Iv1�^x7���>_�ӏ��MN��.(BW5��U>B�\�M�M�wN	��r6��6J�
�
C�I!c���4o��9D����gW�N"R{�yi���С N&�yP-6�_�2�;�B'GD�Y�{ 2F)xچ>Y&�^׿�	��y��Ş\/.�6׷��6V�_�/�����8|%��������"�u[B�E<J�/Wd���u����I5R�,U��Uk7��p�����*��XN^F� `��4����¤{�)YЯ�h>P�Ϣ��y���c�{��I���~�v"�Й�,��YhSE�#�&y���D�C��nlnd̤�'ڑ��I�d�;)[;�&�u�R'�$�ZWH�g��-�>�c��#L�6f|�Hā�҉Z�D��̚���y����g���R�X(�!���� tG�p^�Lٜg�����d�Q�h�@| k�lq�ʪZ^��&-s���"�t/��#�Cf��h3��*���]BnR����8[) ؖ�/p�%O�m�r;c�^`�{U�*d+u�|��T�vC�*-Ҭ]<w̮lnM���%?��!��?�!�����wU�@���*Z��䆎�'R�g��Z~龑���|����B|������)r�W�J^˖�)<���F;m� ��N�]j���Ps��=<��yr����Z]��u��ަfyZT��d~Q�ɵJ�#G�CA-	"t ��r��1�z���s �FQ� 	p��2��C|tk��V�3iQ.�gY����,Q�a�}���P�_��뻎O�ԏ��НZ�@ +�w��.O($_�HE����LQ./V]�g�A)�J�U�-Ϩ�h�"��PzY�G��h9����V�>���T�NlW�"O^�n7��b�b�3@%<�Q�U��X��_�c6qC�X������2*��NuUH�z�l��hi�)�!��"wj7�;�zP��/>|۸ryd|���D�H�G���lOT��%!�<c�#���k_(UiU�y��0��r�,��1�٘GU�=j;m������O�ßc]8n��'�$U]P�G��m}���<��kG��������}���!y���"x9��p��h��/��0��v�reQ�a��LAE�R�C8��a�|b�9r���{�[�q�5��8���v?�n��Z���$����XD�O$5C�w���[��G'ۓ?z��|O���nQ%tT�#xO��P�Q5Jd�0��F�qlc���[ ��pz�����2g�Tf�>�?FI�U�E4��h��׃1��
���g�v����+��  d�ό��$�2W�����ҍ($�tU���p�&�Oa�ʭq+�_�lX�6��/��	?�g�'?��?��,�fѡP�vU�2��WG>^}�!و���t�7m��a��w뿛m��{P�ߊzl�Mn���4c�F/�mȇG�!]?Ѱ����儡!�X��Z���/Owƛ\��H��1��8���ƺyt��V�����x�u�ȝ�psOS��a�"|��d�@�G��rys�e� ��2yG0��;S��`�ͫK    �lj�qc/��W���7��[v�|�G�N��;y�-���]*R���Y�i���CwmA5D�8��{��\��Ⓜ����uy�{�8>6����z2� �:*xE{GlB֒�^Dȭ�""Ti���6��*����X������@����{W՟�: f�E�*��ASS�ES'��N@p4����m�-�+sq?�\���+��4�W����S�8�@u>��7�B(��O��h����h�8XE��`,\��B�,�(u(#U�JwPu�{��
���|D#��7ln���K׿�C�m�?E��Qs&��C�TӌEtbB;�Q�q^;���4���El�x�r��B+M�:��Ŋm) x(����<ê�^��K�ݐD�&���)Xv��巙|B5�ǯ�i�>uD��տ�Y�T�v��)KȓH��Ԁ�Q�!׌�j{��;:M>o�ix�9��F����J�ƺ9= �3!�GG`��	�U:˶Z��]Ή�)���;q��4��Rx�	R�W��I0T�*�?JO4��]m�ꛉͰ���@�\
��
E���g�B�ň���f��7��atD4����H����9
����2u�_�~?u��|�1a�G�dd1l>p��P-������jV���;������Ŷ�����(�����;A�l3����i��[kѽ��|1LPJp\���8�8����	�^ޖ�4����`�pR��~69#l��nx�9�v�IgݽƸ�H�0"�$�n�)��J�v���m6f�*yxuOa�Οv�:�R=��<I��%'C��,��_ﳨ[����k�JT�DZ�f
�-"R��y^��޴����m��%�<�&3*mU�#��~S�EF'i���{H�����T�hh+��h�s�P��	��>�����WЧThÓx��<q��o��p�Bo�Gy�%3�)r���b��a�Lȵ�P�c�������Jq�E�6���P��{J��q�I����`4�h�G-���A�pb諁��u�R,�8:P񒂒���ÿ�G�ե\bTˁH����+���L�|Qyr�U��B�eHe���������y��&BL��k.g��P�D��z^m�ŷ(�K�_�XL�Y[��i���ȭs�[�y���!���� b�1��.��n���7kg��l��ˮ���M>��k����|���Z�S��5~�"��b�(�i��넲�cT|�v��*+��_���J�"�j����Z@�*:�̓���A�;�unD��	�q�L����PE�zVTVTE�xb�XV��[&T�3�)�2� rDa���!
}��FɯL(�T'���&d+���S\5m<�4m#lyf���J�]V���e Y��8�.����ɔi��A�U�z�%mA��(;Mn��3V@�u�<V���ʦ���f��Ц�WbNQ*u�#���چ��	oC�y(�����2���v��ʭ1zC�@�M9W����^�cBD��.����DmۍŬ�F;���h
49�,�\ǎ�r�Q"���K��L����-�i���*m��8���d-����b
Fߛ��?���##N"_�/����l�����VGտj���̅O�]~�m(�T]�2�� <c��-�xt�n�t���U:\��.E�����/v�,���v���i�B`h+�U�Em��v}s�������*�C?����Bs3�z
i��z��CW��m��gE�I�\!�
���d������	�r�T q_=�$�}g���x�{ƪH���?��	�}�*�}'`9�v�oBUV�[ޯ.�XүV�5wix���Տ'�Ü(�W/�5��m_/�2q%m^i�q2�P3� �)e�?���@�������?)u�?��XC���P���'�\��ن�R}9��-��4�[�C����^��7��K���w{�Vn�@��عԚR�U��.����ʞOT������\u��(A~�/e�!f��de[c�~y3�
[��@�4�31dT��$�Ay�b�"֭�[����*e[_u��y����4�,�����'1�U�S�KҢ{�&D���E�n7Zl��ſ���+|�ǵe���vy1�s�;=p&�i��GPx<w�"~����H\�%�s_�b
8��ĭ�̪ 99�)V����3��KaN�X,
�6�u��
�����פ0#rx, ��:�8!���'�p!q�]�]����fdRL�E�E@3��q���Rc�E�#��:|�u�5�D��?M4��i�M~m���rP/.ğPxZW�k�ŀN��; �<Jr�A�r=W�ܾaNǡ�:�����/Ĺ� 욢n��/$��3g�<�i�^#R����F�H�~����W~��R�2��;�#�F�h"{���<uӁnꇐn�,����Ҟ�c�������x�=0<"T�8&A����p�T�����l3dvuG�]i��p4v�
���{�����X�M_:I�Gݘ���uQ,�fX:��ݡ�ķ'�	WNM]9���22�}}	UR�	gQ��=��e�
9ѕ�*Ř�B���u"�x�U�H����(���&~Q�¿�����m���ʊ�Or�2�w�H^�f8\D�����xQ�Q4[l�Q ��׻�������S|��Z��Ԯ^/k}�.V���e��RL��9j�c��Wu�9Zs�� ;c�tć�fĭX?Ƣ���-!nEf�����@�8b�jS��=��ʘ��Y����Qb?vq��iMᑣ��Iׯ��uE�/fH��V�+����f<�^���>�=�$�N��g�'���Xm�9$��IN��(��r.\&�}}E�*?�8�W��(����>���C��-Mm7��3��O_��P�J��Ө؄*r��H-��mxsw��0e�F&��N��@F�;E��Ĉ����:�=*���)�=f(<YJ?v���&$�Z|�ԭ��5ۢ���\���׎�J~;%k�T@��ļwd�GUn�̝��I�����n��CzSwY�<p��֒;K�Ϭk.���������6�H%=�vy���iw�pY�S�<��6�j�)
�'*�H:6q"_�<����ry4���\�ɲ� ��A跳瓝�6�(D^B<�L;��S2��y�@��G�v���>5��h
�$X&��������}
GN�Q���[�2�����O��$�,���G��� ���_��Y*uL����Sx7����6�-i	�eCGx�$�U���uC����rw��D-C�Z�/��k���3�W9<+�� M��e��m�x�s�m9\�'T�O]��;ƛ���1�9�;��^n�d.��E��*/�&+���o�a׶�����Ce��A�k�7��l��S�!iNP���W�?h$3�9~xh��^�zRG��L�ط;�����%�er3��5���3@����Kw����e(��E�CȢt��R���2T{�m ���WS��b{U��9�p�q	=�~߁�Amb���NOθ�`�`�1��'>���f����X~�kKQR1�1��f4L"�R{�IM�x�@��@�sGL)7�
	'��� ��1�*Q#�D����~�����h�W@��Յ�dt߃��8{-�dY��&��B���ўZ�r�=�ME��#�n"��d��l���e(�����N;�o�G��y�J�:���~Xe�ݒ]ޤY���(���r�L�\�����b&����q��w��5!� �+D����V	�X�ʶ�}��⡧Zx�^,�d�@A�O"��}���H�UqY�z�-���޶˟O��5�y�U�4�=��黯$Q�rý���0 �d٫P�DR�Q7 vf�Ϩ�M����|�D��Kq������>d�����d�Y�Î�-���x#@���ۢض���ЛqOd���+�I�y���nU��چZ�Q�xD!��"^v��^�x�(�W�A/ �c�(��}�� ��(���b��-d�ݑ����~4gJk�fy�����߸p�bͿ�H��7o�ݔ_m~���X�itO� ~�{@���'�����R��B++OI��@�    Faua�sy&b��2��v�!՞���Ӌq'���w`u��_��|[.�݆�~1� UrS���"���By����<��3��?=r�O3iC��*��"Oe��0��`�b�.!�E.�'@L��*�T#S4�ӠX+�Em�vw8p,��9�y����)^�Q'�E�f����D29/�#?ٓ01�1��R��G��Gɭ�5�?u��#�A͑�b+�\]N>n����� ��>���]��)u~�P�V�
��O���L��Ё�o;�&ԞQa�(X�?{��#`i�NEE���c[��S[�ˏm��J�M�%o��QUOe�O�]2Kl!<��C���4�η �?���9rR�c���5⅌/�b��h����G'7�pb	����������L�BC5�9_�7��m�5�� ����y��f�bHgj$|b�>�K�E�f�̔�o�����CL!,qM�3� _��yA�v�L��2�bIx��o�5cW�J5w;�l h�+w����;�;œ�G��F�5|z�wv2��������"��p��:���cx�B�3P.�V0Cϧs���-��S�&��ӀH�ի蛪��^~�4<0��e�I��T1�"5��ߋ_���Yfl�j��q|�A��՛9����m�<ZEh�4Z.ys9���U��;��7l�=e���3tW�3��������L(&�f���+g�j��?�Ձ�6Jڊ��CG�-��CC2l�	��{p�Ah�:�n�ߏ�}�;���6˫>k�Rqy�|F�r�����^��3��a��N)�	�9�+�_�_��ܖ�'<�'b������6]����)$�6Ũ��s�S�X3�7�R����V��pdb��V��b�W�ny�+��*x�f�ςcD
=��8`0e�Ջ*��r�^ ����I��	�o-��^@�?�z�;H�D�8�G�[�3�i][��'�tU*���Z�H�7N2��g�5jG��S�ɓ��hm!vӨ�-"�7�0�}�_�.b�%$rc��ך�PP�U�ɫ�󄌥>�������r���TCF0μ L�t���L~��_k{��O�����&�g2?c�D��P��6R1�����Q�����O�}�25�.�&df����Y�'��y6G�@G����܈�^љU3�H�{$�Ė�������/x
C���O~5��n"�"����"��(�v!��4}����ʼ�������z,�P�C�`��W�D�G
Y����������r4����پQ�ܓPPTL
���/o���Y^�Ve��W�sWX���h8q��i"�!�h�><�}����׎���@�~9�����#���Wi�|�YU��*��6O#FI-��������z��<�*�-��d�y�1��\�h�;%�Ij]h�l��Hd5�0"����!d��u���f�b>S��2�)��@n,��� �c�^m��}��%|&C�zB|���TV�z�-�O�zE�6���N�gլCsDP¡4�~��X�M��\����q��D��Ճt��ig���%�t��H��U�5���1��է#��IC�(]���o�r㋶K�ȤަR�%��G؇�6e�v����"(�u�2��2#�kw��T+�ԨB����G���y��e�<�`"��9�Oz��������LT���Q�����>�:�8(y�fڢ>��ibt�5A�����\��.���E/@,���}����*���� \{g��B�
�k�YT�o�� [*�.��0�C���M��܆�|Ĉ�������g�p/��c65�e^�����ƍ:3J��6�I%�u�������ݟ�U=>�V�}��[��$fm�Ur_�,�ML�՗��kخ?�r��-ťR�� ��L�԰ ������>��C�`]���MY��3���,}� qV�}��d5�Ve�z�s�Cu_,�d�9+�Q*}N�%y�NR���8w*��Mn^tM�]^e�����ɫ�/�x���~����>�
���8p�N�G����5��(�H��Da,E����^�-/mS��/�<B��"�,>��+�E�
1z��Y+f���4|����e��b�w�M^jQZ�bAs�C�'��_����8-s�S*� �ҹ����w�Z4�܋�</�G�>�݊�o6s�v�W\Zo��2J�G�gq�>(G�8���/����1�eC9'JP�C�O�8���`n>=��� �v���)b����:�B�rxG7S|Sݟ����q�0x�*7.ڏ��!ӂ(�t��{(�k��BI�Yܞ�#v+s���H�%��G'Z_���9=R����q�4>�<�?�=�r(����HN�H�[���4�R����FB���m%�c�����P����s�D� �Z��)�'����E��Evy���Ϋݺ��L���ݹ�]�~�:34�9]:Qr����i+��8K�舨[��{���*�'X��o�H��fV4ᙆ��i����	�#Usɋx~w�]�h�������tyG��*����=����M5Z%�8�ZL`gB��������g2�5A���h>��N��UZ�Ⱥ"Ux�d��A��$�J�1�u~��;��&�е#���>��o#��5/��W&�|sg�פ&2��0��% �,.h=�Di�����cX=�$��eZ.�W�+U������ҩ�6}ƉlCn�u�h�>p]J�Y*D���=ڡ���J�N��//�ʺJ�
v9�>	j��o>���7�����h�@9?��"�b���]M/V�Ծ�9,$�B�QRB�4�>�`F8��
}+�L���G��w�G���G֔��^���K���G혣'���/ vK:H/p���!�.�Ƚ�F��Viܻn�^��ell�
1��/��H�۷�A��Ra(V�0����CwR��yhk�3���]��0��m��),.��]��:��t��"�p�*��p��#�	�[j�BN�J(�f�2�!�D���_w�=uv���y�mJ�����P��+��8��0�"':{X�C��Pb7w���_�;�6X�y�.:�G>U���x��� �l�D�{/�:�雛�6 �L�
�.=����t�z(m7�Y���ƭ�2��Y�4���.\Wߪ���6�"8�c!��v��8tg�}�x�y�U�$Ty�_��Ҁ�T��@���(�3Ϫ��#�
�b�="�F2�D�����r'u��k���f�IͲ�P>�sI��]�*3v#�r	3�YNi�>�i�#���� O�1��b|��̯r��3v�w��vC����h���?+<b>��gjM�YYQ���WY�g1[��U��l����RG��J�G�F��:n/A����,���G��M�@�h�R�yc��t�cdr�>M����	��#���]����QY|*���FA� ����󌾉 �0��� ˃X�r\d��u�J$�(��G�Y�
_=�7o3�܍�]�!_BA�&��痆�wT�ԡ�Z��I���.z�u.B�~n�%���f�zD�RQd*����5��y)��-\���1��r���|gu[`�L��R�N4N�Y�V`ؽ��l(w���J���9|�D5��hF�#U&;�U�Z���#���;u��$�|cP��z����4�b�5jin�/�c��{�n���CS��J�����Y!7�;R�4����GIQÒ�C���O��	��c��� ;��q~�ݝg�(ngN]w/�t�*m�)�
x��8��X�Փ��)�Ǻ�V)��&��0�w��ǹ��0��@dQ/{\��R�5�~��3�	R˂
Ҹ3��iuֻly�N��q�}��e� bA��j��C�4H[���^�2�<g��e�_�u��W-��ϝ�|��<^MMa��H����^�b�'r���cjE�׏�곪|A�W��0���.y%�RZ�p�/�����&h�!$Ҡ��M�&W�~�Q_�"��r�P�����c4n�kǣ`�[���M3k��ISi*k4U�[��)�i�H��N��S{լ���)]Ty���O�jO    
,�@����@��L�ɬg4��\7#�i|O8EPw=E��d��9T��>)�D�PB~E1����^���J����.H]<@Nk�k��G�m���&����o%��_�1j�EC�8��U��RJI٧a��!�2��0�B�&�O.�M8ǫw!�i�����9��&��PBL�YlBD�9.�,|\2�RF+r<2��!n��O��&˗g9gJ+C�*KDb^78��s�pR���w�H���v�h
~��D�AC��$>�Gk���R���V䲙w�z�y+��*��D7Emg�Bw[�-�3��3㳹��.��r�uF��ڝ���o\$��1�{��#�|;�7[=�ۚԕ�}Eݕϣ&V�'?�Ӝ]����;(`�N�z�l��n�iۉ���26T[Y�����]*P���/��'�RDؼ��'��D��&��6
q������l�E�|�U�v��p�*Br�%�dK)��ѧ�j�*�+3cUL8#�z`x<˦_ޮV>�RbT&��kxn�'
|(�.�RcS���ȂQ�����b����y�X�8T_&/�U�r���o�{�_B��&s�/ ̎�s�AĐ��� �F^.�t.°��P�;�dԪ\=l�Z��zy`C���:�O��vj0�a#0:I�J�� V?C�v�T�!B�*�B�*3��J^���}ǥ�0d���7M1�����]����_�/��̖���0��������.��{���c8�)thB!0uW��@�ן��/Y�Ҳ*%@Y��4��k0�����a9�U-jӓ���חè�<N}��8�)Xi+��JUa��@���^Dʟ�PS���r�r��âm�L��1�"Q�Vu���To�{G��VJXd���;������==��E /#̄�L�jNOp�!���bV� ����jW��[���"?� *��݉�]���I_�P�y�.���{/��$��Ѡ�u7�uV�ܝ�&� e!~i@���Q,,����Z�������A].��L�hU��EY=rϖyי�E�qPk���\4>oG5.Yh^mnp�Fcv�Qbc������~�v�(Q4���۲��b_�gyn�D�&�k����$g�0�&��J��m��s�WHr��.>�ի�X�UW.�Ua�LO\!����*sYtS��j�3}��٢��-�̝q�0<�>�~��(W�}���ΫL%-CBL~��V"^'N���8]c����`s�?��K~���9GG�9���YCc�PS��)W��c�i:�<Y�Ҵ�����?���o���f�#NY(�*_�24?[��o<!ln�B�Eh�\��ƨ��q%{�U��	�}�f�Fqc���Nc�@[�h2��ՓV
���b����( 3����A1��"`?�Q���j,E+?�Y;V�Dg���U��Y5}��rƤ���Ln)d4.+�0�f~�p?U`����Q��SS=�_eGA.��9�|?�j�*EC�ŧ����/b$Ĭɟ�jX<�b�r���߇Eq�������|�ߎl�1p9ť(�G�RT��D��wu���Q��fpi�_�5��#�|A�Kp��P�7���Y�Tl���;���TAĐ�D�z�[�ٶy��,s��( K���cu*�A�t���W�Ǹ7����gTQF������3��ǫ�Ҳ��5˒�t�R�"�IVMn�ș��z-V�hZW�@a����{?H�ӆ�D���Lt4~ P4�Q^i��@�ҀE��q�����r�#�)j1�.���UȽ��{�=�ed��5�/���˰�8��5�('�m��c2:�Cx��h�1Z
�{�w�A���H2�\����`iw��-�`PG�|��mU6�L�����	X@[�aG������+܃��*��ݾ`�*wWIߕ��WU�P����Q�Ƶ����� �G���a�Q����w.�>�;�'��#*���B���Ғ���Vo�|Y~!��v�\Q3C�]��Y��k^0zv6�R7f6Z�4�����5�H�1�k��?����y'"9��v/֘7F՗�.R�KY���̌=�ț�7>���q���:��vךp!���3�(z�ss��s:1��+��3e(����e,v�2��y�����z7Q��w#��us�~Z1�������T��]��,�5đ%k�,e_?�����|�q
�7��H���P��3�<{^�|��vk|�/O��n+��H�՝��*�{��|� �	-��U[F|��X����C�����Zț�ԹqV&�	��V�1��9��R!ī7t�����I�/����%1g��CW��������"h�=��i��gy������۬^�T���v>y9�r�(<v���o\�ES���w�:�ؼ���e�+�;I`n��������&�V%oh �]�}��+�:��� qt!�P_��L�G��2���½�����Snd|E)�(1B�z��s���;��͞�I]��7�Sb����_<v���0��7� �EW-�B��+�Q��	z8Q�С��UI.JV���5�W���P7�o�)�|�c~\����=�6���3ִ�e�q4PT�53`K�(�S�!�1%v�'3�꥔�m[�-�M�y݅���IsS_ZIjR�*������)Be������;�����-�u��Z,LZ]e��:�26�D�����ɛ�_td�!�p�'id&�pQ�A�-_�����/�����E��V�j����"H�ȏ�ݣC�3�K"7�M�Av�CU��(�Oe���>K��g�
ߥ�nM�|�ivͷ��4�(�.9���G���n��c�1zב�������]�~h�r�/Ox���'7<��Y$Ҭ�<,״��W�+��K�q\�Ob�j߹�]��5ޥV��OޡGx�q��Gɶ=��H_��q�~S�Bp��Awލ(]�H��?$N	����E��d�<����V	\T�o> Qb�N�@�����bs�y������Ţ��{��Ik'��RG��ɯ����f�m��'�R���>�	��@����N'y�E�,��7Gj#2ݢL�In4�����!�F��_u�k�űQ
��柏c/pR�k�Fk���Q�GQ7�p�CJ�#�±�jj��J���Y�� �U���ȷKR%W���O�������;�W�')L��뽵2o���e�Z��������}�4��l�ç��w��=CB�����Dn�(������~{���y�<-�s�Ky��,�$le�Qȏeh�6�2?��T���ՈX�s�&*$]=ץȚ���Һ�*dz���}����s�[?�^�"�)�՛k��U�޸�Wȸ���d�<�	h����/>,!��� �H�Y���zߩ���5�¸���9�<�"8�XG�m$��~'v�h���I5�����'��y����0=�-�{�7'�^���WQx*��p����X\�	৒+=�sUr������h�{���U�8؅`_���F� ��CL�󃃚�����t��Zdy^(H.Onx�D���Ǳc�G(:tR'm�n8���6I8��Y}�X�����B����s�|�u>�C&ȢIvcR�����C֨IsӍ��Su��@UU���|�h��4EZ,b
osa�����6���i�U[]՚�uD�w���N��:�G��	��1ޠ�C���'��^~K�!Y��e���7*;F&@y=Q���p"���vcٚ0�X=C��]�T�g�ei�\�d�|��D��'T����l���a�����m��˧6.5^kf/z\�ܹc[A�#���/̴��������|�4_d��C�gh��	��j��S 5�+���d������u�U7Q�P�mFO����q��ڍ�Ш�H�������t��%4�"�u!�C�p(�P|� J�Ut�N����)Xp��| 9�5묃 ��#����R ���O㆛e}�#����+qUI�|4�.1��HW�2U�����?���|lCv�T�А��z�=*581�F�y����\Ց�f��Z_�5�S���f�ĄP���y����    �@���U�n<KFh���7z'�E`�Ջ�e���Ke�T��'Bb�����b���'9��}w��鐂��G�l�v�b�>�գj��jr��p�*SV7����%)!�s��(m�5������@����R��w[���p��مo&%��r���P'�q�	�#F'��Ϡ�4�r^��T���]]�p��ٿA�ꭩ��a�ҬL���e��N(�nѵ�z����'�.�H}���|���L��:[���T�l[m_>[U�n���%<��w�����Ao!_�:x�+�,�
�1!�������%���*�[(T���G� Fn���E�����(4��c�U�v7�7�
��Έ$��e-��]s?f�����#mrs�sVm�hU�b$R�"�~���E��l)�-5����H��u8������0|��ޫ�C�ѩV��)ꬴKջ�2��JY�Cb�=a�|�~l�Ý���9�~�MS&�qvP��l��d�N���I�lRo{�/��5E��y3�'�P�?s�*�i ��Q�&e:"}U�e���r|�����T"���§�z�t��uS� �ޔ�~P� ab�5`�TMT�0��q??<���Ƣ����[�MN�m��T)E^�^f�E�&��yk:q $��t���ǑQ5�"I	���؜�N��<��"1�y���ZԺڇTK��z����}��p���@SaW!d T�?�ke~TB�_c
Ү�HG�dE��t&D�c�l+�`�Ɩ�t��p�!��٫�����O�W80���lҲ���y�_�#�h1���Y���+�!�&6����R��z��A�"��O���8F���f�{��6�����}n�J*��x���9j��|�#�v�"�$]Ɵ��'k��ATA4��m����v�O�ч���P��g�e����!{P�i�U5	h���`|���y�ߐn'��Y�ߠ�ks�Z"��^�|P����yꦇ���n�� ��t����ؤ�>�U��V>����L�)P���'o}lP����e�(��,uii��.Е�������:�z���@7QMJ�7�ڻC��m�DU�QD�״S��`8|<���>�+M�./}���2M>qc3r�]�B��O��x��Y���}��"h?��������|y��TSB���
p%jr� �1�p��I(qQt�yťW����W���z����ɬ^���S���*�+�&�X0]k��l2�Bx��jF�A�$���$��OZ�&h-Z,�P��}E�ATS�]sw���3���!'o�Q���q�(�1 ��Q!�d�>���/�q!v�� lӆw�V���/�M����zX~��'t�~X�
8�3��I�X$�8���H_�I�A�2G��s\�Է����Z��vRY�XW�8��;�M��/8�6�,z�)x
�r?G���Dq�P�a��Ж=�_d{%0r���{H�i��<�U�����&׷�W�%9L�=fxHa�K�e��sҀu�(�����x�/Ru�/.���ɫB�v�"��"ԓ�U2�.#�>�~��2K�a���g.�R�Lދ��:���T�1ŉM�'͖C�a>Ŷt𵭱)��+4��3��.�Zf��hԜ`��s��q#o��"�zɖ2k�|))����}�<|�u�T�b�z���y�G���Y<��� i�-8&7u�����LŲ9/+Yl�H�y�_O��B��)�-��������VW"��Wo?J�_��9��X=��4ux���tSd!�0�.M���8)Em�9X�W�\m�I9t=�g�9������z"��j���2O��\V�}VJ���C8P��kwm}��q<���D��)��~�]�n�/#���f�"�Iދ�$���D}1������|x��e%]�CpW?�(�n��/�Ψe��������Y��UDԇ���D��ws��a�R�����Q��4�;�+��,�������p6a#�#�C�������	�8��9�,�r(�Wg
�д��߰���Es�H|v��̖Ej�fyek�*rS\���]�6��Q&l�V(d;�4w"�
s�~�f�3��H���ԝ��nHm� �=G��N)� ��ɷ�k~��\��70��n>�j��H��IN�hEK�+${d���K�����4��uY���M09d��v-������՚�!��Uz��g�^�!��$e�!g�C�[
p�67^Q��;3��������r�a���P�~�~]8�E��x���'@��Z������H~��}���#�#���a��� D�����N�:�!RUQhG�\r��(��Q��CG��'ߦQ�9�|���7��G���lަ�ғ�O;A�즉�lm���#�!�F1���=����i��,FH���s�2���#�Rkm@*H���f9����"뗬/]����G�.�r�|:�a������Ve��@�4X�@TTt��(�`����N
�	����d���M��P�8^<Ї�����e�����}ݵ���Yj|=�� ����P7b�]���i7�!Z`8�:���vFw��������||��fC0`�_�-&$Y�B���gFM��5��.�|9�k����hwιd������^(=\��
����S<pB�]��S�.���q�O1[��Aˮ�#��v�^�u��U��OW�)��*��xX[��{��6�Ej��<R/xBɩx�*d�߼�&͛�_�Zm�<� �1���Fe��n���s{��j
ٷ}sxMc�ЌzL`Re<�b��.4�*��Ѐ�ʦ���N�j�򗮝JFQ�C��0#z�S{QV�ay���	õ��3�+z�#i�H\�-��b���
�7��;
���rF�y �n��M�0B����'N���ëO!�ޏ�k�}|]Sz�͆p��{oVo<[Vy�r�1�l�I9�6'�����z����pz������UA�:r��[^���~>��e��>_V��uk�g��r��I�"�7w�h��#%��!��<"�(�UU�Tڌ���쵉R\��XIEs�$������]���%30&k�Jf@���.��e��1��׏tl���Dɥ�>��jT���)me�fۥZ@!4Y�9�z���H.�E�H���q�u�W����B�C�K_���-��6�V�L5ڽ�ҧ�:����(�^GɃo);5C���5����2ƻ�c)�M�-Օ�3i�)+�W��dB��(��CJ���T�VןE�۟F�K:ቮo#'BV�����i�" #NNpGj���C�Q�A*�Yˈu^�ᵂpʨ٭c�� �~�����^<Q���t�쎏G�q�K�&đ ��%{����QV�P�<�	=�|({����wb_q :�6�4�*�9��U��(�}R��7���A�{��Mxz�v���[��1���,Oz<�t��
*�y\<����N��j������pɗG��N�U��������ԕ	w�6�=ܕs�F�18�Ʊ5 M�+U=�-�
��A�e���_�&s�2E�T&�7t��2P���BZ�q�� �S#A�JT�t%�c���5���Փ��7y�`��\�U>QZta���4}�0y�2�vO���O���5s�-F�ڥ:A!F��VUe���ݱ�e![��jBY7��'x�5_�+�g6�J��U���Ӆ�Y�����Fd�<�J�"��RH��o nP+7�aTv�(��m�����C'�w�L>Cq�L�bh��(:�]�8�7�i!�}��w�T���C�-�&]#�N *�Ȋ"J��^�*~���$��
F�V�F%�P=c��������-���^��T@��ԥ;���1���+�Y]� �ƀV�r��>�4/��6��s����O�h�6�ft�ı-�5*�qeKq�p��@h��1�(�S����(�+Afx��M�~M��ۢ^�(�ئ�b����
Iě�b<�[@�(rG��w��3ߎ��7�U�z�Q�e��[^c��f�d�iF���1�aDqPXh��UY\.    �Co�Z�g�	Bs �Rz�Hx:_�^d����v�{���R8pΞӃ���Y��Ц���q_�aH�Ɍl��������W�N���0��.�+�a���U�"BI�6��{!�t�vNz���/��B�"�W���W�㚦?�(�@G'X�P>	Z��C+�\��Al�D�B������٬�xK��^�د���z��t�l��+��ؼ���Vm�F7��=�@j�v?;��O�$L��=�Mv�^����bę�ʍ�2��D�r�T�]y�� P@4~6�Q�)�D?�_Ĩ׸�p�����h�m+�����-
�S*)�j�>+�#����'���i.LF�l)e�#n�^��Uz/Iu~~:ty�as�C�o�B8��q��=<,�W;)fЍ8���1F
,j��0�n��}��@�j��|Gw!U`���7�@*�4�Ju��TvȨDF�)���L9�g�ې��B��Y(p:2�O ���鶷��P�P��<<���]8�zxI ?3�e?��n5M�_.�}�b	e�<�'X�E����0���ɨ8%�'<���df�n�Q:v��
��*Ӭ�#�L٦��c��<=6�p9�k�4%X�'�ⶾQ��Q	���:���ԕ�3>��o�]H�E��/�r�x�`|L���u)!*��_��������mEt9�D�Y��g��.�%�T��"��JBX&�Q�,)Tu� ���h.��ۮ[��E��B3����]Ԏ��[��d�������H܊ws7p��*o�U�o�y�f���;�e�����N�m�7�<�c��*�ks��jcZ�À:��<�ar�f_�,s>���
��F@:EğFQ���T���Z,�{��ٛ_i���D���SyL�w��³�!N|յ��B��\Nr�F��>�H>��h��@��NF����X#��$AOPH��6��H�UP#a�%=<e�O��ӡ����F����(z�,_#�o&�������A�]�nKn��ǽ#hZ�L���qrR��l�e���f�}!�H�&�|�Dy�""�p�8=	/�h��722��/jjH_#h���ț|�WZUy���ę|�����\u����unuy�z{��
��ڮ�ڼ[��MS)�2P�e�E'C�s8Մ�5�0�Cv���Z%[��4�IPvN:��t�\�^��[�^��-�+z����qe.����Inv�ɏ�g�����
�	a� -]��%p3E�Fut�D��(��k����6�[��*�\^�Ŷק�|qJC�w�����>�w���6%0!��ex�Dg�F��?�A�O5�h�����I���6���0帝���y����)V��T�C&"�LC��t��)y�w:2z�;�t�k�U���7E�&6�N!��Z�a@�-�;����4�6o9��I��==^jy?B@k��[�24!/hC���jG�Je�ي�L5�̍ˉ����=g�&[����?3Z����9���Ǹ��pF w���@I����8�у��$��0m'��X=�ֹ�4������l�U�8Bw;5j��SvW�KW�����e�.��Y�㓷��1RIL�r?B�8�-ڿ	�QF�_�N�?뾊��V���e��I}����Y+�>�Urs7ESZNl��w(*��Fwɉ9&p��
�� -ۿ���?��!�Q�|�Oq�Sw��i����q2�3i���|��=��͆~�xr�z��G��:dW��E��ED7P�j3>��#�]e:�-Gʬp�T�&K~��!j)�#�{��Ad��ߨ��=�|,~O]w�Ob�DeWU����k�
[8yn�I^�n�T&&.�P�F�Yx@���ǗşR H^�MAڨ����q\$p�t%��~ʴ��a��%|5���>�i�g���R�t�g���#�v�]�u��=<���Γ*�ŕ(	�j^�`��C]�s���`e�i�b�R��5ӼT�1���	��IL���ţ���S���s�G2�G<���[QX���.���(E$ޚ"<�x�1K!J�@3ቫ��g۞&hr8�z*��^l[��fy>� ^�i����3G����)��NHk� ��vG���t��ŔZ�>��w��m��_�7O�9�Vd��V��鶝���ǰJ�LĬq���	�E�%")&��Y����~��3�.f�f"�q�Y����kZ����=<G%M��ϔ_ڮ���I�	�����{0���j��Z��@6r^�쭩��G?�n��)R3�LT��~����UG���k�̙����zg�$�i�
=D��eR�U��t �gq�Y��S=���ie!��� M�"6El~$�Q�~X�����m��D��i!�ENr��7�U�(�Pl�a���b0�'��S) ��'�.�M��jf�k�F67�P���$�)z�A�*��!���|�ba�(e?���~Q�M�4ˣ��I#Q���tL!xb�<	ըB�b")�����A�t�ˬ��gEY-��ܔ�Ah��!���J����1�W_���z9����Cb��%�D��	`/#o��B�G�@l/٫�}ڗ�bA-{�D���}h����5���>�8B�F(�'5��?�s���r�Wn�Yik��.�Z��J�	.<
�*�m4��;�Q$*��Eu�~Z`��t��\�����"���xa�c'��M��V��D�`z8t�o��nr��@���g�b#+>�՗��u�-��EYT��Y��ZtrK djIr� w4����^uY������7۾�.ʬ�ryl(��3y{� ���-u�"2�X�RD%�ai����<kM��:/������L�9��E1�n��M�,� �;)!­Q�Hn���"�s�֬�Z�y��t����+�Ȇ�K5m��$��|N�(U2��ʚ����=�@8ŵ�{P>��C�5���G0\5��"�h�>�Q"�)&��#��C��hH�	��D��"|�����~�����iY*pߖ�������3D��I��V�O��
ۋ�\���7
}�8��>b���@�$�m(�����N��uɵ�o�qCr���e而P�C�6!��NCgY��pU�Y�ŭO>������D���_[.���L}��E��=�ۺ'����ͅ$G���~���R0^�z�/�ֶ��~��(
ut;\�/�J�tU��.w��.tu>�UD���{��jý���Qd:R��r�t._殷�/1:?Ѧ�E��[������Dc�/��*oX+��)���/���
�9�Z�J�tq�<a�N�G��^rD@��� �����#F����=="�J�ߠ�DF4�
t&��1��?�"�W�ف�
���7��xhv�]!ݙ,�g��|�y�V:ߙ��\��=gИE�rN�Q�:�<^+��$"�"OZu4��Y�V/���3�,�-e�U@)2���S�9�Ee<B�cA���/8�i!e�P"W6��Я��);�|�<�����E�I>	�7�g+�GT�����𭪩��nna�+l����5����b��
�+A˓�����S�I��N��@��#���C/dJ��D>f�����fq�\\ey��ŵ	�����ǯxag�9E0D�\��Anu2����>����Om�/��Y�rF�V$�����Z���=u��6Ow������U���#�G���W���E���LtyCt�/�}�ťbqe����)J(��bF�!�M�<��]���*Ai�G'��9��෕�'>c�L�KE�����>H�8a�ʙ��|���������!���S"�S��#���v�=6!�@���;rY&.�f,�J.��󤆅�GY�o'���n�v��@o[�[uC�V�Z*�+�A��z ����8C>N���5I0M�(r��x�6Zh���������.���<�!��HB��*?w�IQA��?�)`}�&�䷪2���`�~�t�*:	���7�jBޘQ��g���Q&_����P�s�/
�\�?D<�c��u8�[��SUƾ���s�)�@'�(��[?ĦHF:�����I�7�G���V��[c��$���)�L�E� ����?㓍�O|��:�P�^Ť��Z��Q    A��9�,�*�����V/��k����67�H�Sf�0'�!iu*�1Z�݊�ݸ$�����ә��ef�y�Cƹ�z�_����_e�Ֆ�4D�f6��uC��Za�B!�.�l�Jy~���5���BT�i�Z�|���o�m7�LD��9��r�WƐVf�	��E�LDϬ��n��엗�����Ұ�Tv�`R׶p�u��#��*��6Y#��U���p���8<���ѺE��e�z�����ZjM��R$o> ���
���W��V��)P2ߟ��y�٤���3�S�F�\�����>����n�ܼѽVx����`�.���"��7P
�7i���'�z���;5��I��k���c�_#�P�/�L_tΣގr�TQvߝg��]���E�8����ݨ��֏r�Ҿ����%�z*�:o�e݀�iW��Ͷm��uOY���r�,��iQ��#|��4t�/��vb�N��D��q|���'��6��ŕK]��K�Xo��%RG�Fuh4D:���N���o"���BT�&��L��zo�j��7a���^����Q�L��$�z���E��.-<�^Ɍe�/o��v�鍉q�#j���� =5�:C ���^<$m<�@��Sցd���U��@�&�$	��;g �텨{���� �$-�ge>w��>z��Z�#�xe�6�./��Y*��eɷ������І��@A&���G������Q��G�~$ao��,OsUn����d�J�gT\���XK&�!�������K�3��TA��0�J��5�%�4T��{�o�za}�o�1�/x�\���˓O$�G���Ve w݀PN�֚q�F����Z=��J�m^.�W���d>�f���u}9	]/j�A��5Αn]���({*LbTs���̷�� 51�?��mG�$�����'H����(�`�(��T7~̈&2<:d����^ko3�i�)��ժ�jH �af��&�:��ڈ�[=����ҕ�����.:��a��zٝ���,)D�ݽ-T�����z>M�yg���$q��YYD��	�<
�x�$5ؠ
�>���1A7�B��~"_'��_$Ty����* {c�^e�n�u�M�������-�1��`��K1���r�I_m�8�i[*��&Yh
��V�Q�~x���;��/�
����W��t�$Yu��A�8�u#���-�4��~��fΙLmYG/<g&���T�%�7��n �~h8�m�	/�ߢ�2�׫��E�=�g���A=����c�-zj� ?+O�G�;�f _{��3��[&ΰTv��g��vo�(����u�FH
�}�PZ��=���"��ލ�3קo��ܠXU�'7ok)�p���"�6_��S�o�߽r���-XB"q�{���)̿�O����Z�I�xy�'��.�ZSpGz2q)�	����w��f��G~�g�=mq(x(?�:�Oc�!�8��^Zri���3����tl�$�4v�jCA�^�g�w?g1Z�`��[+'	�2k�q��^��vM��˟OW���֫4��J�6�Gp��xA�� x����D�j��fu��]�L�bEb����D�h�#�E}!��{���Q`��8��_�Y3v���-���H�U�-�y2�=����#9&b(�I>1Z0U�ոlړ@����^
����������Ҝ��3"�e�q�+�'�q#g�s������{�=���+#��\�J��f����y���3"X�_�rn}b����Y1W���*os�D�Ppc�Ǖ�M5x3h�x#���Pb�]��*_=��Ǭj�4�Kr�h�2z�Y�Y�yl��߇���+B?�`����3�	H1�Ǡ�vB��4iZ�O�{���b��׺ȻxX^�e��sZ�γ�AEO�G�3}R�3�+b^�~~��#V�ꉍu�u˙wŝT֩�Ī:
|:s�%���L�L�K������2���1)�����q��^{����G�N���=0�'�asc���R�� 	P+s��J�W~�p��k�ݬ��[��=ZCU[�.x�ys�0��Z\Ko�J0^�.��K �w�d�?��K�3�2U��F�����O̓�aY�G)�:��=g���Y���>׊�� ��Z���x��H��P ��d�uvUH`��q���vJ����z~� �:j������ʞ�����<�ۮ:��8��4�ЇF]M�@�X�_�|��dk�y��:�~�cy�t�-�g�*�0MZ��M��(W�����='�I�[=r]qS,��nn�u���@I+�g����}:�DOʒy��G�k�+}(����;AT��S׭능�Qʳ�Hj��E�λ
�8*�I:������s_���ߠ�Mҍ�{`	IQ���Ke8�kvTVg"���j���5!G�=J>���'�PqùQ�[ �?B`���sA|���ꗯNʻ$qR(j|+���V?߫5|07}�4;�$L��� ��z��`�j5uZ�^���/�1����f��d��N��?�u����}�����O��Y��4P���iL�Q6G��M��Bޏ��I�^��n��J���4Nle��?/|����t j�"����@���}�Ȧ�������uC�'1�
Cy�q���`���O��@�\��xȗR��c//�^�kqݹ�\,m)�J3���4��;x�)��x`5]�� ���񴻐'�#N��1D]��l�[朋�L��V���X)qf�|��c"� ��Ͱ٠�wJ���삘��_�5m����^uW�q����T��2h�{�9&�(`ka�47/�r+ZKbٮ�5������:���~ص��a�����v�]���!\?�@��_�r���A�Wa7NDUqּa�iⵐ�Ǵ��;���!D� SqF�}�6�]���:|" ��*���F:0В���|�{��y�i\�"7ߚ�u�E|]k��3n�**D>��1�&%j�?C5�8i��KX|�Ҁ[�L��?���P!u��W�i�h�j�����ަ�2�	����'i�Q�
�zĊ�&��뉺=򨬿쫱k���,�]nUKN���t+L_�G���^�"�d�8����+�4/��i<�� \p��Հ_.�m�z�^���M��<��!�_ �H)S�2FDv*�r��@�X��pO�������1�*���߂o̝��L�~D������r�����oS��P՟�p�f�=ȿ���@b��[t�U�`��2�=f����tr��&ߊWb�|f�
W����q��Y?m�����H*y\D���r�gK���K��������7����/�Ł��ą�>$z�^��?�7���ӌ�K� NH2�'��_�\�u����2�� v��+/���*��!�٭?���r��YA@��OV�̥��TQ$I�Y�SG���(ذ����tcT����n�UK�L��j�@ɭ��MgI6��PI���RZg��R���z�#O	��|�0K���dҲ.ЯQRa�/�����me�8��f��V&e�곖$�*$3�%�ζw�W��(H-R�$xr��T>���դ4�5y��I)�8���@G�@ݞM�!>�2 ʇnP�>0�Įm>�i��r)$(�������M��i���Vq��:GH8G������t+m
my_j%�Oky��KʡO�_�*KJ5vȓ����5��8Q��KTЦX7 ]��x1��Cs;����X���$C]�ψ[UH��qˣ�ƫ��Q洛�v�LBןG-S���^��V�N���}e+=	���&�fCT��'���3梵s�jT�IYO�{/@i���6�I�Kğ�^)%�7�=�~ˁ&���]> ��$�a_RF����ä|j)iOx�o�{$��:����T Qli�(�_=)�q�uq�x@*��P�<���Vl�G2s��Q��������p Ў���w���j<��(R[��'���w��
[aKp�fϖ2>xN�����	�om��c&�z�A�_��#�������ӑIR�Ŕ{�OG;.ӑ�>�c��	V)��?�F*~����?���9�    ����X^�� v���J�
�24s��������W�^z�qC�-��WáP�_-��H<���G�Mo0���9�1��@q�V�Li2l]��)��$�8�q��������'-]ϻ�oP=��e@��v��.�9r#d���$5�ЩS	T�V�/T�u;=�4ۚ-�~��f�nBO��Ā` �N����"���`G��7����֞puCtΚ�:oW�:�؁�"�����27��g�2�_1��#�-�����JA۝�c�����B�;�0���	Cpٍ~Y�ԫ�F6Y����|�T���i��uՁ��m't�m^���I@�)-�gz���M�\�xk[ݥi]*� O��wln��a՘2��4�W�7�5jʎ��?�MR���H�{m� �X˰��K�X·na$b�cQk+���|��JW��j�4u��sqfC�4�^K�0=XL�ЈSK��{|�	æE��J��c��x�;舲�a��r$�J>���T4E��U%�U��:O����tU���`x�KCf�����┭�ՔI��lq�2���i'�T�tΔy,���#*d �T�JRR�o��[���VV�>#^e�Y�,�_*�7'Uڛ�����=)��)�<�?�R!%u�!��O�;W�����H̉W���W�A$D�M[���=�S���*�t\�L�\�~u0!j�Lc6�M��}Pj�;3���)i%(����_����<��bE�ǩ�\x���a5�9{�y�Hl~�^=kq���AKO���iǑ��v�CZ=Ǭ�]�<�--���͟K�_Y'�8�+�=Jx%hE1>���Սk��OB�����hb's���Ö5�n0SC;9M7#'���_�ib)k����se�Y����z��1h�(�i�'� � C��c��m�w?\��']1��i��%����X�*���E/��<���h4�JG��nT��fR������7'���Փ�13ڂl'���UZ�f�� b�$jᔻ<��y0ĽUt7FW�K�z^CӶ�t��i �����6��E	2OZr��=�h�{�o���ր�^��97<����8�tW�C��8�zCX�*�@��G��<`k�i�+��zd}م)�)P�`%-��� A�[��m(����ZJֺk��ZRi�0�����{̠G��`�[LJ�
���a��)R��j������z������3��g1��ۥ�G�xg�j��sW�CA֩/� ���I��fuzST��)"����#}�ǋ)��]��΢�D_x�lO��z�`�H�|�n:��}:�1Go3�!�P>����T~�[��L�&�����La��\R_�H�4DM��,M��U�r���iG6����@ �����жY��(�7۶&s��W�
��	z-i�G�t`���s�`t���7K׏�]],V�pU����"�Z�\�1?D8�A�����ۈ�ͺ�.���s��h����fB_G�l	Q����5*z$�y�ޞ�R�2Sx��?(�0�V��n�,I�jy�$�{.+�Z���UW/�!�(�d .5>����76�����!�oN_�>�<��]�۸K�qym�e.�t$���'�n5��'L�q�
�FV��3����6qY�_άNb�u�*��w�aw�^(��906>:^OG��H��ʡ	:	�<��! GG��GQ,Wπi�&�w���t�Yn��Lɉ��7v�f^֨���y�^�4��	�����������Aw��_��/��G2�k�<��P�`�yZ�2x���;��5����s��$�a�̔Z��.�ߗ���7(�ءN�4��N=�s+�|G:p;�I	t!���Iy$x(���6�pIN� �� ��<�inRn �&o�Wh;�S��o��|�Џ�q#5o�;�ݼ�
����MU�$�`
XW~:h����DW�o��b���#��*��s�@B�I��AJ�㭬^��Z��H���E�< O�W^�r����&.��c�v���V��<�ژE�q����L��w�;�<jS���(��<��i���L ƵV�_Id������|fk��a�D���j�aGL�)|p�G�.�n�S[�I��t7'���N��a�=��m�LT,d�B�(O���U�-��mX����x��h<�p����5}W,�p������y�������JBb��'j%�Y��`I3����:���$��	��י:�ҷE��wT�e+�������mDN��w����%�8k
+^���i$�����`,�(�#�5��l?p	��W���(}�[M��!�����g?]l�n�#��QT ��v�@.�C-knX^r�BP`wQ�C�"�7��#ӀEV3$�s�g7e�ۘ6s�P,�TqQ�Z}��FÈ��С�PY��>� R/�4�f��`��i���v�Q×&&Ԝ)�#��J�.�s�;G /���PO��\���F��3��?��&|���(}�� A.e��ߒ�A����'n0gY��V$)���V��3��e�����,��2��A.)�^Zjf�cc-;C��D���ĥ5�6��Yzu�.�W�n��l���UUf�=�Ed1l�圉3��y��꫕�a�	$%x6z�<���oK��� L
��"��Ψ͋�i��QuZy�s^Fov��uHQ!�߁�2c*�v�����C���D��/���}Z���pu�׉=�T��XzY�����S��Wp���!}�$y�Ƣ����.A,W�_m���Ι�pJ]�+�:z)M��ir�q1	��9�{j�U�	�(Q���-��y��]t[tiѦ��V��u^Ć�6�)�V�AS��L-�i����Y�~�Ж 9/,RaI�(�Y
Wg�wq�W��Q$���Sī��e��q�<8y\^�����-W6�o��>׫u�`���j�$����n) 	�]�y��s>�&P�MFr��L����H�U=��J�A�WOPk����"%h�׵]�,z!-G��A")���]8�d+?Dȭ?�UM����aZʱ�"�ȣ��T�m� ��uפ�̷�xm�"CX�y)�s2h��S!�d=S[r:�=%KA$��^�
?W�:�8�5�Nk�G�Ȼ�J:���z*k�ʑ�� ga7�<�6x���1(5q:�=�	�v���SętO������Ĕ�Jy����"O��Oi�m����'�:餬_|�\Ry�ڢ�~#(Mze�TI�*Y�1xI�?��u��<>y�ӛ$�u��|����iG��.�K�4�F��.y6���m����!��}��Kg�L|�*�R,6��Ȗ���D�^��X[�U�<��Ib2�E��w������
�����**��#��=��İy%]���ٻ�`�$���k�@�!��[��5��(�� �+}f���~9`���fh'�@j�J���h}	��r*��s���y���}sZG|3��b�o1�O�[�.����#M�HchE���ą,Vo�6I[��I3K�h�ⵊ�`�J���,�a���I>�wg��TM6$�-{�eq&��-�����̘_&y	P���u�?,C�{Q>�nfe�V���H:����4��f��!��N����q�����&q�욷ޯYa�p���u.Η7����E�����S(�t,	�q⠹p��C_Ŷ�*@B=~Ĩ^=`�m�nL��1���F���F�8P��1�,�0��y"���W/��v.�aqh�Lr��z%�>�IT%h��.�-%q�����cU�Y�y�䪶k��]޳�<iZ��.b�$?�y�� �n�3�]�ZUb��9�q���ħ��<��dK�[}"݌�(�0:p�)ݞiy��ǃ5B�2N�},��m�� oy��"K�}ʍ χ[�	�j��#�דwG�i:����	��r����\��ʼ桸����2[��6�I�.ݪ,��5(����ۙc����}W;��e�zY��a(�����CS���Is�,������3o31(�]l-/��`��F6�-{Ԣ�m%|`���*��,VϞo�j��'�.    ��ԡdYE/O*>*T)2�Bj!x�x�Ȭ����B=~��힯}?�0��W�nǶ_��>S�j_��N���,T��z���T�L�Pd]�� ��� O1������T?u���rj�O�:C�$6�-�4�����{`��.zt?��cL��(E�"��Sh�O����K�x�6g,�p*��2'��8���#���m�Y��R�o=mT�X�V�?'B�i�|����8���ɰ*<���J�6��6�2Uw������c�t��xb�q������8��2[~�ˢ4�y�˯�ouCڴm�1G9}Q��f���W��o���,	L⒬�}W�@c�+=L.֊�	�>"�n X&�7V��q�
'���ǧJ�^�R��`$��q��y��N/@5���taD�ӈ���ogU�CN��7���1MV�D�%}S�jqLSW��r�[ȷ)��2)�r}�͗Fg�ʻ��~�g�\*]}"�SS'��@ɣi�m�E7s蹹��i�738I���V8��p�!l(����� V�u٥�+�xq����K���13=�ͯ+�XpƜ��"$z���{�ˇ%S�?�?�B�Q�V?��\�,6{BT�2����J��5O7t�O��� ��Ap� J��װ��zX^=g���%��W�&
�=f�TϺs��$����MF�֏��b��Q����Z	RE�f�,��]C�{��~@�N�o\ݪ\}C�e����K�<wUm�H��-%��l�
A�ﴣ��"��Ḋv�`���,B�cĮZ�֫��;k�����Z�c0}�w���@4G{$�Is��/Z����Q30��'�KU;I�ߵ�^���
�"N���-�ȫ���u�S4���� 6�4�Id/u��n�kY�H���V9T�؂�P��nvE5$��.I���ӈl0�;(���6�g}��p�Bl �����;�77{ib��m`;�Qg�:Y�t�+�q��*s6_�]�\�G<�c?C�i�0S��(O��}34ߤ<l���"0��F��d����AveՖ��,]����	�"�!\����3����Y�
����k�z���%�.?nU�{Hl��N��م�6�0r鶻��e����b���oЫ�YY���a��x���754�-d����h`�ۛ����.�q^��O��뤀_�H������WN�(MO���no�~�ǽ�|@C?(5�:6O�5����0���c*n,����޼g� �~�=����UG�,�Mt;�L3R��j��#j�S?�I'C�~ݨ�����������t۝�U�V�g�
:�5�}:x��g�>�<!�ʝ��m}�зL�����M�(�0�~���������Fv�K89kE�W�������)��^$Eb~��,S��Dˍ�4�E)�u�z~�����1�i��J���5��� )ء(I�k$	�BB�1�E>��ANn�vj�*?E�I�~nj̵�:��/*�XW���tmޤ���(��,s�b'�g�rQ��ja왦��`��Jp����`�F����ux��[��T����vpY�,i�d��-�T[`嫓<v�X��OeQfue3��̀�KD,Y�!�q|!������E�H�%Jؘ��������%Q��&�I~������uqKڠ�ŭO��Y�,�t�,z�������j����"`0��G|�o���ԇψO�g�M��3N�a�̺�&�NA$%�;%������BL�o�,���$�G�J�/��Q|"�﹆"n��I#���Y\��GQH�N�� �co/��ux$l���%��;�m^�"�$R ��}������І��s���(?�t��[��˂[F��ΗY8Kg ��F��0*��aY?ʬ��ȗ��B��a����8�x�9�Rbu��s3| t��I!��)�hb�v������r�M6tj0|��@`��S�8��ry�-]b��E\+h��b/�9%����+ac���/�CY�s��u��U.V��"�:����o|��Mz�`����D(�g�E!�X�6�^x:͒b���N|Ʃ5�	���U����
���Hf�9ҏﴧi�My��Qq{��P	n����2�l/?���e�������T�=����G�d[�yuH^א�(v�RFҖ�Y��0k ��l~�u�;u�w��[p2p�W~9��M�#9����`�8�*t!b�z��C���kL9�?��Z}��y/>�U���vI֘�rRIAy�74���_�xB4�b�mzW'yZjI��yl� Yr�߆�R?���J�@�����T��q�J�����.iG4R`����3���Ʌ��ݛ_�����B޲A���ˤ�i[׋��h�\k�d.����С���M�֬���[�ICY�h���<����<����p��}�������%Y`?M)�$�_g��J����tL�P! ���@�9��?�]�c�<�eY��VD!�ߨ6�A$@%�H啷�Gu^��j��'Mٿ��|�`����S�|����Z�X<��%I^*��HJL���r�n�M*�Nmpo���i1����P�'�zPY��}>,?����%���AN��.u@����$���ЛE�|��`z�:>��&�c��.#k�|���1��ڪ�Z�JO]�;5�T(%r�� yZ�rX�U�/h��gD(�}��8zEA���}s#���Â2��*TD��Js�ԫ��󪈋�7��RIeE�hE}B-�A�6�7��A �<`|pNU;�D�I/�q�vڮR�Pl�D�_�q������y�W�4��N���&�1h/S%�������>O�tqP2�
�R�J�������z
7kɁ��?����J)�gX~���Os�0�,zq��{�i��8�97A�[IM�����x���vӦ*F��	��mN���u�4�<����pUCf+����8C�5��M'�ұ@Z^��q�4��0W�I�~������sE��c�mCY9n�:بX�r��@�S��yw (f��k~�ӑ?�B�����=xio�so>O���_C�g	��5(u�hJR7k���a��NJh���������F2ɋ:N���j����u[%���b|aL/�A�֯	�W��|l����V��d��^�p���A�$,g
��3A��̡ �t������x�|�o��,v���L�X���������DH�h*)�M3}?�{��n�G�i���ۤE�.O�eU�om�V�k�R=����̲��%a<*��y���<�\�n����:�aUZ��,�7�=f��VYW��A�A�jU4oP���;�^J'q�����+G�)���S��V����+�����xyʨ���.���JΒ�1N��)�˃[���f]&��G�%�/���OGGe�S��C9QpK	zT>B�w����v���+�t����iY9m�\}�Kd��vm���
��o`�-�m#r��u�")_�ꇧ�FJOr:��&����K�^����菀^�Rz���ܼ�rD�$���e���S��w���~qӖ�%.��]�,z8f@�	d��f�������G�	�Kҩa���^�tp"B(��t}/�����R�>�,\}�t� �Ĭ,�9����7�T?�;V )�x��a�L^(���v���}_,�d����"YD��S���yzG����}�b'�[sNP�| �W��ۛ���u���+�/�v�i�` rĔ�s�Ϭؚ%K��Dy���~̓�����<��*�'�	��j�/`E�楚-Ifx�u�>ӒD"�z�a?v��/�\YƖ�P0�7�>��8U� �D}ӞS70<i�0����z�d�!vC�//-�4u��Qdq�~�[����+S^�F��vZ�]���{T!,�t�Uͥ��I�惜�t�|�'�z���I�eˣ*�X��/K�[�6�<SqR�fs?I���uw�h�\d�'�	���b �ghl�}��蔌��P��C�����8�7�fϘ%�>��X���qL#��ׅ��u��S��Y�씹�yn�sn�ai��    �(�87SP9���^��z��{�z^R持��ɤծdZ�����&�����/E��A�����,�M��{]&���><?>�����y��%�O�����^`�ܾ�=�H��%��"e�=�7~�N������b����4ٔ�W�	�����̗��:*�ҺQ��*D]�g�W\�ի��ˆb���H�<պ&ˢw���]����K-�_lo���5pFזsE�"L�~:Ԑv�i�_����J�c�oϰ~����`��s���n�\�=)�[�^ծD�ֿ����lymX:�I�Pw�.r_���a�B�qN����T!��o��J���V�U���,#{YgV嗧�alW)����� l�z�3v�|l�83;���Y�6e�8zU*1ס]V���X)�����(Rc�~F/!x��~�������"^��{�!�\�/ҪR>{��u�;�=d�[X�{u�Y�	F �<@F��cR�����t�㩻\�j��Qe���w��8��OQji��9����;_C�l����6�{`ƖZD��p@#(,"�&����p���^���}�.Ou�����y�8I��~ �`�Z�ԁD���X�B�����-H�K��P�y��G��@R� }�x��4���Wj|��Ԛ'�������Z���l��;��S���7�?0����}) ��j=��_�tKJ D��կ%��͛|X�$N<B=�L�}�"�2R�N�	����0[2�T� �#���_C�vu���%�+RK���.�<W�p���\!*���ڲ�<[�Ttj�V����r����I���W���蔛�A2��F���"9Y�ѳBW�3��D�գ#9�}��p�URZ�奧����%QT�A���<)J惀�I����g�;-Xo�#������8��0���l��{Sy5�l���$�?t�si�y��l�W鋩)e�{t�q���A1��f?���5�pY��Cʬ���f7�oѪW&�����2J[��jbH�t�r��$�	��x*l��3�1��q4F�ݗY�4o	�T��n�s��@D�i\���l1�����}�!�D��l�ػgde�����ʰNM��{��ТR�H���U�1���QY)R�z5��n�f�T ��\�bK�u�rw�B`������?��{��呛r�}u�����~�46��Yyx�m�p��Y�\ǑB5��ݝ:�v�B�d��ZL�\P����R�/��(ώV�]٣�"N���z����,ߨ�������)S�ụT��?�;G���۹�i��uxI���Z�lhFyPP�	++6-s�P;�C}�8~0��F�ā�V�:4u<�x���*��*b�[$v���b����B����O����B�g9���Z�i���ov^ԅz^}��ߛ���-l����y�&c�!��S�p�Hq��;�~��m�*^ޔi�b�
��L۴O�X��E78[G!:�OF��Sեu/�~E��IQ����:�B����<B�h�m�K�耠�n���)�ͪku���NU���z���(su�2ɪ��E�,D���,��[r�8��S�lZϒ�I`z�P�r�3U�4�F��1�z�]2.�ʬ�Kݘy�N�!=�@TWP%��q��M�VT��%�쐷{��g.��0���ϲ:.��������n^�̜��$���>(vʉ� ��$�ҍ�M�\n�,_���K��/��Vi�X���W�+�a`�q�10s�۾\$��w�i��g�_�t�c���U���(*��s�J!�w�1F/��-k6l �%�:�V�z�aȻ2[>��Al�� f��U��@�B�Ez�j�x�G��ڠ���<���/�ʶq�_�ڕ�a��8�+B�Խl�r�*+�ݒG�~s=��4���L\T�]��ۚ��WO��$o��\]Vf�]�I�v��}6�޳����n��c��va�^����eV&K+8y���4|^�F���ݙ�\����E�i��='ˠ ���'�F�d�"���'�baX	X��\GK��~�j��ܾ�1� �cP?���tU��`LA�!�c�x��O?P)����c쪱����.K5�)�,ze��4`�8�ш^�S{�ҭ~�1ƍ�\�8&��+{�y�IW����*OE�J��{��_M�c�	=7�D�m[�p�!�Ó~)I��{	] ���ɉc<J)�,�p��J뷲�����^u�o�_1(G��Φ;M� k�_8��sZ=�Zi���c�&in����t0�Ì���|��՛3����k��;���7z$��a:�R�|�H�+V/�5&M�����e�|��jV���������N;@q���n���AY�[2�ii�ly��I�,Hu�"�(��5w��¡�s������ȟ{e��j�Ś/Mv�|$'���G��yD_{?�>��g��0P�{F�<ܢcb�\���&�8_hĥ#����XV���[��\h��Sw:�h%`�4[VX����V����d������,t��a������b�����[�"�T�9�C��6�]�z<���}//?��+?�X%_��bU�`eW���Q�~�;�C˫Y�1�f���8�8�	 Ls���֓y��ʺx�H�����_�������U�����e�'�,�rWi�f8$B&!��:
��-
�Zڨ�&Q��L��yw��1'�}S����/�T#�Z����ڬɗ�Y��=\�����#	����x�k*���U%X.m,;l���{�Y�S*<<��F�;�*�l���#���xFd��eZWY���ޝ������\��Y�_u���	x6���&ޱ�'���uk?�PfE/V�(�r�*]�VҬ�������K �'NQ������vo��#`Ǭ����Iʬ,��%�CO3�ӴT�Q�a9:f��QY��ܘ�c;.�sҍ9[�Ue�N��:���AI�7W�u���0B���l��:2[��2��`�z�ڦ�2lU��f8�M���DQԆﯪ��,���jҽl���p�CB6���O 2[�k����O%�nX��a!��w?��L���[&�y�U1�Zʡ��u)���C,��oIǢ�b�s_Il�|-C������gk�t���ְmP�Çw$�@��W��:C:��X��BK�:�(��.h�E�[{��Wm��!�������%{w�M�0�C�ןJ����X���Ui���z�F� a��(no��^��@�3���A��&u�4C�מ���\ף'�!���Ռe]ϸ�U	��C��0�<]iK���3�tʄ���/a�8��)�N��МYg�`E�*u����Z�)�$�蓴��%8���8#���E��Ok�X��~����u&��y�R��λ���ᮙ��l��z�`�a*b@�#T������C�,u���G2[��~�/��{�N�Z�ThM��1U�yD��Q�D�Jj�
��Q�L���W���*ӥ�K)8�ܙhp����ܿ�#X�$�J���YI��oH�������dk)d�ty��<),`U�.x�-i�(\. v�2GeT��M�D$
X������H����P�zH�2^�$�c]���Yp��i��+PQI�a��hS�V{�->-�g N�4�����5y���%Yif�R�H�$
���=6J��bLi��~d^��?`M�n�[��N2�(�~G�o��`�T�@3���#	�R� ����$�����;D�I��˼-�0Mkg�^hXc�HҬN��-��5����g�j�����l3s��Q��.B��v)?זE�<�������E�	�`�v���0���'�RYĝ�	���^2cl�q,�?]���-&Y�Y7S���R1��Ԇ��S��:�6zu������K�">M�Gl��	A\����%�r�1K��ro��� OQGBW/l�ͦB6n�dJ��щ�#�i}���]1��������e\DjY�O)r)����7���4��iC"���9.c�gU��DeIiMh��k�5�t\�,0��&&��iͤ?�_�9gEì�{}���:�J����iӕ˳f    �g�L�q��맖|4 ��:J�� uZ	�!��WV�5|�W ���ny��2S�L��+";������I�x��r��"�b�R�^��6G������i��OV�L��eut"�_^�qw�={�����ԫ�J�CVt��m��I����IA�7�]*`̰ŁQ�A(��8��#�^m6��$�^=gj�&���\E�֥VI��>����#�+U��w�3ʩ2�� ��^w0�د�JƤK��,�U�L\�v���?�$R�R(���z��F3�3e����74*�w�۴���p����Du�f��wq�<+��u����M���JtP���P��C����_b�VS��M�Bӈf{0 W+R�C}���x�8�ϘΖij�G/���?� ���e�uC;�����U�J%������Py�Ɑ�׵e�'���	�����49u#'�z�Z�!8�O+�~�c'�)�.[>�-�ĩGe���+��b%B0j���H�dfpT&)d�~����ǌ}��F��"B��Q�$��'�˶���ʻ*͝�ժ��;�
�ǃ�<o��;W;l�o�G޸��0>"i�R�ܢ�������$.���oUdun7���C��֛*F����v���TC1�(��&�K��W3=����d�7$_�AY>��C$�uR��sH�����8������?ݪ���ON�+��~	2��dv7 VN�j���s�|��\�����)i@�곖yRS���B�ܻ�Y�=x2O�7&�>V�G���9hQ��?Y+3��\�7v(,`���r|���6��]<Cg+7Vw�X�����h��Z��Ur�������qs8?r�=��XB�� �G��=����{�Q���^r�G�q0G���M�ܓ������`��g��:�*��$���^<N��NMA��o�`�{�3lX��nd�*�������@�����K�;ܛ��������׆ڗR��g�u���;@�^�ms�j$3�׃��	��dJ�yIN�kO��ޏ�� y����#wF�^&8@��#2��8	�ڗ��U�*햇H���B�y�eg>I�m\�W�a��!����<��D�V/O-�*�b��~u��y�&��ީՅ�'����W������=t��Π�%u~7o��
�vg:xD5�/8�mS-V���f�+���[n�)^>N`:�!�7'*X+A��U�ހ{1������M�%E�f�cV%�&4i�&o�[nmXo,�T�5	��`����\🵦�)�����hbe���+�O"����J�r̫�<M��:촊>@cUMCH߆ֆ���Z��pF쾆��Ұ�ؒ�����.�!��n\~���%����%r݃��Xzܓ�s;xm���j�&�M�;(�,���c�S�.�^6 �Y!���Ü/ޝ��f���Gz��#e�N�c� Iw�_7����V"��xm��>��b�lu�n�v��겼.,�I�T�O�����w� ��vq�/��J@*W�Zǹ4z�y��4�¶UǬ8�p�LQ� &:$�ڎ����Q!vo.Y;�I�X�u���fi\�I�\�������Y��+��l c8{:�I�����X/2Ix�ܯ�\��$LUusk*��b�̱���-�N�6���E5T��un��Q��u����2I47��^�%ȅ����@:�LU�/��zU�
����7zWQ�{7"�?��.�����/�
g�qW ���.'�������8���o���Al/f�g���Ê��K[�.��a����K[F�Ӷ9�����t��O=V:>���!��	:�����{z��iV�Ty3��̨.��0�{4CD)q��ϑG^1������{}�:�P�A=��J)6g�:X�My����6��C�ҁ�������2��(�B��PE̐�����G�\�j����敜G`�����{���r��^�l���T��$����$@�qq,��C7I�C�.��E�$�0]��B�.���n�Oĵ� a��b�A�	�U6d�����Ϣ�&�g��dr�m��R�j�]~�\*}mc]��V�u���<��뮞m��p"tҮ\���B�qw�ys~:��Q�M��L�3N�^n��Z}J$�$��*֘U�G�̣w�i�s�p�<xT��3L�F��Y�s�%t	����\������[^�ua��eG1��c>��NiJK�E-Y7J��T��eh�t�����)_���2o�gdoiY�x̒�=� )��3�O:3�o]?A�C.�L%a�<jZ?�x��� T[]:�R��L��~eV�������焿����py�������|��f�w�ma�`y��U0��~k^�E�.OV�n��Zl~����������O�� @W^�k���P�7�d�䝮x�wN�d�b	�5�>���������q�,�^7���Wa��)9��<o���ȝ�ٲ4zvE�Rn�OV����;X=�k�􇃩a�A_�Ҷ����v	T-����3}�����M#=��%9��c��q%R�1 ��^�C����m�<m��ìʹJ=��,�~U ��'�ō+�^-p�ԝ07e!�ROr׭��9ձ�2�08v�3�d��8JPݨN(^ώnu�i_c~���2���P�VyG�!�^0���krc�ׂ�x���L6�0�����}��ST�¡T|O��>� �IS�������=�	ȱ5�:G(����3p=0ã}��K��l��#ݚf�{��l�ql�,l���9P+�U�=���FHN����m����j�*���g�)t�$�_u�;�yWL�:ے8��Aʼ�i�M~��і�J��:WP+6�2_���͡y�<�Yj��eV�uc���Y�%�yC(��ˈI(�<����4��*"�x�' \�S�g�3**��f����M�?O�5�\TKF3U�k���[� �֮ ��]�����J�_�n}��QcNH�_�^�6oU������q{L�pO-T���ܮp�bD��J�5�,�8��Y?���^����@y�/�Κ(���/؄pI�p:�:[=P��5m�.[��>O"��Q���D�;;@s5<Se`w��/[�� ������xqd$.�a�T��R�w�;
{5!�5�==��z�fUq��B��F��`��a��\��T��N�D���.ϖ���s�-�.2	'*��r��k�����'�4$�>H��t�&����bqh�8���g�����k�>8�#��Ϟ"s!��8�wݓ��*��+:�]��C�J)�4Ty�/�8ڝګ�Bg��<���!���l�9���e?�����Ҷ]�(�2�}@^D�,;7H��)�_hw�������Tb@�S�=��r�� ;�!v�M��;�����	�%�V=iB��X��RB�2��]�5�
� z9�=�/��h�E�U�m����V���8��~�fg[�qJF#i[O��*�w0B�'-z�ǃz-�8f�RE'��j�0R�ǳ~���d�q�4xq2�<���9�>���I�~s:o2��s�|��SXl^��Μ�I?f�˻Lz�DsGGu��+[���ɒ#����<|ư���]O��NY�����$�ڢX~��:Q�� {L���YS(w\zy�0���|��ȤP��(j�W�-}6O�����;|"��%I�7����gR�j[Q�����������NJ�{������xO�[�R6c�Cv���"����q$�uVψe�ǹ�G
�1]�?m�*m��F*5�ٜq<�B����`j:���|���W�~Hh4��N��[�ۘ�c\.;�d2�l�"�c�]z[9���6�\�6��z����P[�����#��\���+*��i��w��p�c~�de�Z˭�������p��|��TN��F����m.��g��%c��C�/�Υ�3c���mN����S�W)�U�5��q��A�	v��le����%�?�՝Fd����.��ny�.%����2��#�@�I=a����	��c��Shvw��b�W�lrv���.���h}E���s�j���?�U\d6x.��9    {��M�Q�-Z�|k�W�-藩��y���3��o�=6HQ6����sC�˟��Iֱ�h�2W��  �4���C/Zâ*��w�����H�;G��Z��"ɲd9�OB(����2��$�(k�'�<N�w��87�j�GL�Q��AD��������ny���8N���I�\��YM��6_8G�sL ��Ӗ�ꗏI�E�|PX祧�)�ܘ[)AT�*�gީ C 4�T�
��&��LH���}cCk�#���d��\^���q�K���tJ7s@���)��QK+1��x�7�r���$�S�
�!�Y���t�E�f�k�吒4�\���0�FT�����h�r�fR���.�/W���߻Irh.꬜�����;e��(h���1`�k�����]�cVą�KWF�4��lGt���W��)���R��ze�z������8:i�$��*�^������J�?q�}�;Gh���KeW�rVI�I��SG�1*������rE�U�EE���	}�����&ΙH�ȭ_d!�\9t���Չw�����#"��f�R��b�R�S!���z� x
�f*Rm����� ���z�}f��E�,��R̈́U�D�x�n�jJ�u���Wmw@��x�I��!��xj�;�Ç��Af��M��]su\Y����z+h���&����I!���L�(Cܰ�R؃��٩!����4��b�+��<�\��&�vz$lv��"�4f���Ԃ�¶���(�m��'�*��+�6�k����DyU��[�۳'ˋ�@��//�rB��KCZ�������"[kO�+0@�H����6�٨" �A��P�?�;5@�%�����<=7��#�k�z:xR�Y//w3�屽�.�	ģՇ��üH)�I�z�@RC��ନR�WY�r�e?��f�~�fN$�� �m�����{Yc���?�'r� �-8�B��_�4yZ��#O�� U�ם��@��<"�����E�h6�Щ��L�Yư�	�~�D�tM�t ���uY��+�[̺��QYoM�� ��'���<��GT�$/!���NZW��2���8VTYUF�l��0���;ԅC�>���w��_�2F�~lN�c�DUл����/�+�MY����Y��(���xѣك8�/`Q(�UU<�������]� ��� ���Ńd�0�5U��V�K��Y�2�\�����^�nB��R,5���i&���,Jc���.�ޡ1x&U����|�b�ĪZ�ٵE_?#��K�R�џ�ny�x������`T0p1ᤆ�$�P��fY^�UIZ�&E�D���5T�F���D�#�V�^��T+�n �ƺ������Օ���걼��z��DZ�ŖU�e!?��q�B��D(ɾ�bg�u��r���Mjo��H��[��(��X��R`��(���-��d�W�-��uRdV��.z���n;�ە��������IUk`��},���}�%>M�>c�Wi����"��K�����v?��}��BQ0�K�2�Y�hCހYkw��|D/}y�f!ET"�n�J4�(?/=|r�����:��KʆFr���=1�Pa)EK<R��������YU��`,{��u�~X�XK՜-�\�fϫ���Ŵ�o�'$�Ƽ�^	���t�Q�?-M��G-��/<��`ch ���~ǬMݓZ̪�b�VOI�z�v7�[
�B�<6g���ހ��@&���P��	��$��߀�	Ac��r�[�4I�v�4)�K]����^y#��P<D��Bgu������t���&m�j��4i�n˃%ū�*�GGo�W�Tݞ~�}a�,E���[����!���<{&!��O���iZ��3� �,4������:�N����¾vC^�J+�k��ruY�ÕF���;���
R⛺s�	�S�
�)�7_���ULK�C���ߩ��״���,���� ��_ ;+��'-����G�������ㇽX�w�R��G.�vl�Ȣ�*B����/x�$����կ�Ҭ�Ӷ�2��JC�G/�$<wM
g��n~'�@���s�c��h2:Y�����0�Q=.S�WS���'�A� �����,�dX^qi^��P ݲd���fx�A�^ژ+�Po�PSB�M���D�'>[���k��vy���+�2��Tn�T���A��CIq+��nH��B�~�Ӵ���3��2��Ҋ�8�z 9�ڗ��l�'��m���w���i�hw^j��@�,W�-I�����g��3����i���Is���zT�?�'۩��K�xCc� Ԁ0��Ab��'4�}a��*�g���p�����l1�X0��j�����?�b�YK�L�Be1ئ�	�}Ɛ��9�5����oz(8��!�[{/Yɿ�w^�=D$���]�4h�N�_��ϔ��~�5L_�� ����)Kf~H��}ЊS)�'����V��/I˴��7���*#M�J��j�s.3񸇧U�����E����	r��s��/N���j��Q��]�dfX%I�/����hpT�l��%6Iy�w��m��*+�dyUW�yZjU���'/C8��a�o���=+��WhҌ�~�a���O$���y�qG�7)j��Ð��pOt��)A�H.��M.�0r�/������vg��*�6gs7⒪E�����G��NV���i�@��͋pOrj�D��QՊ6T�V>n ��e��0o��y����'�lB�թY��%�$Y�"dZu�rΆ4��<u��I}���xU٘�Hjܼf�Ot�3A��Ջȧ����p%�K�.I�Uu��N�b;����rs(�n���X/��BgF�C�>$��r���u�?�M�UU�<�y��<�'�Y1
�8�lΡ
A�*t4f�;Y���Z��I!z�O�.?�h6����G3��R�J�腲F�v�,7�Z ��6���G�����A���{]��|�U�-}],�Z��rr�
�I�QG��s��lȡ;������`�7NۼL�fy��,��U&JM� #�<R{d�Ҷ<<���A���:NW����Bн6ȈZ���^�vi�-����F��>]�u�*�����,Ҝf~d��ޞd�,؀&�F~�q�R����N�ٸ�A
�!��􍋩���0q��8��6�Bm5A�7`���Уã?���;�_Ac�4�6?1�U0�$=üA0i{��3�]�k��ݕaK�n��Z>K��`�ۂ���U!����0��y�o�����I��$_1�+��;�u�����[i�r~������ΥC���;�.��|�Xa3��>�Х�b�~�ܴk��[���+�Wi2;�z��a���0�z��f<E��la� ����z�n����ċ㕻<�ut�����������y[kO����K�I�>',u���r���B��m����@�E<���`C36�� mH'Gi��Ld㳾y"�V.hW��5p��$�fV��[�XrL�aX^�u��vt���m�Q�,��]��h�yQ������P!�H��B�ԉ�6<�!����c��u�8�e��'-�w�XI��q��j/�!�?���Q�����/�ʺ�bU#"͐��Y��C�� ��^Q��0@��X������n����^�M�����zt�� V�4�:MK��
G���To��r�6�p��6��j`6D��������������(~�ܵ#�W|T��z�G%N�u� {��q���)MYM��6����C�M �S���dk'�|���E?������|����l0��H!5�����~�������S���Mg����ٍji�At����VWW�l�������&�^~��.e�'��4� ���$i�by����M�᫡�C�t���cUh�KZ0��Nh���iQc��͈��C+]��巺��Z��+G�Y��gK��С[Nn+=򓷲|0��FS��>ѥ�K����RK:)[ �Dο�A{������	[>��ǖ�ū/�\*_פ�c���&>.�����@�Ͻ���,�K�U����L��u�W��USd�#�@�Hǯ�E��������˼�t�K�    �;��Q[r#0�\F��	��0 �4�0�t�}�se=���(�q����j��2�4"*�L�!,&jF��q�7aQ�mJJ�M��V?�����.�KTE�r�U�_�[]��j?��0
ŷy�\V�)[����J���߲4O��nh��ELRZ������붻�G2��*�q={�HV��z܂�}��n�5����1���j�Ǫ���#��T7�Ix{c��3��+�I��R������T��,��f��քɝ^
؛�D�pgX\�K�j��\R��7��^`]�l/����/S_�u��W����L��(�	��Ը
�^���e��DԼ�W�vY7�K5rq��*+t����ӑE�4������Jɇ*��y���~s="�W�e�@�%�T3��C��%@ ��z�С`Ә���;i�t���;�qK_4M�G�����I�'�&̶�
��i�G�ym��3�͙\t��7�2P]ݜ�m�s�]��	�hv��������<�r� {�*��(@E��Ww��7��t��6�v��du-b�pC��[����8,>R�R���~��RCA�A���j�Z���)W?�vy�������ڛ����
��/�gQ�0�@I�&|8q)��E�[�ݩ�G鹫Ł�/Hr�e�4�;��P�p"ڼɌ@ӓWy����8����Ѥ���_��,+mD�%ѯ�����I4��<�w�Ϗ�p�������Z7�'�u�g�w�h�!}F@�B;�,�^?���r_���ᬃHO�#ŧ�Rp:��izN��]^��i�j��.z��s,�� B1���ͥ�����n0�b����m� TW�;5�1M׿X(ˡȖ�yQ�Z'hY}DZ�����7��'�F�����Rv Rn������������<2�p�(��J�%0pԙY	��M� ���-��3ꑍ������` �F�ɬ 'EB��,�TZ���%����h�9�EPQ/�T��p�+�8�Z\���&�euǻY�z΂��-����N��q��@�7ao�%�Ҝ����)ӹ�YɑP��#��%�V�^���I���GK�+�\{֬�~�P�5��I�w#����^<�O�Ǎi	`Y��������C��O��Y�-N�'�gq��1��')��@�;I�蛍k��4����n��+�ź�3��Zgݟ���op�2�g?��ӮdL����?�w&��,�5���A�v|ϔ�!Iy	��2n��t$G�%xz�Q��\J�����w����4pĄS���U~أXc�/����Xe5pH���~�,����� ��o��a�����Ƈ{]9t�`�Ӛ��>.����JR�G�r��������<��~��6t�W�@��_�5���奴$��dCr��� ��&�Đ�!~��4U?#TugvJ�����L&��{�dx�]��G��Եo�H'�-�߂x�x��*OVO�r͘䋙�vqV�$.w���\��$=&���N�b���H|���\�i��n� �����3�/☮�(̵y�e�/e]��9�Y��+-K��v��L�"���DgP8�H����
b���p������J�����)��Gg�MY��=�v)�e�~�pe���u]Z�]�<\y匸��-O��- ��7��Hu`L�Qq�ʩ��qZ?��uU�.	�8�Y��h)/# ����逘a�	���;�8��zH�a��Ԛp�Y���;	~G�w��w
g����0�B�M��v
k1oVB7n3P���_�j"��.�>�3��v�<����(�6��i��#�3v��Q*���w65�ɉ:jpP�c�.�7�ε[��1���ǳ�q�Խ�i���=Rz���Է�S��R�?����&P`��NQ��@��8���C�D!a���Au�b��"�u}ݤ��c��8)t��W�{�,�w���Li��"g2���r��I�O����(�q��:z3᨞��4Z�Ki�o{��q<��우Ь�]�����ݍ�1/��`#B�F~�o�q����ms<8�\63w��Ws�X�;�{?�PF�VA����!1�>g��iU�*������o�y�:>÷!���ں�����IA|�Z�nl�E�wlFP�C��tN���m�&��M{��l��Y���{&�\��ԋ��ě�	�k���U_�*Y��Ri�3��q���#�gZ[c�3����dU��<�F���Djh2��>�b��z�K?��,'v�̈́j*V@܄��>AuՄ����L7�`lS������w�n��D|�b,Zī�FrCY������ify�H��,B�������){b�¦��7߻�_P@ͮ*&��u$��	ukn�� }��4�U]���!����}c��i���4> N�QhR�qW};����X�0��W�`#m�^UWf!Պð���Õ�{|5ُ����d��+(j�IUE|���fFcأ���L�6��B���n�Q!l�1ǥ�pSa�k�*� #�I��SP$��q7.�~��[T�����c>�酔�*��uw�|����֧����{P!/��08�r���ϛz�`e�ϒHrxQ���~���Z�4�.g��r?P�X�b�T��|���{�˧}����؈���r`��r3tQ�?���+2aw�o-���G�|���2��{pO8�%$��o�aS��V(SY���z�u<V���,M3{.�蓟{A��+�1�ʥ'S����s�:�r�n�E���y�D?*�dq��k��y�ٵͣ��In��-��'_�#tٻ���L�x�]D)[��C�m�//�JlE\�a��}���}�*ZGbp���e��m��(�Rg*��!x���W_fI��Ϙ��Ub&�UQF��A�Jy{������3s>BQ�=��J!"7<����,i�^^FYR����ýT������n3K7a���4�o} 0�D��ի����tU�<\U�w�E�H��C�Ծd�Y�կɕ�ʳ�O��;PiU���ʴ(MŪ��?���PlS�$<v�l#q��\��U��{A���hH hX�H�X6�4�M�HU�/�~J���S}0��<��'����MeC��R�T�<�3�PYbe3�S��`�������4'f��YN��H���;I;�ч��>C�J��"�̒�p.�=�f�$�� ��x�^�v�`*�]��z���,ʢ\�m*���m*��T)���{,8j��� �r�w��x����eU�/-Wq���L�O�p��z���N
���6r���%0��O�����4y�.?9U�j},]�����N18㩚� 
$"��^�?˒��W跍6Vf���~�N�-R�B<]|���w���i�g_	B�<���h��Q2ـ��e�����ny_T��N����?�'ՇAa6��,=��r$���lG�#�}���/H��f�-IQC�(e�,	����(ƐS�_m���<X��*O���:�"���m{X�����@��ᬿ����/���$�����g�|�oaM�[���Kp�\�i�;sOxc=�dV��eI���tj]�~�4�}��"�g}K؊H B�T��7�|��>�pCW�:����_�ꇢ�(�衊6�S3=��I2��F�;�E�ǔ4��Uh�C{(���%����|�]��wu">3�W	��q���ȩG��U?����E�<��� ��ƴHt�k�����d��k�򸂙~�H��c��Pk��Ճ/�B��4�դ�s�G[b�i�
���}@�i�rχ_h=�=���`HG�S�zBc^f�ēT����m6z�]�M���E���������Uv͞*/
�|6��ee���[�664G�9��,A!����S��bW���Ź�ͮ���%7�ʮ��Wq[������W�$��J�3�ت�v�w�W1�ܼ�UW��v�b�C�6�$��m� �b|6��"�U�d��W�j��4��E���r�í�E@�2���g���\@דg�U:�B�?�b!��b���.r�Wq�O���B6+&�~Е��ʑ{�� ��t�9{�	[|,    ����Ӻ���,g�1�J���3�Щ��ɣO��b5�ȐATЩ�p��������c
�g^m˧�"s]����.�'���[(�р$I)p#Q��^�<�c� F���3rrܰdz�˳�R�)�I�c� ��D�6D��]��{��R�(���(I	AĲX�q}n��n�鱬l��'�r����}��w�y�����3�Wu4��*����_���P��"�l���D�e����m���Aq=T	Q�ֿ`�M�M�(���
i�k`��~�^I�Ӈ�rM
S�}�<���1��ieݷI?���A��n�ou�odr=ͦT��N`̪]�2�Mؽ��z�ה��]��l��~C�[�&�
�&J�Vu�F�5��>��B��q���6^'���P���$֍�MǆJ���Cͫ�}��=���H-�BXl�_ՏF�^��P������p/q�9��ߛ��6�d��9|z�*R0Щ\c�X��D��&L�,A���u�o̰������55]w����Qȹ*���[�O̊���_=��	9�A�/al~�/���Q�fً����}��B!ov�����!�&_��D��}�d�;�6�m:�Q���N�l}a?o�����E�"�����q���D�儁���Ν�ӣ�JG�l�w��+��U�����g`�1G��~V�"Cc����|�t/mǟ���˦����ZquWi5 E7׏�x]�̀R_�W9�g�A}m�q-jՆ$4cm����P�2���[?\��y2a�zm���q_����H�$�y$�-t��/�Z�sa�|'�hh�~Z��y��T
�^l�rFy;�]=��0inU	Ţk�+aݞ^�� '���|��r�+e�/O�we;	�TU���VF?���A����BG'x �{qM����\�i3��s��X�����D������*���ŷk���F۲���"�캰[�Օ_j�"\�E�W�7ӫAk�L���Dp���.��O���x�e4��^����R���S4� 89__A
�><^��^j.�d�*eYˁ���r�-sTAp*����2���`8X��P���V�l�B�]����%����� sdF��л���C��Y�P�x5��{҇�i7�%q^�ݗ[�"��P�ydbp�*�.��o��� ��6���<a 	IH�t��oD
��WY}�
Q�#�t�t�D�ۮ���tw5-�J;j}t{�������g��EA1�ySN�vA)�R���Gr�W*���$�{	�@�c��Dt��_���œq��]'V|�l�`5��LC��`j��Շ�//P�=�]��k)s3��i�  �? ��>��V�s��E��mi��HS���8�މS��)��:c/.Gc��X2�y�� AFQ0��Q�p�r⌏n�R�E\5�y�u	[�6F"0NS�u��w��=�,.j3��g4� ��Y��ۡk���4����*M
��P�Mw��[�;1����
��j���e�ӑ .>��Ahѯ�����9'T��g�����)u��C�WP�@��l�j؉��~��"��b����б�����������n�($mt�A(9�b�S�"M�!�~'�ªऍ���^�W!�����K\@c���1��Vʉ{űfƻ�B\��lݫ}| �Wo+R3}=9�yl�J�S}=��w|�|z���p���9l��W-�G�{ZչOf���":Ӽ!v.S��6�B�HU��DzI����?�Q^��Sэ_駥P(�E]O"�'`�Z�������{kVO�)��K�rzlmjB�lG��1kdbp1%!�\ov�+T�h<�i9Q���o��E?�/-��XɁI�Z0��\���I����g�T|��u%~T��{�0�"�l��TW�2��&i��ӧg�	�~���?�h*�I�[��o�L���=�7\�񷨈w�z�H��d�"�E^�i�Ok�Z�5�T���T꓋���~��w�_�;5�Q��EZY��ɮ�$B��z�"�����"��7�4����ff�<
*"{�=���/$)��
M�"(ʍ3ƃX55��BCSc��!��b����dh'G�JL�KÖ�\���X%w*���m8\�l~�q�����a�+_�;R�&-�'��e�T�������ID����Q��� �k@����O����J��ް�(����_��ݢLZ�H�0~�����e�k���r��+Dk���뿅�)�|zyb�,��1��\6/���tU��#�
7�lLj��R���MPgE#��U�_se�$��V�����و���B�9���Q�<����r���.^Ј��ٝE�V������R�M]��z.؃#����7�&Vw̸֢�vw@��q��q4���lQU�i��j6M�B�I(��rG4�`���*-��}{�<�5�(��N/�u����M��
���b�����V�(YTm���[��X�HG�����x�o��$tS�ܓ 4T_���{��&1K�_�,)���>rx��Fb����J�����0A�RW�B��)(G�B���x��O'[��P������c��%aA�!����g�����e��v6.���ɔY%]~
��+����X�z|�$��>Q�#��C[Z����Q����W�UX���6��$.��,�w��o�֣3�Tjg@LO�Ͽ������:�ޞdn���D�6�d�"�"�y)a�I6����S�%
N���`ѮBt��];�a2��E�d��aQj��ޑB�,�(�y�R'��U�pc���� X"������(�-M�\TCmj�O"!�V�̽2���D�f(�ឨ/�#�Kqܣ�J��W3��i7={��5�!j�8�u��.�X��<���Ojkhw�w�X_Ϻ�	��CC��~��c�Ѯމ��{k�~zMR�B��Z����K�#�y��+Va��ɱ���A�����zٓ߶�〶�)��e�~�f![?i�h�~H�7s?��w�,� �q�� �jY�w��g��ڍ�v�	e����D.š?=��x"y2˨�OP�r��F��4�йyl�8{�V�����B�^[k��q�^��ܚg�,���^E�KMѓ���t�8eA��l#��Jq����G�g�����ג+EKeI��<��J��'FC8z��$/����^��R�,�~�H���o����j����q���%���-�;����0w�'3�\���K}K�胗h"�{4 ބ4�">"8����6�~z���i�0���~��c�=b_�EUr���s߻���8�T�������<����u�,�Ah�����WH�ңX�����s���՛�>�g����V�]W�SX2���4��>�+W{H�7��AToUt6���Y�W$�/��~��\5�XK@����ݻ��^K:��^�_	2-�#T�A�z~Cx$�E�8){�D�����o�-��<����=�T7_z��Y��>��i=y��uQ�����"����F�'%),��=��T��Bl�&�'��e~H�Y}��c�ьo�hTR�!`�=`۟����m��Џ������F8--tɂ��_uy���'~EZ�
��L��4-d�C�Q�_��<-G�R����u�B|T���(:kM����E����F����{��Ի74������z�2_�t]4��^��W����>��s��nȻ8��2Nc�eG�oO�ot��"��D�P� ,S�t[���WX/��i��C�V�%y}�&�yO�~V7WH��H+�Ǹ;>
H����UPw�>D���S]�;D}�Eu�������O8�6O#ص0���PT���ళ��7$�����<���n��9�M�L	Vy���,�(	_��aHV���Ty�=3��t/��k�M��⩌T���t�0O����5��$W�8q)w8��G���آ�QS����W�z)-y,`�r.Ɖ��'&��#D�@S�W���Ȯ������Ȧ��&5�η�"�م2�&
H��b�Û~�im�*!��SZ����1K*,H��A^n:�    ,Ϧ�fQ��A��0�QhM�~F���6����;�7)z�m���.�� P!�'��Ϩw��&)O�b���O�GA����]xw�0�{h� t3�bŧ�g���gW�y��F����NL���y�ӤKP��������Ԏ�|��ґrD@��ʝpc���_k�~,��y�z�iWU�M�sLiJ�奬޵�D��}�Ӗ��^���CPP�����q�T�B�e ���ʸo�0=��$U95�å��u$!�6}�=D�7��.����#\���1e�gU9}�f�83��M�Q�h@+|���o�Y�8��A�Pe���t���1��u�tj���#��������kyk��H�r<��/�7��l꯵{�����_�d�m3��v�,�%E}
��^@F�ol����+�9�Af��}|����s�˴����y��*�H"��quǥ�T���"@����V��.z���:��sX�����7�6W2(%�H������F+|�u5}���"�g�����N���5Rz����ng܏>�����f��;��B�Ǒtxb��y8�?<r��M�}s�j9tW��(� ��V�Q ����$7u��Ą�LK�S����t8�b��0��M�jT
���)�7h��(����rN^`T�_�;Q�S�oF^i�)E����%e�L?��N=�YD�;kJ.^�+���&ﶠ�oR��wB��7,#ٰ����X~*�y�jP���N<��FȱP⫵�'���t��t���k�a����}G߁Ǳi��rPr�41�����8vb���P�ڝ�AE~)��ܭe閭9Ak��Qy�^�8��	'-�U�!�A� (:dn���l�b��.>+�o�����Rk��8r���\�a�:�~~m�� >�C�C#O7�h�D����CJ�q��;n`�:�V�cAS��c`2��l���2O3Y�� R�g2s+�����\o�k�A��|`��2�f����z-�"_�VN�ۺ���BY\Z��(��G
�S:��_�%�q��~ЏWt9�P"ګ��E��"U�Ө�v}��Dկ����R�l~��q��J����^y/�%��2��b��W]L���q`P�Q���
c��M���-�V��PsAlַ��X4�d�A֐�hH��S���<���	���e�GIQ��C�5K����] +�7�����B�J.T������gU���VR~H�ѭ.q�WOe-�z����1�\�Ӣ�DF�G��]1�����Fn�X��n��T�QgO��E?�M�+�Tz[m�0�0�'W�@��HU#������	���'�*���&%� �(������z￲l�z���YV*����O#Nu�9Us����_H�˫+�����ե_s��lN�D?U~�����l�\=�����rz\Ma3���I�7��x߸+݈�bCP�t���{@�AY`z�~�u�23�U΁˧d���vI���R�g���x���_���dbP1R����� �·��� A�y �z^�9�*���ޯ'4D �Ԓ�Ik7F��+�.�����+{pP��1׋Ի�64�
�G�����V�T]^��O�+f�X��2��x��+�Q�p��i��[��4�,贈(��y�4yӼa�U��hy\f�w�G/�LѺђ$��O2�:��ղ�����_�QF�!ݕ�� J|�lzkVeU�iD���e5��u]f�����L� �O��Ņl����p:��kB4�*}�}�Ls\��bG:�ԍ�jL(�W �2?�(�]��~�Ia�B�����@�Q�3Pi�72�t�{!C���H(�<����bDPj����� hג�P�w�� ��78��ć���A�����,����[���Z��Ϣu#LE5�3b��8L�E럛,e�]��a��]�lmڿ��5ij��-�۶b\��}�����T|D��m>ɬS-���ū�#���e���*��bUZ+�(�Z[�����O/����o�$�\�h�9�~�|!x�Y�Wz����{���5�X<=�B��V��ϿS��}����������#br,�-&�Z���a��Lʢ��/�v�P�q�+
9hv�j��+]�� �wpjO'�!��C�*�Q��|%#�!!�S��;�ؙ~]���*�|>�k#�v�f���%���r�Y-�_	օ��0I�qV�+o��O����O�h7R��,�n�;{�=�_�(�*C�벵B����6�����{k$�6��	LI�ŝ"D�C��;X=�(	�����q�	j"ނ���§�|t�-�,/�7P�b���E�l�	ȶx����������e�YmOe��P�[9@�\%ȭ NJ%wC!��G^�m�	ʙ?B��0� +1�' ]�����\�#�L����tC���y�/�3�>��0�����KIaJ����U�x7��aH�u;1�mu�ߛ�`.�|�@�_��ߘ��9$����}�dtKF�K�xwc�Wr�]7�\��^yR�`w�D��	������I 5�(��
����.�N �="c1�8��E�mR��Ƭ��&}����k*���*�ޡo۫�3�p��,���w	S��c/Ūh�����ek�a�&��K��(��ʢ��a�+�w���,_屷u��+(U�u#�B��Ъ�l#�� �XN�3a��8�u;�(&U�k�Y�ч��6UXZ���d�?�����v��Ӊ����\��ZiU�ؔm�<��y��<�����$��֧0��˻r��}Ԙ\P�_�#dt.��Q���"�/>~��?B;4y9=�y��Z#��;�V�:�:�G�׏��d���BU�Z�WU�I�ߞh/.�[��u������G�!�`0K����Mk�>��d���iM%���D? �%EĞ�y�H@�W��
a��kU��B���� R�W�-������"KTԫ������\�E�t<�]��*�U,p�Y��� q�D4$�M�'�<�K��EEZ���^�}\�Ir��a���p�C/�x�*�Gd	[6���3(>���Ӗ���N��&�� K��U�����p�����UxcH��w�a�����3t�� )��7͚`�t�����]��v���:�1�TN���:��v3��+U�%`���@��
!���]t�'`[�����,��K�+��l��m��n��05��x�(1Wh�<����n����-�r�>����������f�6�_s}�K:��	�SN�t)��D��Z�ㆬ>]7y�g!6R�zn��o���1���7�q��C�~�*.�6�^�ie
��,��ݣ͢ț��HY�����DIP�/�)��z� �{���(u�#��B?���>#o�
�0M��X�06"uR�UYC@��������.~�m�;I��"�8Da°J$2�����3��0!�_u;{��؜PO�v�F*����7p-�J�#��怎Ą PE��vl�k�6������w55��U\��*E[}���g�A�K@C���R�{Mn�УQ$"���B������G�L�*����/�w���pA������Z�Z� Og�Rd�
	3�s��]��i+�@E��񙗐�.ob�S���]ÿ�Ɣ@��=���g�<�?�.��ȭuG��ܶ�r?5�P{��:ӏ�����H��"��u_d�\��9-j��z����Yݞ�@������q=�߱o1?����$~���4�Q��n4L�]��+Zn�4��C$��m3��.�4U²)�ϣ<�}��`��%H(���!��IU��툵��[�@Ds���l)M?=	TIU�����{��B�H�M��S�s�
C�����zl�z�U:��]ף1:sC=.��p3�?����:ls�^����8��6[��< �պ��zF	�A���##�����=��^1�;*DꙄ��x<ܰ��n�j���(j+��ɵ�P�n��zg�7�BC�YtE�\� ����=��$#)��$�    �gk�Rn%�:�D0d�+�ݜ�2�'$��8��ꥹ�Ժ�yz�Z�e�y�1A��
?ЮW�؀�PQQ���/K3īZ
�bӿaRd�T�,��T�J��"�p9�����q�w��P�^@^�L����i{�z�47FJ��0f�nHUV��}.�E�����!Z�(QC��$hew9�Έ<�Bµ�+�z]�*k��p+[$��n�胀�u-"��hw�Șa���#ѫϽ��T�R6�Ģ����(V����2�l�z;W�wf�T����ܦ��t��CP+����d�y����E*&^����z�iEw�&���Ty]�o�θ̟�s���7��A�w�g�z�n�c����� �JU�!�K������Y�h[�M��FB����VEVw�Lγ�/vw�%IB�y�h(�:���s�X�P��ܙ�v���U�Ŵ���JF73[D�P����@�7? ~3;�F�7hT�`�'(A�{hō�>�ջzU( �]s	k�'jDb��w��d��mi[�m�?�+�������v�5�RHf$6E�=6���꩖U٦��~�Ӹ0�bg];	d����q���{���l��:'��� �EԨ�����(������H���N9)�1z����I�Y�pM kө-���������F]M�[3�9#����=�j�����6O�>�A�7P���h�[K� ������x��a����c�{�����P(bˍ�W.f0=��s}�{����F��r'�ǘ�$ �����;K7� ��Z��vU٪�&�(aqM�Ny���⥊�(x
��.)�-����q�k&�S
^�g��Pe��|V��Y�Rq�N-��&"���w��� :�ȍ@]��Ԓ��A*l��rv0@r|�+k��ĨE,��ݒ�1��aҺ�۩�Mr�����?")��7�Aʠ��ټ*޳�yI'!!���.�'���ʸ$�/mu��_I�וMʲ2�"^Y<4m<=^6�S�wi�O2W�/�矊k���`��8z�u.�1��x����-������c���!�%�e����X���/ST�aE]f����H�r�X�,��"�K�hH��_���n��a�6%����}�ѽ���p�?`U��	��O�A��r��BZ�L�j�q�AX�F�/��"���]4<�oFӦ]R�r��$n�N��ʒurA�'�2P��^� t����<�X���\��A'\��pZ�>l�
����Q��KQ׆�C9KPK;��A-���	��f/��$��83	�*��U�'�}�U��EJ����X�6��:g��y3T��C2����~�"
]�NƏ\��ȿ������!:�͉�ʥ�>��<Ǭ����3w�b1��aR{+U%�j��7"�h�2^�F��p)��VDw�_HxvW^�4,%5�J{�sFsU�bU6��y��@���g��G@�`:TgUD:�9��^z��ѓ�d^��=V�j�=.���u���\s�.�)�9�+F��)�&��ܜ����W��蟇Oۿ��}	Z��í�(e.d�����A���㓪:�������XO��[0X�F��X���������3�ߪH�����Y��N �D|Ťjx�;��AZ�D��V�Pe�5�
]�Ef��ض&�C�7V���zz�L��L!�U=Qg�zU&�伿���)�#�jaP�A5�>�S�ҍy�k�&O��P�$M꺝#�e��rr(M��R?&I���7�C�?�z��Z ;Pv	�R�~�f�>��B5c�]��O�ڼ�Izc0�D�Sj���At�$�����q�7����,1�D�����m:��$Y�e��⩲&��1�؜�%T��ށO�j$�Z��j �}�� ��u���Z�X��v����ߍZ]7oH��r'���$�~�n�0��l���j�у{T(�ݹ��p��b�-�~�w�L�'fj]�>��9XE$Pډb�-�8OU�(�K�=���$��c�$m��	FG2�+���{`�~Ӂ2 [ga��gD�Bvq^�H뻴(g����J39HIb�� U�z�)A.�<�8E�'y�QWl���rӴ����s�^��u}W�Y�Y�a�<���Jb�u&��;�&dX�Q�C��q���}�7^��$�b�J�4�����m�zr��ĥ(NH�����������>���y�e�U��Y���t(����L+�x���
�5�N��æ"�:�kO۽�i���C�r0 b	.�K	����Y�b�4}^N�-sˡf�D��SG*�Q팜�9M�a��a�*qǅ�"Qi�T���:6�P��eY���-M#�t��]�H��Y	@����^N���VW���o�����*�K��i�4F�{ɍ&mmvb�)l�PE�3�g�Ŗ6�*�v��|��VI�i��/�Q)A��V4��l�;6_UަE�N?2y^p�B��E�7 9�6Rl�OJ�������-/��U�܋���A�v�/66�u1�Qj+3�ӻ�����H�2���/���i���}��.�pƱ8y����Tt��b�A����/`i��Ju�����*�^`IY�0*
l����������5�21pW�`j7m�E�Ů\�%�meߥ�J�g��H���lj�O�����9ӽ�E��~	�
z��D���O~؂{����3ֳ�ɓ�!3���Uj#1K�(I�PjE���+�_�aq�]j8ߜ����c�ڂ�/��?��o�+�Q�P�� 	�j��_{��Au|< ��갻?T�����Q����a@v�lV4H����sn�19nw����E� �2F�0�X�/���O��]�}��/�x��Z�	�FF�����{a�i�b�+�T���
�u��P��k�Z�=���AD7�� ��B��/�2��<��Ð��}�-����n��̑��DS��u}��H��ɽ�:}s��
�f���M\�Y��t��qb�$q%AK#�SoQ����u�Q���yL�0���x7�/.V��O���C����ʫT�,z�B�c�#z=c��O Ə�t��]�҅�_ʡ觓A\�L�)>ˣw�n��V�ܟO���5w�>��V�����m�t^ߘd/��l��7o���b=X��C2Kb�酮I�T���"�O�:�ϡ������ͅ�{�l���N76D�m��Ǻ�������Z�8)�2�um�.�2z؋0�l���r���Y䚂L�����>��n��Kv�0��}ÓjlZ	)�"���p�"���ؤC���nd��s�^y�^X\���W[h�t�,��%��c�e�b�6������� $-��K  d����:$��G x[�6�s�u�N澾|�ʖ�R�.�;�j1 p���,�L���l�g	���F7�S�Ss�2�������2����@�0��,[j3g���N��iLc�籰�D��C�	�'�\�Q݉�=����G�.'�~��Z�a��� ��s2���]x[����I[�}:=�Y)t��VN������
�^�2�;(�7_�_3e\�s�%M�!����JT�4O���/b��9uS����@Q�V`m|m{5݃9�8��.օ�C�ճ��c3=PI�)}:Ϣ�����PG�됎�z���Eu1��l7*ml���#�����<z��m���;3.t��s-�\(����G��� i�"�n��!3�����خ�L#nh?�o�F{��E��-�k#p�D�VUk�e�Sȥ�s77��<�d��n��>�E�����_, �u� <z�Z�|�!' ��O~+>v$�U
�(�X�߃ӹ��4����Ҁ�`��D�����;��au�GG���`��o�W"a����N$�8n�	�A���
�);=�ݹ^��]m�Y�k��ox�83������j�+��W�'.}�w�(V�V�YSœ�h.�Q-�����Õe;�-䂈kJ��5����"��j�I�͓$}C^K�����D�RM�x�ǳ���{y	/Cy%d��+�Ϸ\2|u�K�+�K��H�0���D��G�S�a�"��ކbܢp$��"X�y�oĐ�
��Ϟ$�M���z�ŔȐ�ĸ�U=�    IO�)r읺���ހ��΄�8*��/�2h{d�.i"�����bP�r}<�s��m+��;�$2�0_�[�h��S�)����(�ߘ�����މ�j^�Vc�*o���;K�e���+��/���Gs�^�9�X̍�C�neq����vyo몜�*IX�qt/������O�}>��Ryt��W#�j��r�z��-������y�-I�Dy�����e�u�AȠЪ~���
W�������*iw�cX�j�e��r5����!1��41f�w��hڨGDq��6��Q�⽸��j#�77 �`��t}�� :Bp�=6�q�`Qt���?�b�?)������4�O��s=nZ0i� ���.�ڇ�T'3O�}�e!JQ�<�~�ݛ'�G���4Dw�cv~�GM:������S4+ۯx]��K�_��A�g�t�}�tR[����'�"M����"�xUG@y�H��3�7�
���Ld�;ߋ��r�!f�Q�f��(��షȣϚ���6
��b�yS�-evc��}��r��ݨg�xU:�������������&��7Z���؅Rxm�3r�뛅E�-�"\�;������p\��Y����,EI��a�e��c�Z���ҏ�@�(��E \$�����Uga���j6%[u�m��%e��D�X�VQ۽q��s���lo���wD�mt��@�b1FV�~�|�p�t��0
�b���0j|��땦~/=�e�r�D��>�B�F��HY�qk�1M]Lﾪ����6��<����w���/�N�n����v�^�rΗ�Lo3���L^
���#m9t뎏�(%�+ge�'���#k9��nW3ِ���Q�T�e�&q)|���<N���t�R�>�<y 0N��d(��b9�q��L�1�� �c)�r�V�]��r�l'��Ԕq&��2��{diF��DjZ���A���(� �/Y�>������v�б�ؑ+�^	������,Ȭ��B���D@��'�������B 8�?��(��CtVҢm��ҐM%�.�ߑƉ�s���x]���H��T�G'����~Rٶ�)��J[v3.�s��n�V;����+ M�e�dJ(�K���H�E/�;��5[�M�8��7Qkӂ�J	�# �2�����ϣ2፥���^	+Z�t��x��.�M��R�&J�z�xy�ў���4�x��������U��;���:����0K{Z׶맿��7"8S���	���%"�!�H:.EOޑ;(زLq��(_��\�v��e�N��X��*�ve��|��F ��Q]���+�ܣ�:e��ޏ��hɡ����-R.�O��U;�Uu���5r� ���U���A��C�n��aN��
�H��lju�}���"��3;|.��)��j5Mb'w.�UYh MDI���,�DMf4��C\�o+�h��T�*�V��<&���h������;ۥ�2g��'�m\ۼ��$I�>6���$���z|��=�GTc~[F8yaF 1߸�:6/ܜ6PJ/�b�#s!�m[�M��(�>+׽ѵI��e�KJ�gj��jj���w�c��C̽Y
h �2�#Z=IѶu�v�seb�\Z!�׷7��J���hFw}�A��X����?��A���t�>��V���6]\w�#�4������U�Գ|� �~GF
0s$���EדWu�>���z��]�T�<*�+��{C�̊�K�E<J�9���|�����?�X�)������v1Jןߺ����[jL& �*�G�en�� �.�j��� n
I��<x �܅���g�Z+��5[�,��㦶��fib��Bt �<)!���&�@��*:���OD;�	S|
=�|(\��;��M�0�?x�6���G�T:��bl���&�]h�L��2�V�^��bW��O1d��0Y� ��Ԫ
0��[���ࢶ��lx����a���`&��U���l��� ��:�������'�F�b^E��ࢶ�DGWV�,�l;���M�Z�<�W�L� �sli�1�o�=�	���UŒ�Ч�|������������H�>��6���~O2���Ծ�sPϩwe
�w.���#Mц�/�3NL�����Z��Z��j�l>�������t@~;�c�K�(�rqVdӸ����{�?�ݐaX�P! ��n���(��{{�x�ʘj��W-���;��5o8{�M6U��{�0W�n7�$�s~�nV��h���b��jm.�!Wa�q>��-@��j��9B�SQ�a6�g�i�I�(C�0O����)?�.�4�h|ӧӅ�.V2����qY��􇢨��2�׭���a3B�^��hPB����c��c������lВߕ�)�V���{ǁCjz��#l1����'w�O}76�gם��b�
ﶽK��`�26m���GW3��6C���u�g6~Ch��TbJ�E?�MTo�b� B'\����{%��,t���t��t�$�:i���p���x�<B�JR������@D��r~ft;����Z�g����-֟͆Ы���f�`�*�ʰ�0EĂ�b�x�>x	 =����_�{��p�6���7�Ѕ�Q9f1=��v uZ�U6��5qe�sa��'_�z�,��w��c�ٿ��5����g��~��~���v�U���
Q&`����R*�!7j���o�՛"��a�Ѣ�9��CA��5cb1�j=���!+=�����ئ���lgbuh��2{?��(F:\�`Wz9�'`���"�X��Ty3��Ǳm�"��B8�Ƣ��PE4؝���dU7;�/]��%1 ����86��ʆ7��-r���X�t�W
�kCA��Ǟ�9�A�H=H%�I^��_��$(���>�D�('�V�tcW?��]Ð�S�\RΓ���$���~�}s֢�s~|�˛-����Q_���[O0i&n�S�ě�}�����o6�O]��t���)T�ߦxSib�r����շW*M�
��K����l����l2A��KR���o[�
��S���S��8/�B��D���8?�yxp��1��!�@��8
gh#q��A��3�~�����5�RI;�)��2�N�3cL�=�'��'�G�7ON�L�{e)5�0�������ځ��Fߟ�߮Z�>4�q�Ͽo����v�����'��r tP���]nC6[�_�6�<er��K�sm��I���|���83z[D}K�W��[�lz�ui�f��[q�J7ge Q���c�)��\��I�R%�Gp���w�U!���	�����]$#>ͦNQWq���S\���[�j��D���bJkU�Xw���m~T�a��R�c�tX�Rs�����b�S��L�l����!H<��ӻWu������"�2@�ot"��8��P9J��w���AN���r���læ

ӏi�gEJ8�5ѧ��t��������'�u�אƢv�.6����k-Lj�#�]lLnRi-��R����6��U�lZn��(�X��(��o��}�b�bfֿk06���<S?����>� N�� ���ޡMP��c}v�Y���m�W۸����]`�܊"xSg������^a"f���P�H#����?���ѕ������B�g}ED�
�/�ة?�L�:x�Y�ն�O�o�X#*�I������%H��Q��5��[��hG�5MM;�d�h��vm�N�L�2+��8΢�7Z���S�*+��X���q",��\ $ˀ<�c�̷Ҫ�l�F�8/��(��a���P��*1T����ր���	� �bۙ�4K���|z�QU�F�q}��������^��^�L�����T֎ʉ�+���Vv��,�W����*.U�>���A�Ҕ��Te�Y���O�I��_8���������(wy�z�Ǌ"� ��X�63.M;O���m1�U�E�H����G]��U��j��!�X5u�JN��B���*.�zRO�#�$[�@�Ջ��m����'��q�F�q����U��FP�=N؁'��)�S2?#    1�u�D	��3w9a��n4�f�����}��j��v����E>L/�M�V<�c}��rm�Y=�E�M�GyD1�:�}=n}�3��(�U���SZ�
w.E�����L��-[�$�#��*���S(qآZ��$mݐq�*��A��[�]����)h���� 0����~�E{������'*�3읞��VZ��EX91"��c@,:t��-8	g����2`�p���e�! �_b�����w=���91-z�Uy�տG��y���]ф0�чM̷n����WE������j�y�έN�b(��T]�W����i^IfL������l���b�����e�O,��b���O�n�����#���{J�4z�Á�������4\�w����k�^O��;��o[`�xk5�C,#B�F��!A�N�]�Q$��:�$#!�䝭UIvt��Z�\���"�~�7Ƣ?m� �ᇈ*B��`��=��<����R׮��i�xz<mR��G����/�P���m���@1o���yD'�X�W�2,�O*U��\|`��,U�׳���U3��0&Y�z,�(p��	u�(ߋ���6r�Ǡ0X9�Xl�6_|꼙�������F$)��G:c���ѽ�t!�F{F6���z��Bt�o�iW�K�z**z��v�86 /^�����i~�Qw��d";�ǻ�QT2}EC!\B}^%�� �t_��(�����8���=����x��!��s�N��t����L�����	N�[x'�+�NA��n�ee�ip�J)��w�(4j3�!�H�WFy���l����E?� �I\�z��蓐Cx�L�2tT�~:+p�¦����eQT�s�+M�厉>���b��ߢ�ħ ���3�͏۳�|Ѱ!_*C��n��doȐ�ͲL�:y�<?q	��q�p���~6I�X;=YVƂ�J�8���m� �?�� ;$l�)�4^:v���"�¨P�����J�
���;M��V���$��&�?\hMe槮eO�� [�Ww݉�
�wb�KF�8�|�_v>J�l�<�&M����~�Y�>�I�F��6_0�s=.u�d°y�r�N�������7�PB!�-�z�ͩ�I�4�̆r!3.f��Y�A��D,���l�Go�Ke��U�|ރ
AZ��4ۢ���B;�N.�[)+�<�Y9�G5�٪D�Vy1a����k�����ըS/�-[��E��}QO&���}&T�BD�_�3�$��P'�/~~"&�
�h�l.`UX-(���d��W'����'D5��RY?9�e��R�c)ae��6?)/�xO��R�+�-
�A0G�Y����+|�/&�廨�>O�V�or�<�.Tpz��$��1H��m>+�[�gO���$&0��nsp��gR�z&�t���YU�7]O���p�����N)AS���4�@���>�ջ�5E�U�G�.4E��dI��1��x�sO�;�G��,�Ƨ$Q�_J�q��͈��0�W�=ڒ{9e��
��'�H�	�hu�(+Ru�u�Kz޿��+�]�T�f���aިZ~�',r�ퟡ�vR:���ݣ@u��#f��g�U�8��B��:��,� 1N>�����\�w�.���e����m{p��_��'���_�i+�
Ւ1^�%~���KE�Zr6	��0�t!BwXMUXi@2�0��~��>s��F#C��!5zL6y�/�hQp�1K@���E����t��6Y\jy�%�gu�H�Ӣܣ����Et3
���+�������m�g(��#���+�K!>gyq�N��JB�lRn#+?q��w�#�N�ĉ=���u��Fm.�_SvU�M�M��J-�e�'/1+�ʗ����v�^T,�\v�ր��j� N�b�������u����ؖ&3R�d��
�1�\(�
��B�z-Ԧ�r;Y7�URY�h������� �jP�y}w�K�q�^�9?4r�*n�+ Z4�������� �'�.8���b�A���ѱZ4��n��"�Ϻ&�ҝ��~�u8�q�B"7��f|�Is|��cG�����n��L�>��g��۬�!��ܻp����H1'l�%͗�5q�Ds+I?(�e�3�ؖu.�w	�x2�ɝ9S%���2�P���O"o.�����㛇�J��V_�	������zZt셙�����>�k���qw��W���\3Z�
2O���Y���A�O_m|��'#o	�O6����7�il�7��f�8��Mf��>^}v�����@6������=�dģW:��4�̯���#�`�`#�]���V`sI�4���|����Ye5�6�?�d�`�0˼�=F���BDd)Y���*M�6Yn�G�*c�L�����Hq�A�n\���c�3�V��͐O&�Uw�{�Y,�I�+���6t9��Z��~w�Eλ�<v"��^�!(^� ;��#J3!�w�0�phJ�����/��X���������Dl\�,��P�M��!����!x�)����w��N[ ��$�^^ �I��=�w��"��i���,J����� &�Z꿎Ц���gKlm]o8eEVTB2N�<����hVL��g�����.��6�c
�"�2Nwty�2W�/������^�g��py/��^e�Jܙ���lD}1��l��˸��2�����:,ې��}gl���L����[��!]�@V��Ȝ�b�v�e�>��a��,m��Zo�p���;�s������A��7�@M:E��&N�3[����Ջ�4}W���6�*��P��G���_QH��*���P#�����b�X�9۸h�⢝^������ʭ$9��7H@���� <a����Ù����	�yҼ��!-�ʧ[����΍b�r�ǳ�`V/>�}b��e���T+�"��Ė ���'���&�������E\Lݟ�	-��εIi�2o����i�i�P���ݱ
������$�L���߈���>��/f8��Gw}�L�B���i��`��F#�ӭ�|���E� ͅRm�2/'����q��)�?�t�$��#��������,'67ŷM������$q\��<�$tP��cyp�20���a:�_k���]������S�慖�"Q�P2|����|0m���V.�UY(��(��9��M�Qo�!R��G�؊�H�(�g1v�lp�6+�~��4�*�_e�^��l$Iu�V�"ކ��&FT���%�s�X�R�䞟���Sԁ�<x�c.ۚm~�6y�}��0� �yƩ�2���T&�f�' ;,�P�{��_ժ_O�״�{���hN����&��J�%@���0C��{=Dg�-?|�����T�[lA2�Z�uii��̀
#,�Ny�n����=p"ҥ'v�0%��=�R�U/��r��'�D����iu	��\L�`�g4�\t����
S�JXa0�ξС��E������c�3V$q�L/���&y�Lo�q�JT�>J��9�����A�AV�5��buAmѦ�dm[>��ڄ�q��f�v�"�h?A~XT +k.Bi!�	���,�/Y��R��� �܊���H*ů�I�W:�C ��K&�]��qc������y�#\s��Lѓ0/|<�6��b3����~�tz�Q�V�B�2��W˺Աn��֍����:./�����m�7���VL��2�@� ���IĂ�Ej}�~�QH1P��s�����o!�@����0B�؆d6�֔p��JW��Joi=� QCAw��(����}A�>��贅��He�a���61M�N���m�#����n�;5�-��E�� ���#�����>�_ym~���{S�]'�|0����e����&��צI�ʼ�,��+T��q�C+���K�Y�Ym�.�~���w�*���Y��/�pG*@I5���Tv;<�yl��s��LPL����q{k��/�ܞ�ۧ����~Z(�䱠|Jy�0�,a!�Z�]�W��C/
^c��{����3D}v59$�&)���n�z�v�<��m=C���4�����k    �_\n��C���1���i�Xi4{j#@u3�8p��(�U AO$�p�M�aD��[EPc�A�#�bT��@�<��,ЌѺ��N�V�"�W�����g���P�5�l�;��=C�����%E�W開-��+�6�>ҵw.Y&JW.m�_Wi�e��
|h��{���'� jo��ë��O�+ �@���筨�Ȳ\l)5ߣ�Vm=Y�ՅіY,�`G*���V�GrU 	�]�˵ �+�dˀx-���M������ӏ]Z��YD��o�9���M�����+��H��^ЀU�i��:�gy@:S�e?9T�����U�\��rG����j��DK�H^��Q�1�,p�P�ͥ7�ۓ��G<Ү�&F�L+s2���j��O���8+����I�Eߡ��4N�D���<Op����Q>^hTxu��`��5�sa��_*��<+se TB��\+������6�L-�1��<���Ki��*Y�qi!�e ���n�Y��C�O�x�`d�R����Ԣ�z��x��5���I$�d���@�s�v�C[5��3V�I���
v��.�z� q���/F����5��b�\�..�:�^`�qQ��CU����h{Q�R3�n���w'(��R�x�q!d,n�j�6T��If�;�ܪr�
�]���ރ��U�L����=�����
/�_0RQ�ZPݤ�R�ZB����]bL�O/٪4��=���f��~��d�s��8��
$��
Ŝ���
ؖ��B ���ݏ�dh�vz��J��r����q���.�FЧ����64�l�pqn��7��X�=�5�D��+�u�M�x��3Ybt�n�(z�rdD%���u�g/tx���oBLyo{�mT:��4w�3a����2�-T�_
c⪔�ޤуЍ�ԉ� ���WF�3N�'�G ��D9�d���]Vey?=��4�cIh&�>�tUTZ�9�g�)-Ɓ������d"B�����/\�7=BU\%Rt�<��  !��'ǆ�G*��j4&z��>��=�I_�RweP	�aLٹ�g���f�@�R���Ȧݠ��ĥbL�g��)-_��t��v�$`)�}%'�$��g�s{�e�ڏ����7�u�]�Tu�O�h��z��2��z=^����G�MV��jP7x|�X�B-tމ�~��^�Z��PN8�:��ܦX�3\�Yӵ�c�Į���V�}L/��ߊ��!�|����̲�#2��Y�^b�n��b6J.�T�,sa��./R��1&��ơ������J�GP^(��ap!N�us-_�b(����Lm㌍���mp�n��GYU��v��b~�U}�Ґ*��r	�J�7.�n��'��%KbO�w�al�b�5�]޲t�wzbL�"U2���߂}�phz��k/��p��7�i��7P)��l�Sx �M"&�&n�H�Oe
���r[�;SV����x��q�w������G�������j-����A�-HU���~@��3��-e*�Ӂ4��n�2UToX7JA���8Sux��� �x3]��L��$ �K
��n]�%��p���� �3��V��.xka���{>S>D�WK���ԍ����򮬦�YZy�8�z"� &�>Q1��Z��FJJ'����+�3��J�_�,Y�_aW5��\�C��(�,����8~�r��-{��WIi^TJT�ȭ#���r��\S��$����q!ʓX=�l����Y��&G�e�#/y�¿"�'?M&v�sL,g���a�&�v�&H���P��C��<��Mɝ#���K\k���o��wB��ƍ�W�[j��-�|�	�l]�i��N�����--�O��Z������۲ ����n(��`�m��R��l�'SEc]���4�7h�����Y:%�E��;�Qȇx��-���z/Cy�j�>]]uq3���C3���om�$Y<=�En4��A"������4��3�x��\��Z("�����Oh�"���,��n�q�k�l��K(i�V��Ӈ ��M�]�5�uQW�U���YfƊ�s����tz����#��(��O.���n�=�r����nm ��Z�٨^]]w���P�&.��I���R���Q�+��#^NY!�΀P8J�{)AU�oE|\�.F��o�h��TPgCv���~z�Ҵ���������������oR�1}G��.x��֕�cZ��e�T��~{�2K+q˰���iK� �{��YL�����w7�v(��ge]#WHl��ÁRR'��$���e$�����2{5t�[��H���fy6L����$O%f�(#����>���@�D{~�i��ą���'�y(̵^o+�x����_�Rr�YHk�������ҧ�׉nYRo�7(�uHڄ5�
�s��*��@b���Y�0��m���&U��*������18��*gB�fAx吏 �b��٦D]^�f�:��5��轎4��3$��-wA��=��Gq<T&���#H�bj����;;���dla�V�чoo��|<A��
��t�|�ePgo�&�R�!jf1��\��]7�0���b)ͳL�T�Zd#J�б�L� 
�>�����}����+
���(M��^�J;��lZ�\ l$K'�b���JϾ�E?��$q���J��{�վn����b�t�@�_�*�uý�P���ʑs>N�&��e	�!n��*�ef��&4�z�Y�j���^<qX��1�g7�y����PURJ�#����Ag�"���V��/��b��l�I�ЖC=����/+��p�&Ly��o>�H|ِ�-���@���~��(���"(�q�����2�eQRF��<C�j+;��U��������O���J�3t*$�
�+��&̶V�ckMWN^��N�		<09�ޗ�y�-챷�+{䋀�X�����p�]����zu��>��vDsɀ�I��x��TO}��,�??��|r��|T�,Wc�T���Ñ�_�z/�>1C\N/��(+�l6�$�j�����	��� }�J<&�-�
�d�7݁o��%B^��X��4�F�ђSd#�<Oݔ��9l9M�b��6a}Z��4=��Q��4��Ƞ��7.���@m7�q���w�6�V���js �dw �Ƹy��o�@8����>���ӹ��>��|����V�i���)a�Ǥ��ED�'J����� 9M��QY�'�4Y�pz�5ӥ']� �K=�f��'T��8�ZVk�3��qnq����$�IeEg�} ��vyZW��'���\�{�4w����@�n���9��||o�X/�&\�<�1�}���J��z�9�I�;ysr�g�~:��� Z�t��b���#U�Ez�(��Hm�����j�����"�z��$��4��a�N)>��*��-m��-u�BQ�	C�����6��؎ S[���
��;�[�U����)q�龉_k����ZG��/T^"��x�Uj�A����/\%C�JN�����n^�Ͻ{��5�0]�NGbiЌS-S�>aU�ٻ���#�z'P��>h��+�kwbW�+��{2��g`w��]�V�gγ������!�`�	���AzL6��1��l1B�l�پL����8�d�>�&����Z�q<a��nޫ��4��rN2K��v�s�Nz�ݒn����z�l����ŨP�L��kR�Ul�x���V&��4�iY�J�&/Z����C���xb�X�/���MƠ���_і�ߨ��/5��IY�..�=�c�?��s$�Ջ��q���7z��x�bq���z�ٴ�\Q�g��	.xU�-�\o���h�C4�ogQT�k�Ũ�� ��n��]����<��1H�m/g�1Y;�����.�S���(h�b2͌t������=��"g���±2|�%Fo��/���$)Jyֲ,�ߡq�����ґ���?C�K5Ѣ�Ti���YJ�̵	�M[�S�%���잳<��)���q� ��Zq�}\�"#.3��k��e��"�6�Y[OZ'��"���dUc��ǏGA�"�ݼf�M����7$�4Ob��I��=�    b�!B���<}��v���se��K��{V�1�{�U���<�r��?�l���ɧ߽��N����#G�D%��R��̎wR�D7��&d�8q&RD�h��w�q/�X��YOX��i���D��6>�H���S�2�*�#j��9��W�Z���;
��@H�ch�e��׍���+����m2�H��?XBRǇ�]$Rٗ[�̬��7Y�39 yb��!�8��KAU���5���1����m`B��Q)�*k&�,l>]����[�!���l���l
S}�ڬ/��2�h��#"���t�4<�_�=�A�+Tj��8\�b���F9싂�5FBE���up����lվ-�M�J�������Z��ɷ���v�8?m�U�cF�ƪ���Q�0BC�P-�'���ַ]6]�������p����-�ǥ���8�13��r�~B�-��_jj�k���A���c�oMv@��"�T�D"��''h�F���&���r�|s)�~�~�WL,������]��b'ćݏ���k{���;��y�����/�&��W�g{������kw%ܕ.�����{���`1.�U��y<Qj;�ŗyU��w�{wA�R������$WE������;׏���-��%�4ϣ����N���S��ɺ,wܹ��=�ι�JU�����8٫�軶���`i�L�ּ�>��p�)H���n�ǆ|ꌠϧ��%��p8�w��Ԉ�bm�|s�>s/��I��Z��� ����ڼ�D��n�{�w��¹^����XٽH���/ֲ����{7L���䩾�hٰk�J́�H�<y8C�%Ao{^�.X���8��A�3*P��w_����{����C�ͫr�`�UƊ:�.[���YXxm0�S&�Bsԇ��'U�[]��aV&�E�þ�N҆�+���C�_��7�gZȀCһN���g��}����x�����)j>�Q�Z�5b���w�lIk�V���/V❆�s�m�� �j��*��5�ꚓ�Y�G����U��!i]!:�\���R�	&��@\�W�Ҥ�¯RT���}{R����N���tE1���Z��A?XS'�8�Rzan].����Kp�{��`��"��)h�[�I�齇�+�T2E�%̦��1�#��(��ݺ? ~d�@os�(
�$�w��\w��$��.�빥��� V߳q]����ǚ�呴H�_dC�cb�����L�Іa�{Ñ6�$۽�ʒ{p�����8���xPF;��L>1R{��EՑ��|�?������Q��}r}͓6&�������
d�J�]7[f��Q_9�#��`��7��ꋡ��nPCC��i
����L{1��c`�qu}��g�@RW�t��x��ӫA��r��y���-Pb{f�aw��_���"^���e5?$i�OVVs�G�2�)��A�oDn�u 1�����oρ�&o�8��;򋑰�OfɝI]���d��G�E�-P_�k/���)yE�WTH�Ԉ�Iص��EM���W�F�2�籘^�\�!��0��%���<�^���\�a�ȫ=^�r�����*�{�����R���)CZ��T	{D�J�-Sѻ�_$f�1����3r��4��`��q<�G 0���x$&0�����	����C�ڼ�Mw\Us--J�T?��\�sd����:���ݱ��B��ғhy�7u�wQ,&+9�s�234��������K\��;�^�����E�4ٳ?o�/�u�-p�=�It��`�D���`�x���*��$��r��!�E>�=qᵩɴ(7�g�9#�a)��ѝH�n��� ���ݽ�gӎ�z���v/��Oη�5��Z�ȐǦl�_�̝P��YO�w�4M@��;+	Z:�Øg�Gԋ��<�n\XC�Y���F��!ڐWU�!��e�R���W"fԿh'�c����>�^����JL	J�?n��;��̹Ѓh福�q^�������/�1L�6�Y0X0\T��jP�1��#"��6���}�_���mU�s���S[<��/z}N׃� �e<U���\�~�`�����t'�VYH$�f�ƙ]��ӐUі��T�R��5�$z�� W*F�~(����Q�R�ށ�S�u��� Qs���z�P�]O/�s�en�i�ןEd]{f�6���o{�;Fp��W�E�gY:98�K���+��7hs~! �o����0�ی/����g����z��fQe�T��ʢ��L�e}���f��'�<.A�ݏ*�8cC��bOPV(���pV��BJ;d���`(�+W�Z�?���*�??���Rǀ�Qs���߮�fҴӧe���}َ�F��3�"��@28>ʲd�d�Hr���le&�sP���o��w���K��0,K�6�;���<��MW/q�P��A��|����\�&����\&�!�ѫD��`�/HngE}�>��lҗ��s��Ck_Ҵ�r5˃_t�%�5U�]��u;pw�q�1:�t�Dy���Dr�X؃�"�������z��~�V[u,z�������>�0��OV$h���7܌k���D��񾊮iv���}��m1��MF��}VR��}�����Zq���N��6^�v!G�/�u����%;��0�h���_�If���ެD*S�`ħm��*�.r��a-+(q��W?d�e�ݻ��)�l�;Y��e�Q��0�zx�e�K�>~  m;���0Qbza����h�-�x�W�Ku&��Ѹ���C���Xhh��w�i
��G[N�� ����N���HP�a��a#�X̣�?l8з_�A	?��P��6�r��n����U���=ٿr-�}�ɩ��蜂>�-w�E�@*P���|��.�^v���ǔ@ �	��?�N��s��������҄���q�J����=t�ɊfB8��^�]��u��w��Y�]�� Ʊ ��E%L��ť���ݓ����6�_Ԕ�qv �	��Ū$�� /����y�]8R#/eۢ ����(�^Q����f����<�5Aچ��GR\�JIF ���=��扫�._��M�	9�(�u"�(:7@p��/p�����q�,,P���Ud"��7�>?+n�`s��b��u!/7���&���!�²�9ς�ſdCq�w��L�>[{�zv����F8�:�s*�J:U��
9}p޹�A]F�<�b��W5��.O[�P������Ԩ�,@�E2�|���ȝ����9~N�+@�n��@��Q�˯p�K���R�>�\y��`�:�9^�@��K�'=*{7t{�v����ŷ�
�G��������oN��L�.m�3�)�'��dh�X����������2M�H��<��ux����E���'�e��m�L��nSx�NL����c��f��V��/�~�$�~"�qhB�-ρ}d������: -jH��+��7�P���}�~A<��XV[{-�S�7US'��x%Y� ��>=�`:ю����߈�}����Y���wJ�v�؊�޴s��4悭µk��a?<bڵ���[��r�B7��į�q���ҴgA}�JՏ���s䫱��\p2[m�ku�
��3���mE�.W48���me�(� sb��C��ax"���hX
S�۳"/_-E(=�Өs�n3�Q@x���N�������m��ξ�;�8ce-���a�h���
緸��u�d���QZHY�qEj�x'���N̂����4t�����fnm�Bf^��������_tcr��Q��[��h��[�VU�kr0AX�����E/(�U����n�c5��R����M���#X����E|@�4YԺ
G�� �f/s�O�"�W�md��K�r�^��m��[�i�a3�̹���N��d��B�^Pð��;͹�x�ގJC��d��:�g�@D�6�V;$�3^N(e�Et���껺,���^���;�H�w��"p?A��7{G\	{�ˍ�<���%��.��g/#�oY�U��ܹ�W�?�ն���"�}�?qF�$.
M�Y�	���9g �����;��R�ꡰ��L�	� #|��i��~���EZ'KR��G�    ���Y6� *����.R
e�2q�+��I�JGwD-�]�0i�n~���y�S���b�AK�eK}qt������Ѥ�p��!l��s�l��.k�Y%*%[��<�>�p< �QNh���;��C�^A�/�9�����B�c��6n\7��D�$]��3]Њ\p�!�s�i��@=뎩�"����jo�
*=w"�aw���1Ѳ������ݑ����sk�&j�]��������I�J��X���5fã~�TiI��G,=>���Iv��Xƽ��M8�1���ˊ:���i翽yX:q�2^B���V�#�3�L��>66jv�e�Ṟf�q��HK_�0�F�l��?�����0}<���S���m.��F��z\F�W��}ݵ#�)u��!�x���i#�ue:e/�4�J���R�� �\�ʓ����* �Z�O�,� *�����j��Y��M4��(�4G���p�Q0���(��<����fs��r�+�Q�#�Z R��"���NUJ^�Y��pm|���6�MQ�ċ[Y"��2	>1�twd[AG�'�_��) �w��]��v��y#y��Ȭ���+��V�$X�x�M������ʹ-3A/���B��1D�|����/0��/c�#u�6��(ڡ+��ŵ���D���:L�d����\���(s�;�=�EY �s^��U�"aE����l��ꧫ�~���Ƨ���h��i��32T�ɻ�����`�`�nS�0N��UH'�N�n���
S�I�O���ŕ�w�U:
ح;���C89��|�^(�`٨}@O���y��I��	~9�����H��^���ޑ�/�mj���c��= �
2	���׶~��4��\q��]����f��D��NY���A�*qG�up,lWp9U'v4
=Ac����m?MRwi2?8i��,�L(F�������6/����I�FY�:N��q`Ɓ��;�p �+W3E^�K�8
"xeT�ug�(�(��	�H&�M�G��\w�X��'���jfaU��o�8.��2a(����\>�����5Wi�o�f5r�Rq64Y������Lcc���QBG�^�@���L5������]�����Ű��h�z{�'�`�l��j���<bl4�:/�4�3	�DAJ�N!�x�0Y���-{m�_퉀u'r�p
�{P�P=V�Bn��^�
)!�D�EQ�:S
�U�\4<?��,�Z*[(S�\�z۩��p��h��0��q�[�i{9m��q�z��q��9�����Dz�u,����u�����~"Ն@CTh�`z��ٮ���q�������&��j/�b9.�mi�?zI��`�	���
�7�^�ILM��{��Di�	*k�ʩ�*����[��	@Qcx.B��a�jw�B�6�e���s�)�<��f����zv``E�'��p(�8��4b��!�X�iu2��Iѓ��)C���9��i�.���"j�v~�$y�hx��5�p�������`����g.�ɨ����*G�UGh(���S�I,�l5@�r�,���,�2͊X�	2�je�M�v���z�ދ�������0�:s��ˀK��{E�[�Ho*R��&�kJ�	pF�P���梁+��3���^J���4+M$UL�Q�m��_����'�3r���Z����A*Wci'�	�}i�nv��0U�S��V�b	 ���m�qp#������,X' �8��{|�SX�0i!ZDVa�?���Q|@H�D7v�X��j�ȑ"ђ�
�@��L�<�������%
�H�s=�4`��)Uڵf~���R)������*����S1�u�����[g�W��զڋ]Uc�:��<Ό������`�aFQ��݁�,�k{y �wc�b���*>{t�%]�)򊀚�ϊu܆f���gin���;q��r+l�d���
�=@��m3(قq�'��T����umЊ�6�s`�8��7�De����3��߲A�?�����'�g��n�eՙ���@%Qb��̓5P7�u"��!]xiت���ۃ�0N� ����αë�45f~C�-��LT���,�
S"�����¸3��1-���H`�0ϩ�X�~��̶��ѽIڠ�a������b�se�	/����FԄ�m�K�jD�cܸT���f<��8���kڨ��cC���A^�8>rw�D��^���>��Z����S6�1*5�|��ۉP�6�}�MI;rmǳ�c���(3��/
^4S�v x�0��v�����+ґN��)�����X�YȲ�F�����_��v7z���@�@sv���'i<lށ��uEhc��4d���"�F�8?.eR�`$6�7.R���?;��E��J���ce!���Øĝ�x5��`�]ݕE3;jQ"�f�$�\	�}|і>l�P\�n?IkX�������G*\7�j� �?p}\�r~⊊ܦ.	�/԰% ��,�s�̳������qĔ�E��7Eq<��kՊ����/��v���D�R�=�?tգ=.�h��4��Nb��}�`����_E\zavӑ��=��f=�V%�%���@��Rs�/���s%�Fa߱0�eB� ���Z:�j�L���Tm�*��5��;����o^C�Y�<�@]n�!�'�v���z�4+�Zތ{�&�ǸL��x��8�t��$;	��uw� ��� 1	��p0=�8¦����&N
m��m�Qr�o���y*�%��o0�9WW���(�_�'B�?�h������<E!$��١1�G��S\��=?��CW�r�����<�W��ɲ+�v��ī5]�m���+�z�h��~~�X�NUa�� ��́8��-��1����,�(��z�ŚD���	����9��mpD*����x�?��,.%��].�N͏��� J7�D\��.k#\wI:��%i��R���Vʞ�%�4���G�@IA� <ҝ�s�ѱ�>���&�#ۙf?q�(�0ž£���[���D��ߦ�_��B!�Aw7����'K���!��i����腚e�	>�����L�<9|�y���Ɲ�Ԙ��j�Ћ��1Y�w�c�Ea,�i�$�'�UΝڦS�4N����`'r�]����j��_\!�h�>��Lv�}��+nY�l��d�Z��4P��� 7n�_��`�{�믣$�ß�de�*��d��Jl!�7,RۮfF U+iȽ�b�q��{)�T�n��[4�|�67�k���e�S�FUD�D}�L� i��0��]Q3����������*@��J�m~��o^.��dCɠXɗ�HcI*Q�ֱ���}f����Ў�< 3��W����	݊U������:�BxE:kM�Ք[rEI����)O�T��<x�v�Wn(M&j�N�P<�t]��9ͫ��+s	m;��j]�R��6z=֢�WڪXf����s����[�R�6�∆�⓻���Á�X�{�3J�l�ݭ��VK����4K�v�eQ�<W���G�������ϲC 1��C8�3���]��g� W�Ͷ�p|��Ѽ{/�6�f�l4�$.�I��Um.[���������n0�� i�� b|ǉ�jaK��s��)�nߍ�i�jnW���@�J��Ebi�B;�$
���$/.��J�Ŭ	#9�t�톥��y�;m�P���j��ņY��OD��
]'&q�'"r�,	;�����k�/DE@����8�-��������Qn�fv{k��	CQ"1�	TY��3Wc2>ْL�y>0�]��d�v]��GӢ�[Ȏ��ߨIC��&Z��@z@:��Y�(�y��ػ(A_JIeO�.
�=mY���}�I�:*\�!(B>W[�9�>�1�9 �"�|��0���i�<V?��a*�w��j���������*�����BoIpQD^�����T#qP�{7[��l�>�P�(yH�$�;g�A�	�*`�M�Qई���7LN3�C�Ӯk&�J& ������"�v���?D!V�MX�A�RQj����O���    ��p���u*��;rm�d��-�.��˫�G0J���#��U/�%6�u�<�,��쪢���Ƒk���n���ոO���E�%��@6ZefR�V�d�8u�k��Q��a�w��d�x�& i	8�~��7����A�V�R�w{n�g1N��e�"xC��	�N�Wq{�a��ם훱��x��� 8�m<��_k�U����xQ����>�����(�^{x�[��@A�<v?z�B�~O��e��ِ8Z"�ka�#�FUU���g��4�o1t����횇�o�CK@�b�ŌP��CF]�+6�Z�������P5�p��
��-W�o���"#kx?���n��͖G��=��Ha�)4ȕ�B�7�!�UpZ:��t�lt��c��D��}=��O쟉S�I� ��$v�$9���b����\)+�\|-9$���{d���/�� -��9�h�	+�6
q*��"�EF�v��}qȬ��D] ��J�*,����q���ٹS��]�	c����8�+խ!rtiλ��v��0[�9)pz�~��/M�?Xj�Y���b�i(�qj�e�'ֶ���'�M8T��7�;�$yr�����Z��F���b֦E=�L#*8>M�׻cu$΀���BE����e�i�{�^��n�����ף���ty3?`i�2�J����j~O;X���.TV��ӝ2NHT�_4����,2"��Ea��jK9$؀VI��k��ϵ&Lo�];7t"ҳI�A��X-ڂ�[)Xڨ��l�k5X�r��6,�v~]�%E	�*��͍Ff�!�ʉ�q���>�/'�9X��-��@k���7�y���6)�-�5�w{n�2��p~X��֛�BD&�&�o�mE�_�CR�$��clm/c��j����׷�8���CFD�P,渪e'��P��3}��6���=P�:�_����f'��j�����?�Ȳn��r;�(��z��j�ow�epY�~F�v�K�2j�HY�;�hV��]��c��*0Y�?����i+�[���M���r��0զu,Jy��.u�l�߽TP�EeQ�?�y�$��2�CN��pWy�o��+BA,$
�ҋލ�}���
��t-$�rJ��0"�qh�؛����3��SA����7%��)6G��֛Ξfz�8�[,ٓ$)!���7�m��.+B%�fQ�V�;,s&V�bϡ���c�,�����Ќ��������[l���}�/��8��6�����:@j��Hbli�jJ�8e�������6�^�8��w���vd�[����F��.*��ʲ�a-L����ⴺ�4h��v�����������9�m��E$��G����K�y�aӕ��u�M�I�G�ɒ�Х++m�	'&��a�o��׭��)�(�`=}�?�AK"�D�zG)�l���b��8J�f�D�g�~fi�vwT����z��׏ t#�䊜������:��HQ5E1]-�h|����O������˰��(�b��Ͳ�O@�H=��$dD��f����z�D2�p��=�����M�4k ��j�qE��P��If��ڈgy�j���r�wb3&��PSGe�l�.�0�Ub�i)5~��1K��N����Zڒ�
��R/����G�Y�j/F�*Yzh�{��pV���%F�85A:��ws*�Z�;���0��@8��;���e��^8���;�E�2��҇N:�
zD���r�eO*��hЋ��W6�����8���uF�-���O�q_&���gi��OY���; �HL9Zȫ�H�0[(��=��`�+e�5�1iՓ���Ÿ{ӗ�Tm6��R<�$	U*+�dFa6N`S*�
 ��v�݃�S�4ZeG^�-����Y�k:=�l��� ��dh���I��n~|������a�v�����֩��z.K�<qҧE�̏Bn�L.�<
^/��Zϼ;_HRw͵�NI�Pm�C�tx�!�w�?�Ӣ��LM�+�,��Мt����<�d�֙t5��@^q���r��mQ�O�iY���o'f�n˹"�Dj
l(A��jN|�G~�`e��@����㬂����ei�MI���T3�+��XIuIX�{5�Rǩ2-3�a}fò���6�3�T�uRs��qn��v~H�t�l���}_���SI{Y N2��ziǛ$�{o�Cw�H9CMm�����jM^o�v��"o�4�]�E��<�`N���łFw8k��A��M<�t5��h���Ee�$��"�Ղ�y�����zT�a��#D�J��pƤ�bE�m�+�����&�x���KT	A\���,ǥɻh����#���+��VKkч��=dʜM�Bz�<�_�W�Q%�kəxV�	k/Î����_�2�9P/�2��O��ӣZ��_�����4��)��p I�0u��'t��U�E��sVp���7����W�ߤ}>��
��ɻ�/�fɫ����S������B?�&sb�^N:F��"��&�z_i�!�N�ޝ���&H���i|�aK�h}V�)�~Geh����1���?�F�sh?󣝉�8-�?���|K -�K�->;X1η�I�����A�*i�rn)n�1c
�a����%�$΋.������QPT~�:
�������㪩;��X���Q�wi|N�r�O�[r���f�D��^��
a�ț��`b�&\���|VS�^J;"��"�ͱ*�Ķ;�8]7����x{���,�ڿ�G�؈��SQw����^׽-�濡qE�c,���TƷn��n�R�����n�	f6[�8���r��.���7E����填t����z��G����EY%���<}__�*~#�µ���bF{qu�쎤|0�D��+�k���E�(vz����	&��x���/�t�Z�~�L�)�:�
�ٳ�.�_'n�h>�|���ҾȂ_��=ܳB��E��[��W�i��Q�	oz� ��7{{�k*��?��6o�xvY����xfQ�Դ"��-��A���}�ۡ��Ϳ�*G��$�Cӥ�o��d��YaQ��H�>D��(�e"�����q~Q4��_�|J��@��_��u���Ø�NS�(���횯{Qu��]�(I���xs%�.������8%�����A�@�|���0+�v����b�Н=H�
�ѷc%k���J�hnm�zjx�F�-��%vҎE�:n��Dq2_��|�S�d�Q�Q'��	�:��?�,n�=vhe����RP"�Y��o�`�
*e�QQƃ��Θb\;��U�ۋ��}�.m��A̢�ʋ�tzL�F�����<V���/ԟb�+�h��jP\n��8�
8�����Y��J�'�^li��W�L�64sk�8z(�4*8tN�,�(D��z�?�(8ӐK�`�!%�t�̿t�� *C��$^M\���h�-�a_���_��CX�e��ME���3�T�
�r}����JUi-Ӿ_�JiQ���isp�q���f@�s�W�QP�8���l�O�u/��	,q{G��f�wqV⎡�Nd�N�]��s3UB9�`�&7'O�'O]�տ1T���X^Q���z�k�1�N��K$*�"[�]Hm�^�xb��j[��)��P�'�SA�?��+�� ��h���]��M�%������I��'��-�T�L���VlG9�;\��i2��$F?l��*y/C;U9C���Y�h1mQ�EM��Ȥ��p�,P�)�5��C�3VSb9TW/�ɜ��$`��Vz�6�&��h���Vfq�Y1^ط�7Q�ً�[������٨�?�ʨl_�9H�b��&���FM?��C��0V�MY/xծ�v�{���j�Qy��@'q�����~�dҺL��m�b���T>U�,)'qU���}��Nmu�.#�Zr��o�ɚx��5p�}KB7�CZc����4�GL�Jg��خu�S[4Ykfs(mxL��"晄Q��v�J�%u�QٔO�;^�2���m@����2,"�\�r7r�>�N��T�^���YX    ���^�5�����/*f�ߪをU,��vZ�2wSv��I1 �
����y���"PE�3��m��-<�cy������lѿ�X���
W�5;��@F��|�u����q�j�XS�>���爽Q舾j`LuMv,��f2�B�^��p~��,�d��6/H�Pp5��e��K������!�o"�����&��.B���������j�����׆&�?�\n�,Sִ=��K���l�e�=���ا��X7x�S(����I �]#����f��΢��|~$S���f�.�h�W��,y��s�����¨NӮ�b��q�T [�W�� 6VY���G��k�(�>�=4���=��2�����j�hU�u�ro$w�'3eۧ����~�\Z�$̂wճ��i����M�=ne�F�iHnc{��̪H�r�e�����rH]~(4�abd;M�0-n!���)��{��j}�bbSGQ�3��%]�E]8Qq�U�x� O\��)Z����D��	qЛ��s������[�_ɟR�k:���Ä<��;Z��33��ix��#i�*P��S��	đף�i�Wb�l
Z�3�E\���ϸ;���x��7Gc�Y�5�QVz����8<�����D5�2���g�K�?x��|���ɾ{=S�Yο
[xDz[��/�2b:��+�F^W���&D����%c��{���1U��!_���=X[%��S ]7�UTT:$	2�(Q���N�Q<�CD��cd�ŴO���՞��;�?~�'�V����_,B�+)hN}8����]��P
������������'�#Q�� ju&R���{�v�"�.O�?��ά�߀��]�ڔ=?�w�E=��{�?/�f
HI"�&۶��i�.���'��s��L�0�'ވN�>��>���Q�L�b������ҸV���r�P	u�+�9�œ������w/Nd����B�l�K��6cE�K^NX���Y�.|w�1!l���4�j����w��r"�|�K�û{�o�tuίK���H�b[9>V��UVwS��B�:���q����f�h�����ĉ�o#xH�TTֽ�P��K�(^m,���i����������AIl����=|h��֫P8�9w*����x�Ֆ\K�!L��jf�+2F��(>cJ�`�q������m�*>�Б��Fd�q�lG�R��P�C,Gr�f5��v�]����q�U��v��&�H��A�JT����''���\�G�VEmr�U��>	MΎ_�6�Q��w�s�fxm����5�0m~-�{[pTDp+V�K�J綎Ȍh��|\�_����E&Jc�:%Q!�\�&m�����(n5���mҶ�Ak�V�T�؁��6�V��\�rMª�����E���l;;��P�n�ݒ˂��k�����Z�>F�m�;@Gt�U��a�]+��G�ۜzc ��y�/6���c��͍ob�Rǁq|�h�(��ܶ�g��D}SHuX��hM+� ��A�A[m��4E\T���ӹ:�m������ɫ%�]�گ�3H��}��3��0�M��b�Q���9㨪��$q��?Qऩ�D�&����}�O���I
t��Ř.z��v�阧2��u��s+Jh#R��o��"�!���q38K�֤����6�Y&C��ohw��XR�������џ+R��u/����4���T��>»�>�Y-N��2���b'��r5>:$e߱;TQ տ�$��x=��R*A	V��|�rnL\�aK���(U�:H�Jr���bc�$M�2�_)y�k �QU�\�H@�xϜ񓐞�|�Pd��QkOW:���h��3��"�tJ(�j�E�N�)��C��\�?Kn U֓�=��Sp�[���.2���G��x����i��O�eY�tl��"S�	��%�8�iϷGe���%�E:)q}~֦C1�u����X-�-�2Kr��g�c�.��eXM��Z�d�U@(�zx�JK�l`Jw���t1oRO�]���OMT��jfߋ�6�"̋.��(Ӣ��F�/�o���}6?n��Eϐ`o8���[����V{�lE�T�� mT�뮿�U�aϢ��<���銲6s�6�T�{��������=��M���fDdV��^�w������'.NK5GJ�	��<�/�����t���<��v�<�@X�����;U'��b3bk�f����ĴKפ���tf�PV��-�.Jl%>�?��(�ѣ��4cV�ɠ ?�z�H�4��P�T��{4��=!�LX��!^y����`�*�#��*
֛� �8%�M�}?Q1�F|5�Z��}�H��&��4���:q1Y��J��5g���3�����p��p��+�^9�>�;��|Us�|�(V�i��N�$�f��m mM�jM���$X��qM�e���\#gV3�^�^��>��G%5�)Aj(O�mF�g��x�]����k^�T�p�oYfr���T� w����G��6i)HxҘ���_�)�%�e�i�����8p7ܰ�C�T�T���+Խ/G:N��5뽂����&K@2�.PX/�Ӑݔ��Ly��<���lܤ��O�G�$�WT�DBT��+O��T
A@��Ţ�?�([k��?��la�k.X��l����#,L�1 5v  Vg�����h�-�Fa���!��CV����SN�=����:KjgjD".��\y!o!E/a��
%��x���}�����Mο�2��*&	)[�:ьG��:ӊ�['_�!�(f����H��m�Е�e����Ik����Е�)� O������I�R����j.�I�@W�������j����E)�s�.�&r['q��ȋ��ӖDR�2e A�¡kw�M��]�=�O�_z���C�	m��G�\�Ui�&�K�:���	K�T�ư��A��(Q@��M;ÁO��`�л�U�Z��)욤�~"TiR(�&I����r�{���? l�N�������&�Ih�\Ws5�ml�0+D�9I�=�`x�N�:����^=���cФ�Hn����3��~�~�����ǝrU�Dg"�{_��:�i�G��	h�����1�Ŗ�A\đ+eT��I����j*�=Ǯ�]yOa�,z��8_�]�UN�as9���N�0pF�O�*Nًo�H�q({@�o�P��BZ�-��;�̫UUN0\�.�r�ܹ� DI���2r Us8kQ��B���%}kڟv�Y�z�fB�#��Bi�d��������h@�����n-,�48뫙�,5�OC۲$s�h�����F�h���=�أW2����Y̢��KVñ-��M�&l~&,y\�Z��k�	녜~M��,���'�p~�'�:͡fp�3U�FP�!���C�{�t%U͏i��ѣV���ڨ�{7�'uߦ��g�a��L\�£��6[q���4j�,��-7Q)��4^��L�Y]����-J�h��~���<�z�-����Q�t����]w���S�_��Mc�P���G��0F��X���J�tbԷ�d8�;�2dj�n��Q\i	Yg��U������Wi\�&���Y��8�!�� ��(�hip���_��d��N_t�8?�Ѽ�b;]��@~�:�j{�6˳EP��	��nf؄q�K)�����I��xA�(M�҂�Ӿя��(�\�҉�y�nd���wo������u"zi+�&������U�s�����ߥ	�?X�P��ݛ*����r�i��,��Ԟ�g��pV�e��1��,8������,�mm����5H��� O�,$�G�����ɏ��Llg��@+)M1W�Ai���ү4^o(�
�;�,��).~.�zѴ��Y��t�a�p`k5%.��8M�m/k����E��b�۪`50�&�șr���A���)�H�o3�B���@�����+Of�~�iޑPz�"i��}�?�	�?�f�K&�B�Kțq��`�
� vU�g�l!�o�ݏeҤ͒�y���ed��n��T&+�=wƿ�ns��!\u��*]o織[e�����
i�:�J��#���'[�!Pu �    9�Qk��z���,�a|Dۛ�֢�	�(�D�I�0���,1���;,�pf O-�7�aR!�������n3��D+���I�+��v=-�~�fIVt���,�K}�0��&��܎�4d���M���r�ٴ�0\�'mzG���/t�����y++�D�cY���k+�h��(�/�8��-�t�'��a�E@�o���sgs�"�4�~<`�Z����֝
��`�q�$�2o�/�n��f<k��F�V3y^���M���0�[�
۫�R;d&x����H=���T�ޤ�U�% ��<ゐ�������3��>K��*�<��h���wd��q%�e9=I��A���ҢΣx��*øT�T��N!�*yO���]�a���3`0�`-g�#Ϋ���Th��$]��J�Tz�,�'�I$52�/��či|��K��i/����MY���`;��#��/���TFM��t��ˁ��:e���4��B��Ȣ�#��4��fM;���R�i�E1����)K�6f=V�k.b��D����G�5&r��ʔ�땀���������	�y��d������/��v�o����A���[��F�B�7����!���g��r���#�y��!#G-,ռ�O�	����f���E�-����I�cڢ�X@�D 6R�=�(?wZ\5<bZ���=�,�:y`����8΅ �׎Ԃ�߽CFjS�	�i���̫�s4D�gՎ��W�q���1�4Z�~�r�L��a�%�W�={ѦB;��hΊ��ҧ���jvd�$.JI�y�Ɩ�r;��b���c\�66�n���F�J��;4�<{�v��-xl�U���{C�t5J�bY�S���27���G��p'n Rd37>l>A��m�A�g�ٻk����w�TI��J~�e�SSfR�q�o6��K�,�$ݸY��ߎ@Gy�W�C�V�zXn ՔM1�s�<�0�bi�r�R=�*�d��y���7s��7���#ޫ�+�"��m����m���p�J�?G-z V�dk��+�k7�X�X��� g��m1�ô��6�����t;�<��o����S�D���E�Y���B�
��g5e��޲.)��'�S�0��6ς_;6���u�C�"c�`X��v�z\vߩX�|�����П�eAQW�g��.[4#P[B`���n�<uM۴����*��#�IV�d������Ω`���q��d��n��<�͟��)S���6B�Ĕܙ�	�a�^��G���Mu��Ɨ�' ��������q:G��Y:Y�9�u�EÜN�,�<)�Yr�iңh��)�伯���g�D�"llct��bw�|̌�
)���4A���P�S��Z׀8�A���$Z3��\�{��W�ĉ�^�3�%�!���m�'�<Ztؒ��[��/m)���	)&h�]�D���w|�N����p��itga����+M�8�"�zͳґH��~D'5�.�%���{�R�Mϯ��4-5�Q��_\7�[�w����>�j\8]�eg��h��Ս�l�s��xwoh�EY���k�"
�L��wG�!�?��Dg�5R�Zh���D+8�������jk15�,����}�<5�h.L�������-����c�����+�ϰ��]X�1�WKjK	�fq�������U�Z�L�%F6��o��>��._��� ��y;a����p�;����Z�*�:ۓOM�B�s�]/Rs��	eHdr����:���c0?�ً����N��s��dub�6<q��2�JJ�N��^d_ �*��#����	V%oa�(�T��M짤���'M�B�<��~��ٱ�p|WS'���]����+۟8pe���E���B�&������L �*��gVf��g�@Þ=M#�{�Tw�A*Ӓ�\�"y`#���k
W_$!�7�;ӷq^moX��"��,IʺifG0�gI���<x?ؗ�]�:�Js(1
��9��b�-��w��"��l�tM��D��"�d�S���NV����%�D.h�F�;$�7�݉�I.�^P���o�B;-6M���Z�޾��+��)�;v٪�g��3����FŊr������s�G�
z��/��0sˊ�~~����~^��Zz��}�64W���u �Y�O`�Ga���t���&������܄>�R�c5�Zù��t�fEY��O]l����Ms�xw��2Ny	6�oI�K�S�%�rU���J�5M
����8��[[Bĳ�{��,풲����ޠ���%p��P��򂟢U'�mZh��3���m)�M�e����M��C5�.��u��i�D���L��D�
�cirD@��7	n`98 �M��mv{��{�,�'6�[���Jȏ��ʹ^MJr�by����b���H��ܶ�q�˼���(��(�w��i����]p�t�ù�f�� Y�n�\D
[a��#�F���L�� ����L���q�QH�I�DQ�:�)�=r���;�@�⫽ce�^i��En+�Ꝗsֲ�h��p��f�"�ÖoIו�>]Eo���Gg`�clE�����Jq��� ��p-�a�}���ل�a�g3~w�O��hk�R��1YMr1�JV��|�I��T�2|�D�}���>����+�w�H�����9vD�VS�_�df��$��ԟۣ�H��TJ)xW �,#1��J���)G��`VkKXt`XN�1I���A{��Z�po>��+]h��~�Lb�6o1�nJ%���X��F!N�tg��98�i��d34�v���Z��t�Ab����?Ԇ�8r��^j9�װ;z�|^T���E6钣x��R�f0ֳ�*r��H�_��:��K{�U^7��t�����?�:]6ڦ��ozO�-�I�8���r.F�˪*�O�����y��[_�ڮ�NX,�� �68�&q�����Y Dc�꡸�j�宍:��z����s�1]j�}!X^�����vpA�s#��z`�P޽ueVWe�g�S�&�$2��"L[����^px5U�Bs�._�8�IG���������@l��4��=,Dy�|�E���}yȠ[ hu��K�jKQ�1������9]�`�v%�d���[Z����I�ڝ�����8�\_x����������d�_	%��� ߝ���~V5���Qu�EЅx��Z:V �+X�5(!�n�) M-8�W(xVe_
!�5IQ����2��G�a��f\�|Evd��l՝���/+:]nZ���l��� 2�6u1鴬i�<�;zA�gB�L��*��| c�R�,j�+�^IJ�$|)�[�&����%M�H��؊V�d@�ځCic����-k붎��A�B��W*v��o�P��@Dמ�eLQG���6��堥4β�ޏ��0x�hɑ�h�������A�s �A/9x�ٿ����Rd��+m=?�De�D*U�]d�^��ūRUH)O 6���~e� J�=O�k"����~pRt4'��S����Y\e:�h��_;�D^X�>�~0�<��rk�m����W'�J�I7K"�q��Q��<�ɠK0�^�Y��m�2鄶��m�H��(���m�M�t���Y���9�pz\wD��(�c��>��9��gb�^T%h���Y,���^-�-6���?����!����[g��F���dO�Ŧ{�O�Mj|ޯQ����z{��Y�W&���q2�^0�2��k��E�Mb��GPg�v}��?�\�rS�b}��R;���Ji8�&5Yhd��Fa��&{���O�S����$�'�ܬ��m������򏺏ŧm�q�#{��K�iC�N�~�"�_���A^�Wӎ?t��I�
^��Q��"������EGP�o{ �)�CM�][P���ʧ��Z`�szka@��Y�h��y��QX��K�K���Js9/�[��\�!+��(ƢT��e��W�=E?�N��'/�lY�ɋ�
�v#�HvכL!��n<�ģ8@3};?�$�G^pV���|�.�ygu2��ÂP    �(>m�A6\d�=]h��QA%���"��yZ
�G�Ig{�did����
hU�1�f�k5D�R �<�����6���%���Wy���84�p�U��ptӞ��-w~N�G�2�$�Bр��<`+��<�S&��xW�c�Ea'K�[��n�S<w��ŜI׊9��I0�ZZ��}�؊WnH7��x�;@P�պ��
�܄q_�O�Y
+t	j|ׁo�	ᵅ��ۑ����*��/���A#��(�:����H���ڈ�E�C�a{݄Q�eO�MQ����+�Ry���|4\R����jO�fNV��E�C�!L����ر�a�E�a�%e�=���@�.��{��I�6�L��Ln��1<v����Nb9�<-Im����j��Ŗ-����?����4/��ȃ_9L庀�hm	��і�;��K%k��9B�v���Q ��L�hx�,GT0\�A� u�� %Z��a)���yi�P�,+��(���O�"�[���r�nՌ��@YA�-{�����CZ��K>O��l�_�E���6[e��Mnهbz�A��*Pڕt�ȁPָl�ذ<�F^[��F �'�_�ċ:���r��a�����ykh�0��7 �y��a���&K$��d��a��̤m�YC57�B���b�إ��&��W:e ��,
^�=ݑ��B��h����/8׋4{sc;��^H�#3�O���yf��':ٲ��P2`��%E(l-�+nV�;x:�ez/�Ak�>?����{�l27�_��$6�TN�)�N�=�H����
��V\�����A�"34P��-��<�PăYk��<�X�l�a�"J��q�AX�Kp���]�J�⑬64_J�8��I1;.�}+���Ӏ~j2�����R����t�F��T�L�fk5$�b��y�em��VV���|` !. �ӍV{Wx�7�~ĵ!]�W��)I����9��:�$���&�xR��K�#ٳط���Q���i��)�U������F�x��vPE-m�QZ�="��=x./�f��'�;�)��+��$���&U�F>ȫj���̄ago��8���K�-=�d�-��ZDa��<��H�i������<��O}�]���Agj���z�㩻�\^�&����J�B��S~��ޠ�9����VuDtߕ� �xH@���HWIn~��K�0Mecm�ൈN�tY�%6G �#�\ւ��/�p�<��B��3E<w8r&\MY)���j����6��1�NMp����o	nc܋��1H�t{��~�Ct��& *�`e��E���Y�,S��Ig�k?���\�c�_���Y@Q8@������qTK $Ӌsp[;QSv�5)	�j}�rmm����'b�g����$���y�zY�c�`@�f�6��p��c;ɵq�g�j�n14Ec�&Of�,��(�[">A\vp�b;�)<ް�L5,k^�[�Qq �	Zֈ�� 
��~9�T���{'�
±r���o��_QoS��a���#/�c��+�&ĹY����/
��Fx���;W;n�TKp����=%����Y ӁiSU§����P�.�
�����.7�b~����� �8m�j�{K�S������D��&�K6�
Я�6� �a���"���a�RQ�צ�W"��E�bO(��=n��z�@��C�ez����v���{�$��g��ܰ�V����������!Ӯ��cي�o��q>|�b�9߿w���D`�-\�˗C&���(c�7�1�+Ѧv�e/ ױ���=��r�>iG��̨@�4h\ߪ�"��`?\t�<0O^���zT�S�1]MSg1^c�F�� �(-2P�<��>
4yߌ����G�m�u��f�B�jP}(7{���#�Z{����>��b�Yiĭ 5b�Ꮲ3��~�^5S�"�)|�Q��`��Z~�>�y�Q7�E+�B}iSS
 ��Ʉ�E�(�z���6I
�Stt �(b�q1��+M��/T�<�%TI�S1�#�B5=s�#�'��$e[���x2y���*wI�U�x���������e����&Q��ا��������[�_vJP�7���n�ؐآ�sxV��|,6���~��qC�!�L;���ݗ�K�X*�7�@�	�PZa\ϻ�(`*�]��5b��q9�Z��y7����%i,�F���8�5m	�(x�îm��2]���Q�ӧ�F��a�A��=�_+�q���R*(E���lY"�4+uV�$\ζ�.V�`����Ǿ�>k��#�
0?E�^8M�����i����Ȟ�P_�4���Xw��C(EA��0sGX���D,"c�8��$.#�����:���/TO�f�-�����M���&5�\�_'���P�XA��*WA�\x"w�4]DUd�j~��"չh�H#!L%��lP����� ��qW����Ռ�����g[!������I�Bh���S��力����Юvo�mfyC�����f\$ʠHJq*�k�Bk��@����PX�l�wr/��V-��{�ܨK�+�Dz�f���7��^@�0a�6�O�IB��/�w����O%hY��'.�i����1|ɫC�mb�9�����.��.�ɯ����S���}�k���Œ�@�Ĭ�$yjR=���ɺ�K�
���d9L;8xR��3{M�8Va�B]t�-V-N�J��d�a�h��yPE��у�G_ʪ�
P��N�Qu�H�j
�Ӭ���8���+���j~�g�$S,P�G}&;��V�D�镉�cEa�ڷ���4Q�}z��^�[��]E;�zML2�Kc��D�[��6������rEX���hI7i8?,�QAj�_���S�Yu����VYu��v���P  ��+6��Y4�HMZ(H'M����k��y7�=�-�J�ys2���B6GRh>/?�)�M�^EW#�-�Y[�Y�?C[�I����r�B�P�S5RP�tz�븗�8�<g����8�҄)�>����%�+<2)sE9���eᅗ6tP��N��w��7�9�v^��ZD2]���®�ڰ��G27IT�˛�!4<m�e`.�j�X�i+66���B�V�i�O�Ϸ#�d�0[M�z) J�gy��D!�*��]�#/[�9G���Q�>lT�i" �WA#)%�9?����u���q2*��������v�%��_��m���v|O���ie����g������"����e��03`i|c/O&�ӂ�5������['|Y[��Ͽy�:�Ȧ9��s�6-�^��(�6+�O7���zԲ( �D�A9y`/pmO��A���GVq<������'EiS]97���F�Y8�\'OD},�?Qo`wv�:ge�^TT]�	O���A��,��#!e��ʖ��{�Ew�8]TaX�6����e��Ù	���}��0��(��4p�|;���;�h��t�c�*���F�%��Jwm�A������s^w0�!EY$G��O8��L�	`Rn�W�&V9�
ҥ�j��]��4�uXG�7�6�y���i��t�'"��Y�<@O�.�	�j�FSV�B�)��5�؉pfY���4�^�`&z��иS�:�o��9|UO�@���W��{
͏W�Ʃ��<�`� �/D�JKНT�z��=x����9|�����`�8?�c�i٭fE@��X�h�����⌊��j퀄��(����Vg�Ѯ�j"!,F�ъ0*4C�S����ފC��v�q)f�{5ل���!�&n��b������w!hgD���Է��z��c7��_����T���-�4�X�N4`#�F��Z ҟ9o��s�F@*l���O�ߏ�~?R���gv[[{q��v/�{����������4��ee��b��P]6�7A;ЪA����F��ǫ:�Y��
Jg ~
1+V�".e�Y�u���Cb+-���a�}��qk���-@�O9�� X�h��j�(�0���r�[u1)��K�(��J�QR��Q�JGŴ�"��ݩ��u�`�+�8����ą�0��]�2Gyx�:�Egێ<���L�0=    �c��h #T&�s;��[g%`��I��c����������*�2��:=pe׏�����v	��%En���f�+�0 S-X�{0]D�x��ġė�'�ȹ�Q�Z�,^�ס���E�I?;�J;J+����O�i��GLd1�霮i��׈,v��Ŗ�E�4�w�쉠wDu����C�G�	�{�.Ժ��Ɍ�����(,��~Y��>17Ҙ	�h��mMǥ+�A%�:��-0$7�29U��w��Ul1?f�t���=D7�{br�#�οj�{"	/��"V,�D��b:ȸ	�`}&Ƥd �w�˨N�����ǰ��Q�����S>�qY*�8���Y���/��Hq2�t�e�W���������d5���&�e�dE�͏V�'��ͳ��w���=�8��q;���{l�G{ң����<���]�B��_�ƾ�Z��v��0�'"��i;�^�� ��z�ŜKʨm�j~O[�i�=m;'w2^�Fl�(�ݥ�^�c�QG8un��0��=����.�_�e������^�d��Q���ͭM�Q{�]�d�[��F�"�� i?�X)���CE�e�gGHWk����q��s�)ԌȲB��"T����Z�����a�3������w����c���ul^��3e�D��(qK�QDN!���P��i�`Db��}@��
�rojb:3wlgI{#��"�	��j=�}�\�����O������!��T�(^$+���_!���L�T��j^`Mo�v��6MY$�#[�ƽ�&x��=��1=�*�P��{7�tO�W�w�T�L�@��+�C��H�bzx�M)��¸4��yI�⬠ qڙ[.�x!�1�!�s���C/����M
�/q),T�%U9�K�A3i�䊔c������"U��Q' _��v
�P}�J��ZjG��z��BT��pj��.FA.�>2��\��Y�"��dY-�|U��e�]#U�<�G%cE���j�R����N�۝���|kT�P���s�����A��_:i�1	{�yY3�⥲jq������?oHO��I���E2$Ul��&���b��l������+ݵJ�R#P��Cg��8��C���(ӇK�ܨ٣�?�jO;,�$cB�B�"���O���+�,\�y�c0���
�.�!Y���{|xU$m��\���!N�P�BY�+4�e�K�ӮkT
����zӋ�2겭�vn�m�Wa�N�f����}dէ44t*x+�p�(�-n�Vz��e^��t�3`E�|΃O����cy�d�A��!�J�L$�w͐�p���*�l�V����|#��Q,���c�e��W�o��J�* C��l�ar.vɴL�Ob��_����\(q �z��R�8 bGm��n�[�M�I17�<�T�kG��ۑk����>��ˮ��F����9�&�o�Xw�f����_`�S��ڝ6���-��"�B�xRs5E���^�����^��,L_���`jKKŪE�n�� ISP�"WXzAKʐ�BbɂW`5��R`��l�~�P�S��ˉu��HE:ʛ�n$�p��.�2�����3��0��P4jY��= �,S�Zڬ�)+�e���<�ٿ�`������"�&����IT0��w�k+�|H%�4�V���>K�7�UX���v0O�H�d��*M�vp���p��*�u1�u�~��͕�
�(�H�#�$�P�W��m6%�i�#bU�j�j��d8�;I0s�آ��b^7𲦅 �z�t�@���t�3�z���;�c'^UqoF�-����M�{�l�C��٪���5�	*?m;	��3B��~����BBwWUGG)|pE�sO���Ұ�KL��|���n�����2\���bY�yW�o �2TK�2x����?jlb~v�rP>4���ő��4pY����]a[m�O�������8�:�,M�7�W1���5)�=���7�����~��:y��`_̞�;������uf���;�2L�qS&���c�����"�*��V�:�Q�rOQLÊ���͕�yq,���}���-e��/SрT�jk*�H*uݓ:����BI���<�=!�k��a?<rE�ᙧs��h��_7�kw@|W�-&;W6y��s_j$+O)3������;��8j���j�i��
�UF]�Հ����=��lè�=�a˒,ְ��+'�!/� ��wH�R"��'յ��Π� �c9�B&�~b8����]Mw�IںZdr�M[7�cEy�,���널�$	7��,�tb����$��)�P&:�:Yi�d��8�wO(����"�����2�,�uU�8(���B��S�#_z A)�vӞM�L���v����U~Oq�xb�xJ���c&Bn/ul��<�����x~(E�pG��7�H@�$�ỗ��vu2�v�$-�'%�A��dMu�B����r3L��������bA*Cq�#��!�G����o�8m�^�hw�,�~v[v���R��ɋ��˸����N(��rډ_��c�| �AH�y���ae-I&��^��n���c~"`iG�,
�R�bxF�h��P���Մ��d�|@�M����د6�Yl�'u�Ϳ#L�"嗅#h"��ݩ�d�n��;�V)�}�U��X�A9�v�7BE<W�Z\n[�7Y7׻�L�\J<M�Ν2ם�#lF<;�p������M����.E8���CS�(�j�KQګ�4Q�c�qI�^���#'NG��{Ϻ*l:S�?OI�找�)Du�&}>��(h�u-g��j��bF�Ud�(��4t>�k�����T��+��EL2L��6�i��j1E�*�Ⲝ���$5���y�	=��EB$O�T�(+{#J�9.5���o������S���"x�մ�ܖt�΂�T*��q�ؒ���:,�<��*I���8Kư�e��(Hɾ�c�N�P�W?E�k��n����K+�'�C���D�b����?��1�l��AG�6�j���ʞr�^
��2ǥW�9!�!l��k'W�H�ʳ<K�,�D�D©=�8<"h���s�����\s8\�4�?A&��3���ip�#pؠp��r�2+Il??��I�Z�b�5��!`�A���U	MV�_ay[]d�v���}F�q@���UI�?Q��ɴ��}�!'����v��B�<��L��+uG�&�
�;T��e�!���cᙬV�-�I_�Ye��E\��F�WY�P���\? 20�%�r8h�(��Ӿz&��F�����f�M�Iu*%h�1��_��Q�]�'�ei?���h�O��t��WH�R&���ǲUf��\��~��	�F�l�q�3V�P`��AD���p� zge��1�C�m>�������\�y�lz�r�U�5IϏlY���<�ȹ?��U��i`B��=­�6�n�F�S��w����n�����1]m�:9�C�͎i���p�'�*;8�Ϊ-����{E���\nP��y�s��4F�~��-r���0�j��t=$�w�;�dQY�/,��I����@��jL��X�UѦY7�m��2�%\q�)o`��ρ\�"�{N�=���g�`oS:l|9Rsj�3�	PC6h8��P�P���P���� ��1
���$2��k�$q�jx��-E����V�.ԫ:Ot{����S8W�89��
{}��Y��m۲�Q+�L�Yl�8i?#6�v�F�P�odj�y��뮕���m���Z�8M��aK�a�v7N��#�q���p�फ8�@��xWr�i���j����UU�y1?�%�)r� b ��&2���È����N9g���I����J<�������z���LY�:��t~M���t/i��.Wt�W��4�ڀ{�Lzs��U�C䅘��"�����<�j~s�'J;˃�F7m6�o�PY���y�E��"#��
m�����+����S9���ʦ�����
�A~�Hp��k$<�iK��M|lR�;#�����݅��j%�r�&��8d��7�!e��3X>~��(��W��_w-E�f�B�)�    SU�N���Qb���΃���RuSE9�#�*��{����#ۉ�����na����n/v6��f����p	(�U���N�]�n�ۙ�rB۶u����]�>J�wO���g�	��cmr�(N�`G�/j�Ӌ;�k�؇^���۟���
��WO�E@G������z�a�f��rRZM��u����TM�?q��g�6a��� �0u 5G����z���[����&ym�7�y�a e&���K�	Vf)g��?���(XG5�Dv57��FQm���������ogj���*�!\".��)�VwpC'a쓋�ťL��&R�x��J�a
�.��:r�h��:�2&���T �=e�^��8�.�k���U!��xw�oSuU�Dt�0/t�d� P�'�(��:�SY���"�9>+3ϻT�z�(^t�0�¼��o�ǽ��fVk�����ؔ���I��a$ݬI��D�;����bwN�F��*�嵝Pl�ew�U�^?;�t�	�Gƨxxw/�R�e_Ζ���%�J�>�L|�#�GA�ѻ���s\`� n���NL�����H�,]MCh���#[�4�C�ee�9/�\�k(B��ϙ���0/�� g�e)-��8�4/��D/�{��:,���fG/�R�#�LA����V�td�I�
�Awl4//:��Oa���R��:��/���ʒ,ӊ��o3<�R��Hz�d�&�X0Ӻ���)V���^dm[GE������Q�*�3	x.C��7��(�|Vw%����Bׇ{�+�͡Z�"��Kaq���cg��'Q��TW	�[����lc	���7CA�F�&=��Q��&W�b�����X�Z��h�;�4�}��K�ߠ�.UR��H�m���H�^��]Gy,�ϻ>��^�U
,���
pغKT<�P/4���j��ƭT�a��ЧE���O1/QJ�m�{�*�Ni��<�LG1�^�vc7,7Ta�;<��߽�L�yW̿RM�'��vI��ޏ����ua�3��\�;��}Ĳ�S?M:t�ҿx3��M
"bݽqnm����D��y,l��o��R@�#ͻ�9���$���?`�?�ݿ*���6�;"������ٳJ�Cb�R�$x'3�+̬���xL6�l�n7"���6i��@���K׉��t�����*I����-C��H�S5O��HLR���TQd��ih�]��=l>����=rJ���ۇ٧��գ-7���:i�jvp�$����dXtȈ��4��e�Ԟ~J�j)���Lt���;�\�^\�R�I����[(��(tH���۝rഫ�7��)��v'H���� ����Uhh���#�}>w����.i��Cݗ��qdY>�_�$|_ɔ(�K�8$����yF#£ba*���ι�̝�z<�� ]]*�Jf�0���e~��]o�),��D�����Ă�0���_�k��-�S�6XJ���d>F%y(�PDwZ_#UؓYZ>�����>��:r�F,��-���ܸ�:��	!=��a\��[̉��M�w�IQ$��6�F%"'������%�n�ƅ�ᬊ���w�2��ʸR��<��������;Ө۩򯟋:�/��
����H� ��=�̮�ܐb��޽�_S����O�ʢ�4�fq��^b4@]�t>��
A{��Sw�d���D��X	�����8�"9K���Ҙ-����Z^�Á����{R5Y6u�'�"V�j �����_a:�+��(-5V)��+�<�(��,Y�%�����"��Y�����<	s�gY@���J��3���! �U�Q����E=; Q�d:��
[,�5�x�qhN��d���S���9��P�
�<L&"TcsZ*�����YK᫁mjL8?�e�[�������9#�q��G�9��`�:<i�%�/�3A)�ه��.�IJ8a-�^�$I_�k�e.�}V��%�9�u���l��* ��t�>L�pAE��@�רn,4�B}�cR~2b[e?��$O�ҝ��i�W�5�b%��a�HG�\�c��q&,����JS���QN<��?}DĪ���aeK��K�4R��<
~�f�(>������F�{�b)k��������"�b�?�R�y������m����q.�O��^�� �Z���6	�4u͆Њ�u�'l���xӀ��(�����2��H�ȸ�<����� ۥ�W�n�ſ�DV����iO�-2Zg�ѯ�"0L�^G>���J#n��z˵�o�H�]��E�8֫�<���j�"�O:�G1��BFIy��V� �r�D���ϦG������V��d@���׫rS�׳4p���ش]�����UV�j�$x'��4S�.������]�G��d`UJ%��މ���6y�K�ƅ�a�4���Dj�:�'r��Z{������'�
�n�!
�_����d��'k�.B"��u�AD�"v��F�C��ھ��=�%û��N�5�[��\����՛2���p�Oר�����0ڙ�6N���  �V�I������Ԉc���M��o���,���{��b�2&e<�lQQ�Q����C���u��;���!�MWGu]�?���J��ɂG�t$k�\�򆚛zi�;�WH?�0�#W��[/j�%.N�� cRx� b�(H�E��Y)�	�y���NS����}��`��, �j�Iu�������>�]#�t���V<{*'Y>���<�Ȑ9x�v-T\��q��"A����Hl�ҫ3Z���o;3��ڿ�7��}�~b�M���s;{����� ��t�G��᣾ā5aU��gYj����0�w��?M*�F��_�"J��#��'M9�ʲ2�dv��;<�d�%�Wc�����R�b�[�'���<�JW�����b�n��6�笂l@��~���z�_E�2lײǣU?�Pp�����*]l��v������|~X�*
�����5v�b�tbg��(���khjZ΅�z|F����e�$�ü��Bnd��S�A^���=�~ΨH&x @�f{�����\L��MUd���"�q���<���"-?��^k�s��*��T�mEJ��"}���Y��U�iT��*��'q���m�룁+T�Q*v(6�w/0܆Mv���T�i��H��~p�bE�j)Ŭ4M,G^�4�v `1��r�#���ȡ�>�����`,V�O5��]&�Q����f�L�,�7�6�
������ �3��ty �����4�ۨH�p�Y+�8�TXd�/�E@��0���c$��P� i���<�����zf��az���m�gy<?7VI�(ܸ�=��8<N3�줔<ݎ^��Y�jzϋa��8��n�����������.�i�ӏ��o,�E���*B�f����<��YԻ�!ih�$k�b��`1�]7E:{�i�K����2����_�3b�Ju�݉��l�E-}Ȝb�#������	�0X�=ݧ��-`o�VQ��}�}�X�s�F�温u�1�5�Q�e�#�#�w���<�������.�;����g:��8��W���MO�P|C���e�?8X�jj(��'aW�FEK)�T�,�p�z�c�: ���B���"(}���Mݨ��O�(1(znՔ��ф(1�̂~������r_�;A@���Y,���������ę�g�A�r5)ե\�Z�;ճ1d���UR
8��"@`����Q��;��2֎�y����mb�p�LE�%e�o`o��s������A�� ��tmaC�W���;��E����b�Jm�0�3FT�X*�2�N4bP쉝�OB��wOHˬ�;ש������Һ����.�������_0�ߠ��\�Y�V2W��^���D{C9d�;i�Pۡ�f� ���^��⼟����͋Pk�2~���X�y؏"���_�1 2�����Y����b$��L;�2>�f���b��Սh����ͮl��C\z�p��PN��lְ�m[���+���U���e����bc�<.�n����Rڴ2t����M�S5�m�=[a    ������j���e���K��UI�x~��8��^�G��j�4�|�_�E�%H�g4��j
���cEX������I�+��T�t0~"y����;b̅/t��=�{���e�
ɣ���B��q�������~�`>��8�K-N�"o����,��P�*��Y%rR'��j�n�PKPǠ��|�q���ٛ�bFuy_�<~���"@�>� Aԋ�L��yp�@���n����[|S��^��\g$WG��oX�j�:��T�p|F���e"�0۪I�����>��"���C/9�	�6�� hn���Ex���כ���z٤���^S���ըi,iCh�6h��]	=�wgt�vm�aj������4S�mo�pr�n��'��R�*so�_d�#^�b�0�I_��ھ��%��+T&Y�ί���~m��U��s�#�G�^k�r��[a���I�U�Ŀn��\H}|����{)���,뺙�r�8��*����h�H5ӏ�� ��� �3Q�AP����Wʮϒ��J�)��&�$������ip+�����O�.<�����L]W�n�y��o�=4���>+��g�\D*�[�Ơ}��%�i�f�ٛ��
Sco�|;L��u�ď�Ӥ���r�ܽCM[�u\�I���F�� �%t)Ngeň&��k��vW뉏���E}`Bw�x�Z�C[��V]�w��\VV��<x���*0���F*�yP]K�f���N�	0B)���2	��>2�*�����j��r-I�$�+Z��J��R��> |]�(wR�8�7Phe�S���"�5��2:X8z���l�2���P���2�6g�_�n�GU����Z��Q�I��˅�C�>�E`g�O�wݺl�2'��b�(�G���V�(j�1�����=Y=�����L��e���-�~�����^��y@+'�Z<��%Z�4�+�O/�mE�Fs#&֘�V-�f��u�99��
:+jC5��{EO+��9^͡j1˖�.�r�~R�P�E&�uU�!`b�{�4~�O��*�c���|o?Lq�I���3s,$a�`0�j���QbںK�c5?�y)Ͼ��G⬼�5���RL��30 b��-��T��]==��A�v`�i^0J����M1�%��*�����5���m��?X�����'B|_���R��t��n���\��*� [O{d��fS4u;?�Wq��,E��(�#��e���|�k�<O�g�DW��2�&]�H�pf�g��_��*׈i��r1*p�t&�翗U���8�I��tL��4�	��>���3�+t�Ϗ�A�����_0�L�k�b"���$l�$.��&Rk�zX��=��v�Qr�8{@�cϣ�	޷s���<����ڶ���O�Z��e-B�������LGu����q�Y�)3+yGd?������~�,���<���HՏ���'Y�;*!��즵\D(�ռ��2�j�$�fC��(��\C�o�/^�Y�����C�]��ŧ�乎�\m���+�d�歍T��I)��!�u̬�\�ia3DF�ʼ�^>��%�!��=��^�:������b��x����5�;:}2Z?:���n<��u|)�§(6y��~�ge��(���߿����i:b����B�&�ʨ�I�3Py�Ƿu�	��4"�#o�e�;��J���F��@����N/jo����n$@)��!��n�t�cܘ������˲ײ}5��;N�t�2���] '!���~]j?�]�6�Ɂn�vG;v�Y8�����ށ�@��AhLRff~!��Rk�*�Ҹ;L�Ը ��ytz7����C7�gf�����j�l~"��J�"
�_k�`ܩvSj/�SFbM��F48��{�4�������ܴ�|7�TD�I8:���J!��pVG,��p�:1r'WL^+��0�m�Vc1�a��c�_�ˡ�#���r�H�
�0,�h�M�}�W���
I'�?Y�;�t�'_d�}/p�NH�u�B��͓W.�W8��-�di$s;�S�Z�t���3�O��*��Q[�f��%���/��5�r��8r���Gv-$�b��m�g��/�4�RI�Q<�!�Q��xFљx�?hY_F�=T�����sh����J}��ט��*�*�W,	U	�+�2"M���?MĦł�7^��	�o����_��~B<��F#Kų��zER�g/��"J�?���J���e�°q�����	��݋z(� �qӨI��7��g��MI���t�OR���p�2�|��O���ѕ��\g��p��A��F����$�wK0����7盁��s�o��2.,�3C[_�t���	�a�����~e��\i�@kk[zԲ|�2��,�@�G�T�C�B��
0S\��0���m��L.�՚�7d5����8��6x�+�m�����t�ܭ�J�=�g�{ѓz���<�(d�2D@(����j{!֢>,�s��tM:����$��r��GAՂ�F�"�.22,v��>�X��&��X��,����&K�(�����Ch�/�'8��.�a�^Z��iĕ��r���2L_�2-5^e�3u�l;�9���>����'X?�]=�"`�T�Z��|��7�� *BY�FMZʏ��mv��١��$��̩��5�a����\i� ��"K�-\������=5Kd"��z[Gh�������D �̤�F��=_��Zt=�>G\�<�ԍ�<g!�={���s�F)x��M֪"���H��s<��Io��>�cЧ�r��7�0�G)�N��(�Z�,��U�[MX2au7����J7KR���R�:ey��.]��}1�$�N��0 �ۡC�Aj�-_8�v��%,h��l"0h�g�LF��j����]l�����H�Ê8
>ߎ�p<h�np�>m�2�S>Q6Qφ��,]-��k� �F���>�C[�����KB���'E��\��'�D���W$��������w�ǲ�M��ِ	>Q�	�J�r5ۉ������d~�) �&�'N�ӎ
��0TWLc@_i��Fl|����E�w�K�&m_q઴�]{��=�hXrP���pڶR�]�X� >��[_��K���)��?uY�+���v�{"��:����z��(tZ���:I�� Z?�����!T	o��R?V��{�u�O�;��:=���h^������d� {p�0:��҈)���A����F<H)&�fRb�dkߓH��u.���*��m�,R���}��O"�X���s/>כ�"���y�D<�W�	��G�1��'�zYؓ��Z�b�\��u=~`��R���8��WL��p�u�g��0���X�	ZJ���+є ��'�՞�մ%�0[��K��o�/U��WąM��q�:�C$>ح~(DM�P\�FQL>U%�[�:e1�T�ey��#Ty�������PFg��=��Z�����B\S�����C��Xcju���ƞzP�-]�-��v�U����B�x������ܹ��m���	��,�i�b���aT܇>8��}�ڭ{�p^<��(�s>Ѡ~�~�z�����Z���O��@t"�|+���������b���ڒ���sK���u�PD��}&u���U����~KE87���J�R/|�`׻j�Lh�����?dh���w����a�d��h%U�O�bjqJ�(����@(��W���<ʫx~(��*�K"{p\���q����U�t� X��Z @~�o9@LEڜ����;!��]$���Ͽ�Q�Vr�Xƀ��H�z:������i�C�^�2䠼wDk��u1|dg����?xQ�T��O����~s����v�1�Q�2K>s�Hggf���>rT��|�"��[Ļ6b@�x��.7�*
��v~@�ʭ��4���V�����w�\��y;����#�k*��?�P�����x"w�b�<2�m�����\
��]���E����,���+$S�5��S����^�_�Chͣ��6�bd��R
L�ݑ8z�x,��4f\͕q���e�������zC�;'�(Z�@�Fy^���V[�.e�ڕE�֯���¶9��jG�ۥA    ���o�2�2/����V��j�g�GL�H}[vm��R���bēy�Z�#�ةF���}�)���)�(���ο���ט���;���T�T���]�@T�3��F
�t�^�,�$��9��=�W�B����2Y>;�<%9Q�^Vg;x܄��]���q���=�nz�3��:�z�O�(/�I{��Q��R������_ �\2�z"�rlW�$����u�5�z�QV$���$�E��	.Ҫ��\�X�G@ٴ7\�6�6���ӱ>L�,D��+�?�q�+,&)�ޫ���H���4J�L��iͲ�]Lp��)���ݯ�����~�c�{}�����Ҵȵ�K�@�7�b��+�Mm�(�f���H�"�,��T�B7�w�
��������RE]��y��0��dʂ-�H츫�t�>:#Fjrl�[Ɂ|9UP{����%��gq4CO��E�Mj܀8"�/�j���Q�xK�8H�^��O�s�+�<>�N^iO��䋉�D)CG�*YEy^�?�?�[�R���
6�*��?21W��b�-��G~=)�(�I��)�;pyB)x�er����O~�Wܵ�bn��2�A��PU���z���]vu]����0��R�����}?.��t܋�Mg'�[E��WS�����z^J	S��5 �d���6>��m�
�0�*�BZ�?d�HeA�ö^��\�v&�)��Ѐ�~#6!��!����/�c�X�J	���Z�Cc.~l=%��H]�?�v�L�;�k��7�^��d$���HDT|���+bO��}�E������a�&OBS���E��P(��'�c�G�eF��<	r#�W�b��f1�ڮ��Z;��e���ʦ�/8.+L3�ͳ<�N��q�Dz۳M���e�ͳ����������!�%'����y�(��o�<{���/�fBh�y�ڏ���>���=���'�
�b�-�X����W��E�S���<��<'@E4�̱M,�o��es3Y��n�-��f"c�I-��µ*�l��FN/���o���� �sM���� �r��&˓W���**uH�� O��ѬU�d;�ӄ�Yde���PXn��4y��O�	H��\�s�cƊ�	�=��y�A[��AN!�A�ڐ�uv!�A��+I����w�w��̋�5]n��n�w4�3 Mf �b~n��^-?��Xh�;y��'���5b�j�v�\�U��+5�D0�UW�+��/ �Nr�l˥��M�\��>�3��,.�sFA5@�D�L�� ����Tf s��u�<�w�Z�s�Ӕb<u5����N�j��	u�M����γ��pZ�����#��t�[��o��hl��e�)�<���+�U�N���'�$�po����q��B&�����F�Db��ﱦ���QUڂ�7��vD���t@���ڶ��W�)M�HU�%#v�IS7 u�.;e-����@���$�B D�h��Ae�f���E��E<r�����(�_�ⷥw�ؐ,0ϘO������O.uќ�*ڥ{����r��H�d�觌�9�"O(Ҍ��H9��]�kȥ��ڟ�����:/;mltN�����M��Ѹ�_����+PJ�-�h�A��Dʹ���X�������ڡ>6"�P7��d���Lv&*�p��W�a��r S^��U$���"�.��E�; 8�i��RY �`��чm���������yܽfCg�.�_e��cU����i��ӡ��Ʀe��{H���P�Y�x=���8��?����j4��(���(��,*���2���>(W����1aY��+���*�R¼�pY~�藭�hx^I�6���׽��ٱzI	��SZw#Z&���a戩��	����\U�ao��7Eb+NU6��t����': ���	ӔRBD_�-v��e�P
�:���B���1uq��'h�s�/@�q��Pud`Yg_:�5�]��x�Ax5&K���~����@�o��M��֊$�����2Y��x��y^��a���uΊ��ft4��#��W������ �X���e�KV�۲���Q��D;��~��KVk�� L�`]B��1Ԩd��#�P�z�s�ak�������CV��r�"���Q֖���VQ�h� ]�~r��ڪJv�q��a| �%Х��&,�6����(T��<D��D���9D�Tj;rP��h�Ը�	Qd�KͲc=��>ɻe�R�wy<?jyT�zL����!��^*�F}�+���j��Qs2�+��@�WK�Ka�MUe<��EU��	N�O��8Dr /�ا��>�-<G�|�h5��R�]&��*�g�-N�L��y�,����ݯ�lp�����R_e��icK<s�R���/h/:��<��d|�ZO&j�tvV�%7w0����ad~��%���ߎ:��Cn�Prs�ɹ$�-m5�'�+O�~L`⨛o�]�F���u�x1
B�+2]�B��B�,{�s^�p{d�/���WF����K�M\�I?��'i��z���Q�9��<%LX��"���(
�P;S�<��8fy �r�4Rk���g���V�^�wm�;������+/�����Vo�biA�0*b�`.|W�/&9a�����R/�M$���xV�=��� �)���ͣ�-t��d[z{�?��X��D���2���=Y���N��jRɈ܂w��s���:�@��F�ʻ��4I�e��|��qJ�U���T��
X%���v`(EEw�ڧ3�x��J,7il�+�,�����E���n���y��P�yQ5�6�6�B<Pe�D ��c@��fҺ��IK�;�_�,KC}Ɗ8x� `*6�1�ą�ǒjQ'u	47 �1�*�O����8�y�nѬs(8�{E|����'��YP*���]��z�u�ս�DUK�"��n?�۪���؞8��4x;xk�u�	��jRK�YLV��+_�nvVd����&���3�8�n"ăq�I��8���Y5;�c�୶ 苶��"��Ҷ�?��d�K�"��$�
��������l){'hF;�v���'"��=���e��#���'�2��vU�O�9��%���O�1���z� 7�E}$C
6i
2�B�'����N4���M7W�Q�z�E�*�%��]p��@2��ŉ,��>FI�����@�j8�X�5��C�+��Dj&bt���D����J�[�1��Ei-"����7�/*WSd�hm�'��YW��3�z#�DT��4W����F14!F�_�Y�a�~�om�xĶ�ۖ���8IX�����H��<S�ZJ�+��g[SG�빆na�g�ڣ���j�����L�$q���Y"�2~�����n���8AG��m�����'��1!!p�aŖkU�2���E\���m+F50�!lY!F*��`C�ʔ�,�g<���S���YK�� }+ ���j��Ky&��K�Wl��0�U�4�8L�2�a����HA���W��xNQ߃&�O��[�2n�z��J�\�I�$��O��,Z:;��}��V���CN���.������=q��z�ht5���t�LY��l��"��z�L���(C�E�Y�Uu%��(%j��ϗ-�ږl���gVV.�h�e^|��qޖ�T5e�w��SчV#���Ԋpvc((�����eG���p��]S�a���CY���\}�otJ"T�4w\ϔ�j���Z�������"�t[���+F�Y�"��:�@G���$����d�T]��h��(�rٱ�����Q]Uq1�V�,���h�4��j[c�S�-�t�N�O0!���	�}.r���"$��)��a�E j��r���$��W���~|a����W�u`����b���:�[Xy혞J�ď��B��Gۣ'���l\{�N%1��@�D��s�y[�B]�#d�?�Qr���j�P��a^Ͽؕ��|����,.U���F@�
��Y�2x>���͂���ٲ��ʬ.�4i����B޳    *��.����zz��3%�f�WJ�(�[�����Z֎
�jڤ��Oj�E����E���*
�++�+YM}�����:�
ڽ���`���=L'�&���#�I9͋ ����Gyث�=�:��y/d���vt�2@@��(�ɪ�2^N��jG���Nˤ�Z�%�V�=jv?5J�!��㞶���t�!<~`���A����>*�v��Qx�HV�	,��գ��N��Ɗ��a��z��n��X���̿�q�j_RŶA�+�|,��S�Ȧ��t�:�<O�@�V���|߽~�i��6���U�vQ��$xD�?�n �bS*�I"Uʙ�
l�x7aޘ��]��x`1
���{/P��IWΏj�d���Ui@�C�ep��n�Jx�3���s�z�KJ���'���4P���w��'�º^���ݴi�G�+�$��(���-*�k�V�%��^�0�{  �5�v>�T�IB+w����ں��g4�¤�e\�ok���p{CQ��5ۨ�����+&X��XY����Z���]�ճ����LSL�>]AM���|�w��mi!���>�Z��C�V��-�yt��
痆iYĺ���wJ{�?HNt�j
�R�t���XlZ�A��5��'�hü�F�5��:I�I�(!2�0�H��^��0������X�]hM��WX��[$W�C�8�[���\\/��O:
A�Y��>G/�n#䲁w��e��/�o�6�Aݨ
�L/b�xB��׭ދD��p1�f��>�$��T��'��}'v�CuU�������|1��p�������ui��:8�u�b��XQ����]lc�����s����&��Xw��\��V��.��1�I^1��C�I(#��>Q9Y�#W�1��8u�{R���`4��Duۘ� f�����Jy�gڼ<��{Mc�>	��i6���]�z��	��rPsz���9�t"p�A�ҩ���]nVE�<�;��
�+�L�m̧�H���v�x%j�;�l����B-X�a{U������z�:XB����G�����)�O�H&~�H�?�?ۿ�ud����W�v��7q%��sz��� ��0���{�y'��8��x��'}l�p�$��0E��)L�_��.�9E��`�밓��T��'��)��+�滴ح�A:��aQ���'���#�����2�2i�I7@Pq��h�֋.��(4��+�X��e�_T��4)���7�����+ip�n}���}�}���T䱨S�a��j�j'^F1�q���.�T�Pq�K��ewρ��2����]őC�a�їI̽λ8�?� I���_m׺�^_�M�3[�4�p��a@�Ic)nh����ʼZͥ&��]��tQ��o��4MB��J�&.z�ѷ��lY�ב���+|��
7���ڪA]E��Z��ZM�p1KQ�>Ӷ����E���D��S����<��yfKG�g����WM�zs�͆zo��Zmk�� ���=����$�@Ez����,�6$/zӉD�ί���_Ml�������$�8�!��u���\�Qۦ���JK_/�(���X� GS�	�> �w?���8����BU&��%�k�M�-�@�,����d0e�xR�Q͞yRC	Qn=��r�+2��|���b����Q�	��p#q�xO!��=MKq��������C�%��M�{��\�Ju7�F$B�h6�S���ķ;����cr���:6�߽Iq�ĵ���!�U�Ӱ(>yX���<����E0�B�q�	F�`e�8�����G��ςӽ�?`d⡈4��$A4��j�D��aԩ�_oE� ��a��+����+�M���Q���J̅B������({.f��)�Im���l�l��[�`�a@�(6E�(�.���j��*:�Z&%�+��>:�7������]�SN �x!Ƨa�O�À�����O����?�Q��Z�Ey@17� V�����D���N�f����y��1"<2|�8�Rx��l����OL�6��@:�Q�'���YK�>����]/�Z"��!|�4������)]gTo�`�G���N���=�xv�՚�.��Eꏴ,Ҭ��$�R���k<ow�[8�1�<Z¼��k{7��r4l�� `�1��#���#���+�+.[���W{��*=2`�s��,҅h!���?�;p�[?&/�D�/�b\��t�$�V�rX�fi�mOm(�(N�W�Q�\�<��+[�y���
�� }�(��~��@h�e��6�_�"�gU_���m�"m�b�j� �����Eո�W�T {�7�jt��a{m#bK���\�M`]~6O�{s�0<��^8��ðO�_��oK���7y�p J�G�=�G�-XԟqY�Ϸ�sto���'/��H��8e\����?��$���������"7*����@�0���S�5syS�t~VN�$���e�a��QHF��(ǿn�L��j�A}��og���'� �w���!Ȼ�����oTlnW��p	 4�~�6o+j���3���0���g�E�����!^�2�E�NV�T8�Ck�i�,2S�r�\��/���ؖ8�7@�����j�F'�g}(���E�s��0V���%͎���7	���[[9�q���j��BH���'��R�;�"{������T|�w�ӗY�e�^y�Z|C��$Y�9$�6����=�KnG�!��l{�Z̀��=��/۬5��f^F�x��I�W����m��H|�����Z-b�����QbQ7W;N���*�	�[6ķ���d�q6��)�Xk�$
��m�~�c
�m�`�ɱ	Z싩�E��tx�_*y��k5їŞ˪����|T�E$je0���/�ph�ct�j��~���E����:<Q9����R��5�}˰�*�U|rB�a������S�7oվ�i�����߽��};�>�߹�Y��3'i�	�/�""�%*lX���:(b��!�b�8�������+�43�2ɂ�*�rʀs}��lx�*������= ���jZ��M�f~�Q�Q�HA����O����p!�-2���������7#t��x�8�7�Z��֧��.��2-���L���萞AN��S0�S�P"���P�k�h��V�`PP�?��R�-z�T�}����FEY�=�l��\�2������N������4B��,!��E�Q4�!�!���ʺLi���t�*J��mn��G�4ϢL��*�����P;��ٟ&�R8�/���nY^�[� D6�S�\m���2���f�z7z�MFI�M�`B͐!i�DrΉ���et�G	�x��E�az^m=��D�%M8W�쏤�'3���`�{�4d���;Ψ�E-VPƀw��!�F�mJtc�p�i�U;/�4�a�Eef��Ӭ��3�����-�GZ�֐K��ҳ=m)����"�S����5��$.f'��!+�mJ��@FΈ��{*,�O��ŭ�ֳ�X��e3����}��i|�A�J큠_8���5�$��V��(|cā�|d�b=l�8ܭ=�W9���&��D�K��67��v�✄�lΠj�7 �H$˩Q�Iڎ��G�Q͈l����J��<�p���e���1�u������A��	�:B��-�=ظJ�����U�J��pw�v�w�MH��
`�2�e��u�g� ֹ��q�a�D� O�ѰYE���1ZB���MڪΖNu}���8�C��i���vډa�i<�ޞ)A���Ew��v�����&��|~ڍ�(��|N���
B�DMX9Qf1:���qxދB�*�2n�O^�i�#+�4�{����.{E�R�s�4����'@�O�PB��6َKb��%(�h���rھ\X���
��8�}�كi��w�^�������&I��R0ޱ��Q�ZY�٧����ͺ|\5B��6�YJx��ؖ��CU�a�А�U}ý�8���7F��rr����;�7^#���tx�� ��# ^a:    O�[�IT-�	��3m8�N��^j��������h��/��"���baxf�X�j^��acd+�h�#�VQZ���_�-��T��@Ӷ�gQ�l���\�a1���iҹj�6$Y�f�����MO���!76���:h���T�.�ԆQ��o+��1*e�"'��G!�],u���m�5�y�#Ya��LL�<�qHڍ�(	��w֛p��!F�Ua��<&^���⚀�M�hh� ���~��	^^�X�E��`.� 9>���6^���Mf'�7��G)?]��;���J�Q�v�ۜo{Q�� �O��,!�Br���:��~��j���b�p�EU�?\�}�uɟŁ1���BE����4�6�|`�������НB>bk�B�NjÍ��}���F��-����PE����s�B�����Z����;�.�{������>�ЕhI,�ŉ���LD��DB�ūN�D}[�΢�zf���F>UT�i�%
�����QN��^|S:s�w��v�Zq���(2����. f��D�v|�w���E���n=\�im$<��?�"�%N����'��"ͣY|tVIN�S�m-v;KG���]�A���9lS%(�:܈���6�"rq�D���QU(�"K�w��IA�ivObݦt[х@G��y��4/�`�� _��%QU�!E���,v�L"�w�n���� �o^A��,g[�:	RE�q�&�1�O](�T�gD1�*]��0+7��B�'I��/������I���u�n@^'~���z%UY�H���H	���x�(���9�Vu��z��/p��=S�Qo���!a��u��R����ʗ}��������n)��9����	��RXq��\�-����j9����Xh+iom�T:��q�F�ew��Q9���+�IT>�!t`m�����EU�8>���R[7��岽+F!��^X��螉?�kY|�B����zR��0亊��Q́�'���G��������8�꤁���v�#>���A�xwl�H�J�C���^����k{T<�XDe)�Kj��?�#���R\x��e'=���\k/tf6�ך 2�k"@3�����ݻXI�I^��ĲL�H�}��"��7a������=�\|��2~J^��Ivm��-՜?�*��)�j�V�`P����UR�"�[fe���Z�NA�m���eڛh7*���{(b!F�:>�{wpm�,)�WT�UYV��QU��D����0$9��d�dǆ�(�z`���9m�ٺ+45[Y������W�������J�0x�-h����
z�L:�����9c	���~��M}��X���J(�W�Z�R^�6�2=۬��:ӎU��&����&��\=H�)
��q����E����*������p���E�:��8|Ҥ�0@��Qi�X�m�U��}�|(}��oy��X�ҭ�#�sl�O�ސ���<�vv�"�"��h��LU��������c_-Ճ?�͓��}���x=���m�'q\��q�b^�Q��E���pA� ��b�� �l����PM`��"ثSh�~�G��<�wf�mS4���Fi�R�y,o��6z[��ڨ��?08,������D��X:ᓺw+�6���\�I���P��<	�쮷ZA����]	v�����A���i١f�;�g�h^ցj�e|6�M��^��q�
��I /���x�9J�	N����t��qI�lR|����i��s��o����p�E�!̂7
h;߶�nKM�or�
./F�ؾ5�橾�@D��0�DI!a�Af�37$^��va=?=�c %Q9�ƺ:����[\7����|8D�)�F���##IC-�gC����j���ܾ �4�O��F� z�Y�U��8�'��EM���a�����]t����W�.���9��6`�݊�g[$`�o_S?��J�\��Մ�����\�p���=�i���T���N2��O;�z7�0�����h/`5���u/�%7��Ge���f���ކU��f>P4���{����7�X a���k$*FC����W�Q��YlP��]_��:yU��Q��[L������5�����89?��t�=]xG'�X�=ȀD���-�;��ƴ��n��i����J��������fS��]����v9�e��.�f�P7/ZU�����)a��x�)�v�~����U3w����&�~\���gY��x��gB��^0E�Z@�Q�R�A�e��U�;C�y�8x�]9�3�w❄��NW�����I�h��*#����/#S7l!!,'��Qe���郓"@�[�7�����j�D�ٌV�-�@kC��^���d�H�H�Mp�T�C���3"߻܈�H�3.T$y�-u��d��M3�,�T`�7�8n����V��MO\'���eܰ	����T'0ȶ�z���S�hvE��?_EY&�ʋ,�oʣNƌ�Lr�o��� �J9��~�;��j�6V�~]Ab�$�@ͻ�(@_Ә���<�sL�*z�ai-���]i���Z��V�>��i_1C�I|���_:�5�"�w=�ף��[��4Å�R}o��7n>x�����v֘Zz����h8�����#��ą�I�;O�T�㸩��)��^����m�eU���Υm-K�x��+�<;n���%�!h�<s16���,���}%�������X�a�az�Qz)�3�.J^1�)�0QoQ��j��P�J���c�i\9@�G�W<��1�ў�Ci�UpJ��ӹ>� �Yϫ
��5�6�"}��8��TK����Z�����
�a5�ӹ��W(��q���G��S8���/����k,�\T��N��"�mv*��B�(V��J�	E���]���H��P�tF�cJ�r:�=�?���HS�f���r�JZM�j�d�)�74UZU�8e���	x������ԇ؜�\�_���4���\UE�޽*��P��C��G�t���1\M�u1�@��}6�/�`!��M@���� [92��ԝ*Im���S�qvO�Ð�-�E6)Jg����&����oZ���CX��v�e|�*Ϫ�;����ؒ�rd�j}��$�FaУy�'��o!rn�I���EI�)
���_LP�@�ؠ�a�������WU����1�����Daw�����3�(��ඝ���Z �0��|%��8R1�!����>�b�l`���
��%���ʵ�M�A�(,��3�T�B0�4�����0�7=;�;��Z;�zMLҠi�<�.�X�U� ��ma�p����m���[B�-ٗ`��p�t����I=ԆE�{ԑ�o2�+��I��}��q^�ϊ��r�Rc��Nƙ�5��HP̺<c��?�?p�Pʹ� 4�G��̛��_�]�������)�"L矝"Ouf\f���ۏP:�ۓq�SP�޻�gٔ0_�-yHl�k(� �
�r�4fy����1#d�SKQ�zN~aT�!% �Õj�ev�f6�P����'%?%�E��aM:���=�I��n���"O��t��`�IS������7���i3������!�Xz�Pj���Q��n^��~RN\0��r�Z���)�K�_!쎣���%����8�{�+�O���q-}�4��@����X[f��J;S<���Y�q�)�B��du��ƍ�:�j/n'�W4��M�{�����r�lL�mp��P|��ț]�I�\��\%�DuVͯ��8Ne�X��OH�"��5Εd(�@d�����%�T	�Т�����V�6<Z
�%u6_�0y��(���_i��mճ �'|��Ց�~�T~���/�`�w߶Gi�$��B-ˋP��Ux�蕋��7
"�%��~d�*jPU�eVM�˨��}�������V#�/5��Ɔr���#�#I�UE������@^�W���*�^kВ/"��eɪ����nk������Z�T��W�]�C���5�ePZ�ǳ�s��6�_�dT�4j�E�Մ�ÒFYݗI8;fE��*EQ%��n݌	���e �	�����:�v�V�����    6
 x=�rw��nzѽ�<�uD��菢H��j��px��{;mdye�#�M�����
��J#�t~�)x{��s9�+T8��)rޏ��Z�{�:��A%xp��N�!'��u�Q�:?	톾"f'K�Z�/W2Ĩn�2��(��0jw�bn�!t�������u)0`#�^�g[��*J���=�(�*���z��>?yh�89�i��Hwe2P�Q�b'旵�8C�lT6W�DPˮR�f���ړ�D�p�lr���(/[�͎lƙ
�U�N��L&,�ȁ�/Rz��66U�G�l�X�#�{^��W�r�p�n1�b(>;b�0S�J�G����?�JC��/,�P��:��B�V�0.F������S[�T����ǦH�+��8��-C�fV�6ךT�x�a��N_�����J�H���<�X|n���T)��A����l����'_�B��+�S���ʦ��K����y�a)\ϖPVG4U�Zӱ����SI��q�OqfO�]e���=!E��"�(��1]�����4�."�ʩ��>:�&����nP�G.gA
#������`2G�&dbN���7��p�������&�i��i���.�y��Ht����,C0 A��e�``{�(�AƄ�-�5Z9(S<{5����'�8��	����#݀;^��)�N���*�k�nT�$86}E��MwSuي8%����q���|f��)DU���CEaZə���X�Ц�QD���NrH�E3� �'GN�%�_�M]���չ{�RT�Y4{gci@�Ta<
��T������s�"Q�v�᭕ˁO���v M;;Lqh�t)aJ�����0��F���Ձ��Ƕ'����+0��� Cis�hՠԚ�8M.����1Du�$���6�Y\��V��{3Yq�6/�x����^)K��!�O���B?C�@�Vۇ.7!k����op�é78�:}r�a�e#-	i~J+R��H�=gg� �}$Z��o�&4�H3?ZET���~N�����lL��	FL���~��i��i�a����e��b��ԋ<�ma�N<;zi\�j�aܸ=�9�n��`G���)+gc�RjXN)-j{���SCZTy��W�=#��RU���Obۧ�bs �t�����4ԟk>�k���ri��Ȣp~5�Ŷ��U�W�aSGN�����^{��^��Xkk¾��'d�}[Ea�*@^����Eޡ�N�v�B�d�+�-5�H��"��a�O��c���.	d>�Ք⨮�E�[eU<���2�*�hw�34�  �^�o�(�sh��B�L;R�gw���+��/�-᧫��^��>��t8����}���1�C�,��(~S[@I/ߜƁc�z4�^�'����B&_6(����{\dE��$�S�ݣ�6J�F�9y�	��6�����,������.>�C���W���S�tnr��ٚql�b&�j��Wr��qX�#1�?*�p�+�{�T{Mߣ+�29����_g'��wߙ�Q�����dc��<��1��Xt�oĮ���M�B
��tE�I�@��w�'���!���2�����,W�ڜkے��Y���˕A�������6GΤ�=Ǡ��j��]�8j�������4�w�t6Q� p��,^m]Ol%*��X�֡F27fӈ�j��B�Z6Ze��&Zy�g2���`b�����>z����������VC�P�4��=��,ƼȟD�S"Q-W[-ˋ�0n�zvT�(�KV�a�3F{y�Tq��\����9�$�-���BxZ��#��j�K-����ٺg6�E�K���h�����[*��R�H���QDN	�qH�u�7�Gi$��N{|���>��V3Km��4J�{kdq��l�m͂G�~qD<�9z�j�*��� �JY�ip~�u�^��8ORK�?��R�|�2APW�{X���UZ$���i$Oh�`>|�dM���x������G���)w��3
����킩̨�x�v�m��Uο����D�x��A���n�d��m#��" ��jzЋUt/�Q��~�y����Z���W��m�'��(�ח@f~`E�#MG?���#�E�,dͭ�0V�:�s�M>�"Q�_�N�_���G�I2MM��b'�����츦iRigC*��>J���q��G66��d�Lc
��Q���ul�?��$5_�4��׺�U�EY�HD�"��ї��&���`r.�O_w�ڌ`e[�� ��!�)�K��VҶ��ϫi�G[~>�(��\���I�&��K��,�!��2�|�4�yu�O�I��a����B٤8��A��f�����о���ݖ�T��V+H�چ�ES%��
*�0�3ZE'O��hI�[/�2a�a�4�:*Һ��_)#�j��m��2)�|~��gE.��*��Ƌn�D�O��ϭ�8�����"���;,�6<^��Yj��m���[����$
>�٪��dpI;�z#{�i<_�Ǎ�L��>^	����N݊�ܽ�i�6��_����&q����~�!�}��9jX�j�@������U����\�U���$	~���R�I�5�P?,�;,�ֳ#���.K#��4����=U��*��t.�}�s��3��@����_`���Rܴ��0����"RRj�Q��f�E�����b/�����t:�j o�}��H�9쨃֊������G�u����$P���%)�7
��W��ج9��U��^}�Od}R�B�Ed�B��W0�����D���E�Km6d��,Ur�������ӭ���ͣ�܋%A}��/��es����-!�G[�y�U���v�[�� mi�աXNI��p��ԥ~��)F\�m��_���*�/����&�@���'�ڤ��E����P���\m��y��1��*7���}�#]s&��#��.�U��h�������·� IWC,%7Yվb�Z�yKjH���e�p���_�S���E
u�7��	��PZ� T��/��jn)f���J3-�
,��n��ϣ���g��Q���Ʌ��D���D:��I��#���a�h�Ai;�>��F�M�F����(�(��(ĠU�Z?�ʒV�<:�$�r
#>��_�+&�yD���(�������W*O�J�j���C��
^�O�q�o�9
�emY��e�W�ט0hRN�` ��Ֆ��QS�J�.���>�
�JÀ���;zBL� ���'���1s��D��u�eqPz��c
?rJH���q�fs 8u��P*:���x����&/���
�u�ZS�K��.��	��Ԗ��q)1~�?�_0��;/����#�n�[՞�if�N��������aCt�j�+��^�OE��w_����3��䪼�����Y�4�3O/����]�'o�9�	����ܼ��W_�Q�E��Ȇ<.�ݧC�g"F>���$��A���0����3S}ws������=��\��TM���MYUe;;���w����������^��Y��Щ��?F5���/�F �n��U;�ޥ�H��J��'��Kft����73��ϙ�v6[�m���fFi��{:'�o�'��*��JZn�Qo75E �l+��r�a��/���P��]�W�7��9�3�7�Y�` :Y��y���vJ�ld�f����k��X>�	���8MO��h��
(*gl��E,N/�Ǯ�<���,7P���t�8�E�ǹ҄c��w�0P)�'�s<����Pb���]�:�����R�mq+)a�n|�L����f�|?H����H��@�� �PJ��VY�F��!<�	�f���%���G���Rj[D�ƥY��I������3��ʩ����^�)���""��3F|WSqYl�ڞ��g�)K�"�J��g��u�1�R/�*]m޴��.�Cd/e��0�C�.%-l:=�U5Oa��Ċڭ�z��x�i�����LV�2� �^�7^
��Dy���Gy9�GZ�"�g_�ﺾx2�����-&J�t���=����Z�=^�,�D�����T^$Y%    s��
DSStt���>�j��m١>n>��	�ʏj~:"��TOQ\ȥ����u��I`>��	���������83}=?Gq��r�0�m�B1�W����"�)5o�ɱ�@���a�W�նߋ�U[P�gh�X�i�	3�u7T�x��+<J4?-t�B���O��T�#ZMݻF�!��G)���~���ö}�GE�-l��s��К8�/�m�Q).�nlőw�3ηvaj5$)J���WaVSO���a�Q�l�qz�����=���<d[��E�V�7�۶���	�Qz_�S��p
,��W~F���Gx5}��XpIRdMjf�2��R��,�Á �/] �$���H�KK�2�!:�M�cE�j�?�	�[����~\�$}5�~;��\�˗��d����=m�`FmH��@�`��Ƌ�
a��y�6��������`%I�8N���=�i���D8
�|2�9�]8�u�9�[no�@q�L��+_��"K>&o���[M����ej�,����u��<V}�,�R�^ ��Lj����XPþ��݋A&Ym/�+B��U%S�,�S��+	�'Z�R?$sb^��L�8�r�p��z����<*���}җ�42ۯA��r���W�d{�A
��Az}�1\}r>L���z����B�l�H����2x�;��!�s�d�O]�-3����h&S���WL#����K���"L�h�]�ò���U�BR��O��W��*P�\�޶F%)ʨ��!�݅��\�Cx��M[Mg1��dV��lD5a�>����D_πJ�A�O��m�rcܤ�:��$*�TQ�Q�U��ooK��"�w_ڀp����9��,�މ.)���-�`�U�-M�e��
<�fH��VB-��ՄW$U���$��i"��U2�Mt��q�_�dF���~7�?)����8s���F�X��lk v*�j,��^��l���6�E�+�$O��LO�Q�W{=Ԥ~�����9���ip"u�J�'a��P�-�֥������O���=1*�ø~E���+�H͟g6i��̵�jP	��b 8٤�������zU?�ӻO%MX�i<;ryR��_�̕��劧^�=;���g?�B�M._0��<�A����ǀ�f�#��?)�:9�7؞�|����r�}b�{P�3�ŭM�E���D6��WEgLjh/�/��������?zp��?�����Ѕ�^$�"x~qo[�{���C���2�A7m��E�� �.0$'�s`�l�U�e���l[������%4u����˫2*�����ךB��l��9�s~��8P�$3�kz�zԏ�9��v�ԫʋ��XM�,l��)��s7O�!��@W4���U�Ja�h�Q&���s�0�i��j��ˍ�ۮ
�vv�ʨr��"ފ� ��=ƕX���(���8�.���k%��4��灲�3ŻQ���T��n�@�T�ׯb�~����C]�S��.���_f�+!TAV��>x�$V���! :f������HEo����z���B�6Zi�C��-��a�y�*�{�ab�,o�7_U4	U@��&"�\Ѩ�������|��Σ������M;���>�q���+���')�k؋��Ԏ�^�s��vRr�~�ͬi����ʅtl������pU� ���F)��4�����V�J��������mkvS3�㓹�MB���l���V����< BZ]�N~��r��p_�$��a�� ��u+���n��A[���	�Ej�Ծ�Ua��,*���-7���zɭ�O\>�u�-��ב��������v��i�h�C�K3@�4lQ��.�C��O��vO{�~�:f�k�
��:��a[�	X
��FEG��Xf�"�*�B[���Ch���z�B�Ѕ�ۋ�Q@��h� ���0�s-\��	�{f�J�;�!�������G1��<���mLA"�w���:�!bPݽ�YY;�/(�ȵ/(�� 4$k�w+��i{&�6-#��&�'��H�F4�> �w��JcSe��s��y�I���ܜ�"���$�������5�8�"�w?}L�����Zbn�(�L�_�D��m�#�¿��6F>�|�x��C���`%���z�Gp��ji��d��_^%��E�i��T~�`{���	�`��
��O�b�D-HZRKM�G=������M$��:�_ ?�t�ROЫU7�	��+���������T�tA���˓ �	Tq�ɏ����8� T6��뇧'AC��4��P��sh�p�Qlr��:�U{�$�}Q�9��"�yQ5xjv�WP}�|x�$���p@�l��G2�{k�4-:{uf����Pots'�6��N$�P\Z(0��隁v�h5���p�i��X��Q��.?���/uAwqD���y��4+��)�8+��/��2{�ʢ�؛'���>�F�4)�kZ�9����&t����j+��$��<�L1���4^*��,�?H���g�|y��ΆH����S&=�A�/�E��A0he�1�@������:/���S��n��*x�u���t���9��S��[����(��0��cj�-��Di��O�l�0�DQ��E��$�3���xԑԌ��b�;l��Jo�\_����������I��m�ԡ����b+\ �@1Gb2��_��ܐ%�Q�����	��W3�R�� ��^o�\���cg�u������A?�z��}���몞?O�¼���Va𳨯N��ѢA���FF��U~���Ý~�V����ޢn�f���ʪHAIU|%��Nan$�r��	%c���9����ޙK?o��-8�2N�U�vP�|\�_��*���!b�M�*�X�?8��k>TV�s��b7��;s��8:�]�� x�m�����Ej���ٵ�^^�
��������P�N�^|�����/�X��w��M�xC�p@����U��E;;dQ�Ǌ���Q��� y��M�P���؜*��U6d���:��ͺe��$y7�`�K���i��UwImf��$�0k@����|?����Gt[�t��b)D`ZG&��k��aU�(]���o���3M`{�|����u��������̆3BM����~�Gi,Ӥ�~�c�QqO�8Tg*;��ʉ�w
o�TTh�w��� Q��^��~�a�͏����^�ok��|赲p��ؽ��r�S{o�+w}����	�n�����0[�����U���a)M���]w2��K�*����OB�{��p�"G�&-Kƿ��r5��b��6j�~~�L�(�Bɤtx19?���Nv��Ș�bᝨj�v�X��#�#RԾ��>��D���]X��(v����\c��׽�"G��h��E�w�&��b'E-��-�[@S�:�{	�+��̿�Y^e2�?f|���6��Ţ����5>�z4`�y��0�r�n�q�up!dz�4��j�K�Ү��l~X�#�Ԗz���pҤ��So�#6�h��p��?�6rV�� ��A�T���8��4q�Y��t����-gYBd�c���X�о�Ƽ�� A.�h�t6��]w�Maz�3c�Jg���F���<P�x���,���O7�X���b�G_L!ՈW	�0iG������蒺��BE��OY�r���Ӂ=z+d"�����9�W'(k��T���5�ze~`��~�J�,7�~�8���;��h�L41ST�x���{�7�����=�oFhe2�q[�Q���� �[�uv�J�`��|��3%��5�*��-���P_8?���|�=rp6��%��1�D�D0\����r��ݕ� �p���iT�m�\Dh��.ol�[On����R�d�e^̿���t���T��g`��g:����d�E�:n١��Ϣ�������_������ǟ�2�J��������q�{xA_)" r�'"I�p�פvߜ��
�2{�� R�����y'Xq��e1���� �+9�D5����oX4�Ș>ߎNk�����*��v;#�`'|O��r!w1N�E��UF*�A�������(��
~C    �?ͭ��$;{j�G�����-�@6~3
���m��3u��2[\�j�֢=Ҷ)
=�U�]��n�"gX��(wWs����G��BBc�V}_�<�Ea��CU�.�����S���L�)i4����9�a�����w8�������3����k�Ww����b՘��Ȫ,Ux�F8�MҙӟC-
b(��RmQ�bp�����lx4�9ʽT�w�n|vΏ�<W�ڗ�g��7��	T�(���Gq���	�o�-�����xp�lj��^C��³*��@&=�/ Vy8����]}���Y�uTY�c�1?�EU�.�I 뗽�G$�rp	��AS V^?ľ	������CM��`��e��g%�y|#��N�삂�Ψ�F?<ԝq�,��3�K�9?{W@�t�T����a���IU�b�Xz(�l���.�8I1�"�1�0Z��%Og��׶����#��g@�[�.�T���f�g��^��&�M��զ�g,J�O�O�Dge�$}bCC�(}���BԴ�U�)��I�77�z2w}/��ag:� �+�"v�3~1؊���0\/���pqB�Y�J��g�kہ�	-pd7�mY��oOO�&�o�����mE��kg��6�q�f���y�1�$i�,�Gxp�����#���ñ�"q��"����.b|�	s����q8>�1��<^&��x�
Q���+pܮ����
:��̽�����G�w�<���R<^D�vq�h�3�����4~�md�� r����h����R�n�q[��s�E}��Ȉ�&�7��lmK�B~�+YK�*v]D����sFd�g}��j�B�D�ș�1o�¿
A����+|;>����1���^�����_��Q�e��:K����Qe6��I��;�jx�ŤY��*��;I\�ٴ҃['�%l�)q&��е�/�E�߿)�
��Q��4�N
-j�a��j��ۙ<�_E^�_��T���@MZY��w>������6�.����kp�5	Y
{юD�ڃ~$�$���s�3�$מ�*�o�y� �($C*dDԹ�z���pDDU���*��+�bj'��P)���5��_�)�5�\OO����R�B$N:�P}tM�֟a Xc�PY���C4��>�t�EX"l�(�#L�����~���oHG?�)p��u�R,����oϿ 
_ٛPw���	�S��@��>��Gd�6Ii�5�J�G�#�H�I8A���\MQ�/�]�B����h�Z��)OU�۠�G���	v��z�Q�^�𲥿�/��z��ַ�Ns5)��f	�ie�ڶ�g�|4�3K>
�C�'��pڼ����~a?�`$��bZ�:q�v��ԋk5�R���t��;w�a���	H���y���AOG4A��Ϫ�����n*W&�+3��X�K4:E���L/�PeR�C2�^ �m�{z�(��K�?���Ր�C��e�κ�`��2�o:Ù*�,�(���/I��Y�" vB��'t � ��^Q2>���)�'Ws;>����b�>��\5���M]�2��*���lA��|]�d
B�}sB��5�t������jm��Ѫ�ί�k�k���D�E&��9��O�����|d_Ң��#�I���3\�jڨK�!U�����҅w�N������mĐ@�
>�w�*O&^J��_���@B�]bnVS�Z�N�r�����]�|�C�ܪ��R' %��}#�W	�<���g�f�?۵��j�.����_Į�r�j���cy=�����"z<���g��Vn4}��թ�Q��H�OB>��^�K�q��0r|���R	US������(��/2�`�z(��R���2��sҵu�ov/��IG������Hi�倦��+&�ηb���E�|b��!ª�;8��JiE6�:��@b%=m_H3��s���2��-F�}�ڲ���dh����(�7]�E*�����ä���)M�:�O���w�:Wco��?
���o^�j�-̏���BV��g�]uf�!��D�
�H�����q(�O��Ƙ��q�����׺��=s��﯈�GK���Ϳ�@����CՇ�� ����:�Hx8ِ��,�jo�bc���(��ӗU�+CtM���%H<p@�e�F�/5h�?G2�����D4��{ǅ��9-���A��$�z���,�iץ�/G� �6^��g���xi\�7���Orw�d�����a�M�dnޑ���nt�����!H6����ӂ���b�{��ȵ(����͋V��jk;?>�ڰ�(\�K��UF�qO��! vZT����w�*��������Զ�_|��P��\������-���Z?�i��i�� 9��y�����Z ����`TQV�Ok�A�R���0�b����o0�2��e������|���O��;�R:�c/F-��E0�
4&��r�!��-�CB����Y%��D��k�ĩĖ�YĬ�mZ~�_���^;=����� �M:U(9���!�{7�W���n9��U����!�ś߀�[/"����W�0e*�< ���W6���A�؋����>ؙ
�_�2T:HH)w<�M�;���7?Ֆ�-s��%��&�Љ�M�ZF�EL�┠�n��5i�w��[�.�JY$���'��|@RJ��6m`L�%�'�稚B�i�a���&.)ۅ��ti�`�.$EH�S��?��	s���4��Y���uc���_(��yb��Y/!�N+���*m�9'%MPQ$,�q�	J�4�zZ�E3�����;��*�K˛�7i�ֳWa��UufuP��;���A�4
�N)�{��ov2����?�p���W���n)�E��"\��$���=���� M��|"���Y�V���(�< վ�&#�/�H��ճrV"z���sE.E�#�k|��_ӓ2�;�����g=YUNb�χ+��2)aE&P����m|�zu�2Q�9�5QIV܄�o��`����U�k�A������d��NxbN�l'����Wv�Z<+�-����,o`�7��^�TEZ�������:�:A��<�l��%^K��(�aW���M/�u`�3�k���klM֗u>�-7���-��\�+C	-sIe�"�ccn^���e���æ�,R�{��&?_���-��8a�+M`g�{[�Y�P��3r�y[,&Le�֖��Ϋvy\��.yל��/rd�>�Q�� %���At����8�[��G�ډ[�j+�.��q�Ea*�[�&�j�bw���À<E�"Q�5�@�/n�o[������PJ�� �t����VHk|͗.O���x@<�oi�Ue�E�<��F䊎ǩ$'1(���]�:��É���K�!Ft�\+���XJ/��1H��./� �r�y�(��r�gL���J����� ��)�YYv�jզ4���K��-Y*j���y����j���7fD����u��E2D9d��se�@Ո��Gh��Y`C��:R�s�����o���g�B�ڢ��Ð�g�W�,���|f�W��ͺ���4~a����3|���Xp�H v�w���@__{T?c�ʛW���T�͞�w �Z�U&�����i
K�6�6�L�8(���2fU����Rʘ�dM1{���U�������GY�3�)�ۇQ�_���u--��B���)2�&��_m3���nlo��od�*l+��p��@H�r��6ǫ3�E+ٞ�����v}�b�������E}�m��`>�Ղ��-2��[�����r6�%�[�SxN�=҆���}���d�Sȅ��x.W1N��Vp�]�\J4�Ե��aH���gM�)4��^��=f�B7��pPy\�g�Fa1n�������}��5��,�|Pt��QF�q���`|�+F�t
(� <���	�j�ًql�5�8|E�o�5{�<@#�����1�A� :XW��ʙ��ad$���?� !�q����v�����j�����2-�<�R�5����(�������-
s���E�b����j2�    k�]ն�x>l��Z��R��e�O"4t�!��8� ��a�Օ�m2���.�Y��o��Q�M���hv�ri�����2J�1�jK%[R��բ��6�)�k柭���iibL0v��%\���a������or�	���Q�����[�����B�R�A�g�����4MߘWDؔU�hb��`�Ӥ�S#���O�~~�AI?�n������4��cV�Y$��M~��!�_������+&�./�8�w�k�u:s3.y#�r�prz��� ,մ`\V30[��:S��[[�4դX�ɯxgP�U5��탡L�DZV�B��V�Z1bb��j�R�z�/�"�_x�4sFk�:K�b�L-�e���#vL���c��m~��ZƱo�)��C�]x���hL�Q�̐����7~���p��u�'ʠ!: "5�k�:�yv������|HN�.`�s�c�X����ۼ���46�b? ad��������4�\-�,w�
�L~��(J<�����2R0�PE�L�e �0^��*,�X��n����ʋ�ӺJ>� ��ٞ#Fh2ʂ������u�򝪿Q#N�3��͛�׸0�W��&�2ɟt�������N0��|~b\�=���d�V[,�Q���l�rv�
[F˺N>�� o�q ~2d9��#�ɧ�I����yW�:�]>[��+�������N�/�1�R�ߴ�:2,������̚z~X��ց�W�d�8St!��C{����fW�%/�{Xm�7�/��6�Ӓ�R�L/T5|*V��p��V��6o���� �'���ot_�e��V�*�LQFJ�͒�(#aI!L���^Pg�a��#P�'Z�Az��0op��|Z�]Z�+Pc��igls]��<�e~��	"����C�ހ}�����2����]����u��r��Pi+�S4����|i"�D�|���p���>nF��D ��AQ�PN?FK�L�� ���_���}U��i8<�Y1p�J8S�P#���EyO쇮J����E�v�+�xh�+�(�_��d�.����@�MH�8����ע�9��]F��߰�PF��N Ʀ<�7��M��v~[c��~��L~��ĴP>�G�b/�� 2�B#��قq�)��fˤi�ۿ�M]�r�\�b8�啭��PM��t�`���R��Z�h��pj�܋l�U���oFg�fv��g�ӱ&���4(����ԓ�+��Ht���o�%�����j˝�вE2Z9�bu��jb�N~ !񰏒��Ķd"Fo�=@~��1�d/O�5n_(�O^;9E����E%<�Ymq�X�k��̞��W,�LP��6Q�[��DW��w."/��c�\k-� �����ݸ�=���>O���u��j�a�u���q�ETo�.�	sB����UP��[̈��&K����imfG$+�&qi��EJ3�L������n/E͇iH��.4,MH?�����x~�m�_ug�D���i�k�f���x"�9��+9�QW��n��NR�K�r#��F`�Ŋ�ݣ��1b��H)`��/���ɣ~�\�
d`��^n�w�����9�{n��FY:���"*���/#'򦔢��K@ugƹb<�����"�]c�n�5�9cy�e�O��D�i$y�W��"���H�0Q?�TE��?��$���ͦ2�T�� ����Pΐ�${k�M��*�?��]��=���0���/ �ì��Dޕ�?����X$���Q{I��H�#��߄��4�n�;V^�J�i/�Y�S��c��]({q�I<�����~�,��B�S��uCwR/v0
��%|�3����;�����r���k��?�y�\�����pf�}oq�]w������Ryf��F�etsPf�#��0�<���G�~��\��r��oX�6��y�H�"/v�|��	��a'�
���,
���q!A�2�Iq��`i����_-6�m�������E�#W&��=��a���ZO[0R����8� r�p�+ӧ���p� �ێu�[k㷜�b��e��cY�*��*����F\X��f� S�+S%��g����{۾"2�9�;�[7<���:WEC�o\�A����}�����q��`S]w�R�1\Mp1 Lݧu��i�*��۴��7>�kK�G�!Ytb�A=�Z]&��ݙ���K}�1�=g�2F�O��&���?|�]��_}�e4����@��p��&	���mc*3;*&�sqf�K>��Nq�qf�p�
��INW��Z�nZ�b=��5�Րz�ywԽ��j��g�碯�����c-u����M���
�!JzϨe�4�|�C��>7����#�]�^ _�JѾ?�t�O���gO��h��
�����@�>�'&b��N�U���B���iPm>@3tub�`�KF��
%��
ݯ�v��l`� �gl'`�'vX�Gy/�"u]�D/�մ��kYی�s�1��"��rWDr���C<�b��c�W {0�{���*����`h���ٱ��Z����?��1!i�A�:_h��t��R��������4�%% ��Ex�n5-�1�>�1��.��e�4�ҘA�s{R��(��1H��>�>�J����T�2����Vð/�!s��5[��_�sA��J��W��p&ݐ��=�~0���5[�8�fa���c�!I��7�|<7�:aS��g/�\n+u���"y\%����rd�C$H���;E
<Sˀ�����q���َ+�.��w��6�˾�!:�nY�[���Dզzs2
��Wv(����Uܼ΂�ڲ���b����*�U�������K\g��E���#�W�-��6oI5�U�.(��i��%�Ȯ��]L��e9��S��d�*m�R����ȏ�:y�2�s3]z�8Qw[ٶ�}��Opm�SZJ��(�����^2}��\�Jп��0?U�O?�Uu��p�j&"�_`����| �ݖ�%آ,j;����̅�Y�& ��=�P��ְ��D�{ZR�4T�7�9H��m~	��1���a0�����ۢ��n���[��%o!�vt�y���?�L��8������
 *�8~����q�7�CiK��������D��3��s�)C��W�����?�`!���X���.u��yԝ-G�T��h�C��,K�<`��,���߈E�*�w�㑻�/pw��,r��!�����oge��Y���RF�,O���t�	G-d�w���:�~Wv4��P@G,��~!i�ޡ����v��
����Z�3h?�4Vy�*�4�
��(��K�D��/�ج��K����XQaw1+�Nd�oa�X�����̚>�_QQ�D��X�ɇA,�	�C���
�r�>���x���$(�@��*ץ�f+�Tw&���i����,�Q�=l��2=�x|�J�O����Q�VP���
f�4�U�
����|f�yB=fM�h�*�Fe�I"8�  �)M�����Y�%��rܠܸ�V�g��b!.�8�Vs&_
`���z��W�"�!��۸�'��Y��A��h9pPw�IW ^�/��9§BV
��d���i�	_n�cE��.�3!L��?U�����Qȕ��0Pa�-@lT��:V��4h�?�U�����?v�5���g�1�f��Ԡ"F���s��%h��X�}s�%1�gQ
�WI# �n��a�A<ͷ�\�g���g��6����/�1i'>���ϋ`6���Ig2.�E����Gh�X��x��-���(��غ�Vb~���꓆��Ǒ��Gl�@ ��K#_Ȑ�$&[���F9$>��PPK��[�Y��g�͙̅J%��H.�`�N�а��|>�bQ+�������eQt<8���U�|�9Qݞ���rr?Q�}��и@l3�(�\�[^P[�};�k�π|$�8\>�f�.Sa|(���N$ե��ߋlr�POk3����@ٙP�>�*D N�XX�{�
�OV�P4�Y��l�B�'�[��T��p� M�Lc��㯻�%�F�䃎�xRW#�.��m�n>�%�Sk�    #���l�Λ��s��N�"X>LD}�}�7qF�Fz�v�:�|~���]�T�|5հQ�J�C��0��7�
� ��s�8�g�V��.ׅt�Йtv��:�SE���pG�6o�K �=��-X0�;_m���$�r\�}�׳�./�l�,/�7]w��`5R���������<_E�,D��O@=�m2�P:c�БJ5����|�"�A����j1�a�|�����VR�1nT�1�n��0U����4R`ؾ�*�븥5g)!�P���ӻ�ާ��Y����K���]�0��w���Z����?�q�^��=�3;�M��V%T�"��|
���8��X�EV��a^ܼX���>���"36@=�*y�{,V�0<I!�\z!;�;�����/Sm/��3h	THӇ+�;�DC%l��|�OA
J�YX,��G��lP_��z�ٮ&�1tx-�TAm��.�'Q�F�z"'ȓ�Y�tZ�P]�;�S�@v�8@�#8�ioЉ'�J���U�"�v+�崧qGh�B�����!Åo�O��Fq����{����_��@��h���U��ѧ�b�<���;,ۡ�m7�Z�.�lr����E�@U�ܭP���E޻�S�u?Q�"������{(ߌ�DH�r������j���:�q&e����=�}�#���^�/��O�<�Ϸ�Uu��V�Z
��tc33mK�n|Y�&A�M5Xb����A �xO��R�q%������$�C�	�^k����E�9V��_��em*-̋,�A
����2�C���O�tC��W�ѿ�(I|���������֪90s�s�8��,�4ty�ƿ��BOU��9F_Z��_qg9\D���Iq�?��B���+��e��1�R~��w5DG�.��Jpx�F��	�I�'�y�oW4�i����J�gE��~#e�{8��'b݁�fO�K��o ����KEq��B��������]]Q%���������i��}
R�^�Zu˒�� 3l�"H�J��]��{��}dtW�.6�u������.�a���5�;o>����i���yD��v�����B<��o�u�øU7��vU���"�5�F�\G�E��˴G���K�IBa�7{`9w��i�4��Ls�d�q3��S��[3�E3;n�g���>[�h(hT�`�+*LQ�'ԛ����L�����%耍��*w��z:�����Ũ���n�B�#�����/ǧܜNDja�؃?'�U�{�ɷ,H��L�ËlW:{�;gڼ��١�^�3e�|k��C��E��8b �-�VSoY���3�̶E�A�E�F�Y�%_dP:���z7�C�Q]j��L�"L&��Q)�g���d�
D"]���17��S�����U5vv\�ֆ�̓�0�a3�i�M�= �4m!���1r:�j��tr�|�;»8���:d�Lea�<-�|fb��q襭Cd*>���'���D]�`Q��$$�3�6 `hlw��?���R��G Bd������bx�s�EwࡏP�F�r=a?�Q�i�!Uǭ$��>��{e�*~a�>����֝��,��@g���~�W+�؋+/L�s�F��Y�ja1� g۱ŝW��ԲL>A�If��d˫�Ʊ�X̝8N��:�KtI����˅2�G���N�5Q�Iߒ�G��u�0��o�S�P.�	T�:����I�G��� 5�H�A�I�߈�]�ak-z�D��1,!!u��$�2JW�Y�(�m}��_^���>)Tм��_��ۘ(xs&�C��� 8�鰥�&����g\�C���מ�tqR�ȂDVeԝ��9�͢����Z�{������NpΌ����W�K+ŔU�S�<JW5_��j�u�à���z|V##.6�rc_����"��J��[MŕF���\�!�1�N��������_*(˄dQ'�ݭæ/��H��.���&���8<��J�5�f���b�E3��EЬ�B��ہ��z|����^��m�3���q���N���|>��n5\[��2=mk�j�n}Wu��x�t��� 9@�D�ş#(����җZ��c�Vc�-���!��WVmk�dU��ى �.����7�]�Q��9J�D�5���^4#�$g��#�\g:k翤��WP� |�m5Y�kA<6	\)�T�Q8�w|kL����!M���Nkm�U9���q�W�, +�WJ��.��(#`�w7�<�K�/C��F�\���ˢ���\�"��wYO�L�즱��f��S���" L��O��g�VS�\�!���0��'"Φ6��*Urh�؁�T:O�W�	���h�q�	�ք�m�1c�V��������.5|~+�*�g�f�8z�ߑyE6��ш�aY��_n�:��P�",6ʹ �L�-A�~v:��k[IB5��i}���)���Bړ@L	�d�ת0�{+�<�����.�'����N���D�E�b����i@������T���w	G�y�HYC���y�&U�������SRS�R�%0����_�(��",��S����k~6�J|<h;Pի]n�5����͎W�{�@�\"�K��:�Y��Q`'C��I>�QZM�o��E����-���U�6M��6`�܈ < H���D)�����P�s�7�^���BH��c_�PQe���d�*y�!2���p�������o��/#9ܿ�-���ޝ>ث�S�����q�l�$2WV�6�&O�c�Gְh������m�e�v�l5퀲o�%ʭ&�[�ο�˲̵�7E����S=F!D��
��KFi2m~L~���&w���Қ��f���Y��{Mx��Γw�.�b�i��p��
V���-�:\D�3v�lq�2�M��e7�(��"4(S%�dYw5(��z؁V�W6������	PN:(�U��9��R5��j���1����|��aܜ؛���{!J�3���÷��,v���<?�m~4Opm8�aR!���k�m�#l��������g"��Z�H=�;�LJs|v*n�Y�,��G��-����I��G�F�ωg	�m4�@t@Wp����B�~FG��ɏq8�Ŏl8��S���|���5�i�N�\�A�-\�<�&�p����]4��iV�ssl��t�����i,Q����ׯH��Du�權*"Q����,R'砖{����T5������?S�3�����,���m�F9`7
�۞�����n�cP-N$�� �޿B8�D�9~�$�z���Y�Q��[�8�1�=��#�+�^���Z�S�O���ܢ�����:����Mv���s@� �4M�C��s8	��Y-5w\A����)57ohДU�Φ5�S���jXx�r���ډ�+����±X6.;����u��\�y��S�ƞNү�? ����j���W�L܍��a	`����UQ�����6��*�N}[���ѼA���gٯ�vC�E�j���@զ����E%�~y�G�(�,i��"̒L�2�Z����Rఊ��}�W#5e��&�1E�U�o%�l�0�y�Qܴ��UA�A5: �������ѱ�ڧ7�������Է�ڇՅ`M�:{#~�d�yT[�?�`���Y�k5O��4�3v6��\i�@���D]�6�Ap��qf}��˧���jw!���@9=x�j9h��)��h�X9�gm~T��IԆ���
������_A�@"��5M�q���Z�������0��L<�6?�g����H�J@� �;ҍ��M 5V�'Z<���xd]}��sQũ�e�[,���G)-5 ,�Z
{||�v	ҏ�"anԪ�6Բ���z�KD
��XM�{)4RSW]��o��5&ӡU]%o1��"v���;�H��d6���+�۷��E�6 ��x�S���1Eĉu�F�mp�����ʺ��+���G�����0����0�C|���ʇ���R�lx?'�0������B	E$�l�9ќB"/&�w�zҽL`�B%�;N�?��W ~�w�i����Fi�/>��*oma/�QA�B���|y���2��Z    Q�zx ��n�?�lf���Z�7ƕ�صI�s<��r�5�Ai��8@s>����a#.Q\��
"j^��Q[W�%���2���5�#j���`:.��:;��I,��2�Pz{��)��M1�W�]^t���<���֕��8��+H��6���zيgA�KJ�����c@� O��N\׫!;[}7v�r;�5�*�O��Q�&�PE!�Z�ʁ��l
q�������S�7q��wrb��T��6��l��Smn�sĢU譛�O|�H_!_��^d�j� f<ZG��)C���j�A�úZk�\q�����a�2Xw6K>R[���8��t,t��v��}��v���)m7�����������j�I���4	3n�2}K�c3N��+&7Mk�2�����<��"��Xۖ(�-Z�םx�L�1S������A�H^��Ǆ�xL���� ��^X�q�e�[/�*ٴ�M�|~���u�l��O4�gI�ŀ`nX#�(�&��Xn�u�)���cD&�ޞ]������ØϏh��"�lB{Ug��!�yB�{�X��M�D>�}pH���{�6�PVv��^�<�«n�4]4S�Rr؄5_��P{�B�a�&R��V��am�����K!wW�EZhl�N>�Z��qDɳ�z}5��Li���Q���}v��d��ܷ{
3^��vǌ�j�QW��Y�DvmZf�t�K�`>dm·4���K쯯��D�r��_t8G{����AIɴ{������5P��AL��j��b��M��6{��u&�L�K~��)-�,qłn�%�O�����i�5�Vь��y[ɦw�yE_bʪ
 �&o�B�r�I�`_�S��q��+��g���nM>d��g��p#�,�����kx���oq9͋���Z�Vw�j���Z���e7?Ju���4Jy"�W}����P�8�&(�R/.�.�K(��T,��tL̆| �����c׭V]>�u��P�������-�k:�Ƹh�sؒ�4ǸبYA;^�
�G��z�[�d�� W�^.�V��7Q�ϫ���)re��<�ppr����^0<����h�s%���7�:ٌmS5�S�5U����?��D��Lr!��#C���U�paC%Q(x B�)���Vk۲�)U�?�M�C�<7����px��M���+���G�#�;�g�ׄ,մ8��w�K�4&#P��[����K���n~@�L��	��C)+�P=g�����=�ԯ3�^�ͨy�F��o�w>U1AM�G�d`��k��[�n�(�NjV�|����Q����+��7@�U�
>��Q�bM,��1�=E1���E� ����o{���!l�ub ��]X�F�c�e�!��M�_W�<��M�{E�����CW'���M�"A����2�?Ov�R���-K�%��W�7����r@�6�~�?�r.���*Y^f#�#���0�ն Pu���IK
UI�ǭ.�W�������ff��B��\��Ot|���P�o�w��ۉ6k�>��P����g� _��/DK��p�E�5
�|"Bl6UكD���adW��.<m�<3�T;���Rc�%��M~HH�HQ���}ԅ&uR�3Ԭ#=��j�L��3�%��p~x��(��"r���ڔV�a^��OD.R5��,nI��o�_�9_����8�Ф�b�d}�jQ宀u�t�ݓ� �{¾Ge;��N�D{)��� ��:��ZA~�E��o�Q�+|���*���|7+�A�@���2/F<�m�%���:D������-UW"zXd�^K�5|UV�/�������bVA�ROu�|���X?��"s�,?k�KHW�w��c9���\�f���'���Ah�`A%{@�6[��^s�惱y9?��Ϋpc Y|���V�O�����v��7o��o~f���}��ʋL�a�͊����R/?�)2��X���\$\g�n~$j<hE�|h�N)����]�t�����teN� B0��z�Ũ2m1��{�V��ɝF�$o�u"��'�Lu:�;p�>ЧեO�+�/�ǈU7?uo�*��yYH�ʺ*�u_'��{kb�DP��X)���(M4`���������Cp3d��j�R.Qm�5E��ع�Va�<�����,��� � :qq��2R���M��P�ʑ����_S�Fj�����r���쪪/���ti2W���1h�"����M�X����T�\�){��ɶ�m��HU�� 4-di����Eƅ�H�g�=ĶM�ꕏL�mvrk&U>V���)�ޡ'<� ��R��8i��&������`�ѨV�8��a\41�/{���;�=�?�9^������myn��%N���������|Ţ�k�F��c�#[�S�^�0�奇9� Ӈ��:�*��B�����ɹk��ނ�l;?�V%>[�d��٫G<O�>�)�Q匳�6ԻM�L�1)~���þ;���'i�3e1S٢4Z�fy�G��rH}8
�>T.�\��uO���3B�j��>�e�"ڮ��hMV�*��gE�@�kC� ��K�oA[c8�J�(��6T%��ҏ�#DP���B�1�]���7V&�օ���~Ô.�2��4S���yKMX�~d�sd2�F��\�����ڕ��ߠ[���gU��-A�Iu1b2Q��������#����?��yﷶ���y(\&�<�|؞���$�$�?ã�N�&;��{��e�����l-`��OY���Xdu�b� �$��\j����r��=��7S._�8�{!��H����5�L��U�&�n�#�$���`I���� ���*c��#w��R�id��}T�ڿ�B�h��0�:t��cě�$��OE���C���N�5�1��  XBk�F�'b�0�}�q���m9y�����Ť�ړ���(���(�[]a�	ޞ��𨞄��\�]́����Y�b�Mn����
%�3�|����(��!��� 6��Q�.��ҍ��8���4���"�m�
3�s�xd0��ju�b�J;��<2 #l��R��<s�z<��t������a���H��?������5�T�*�y��/�T��o�$Oo[��u��]m����_��0��K�2��,����p��d���g>���׽� b:��K׽2�j"�&h�n���R}\��
U��+ҵntY:>�
�;}I��@���EI���m�D�3�����m�}h���"���knv�����r�����\$�(�2��Ӷ�Ǽ)��A�;N�0(z"�& �X���[���'��� �e@��:�`.N)}��P�rO$�/[A������J��Q���楥-Vs�_8�2W��� ��g������歯�z�uTB?݅,P�@�$T{��F�'�D[NW�"��Z�����tJ0��]@5?��d�p�C�1���<V��=@GTP��}���AA��,r5F���>)�������^!ݻ&k)���tY7���N=O�S�L��r.9��Č y�0�>P!������{T4ca�t~�
Ky��U�J�K6b��t� �#;�9!�!�d�?c��.1�z kf�EB-��X�*]̧�m}-К�Q�R��P"��O��e��^�A)�X�K�&Ge9�n)$�$+�I�s�*�)9�R*
���c`W��F�/�a��a~`�§`��c		�f��/Ac���'�zi֠���;�O���O8����?OH.����Z�s��}[ە�1����>m���C�im�=Q���q�����Ir.o��f���������n^ͻ�\W��oz��N���"M�6��}�\f|��ݿ`%�1�j�a��_7�Y�Փ��-Z�2o��V��4�W�o�5lY"v�"T����a�H����C�,/8���HP?v��j��K�ھ���>?f67V�"O~T@�)ze�"׿�"VGl�tf�`�-+N�����K3�`��Z��G�ᬦA��f�?㱙_�sY8���B	�ύ���Rf�(���O�?l��Z����],<��ġ�4����    ��U� �x�*��t�#�f���-j�頷�Kv��-0ʟ��	�g�/ ����������(�(t�9Ua�)������'Q'�hw���P��㡧������*㡷��7��͊����@��9:�嗫=HT�W7�'j�,��G0Uֻ��V�r�*�gTp��n��t֎A�}V��m!`��p��
*�2�z�Y�b�q�D>�n*�*]ka���!&����e8��k����7$(#s�G���d��F{[�7|�Z̯_K��XSԉ@�@5;���	?����EQ�H��b#fn^Z���_1g�xo�n���M���.������0�j={�U�"����]6��J�4��)\�I־LbGe�L	{S�6�	*ϕ�<��q��)c�^��M�-q�wiV�n���:�2M~B)@���x٧���/��emF�2���Z+��*�.5�X͟^�Ԧa,Tf�L���A�磯�5�r�����]ڎ�8�:0��j���<y#�V=?Z&��8�jHWԙ��X����L?��ܐ���0�?�k�\Mr�)N�eU_Ϳƌ-�L����g����';vܛ���_���[l}��K'/�_W�/����2�A8�T:z��~n�t_���~��JΥ�*]֍e;��}��
1)��_T��ۥη��a?��'��cw�x�~�������.C����q�`�RԊegp˛ty���i~p]���ui�1���=�d�6w�?�kC�;˗�җj�ȸUke��j�.�]�͏��m�B��5=�w��F���6#`Riw�W��/dӟ�ÓjYDD6}��E�}ɻ��އ�P�h�t$n�pGX�b���(^
�8#iA������_�)���A�=�XXwS���4ؖ�3�bT������������p='"T�uD6���@wW�S��$�ۼE[ui�!�UF�4��/����5��I�����|��sv~��f"�V|�P�oJ���;�jk���e�8���7�3�y�%��z�)��R���YJ��|��|���{0/�ǧT�c�+�)�RDh<�=<�P�f���/�D+�_xo�#�h���i�&㸞�R�F]ѥ]:�rs&����E"��$>!�T�=�/>��G����'&G����CYm����+�ax��\�ڨy�'?2-��hi��x9=`��R��)f�]�8�dovL��j<��&@]Y�u5w���_l��O^���+�� �kw�s�BBgD�6X��B�$��j-}�o��g��A3y�U������w#�y�s��S1eeT�Ҹ_�1���l>8��ҴJ�Q����Q�4��cҼ��:�p5����]U7}�͏Ii�*�H�'��	�T��g*�F�I]=L���I�D�XR�}]�鐊on>����8�����m���7���;>��;mfz�
~o���" ��ړ� :�}�Z��p��%��懨�ʽ-l5�z�H^ ��37����d��`��̥g.u�����ɺ��������B�$���53Hm�SKY*������n�O��Q�փ.F�!�W���fFU��E�u�FyI�=��������{;;y�Va�X���H���=�zh�+���|���^94�j��RK�δ�,xE��.�S]�$��8�a#.�n��
�u�Tt��G����ht
����*w�=A��I�x�$|��zo2f��(�c�y�b����D&! S�m���>�_�T@ w�0��Ҥ��o|�g�yw��^_F��- ���ģ�b��&��xc�1�wF�O�j����?e�������15suD�߈�0O��}֘ �}�cQ��`���ZnrQ���-y~W@�V+�&oIN��%�D�����\ �h&dT��K5wuݷ��;��*Wjmb�����h%����@-�}�=&��܁TD��)�|~�[T�����~�ZVN���g���v)6W�c���ꪀ�1y��am�� ��8�+�\6�?���68�F��p=q�&$U��5�jm�RL��c��4\��:	1E��K����<�m��S�@z�2Y�
���oy`��燪�\<�e���Mw��r��2�H���%ޔ�	�!���14�	f5+��ܸ;;�M;���R[��LU	��+)a�|��߹�t(��12�j}|��v�#�ʮ���)u����� "x�1[���@w�O�=q�*K�4��j���@��;7���꺮��5�i������[U�`
�� ���6-K��&	�u'�q���n�d���s� j�U|b�-]�>���h��.MV�A���#%���������ZK|���U�l�y���p�im/���	hR)aˌi}��]S�y>?]�ҟؐ.�q�Vh�.s��m�ͨ�4{�C]�dm:�U6��І�N�0�1��5�T�W�m�FΉH��ȸ����8?Ju��^xu�|Й��0�������	07BWqSv��
���v���-۴�_w�U����'�� ����7�1� S1mJ��DHċ�~�{յ/����q�o�۪vAS��Z�F[��6c=��L��.t5_I�짤���m�������
I	K'��t�ʘ�7�o�ui����H��q){�����xf�G���FM��� ��Q��>�.GN� n^���*��b�c�_�u�|&�?0ÄZ&�ԉ�.W��M������Ѯ1Y�����Q����$?�ÛE�/�
�N�!OQG���5��E',%��@=^m@�IB݆)TsVj'.կ��P�����S�Ͽ�\�Wy�(��UĢET򤝸��4͛��L˷m�FH۬�� n"ƄK`�!��ǸZ(��U]���4�NDk���<�=d3�_�t�Aw�4b�EiU0�a�{/x�(R���7o=���������=+l�K~WVq� ����sL�#wd����Evjw	(_;�?:
u�,���y0���L?���+�Ƕ��@ٶi"pY*����R�b��KRA�����A�� Fh5�1ˣ���ݲޭ\�Er�XX*�^d� �˕�l_��t� }n�u�c޴�{�[��o���?�����Ɔ"� YM��z6��@HƁ���_亸�`�����<���%�����'eӗ�,Я���ʢX�EO���Ԡ(0&��ʻa���tNŬ�F|*jw�>�Py��?�����fW^큰,=�B��=�tS�N�q�<bw<ַ�\���7c�o�����G��v�)�J���8��uA�~��6�#�S?���}���[�iw"V�F7�yI�n�j����nQ�ԣ�-��MР��$�{��ui�۞ϸC��!L��
�\��4i
WF�|���Z�8��h�r~$�D��e򇶿t\��*bZ@�,�mB�WIԢ�7�*֍�����:O3-wl��(��!_�N����O���l?���1�3A�}4ƔJiJ�z����q���Y��bi�0ѷF�퀁�X9��@7�g���y��?�m8�Jz&o3T��� u'��u�`�V��� ��E]���։h�� >O��i��-�2Jp ���W�l5��Fq�<2���sJ�viY̏bQdY�#k�_�|t�{�.T�>��'��}T�S�� �ӠX-����Ju�ÝP�2��o��gy�����NM�	���d�&��+��݁���]�: �%z�^�L5�-` �͋t��+�~��Xf�1Z4�4=�(�ۑ��ˏ��x�� nu �o��S���"�č(ؔ�t2��o볱��)��lV�η(T�c���	 P��A��6JeԮ����-����jZ�����m;��+���'�Br~g�h���.D��{� �t�?k%���'�HT��o�H/�qz��U�<�i��0�ϛa���*wE�)�ɛ84�i�d3w�Ӊ2��9�;�H��a���[��}E�Lm�����x����i�%PGp�5G�p���C
bl��9��g!�4����⇠:�q�񲿦������~���@�M��?��H�'B�O���w���)��|]�d    �����v=:�K5���
`�b�>��zJ��)_��q~3m�2:W%:= D�'i���Q���w��׎<Ծ��*���Ʒ��i���#C�f;�d� t�;����)�Mrp����na��O,��@��������Fli�*��E��D��f�աa%S�~H����!l�
�P^��OT��v8c��.��i� �A�$w�/���I�tL/�=2��Մs��"�EW��Kq�Ln� ���i��R_Qŗb��=έ�R�\~�Zi�w)H/A���ɟX�<]ٽ��mPB�o���8ғ�^��n5��r�Yi\U�?Ju���;�|���u���n�s�����@��j-�bn�}ٶ��_��e��P���TZ����߻\u&U�m��j�j���;��C}����]@-��& �σ�I9�Z���d^_�.�^�L����x{�UӤ�m�mw����s�}�jI��U��@P6�H��P����~�U5����f�1N�%�Tx�����0���r�B �A�[Mi�V�N|@7h�f̻��-s�Y5l9�0���cW� ������Z\B������0���l�]ܛ4����֦H�������T��%r�'�&�-R�zݣ���e�zS�i;������0AC}�J4�˃$Кo�/9�9 C�H�Қ�ލ�p`�V3l�1���M����H\��i�|�I��_FJ}�C�z�+���JNUZ�Hq�����s��i =÷��W���k:�u�N��~���h�8hV���}��p���u��璢����L�z��|�'X����H�?.���X.~�`+K�SM�>j�G)֠nG���K�7�*>K�g��ʝ������	��D�Hh�%ٻ������FY������ƃ����Rk�ތ�+�gW�\%��u�|�n�򁡴�p辊m2y��/Zf#u��r��(\B�y�o~R�uv����`[���9�&脢��y��~�疰B�����r��A��~����@ق�3t=��V��^������n��tuH�6��3�-�00hVG�Ǘx!r'�S�E�HO(��:�/R۬&����t_mU��CW����K($8E��-z�͏a&�/L�a��Fj��ׄ��&�6���+_uU_�	��f���wm�C�H~�E_��g��*SY���@b�[6%�
��_����p�>d�0iV5"eaǳ䬶|�\|�-��W��]��������n~|�ʅf:˒7bo������_��CG7�[�Ϸ�?���y� �����8�-t !Ǉ�[~)��YV��cY;h,����	�(x.�"�dXVk ӕ�a(��<�W�"� c��D��Wa'_R�'��A�ȿ��b�V� S��*;?��U���l����'U��b��ݝ����j�岬l:���#c���42UBLƖ&�b��bC���n�+n�*L�(������E��u��-6�
f��h)�Ҿ)
WϿ����6�����f(� ��>2r7Q�E���C@Ǆ�����n޵�ol���O_QƄ�W'��!:Ą/t�@%\������P�zzx9q]�̥�yӓ�r:�!3�����&����7~a]V��&����SzR��xJ[���F�?p�/���@���QkL�e�r�L^	;���Lku˭��v~�V�e�:E�ߕ�&�gڔ�I�R�OH�*:�o��c`R�Ռ��C[��o�������ay�|>���>�)�} ;���Ng�TA����k��u7O~�۾��W2���<K8DTcا�S`7pt����=�j���f�]�5��TZ�U�k��
����#��e��@��ϛGh�	Z��	�8ͨ�edв���b�'}�_�r~�[��R��"��U�b�1^An�G-�����>��_q�\�:E^B�
���-���AN��#������� ��.>�>��6��d�3~�!�����7d󑌦�R��/�*��q�Wn^��(-&�lT��(��O�+;���q�����r~�L��3�|�SP+Pw�J9�"�8ͅ�5#?�� ��I˔1[m3�� x�����c�ے<E©�!�JUk7P�a���p�~��޾�5����=��q1��n,_Klc�+o�s7�_��کfD�����,����!5D��i+՘�ǣqBE�� ��At�X�9���Ȯ�.,���W��l[�UZ�ŉ��=^S!\����0��4��7��W�:��yގ�@�jRvYo�čeڙ�կ-�L%��"K~�ǟ<bT�_��}h��!dqpG��j��bH��e�̿������ğ{�?���)uh����g�e�ߟ�C�k��!rv��(��ov���gkw���1�84'@.‗a�o�>�E׼��w�3J�/�2yPL �Ot��1����'��� c�<!jK�q��$\?��xMpoʸ7��=��6�q��K��J~^����)�=0��̻Z�5�ـּ9�I4�?�m^�|�-�\O �����`���[_�f.Wח�0zNU$ PXǽ��>(kn~��!%28�+���u:l��]�uƱZM�����?b��X�
�N~�<ۿ�9����/�	E���=��̎m�Ϗ��M��M>A9D���H*��iQ�|8P��te�P` 0\�����\��k�&���w��mtb�F��8�z{�D�=�D������6X T�Ӊ���|S)Gy���bdd0���ul�<��̏mU�J��ep�0Ԙ�D��MJJ����i�n�Дi���O:����t��K	by=v�+�i�1^�%	CI^f0��Xd�@�{ �;�`���)��f���R
iC�٦.g�,�l�^�E�'�=�a9�}���i��@��}�j&T%�#��"fW���#��ͷfC�u:?���RkA]�� 匂�O�/�,�()��]�V.ǟd����(\�����A�Q���tV��.ńP��n�+H'�͢,�_��+�����\~	Z�>�l�oWg6���$��&`��:��%>n���PKό�z3��6eC�ei3��)`"^�*�t�}��GS��;ٽ�|�)AQ��cs��6.=���9˵eVv�+�T�Z���7�,�g5�pשC���.�k�N}TQ��y!���_�̿�
[W��,���f���A�\�p��E�`�T+�LU_?�"���A� Y{�*�#�in�8�퐹av4��gN��?��l��@���d��90m��qPq�CT�<y��2翥��� ��h��h�v�z�_D��x��S�Ŏ[ s��y��P����'����]��[��NOGq:��hb�˷˽H���O�����+���t��k�`���j�yKQ������8V�	��*K�֥o�C-�0H�dl�t�;�P�B]0��l�3C��Q�����&����*S��e���N+�2���.��r����b¹��8��bb���j���o�E�c����3�T�O�����QI2Js[��J1&��i.�97�/W�_GS8�R&X'��#�ܗ��;N�,$��9ɭ���0^���,���ܘW@L]��ZU�O�E�0��&������)]�K��oi���.�j���?d�QyD�_<	�ݩr0C\�<9n�k(�C�6�-T�j��(�
����.��+�<lw�����E�1��'�M�ȃ��,��nW���M�ꮯ���.s������4>�^wZꞃ���a F�Z�g�ѻ���y�Y��*��T6���8�?���u�;������>E�0�m���m~;��M��C��Gp�N�����O%;hmY+�пjxa��m� ��i\t��X2��
�2����@o<����b۵Y:������&�>�W��8E.#v����)P�#l���M�GX���ָڎO&�D�glɷ2��nTX"]@)d���?�^��f��wW �A������_Ď[Mំ��"��ڞD��I�{��jQ1�{��x�)��Y��    M� ���Ƌz����!�k���f���� G�o�!���̴�����`��r������U@ҙ,y�=K6���|yx����=w<�k�dˍBT��7
.��P�<y�#��tG��x��:���Q&fT��}�w:a�L�����nl��*#������G�t�S��_'D�� �4ط���a'�ľy�^9���M��Z�^�*�;P��?�՚�Ś�&/�'@��1����x�0eBI,��m��;�t�C��z�ɝ�u�>�}�n�=�.T�����R,���8��w��.�z�h��yV��T���::"r<J#I_
]�_��\�ZՑ`�����K�Q�mn�{`��U�d
13}R��(d2���[� E�_�
�p�{�w^@>���M�?9����X��e�ٺrZ��z�����<k���k봠��C=v����쨈Z��l1����Sg-��B��c��pb�5���:J����릚q��pەYVΏLeӘf]�ҀX!a�+e�E�I�#:FQ=X4��y���˪�$&W�A��N}5rz��N��$x_D�n��A'��V��iUJ��H�c����;ӏf~���VZoԾ;`i���2��h2�J/U��!��%}�P-`&~Q{���^mW��2�еc�Ϳ�st !�y%/�݄g��Y��^Jo)�ƚXKD}�M��U�g�vP�޾&7Y�Ȼ�gv>��yXs�E"�-��B�`;ֈ0c��d�������'Ģ��wИ��T�u��Z����Xn�W��|��!β�	Dp6��/e>��@��ȱi��e*�~Ȋ.�H_�Tf]�˄+CE��3�-[��E���߱23y�ɬ�>�>��f�����N�8�uA߁��^k��Zm���t�˻�wxYԥ�:yf�����Z�+�+G�����m*��C���u�+�2��O���-�W�3kKΙM~6A;�o�L�m�I���V9Ren���e����٦~��KȨ�K����VQT���#ݕ��0^m��V�f��܊it&}E5_U���X_�p�WOM��Bl��R�m�'�� e��'�/N���*�`��Yv�ṼN�)+���>������d��:p�,�a�
���MǱ�����v9ʽ|&�M�K�7��j��՟�q�2bL�6���5��T�1�{`6�7��5`��
yҷ��h�%���C��F�b$�1�.M�_m����eI� 8���h�(G�wP�i��*Я�5V0�U~�#�1���xűry`F��թ��t+g�(�y�9E~xhd�6�Wq��1�����u�.�*y�����pl�e�v/6Y���	��~�6���|�K��@x<&i���cV�8�ޯ+tȭI~m�#����mX,���v�y���UY�+�G�1����v�-r}e}>����4�u����������|`{X���{J�O�
���ħ�F��27ώ��u��I�-�x����> �q�lĦ�k���q��{`�������Rs�1���+bc*�n��{��%9�f�"��r��^�e����;��|�$��ڛ'D�y_��3ri��S�&��Di2µE�M\~��;�vh|$��%?��ŘnmԪ{5`��� ����jR����|����Y=�ǲLӀ�uY"����%��p�Y� ��A>�h�����o����۰;9]�E>*$_���؋�����a�c�C-3ٹ��.U� Nb6,L��j�	�-�w�$�}3��E��/-��	�	�M�J�4h�����"E&>��P��N�O�g���-^1��9��EU}�����W
�^|��!��s߂6�ȡ���
�	�4�q�N�cu��;r������'U�������uy�!��$�L/��*�e�'[m\��e,z_�W"k�u�z�Bt/�F��ѫ��0�ᬻ?���=4@�cx����̫�R��t�4��j����c��i_�2�R��L~�oZ���ѩ���TC��&���͹	���gH%)hͭ��ZLy`,��+3?vu]&��|��x� F ��+�P��?�8��K�����6y3;4Y���L�a1
6V>����pA��x��m'����;`t�~=�����2p�jt��FIUގ��3��&�7\�|8�*e�T�遉��7\���7��3��r��as͐T����I�r��3ce��-���E�5��<�0�g������"�y%k�=l�A�B7<+�n��H8�O�4�am�kCx���UǪ�ܘΎl�Ue��p.�r�x �@r�>R9�y���<F��=��+qB��7�b����}7�"lU��RD�b�Q��5�v��A#R4>�2�y�����}m�ju5����Nd�����=����Bs-��M���+"k3��*�,�2ͬd-R���k�FX��R��*�~� ��� �h�u�t5U����G�u�l NǩL˚2͓O���#봬��� )<�~͛��k΂�,��?�z�:���b��Ք/S� �Es��Hd�/a�|vT�� �E��5�4�&z�ms����H�pv�P������0����ߜ�N?�	�+�q�G�R�ɉF.�!��QÎJB8I����*	9L�!��Z��椫8#��zi��c�۾��˼*Վ�LC���}�|��i[~�Q��Y����%�cs���Y����!8�!�	������Lm���$t���n�:Z�G7���e.ƦN~�@M���Al��C�IH��%Ќ�j[��(m�������Uy��pyY_$��T%ltH
��ȹ�ݞ�y�#F�^m����,�k�)2��*S�5r"e���|:�ۜzvn�/0���ӓH���A���mFl5��>k�t�7�W�e;?9V��uk[fiBgMbT`	��A��(sOU	a��(ݾ(��z�u̎�)��� �լ�-�5eԧ�ե!N@�P���뻅�x�3� �V�{ 7�w|�I�W&��Ϛ|0�7k>�����>�@�P(ش^t�B�t�������@pV�����ǋ��~°�=��UH�Fg�g쁤_��?�?�/ }M'm�T�a�E� ����"�y�Jy �$3`jP�ڊ����hܿC�/����IxA4J��B�y˦��z��Y���V��z4O�^�G{��'�'m'�u����0e������y�4?�q���(�}n�<�;��Bi������=��]C�t&���ۑ�"��)�նJ���-�n~\�U��'+��|��ʸC֠��	��]/. �����:��a�ɴ��	����Zd\�`�����
N��ʬL~��puz���{��)�j
b&��H�)���+J�mޖ����WKF�W%o���i[��'�wc���7�'����S��z���� ��X+_H$�}��2����g�0��M)�`főJ��aQf�	+/�2�]_�b�lW�:��j߯bV���I5yxo� i�ǈ	9��]z9M���k]�4v~�j�3���M�Bg�C�G]��O�&��N�P�|~Ƽ�Di\2�����W���B����A��+Ʈ�W�\��5o��I�!��Kݛ��qd٢���	��G�"E�EɒP�^|̌bDxvLe������A��p�������af{Z���.��w��%�kb�W�+A�����n>]�2,�lg�Q�Z霌�Z}�r<�c�p~�]ea���I�f~%�
3���{5�fq��	�B�Q93`��x��0�����-^U�E��0��29�`7\����ykݚ��A�<�|��+�!�[��pD�J]:�1 ����_$��{��x�T\��W���[�?Z��΄��M�
��l�����{vI�DLc�>ڥ��(��8K
U9L�$�GT��"�,�ǭjg���,#��+���K��@e���v�"ȉ,%�v=X�b���K�}Ώh��*�0ua�zP��]c�E˟�Ͻ� ��gNpl�M�]�����q\���\��58�6a8��aA{p�'�f~m	��p��`p� ��.����q��'c    F��?o��ݏV���]/Oky�S���$I`fw�Q�U�;���vpw|H�>�Jy�����t��4��nv�մ���}����.��Ҧ�q �7�V�Mk}�t�y��Mף|�l֒j��>�E�+Z�/6vvw�����(�#%+�:�-5\�lu��JVM���h.�yF��"u�N�~K+HF1������%�
�S�����l�V����,���_$6!��_�b������{���B䝀t���<2��j"Ë��b���G2N����\?�fT%&/0ʔg6.�7_.�rbkr�o��vU3/;ѷ�}6,���P��[;U3�b�$N�<��=�x�#����Q���S��,�ZQ1�����((e��'L���������`e&Sl꭮�8\?e(� ��3�x�� Q޽v��P	c|;����.�Ѿ�A�V�.�.T�Ց)s���1 �#~���<����h�>j_rV�2�}T\����� _�Qp�ϖ��+zu�P� asג� J���j͝�Ք�"�va�j�n����I�j������������[1Q�9K!����{3X����^�Y��rk�up�Ur'����t؋I<�l����w9��כ� �[�>�4�@��*Y�QG�ɧ_�hOO\���#�T�$�����h��ćGR��� >�O� �u�s��vz�>�bִ�m�W�C���g�o1<�}��C=m�H3�%k]@P|E��`����D�?P-�V��[Hr�βj��Mv������?ce�|��w�jm���jIx��t.&}�w���ee��$>Y�|��X����i�+ځ P10ѭwa��C��Le&�&I�����Z�ނ�Ynz����9�|�p+�%�r��~z����Sx���B$J�:�����i��$5��k��E�ʩ�N�(�Q�&߶�<��͛w� ��_�)��e,��Tf��XQ��O�iW��lY��:����
-��t���O|@�U�?M ��0�4Y�呄��ɥۦW��i��ஶ�\
�ԅ�e/襳�sm\�<x`�!{s%�m�.1w�W��P�c��\K�h-�uP�Z����#.hYX��W
w��G{���	�_h��۽�+�p�ߓ�'���|�%�B��>ʊ��8+��NZ�N��	����|�cqzH�E�cw�^��X,<I҄��.��¦ZI�d�r�\ɕ<�sx{��h4ВP����1��]fʘ���Q�\����.�>����	u6���dLK���d	�F�Wv�P��_Pvg�����
�\Z`k�k���;�'�$�E����dJ�~��p�x��z|��٫f�g:��i?�;����4o��8�?�=����ʽ���բ2x� �����Ʋ̒�/\�EY���4>jx�.�-�WV��8�r����a\I#X@I�������\���q���0}A����(��rm]��t﹠Dg�(���|&�Н�<���C@�Ni|6qWS�\�׺*v!/��X�6�$Ǜf�l&�qaa�F�NwA��*�߻yV�.��M,���7����|�]EFחIm9'ʰū�A"L��m��?ke��fi��5��EO�*��y�
毷��;w��1�M�[�$�S_�礠��	�?]$7bG�l�]��.��)� 2�Uv�R������4��[��E���n�-��j�y�qq�(�誻0��[[���$����Y�� ���V�����$� ;�Ӑ0z�CӛiY!�Jf/�%�9^���eQϿ�eR$��N3W�^�0��v�N���'�p��L�*�u�w��χ�g���zԻ�6x݋�œ �Pz���B`B���v7͢����#	6�a|�w-�Y�h�����2���q���ĳ�a���U��Ui�J� %� e������<���n��w\�M =Y
8����^��,� o�[��Ƞ��&UZ")a���5���F<{��o;x{{�	���=C.�؛z�D2%�����٥֌.�U��iU�В�U���IR9=(�O��jښ����f�x�щ�L]��,D��;Ir��a83��
V`�Pm��ޒꭃ���Ȋx�s�����P��4�[;���b ��A
�����F�c��z���`�;�� ��F5Hq�J'�'��w�c����x�'"I ��)����]?�'8������V��.�A˸��q�D���,	^������!ѹ��|�	Y�U!(y���n�3(6�ȍ�2^�GG�Q)��"y��w�ɺ���{`ͨeH�?���n��Ӫ����
�;���+[�Z���׉�Y�Ԁ���b�59�L&c+����:���o*�����Sȳ,xO�R��}�%lo��]��%�8*�g5�ܥ�.\|�"�mf��Sd��Y�`�#2ĀQ�y�_�8�H}��=�r���ǣ�n�{N��� �q�]к.A�H�<+�ZX��̘m<N�#��۫u3���7��*�ߺ�`�iؾ�I�,-u��N�wO~�&[W�3Ƕ\�nw+	�Ɋ�_��u8� u&U��.��:�~p���/x}EQ\���.���Z�i-�Xo�x�rSu�&Yb�YN:ڰ;����
- �"�e�� ���$����76��	��^��&�F~�mI+��i�����+��2��էڷɛN�᲏۝L;IRt�� oS������q�H΀�]]���	,6�r��*"�=���*"jZ�F@yjH��y�(��(� �T�!�@�G�(0NS0f%/����뿑Eܦ����H<}���IP	�� �{�-�[h�BA�!�D���	?� �x�o]ʝ��h��M|����q�H|Մq-�����e A��������������OM��/�6����p������B �u������Px �A>R�oB����Fܷ�
k��m�1��<�%��8�
=Z�Q�¦sp�E��]�����D7�g ����ؘX%���b7���&�hżF��0u���Y���"��^3Ә����	�}�z.��º�8��:*G>��j{�0/�e�my��;�S�_M�$��-��
=�ֳ���n���P��y.]��ŷ#n������BT�.�h������zF'ۻ��Ȟ@��x9J�|�z*�0K�R%��YN�z����m]ų��]�-�,xC��mE^v�y�����* ��ru"S9c��E�b��v���I���@�<�ڷ�q7޻@@ڣ>}sU	�^��@tF�*��ʐx�,��@�0j٭�ua��M7�B�EW����пjO]S�g?chW#�.uâ��fO/���c��3���x@}G>�+W��JkH����b��������b�����}V��V���G�
����˽��w��:��6?���� ���,[O�})�lw�����׬��*�ǩ�s������Ű�4��֋�ja�<��	�G#��3������4��Di觽��G���aW��jq��0�ba�pm9�����H'7}}l��lC��<�KӃ�\{-�N��Y��}�y�]�{����r܊{��3�M�U@��<|�����|���c�n�'2n�V�nwm&Zw�𺂖�Z�f6�V3t_ʌ˝�a����H]��
~%>�t*��>y$f:v\���gVN�`�k1[���a+o�ڻ��?�+�(	u6U��6��?��}�bX2*��8-�s��j�z~Tʨ-Q��rV�T���y�_յ�W!qQ|}��8M~��\���L��� \�"�������b�V�)�q����$�kL���'��4��1�~[~�~i�{-ޤ�ȣ�Ol��bsH�����*�4�,�I�F���(<�"w��<ݐ�N��)��>��рSа�����V`��WL�ƌk|�fH.�U_��יV�L���2��gt�JQb,�Ռ&��CѤ�3i����]Y��$bU�$��h��{p�ȶǈ��z#%�ʵ��a�u��.
]{X��2]��9�v�C����Bq�q�n2������J��	    ����N�
Xq�����4jz'��J�����폚�7�B��9��M�"�{�W�[���A�b#xe0A��Q��@Y�z|�I��w�vo�U�Uq�h%i3W�*��HUEH�r�ͳ8�x0�����M�'���5���t18L�I���DQ�~Y�U�f��P����z,A �Ҋ����9קo�_��ZT��\]��_.�EQ�����D�_�/:���`IL��1��t1c���2E���Ջs1 ,c�ﭧ����g0�)�ߥ^8; s�Rr[�sP����� gw�]m�^V�?��D�G��jB^�GJP���ym0M8@��D�w���J�'B_�wE@��<�p�'�+�Ę��o>?a۩*�����!�@MK]c��5�C����"ƴ=Ѯ�}�g�?�x�W�mYj�ѐ����8Ot�]��+��s�HJG�xADs�7�/���?�1_�6/�|FqU����en�91eM�@}����]�Z�^���	��W��u޸c��]!w�@{��
���^�{uI��N,UUC_����4t_���M��ʾ����ԹZ=� �瞾C��#�P\#=a:�Ӽq�m�c���Ag�X���C����P`��'l)6辋ֵ��Ȣ��Ws�Z
������cVD�9s��J���
9PA�ȫ-�����d���B
�p�J�~�=L�K`��%�9�Е�P��r7g'N�|�E;Yx�O,�����K�Z�0�e2���4�j�e|q��M�GqT�@�秫��;�!�����</J�:��群�J�	-X�������[G��\[y�<7�z���`r�3j�P��-<�A��z�H]��q1����\��a��e �?�~����#`g?��(�0�訊q��p<��%��'8�!A��T��N��z�>K�����Z5��ت4��7�x��<�
�$���:l�P�WE��h%�����u�K��vQfe<?Ϻ�ߛ�Wa�}�����&{���>p>y�EKJa�?�o�3�S~��E[��/�<����,�C˼U�2�ֵ��1�G	��7C������`�@oYģA|E��7;�tL��HV[�,w��'���ޝ�8x���Xj��u=a#�G�p���?p���@����t5��Q�n]o�������̝�y�aL�����}�)#�=0���<�%��W]�E`Z�'�L&�s�� �\�N*�l�n��k1ݑ(/�*�_c�i�T�_�4��/�$��������� 3v׋�����F����={b5�]iH刻�S�DW�#,%��}����#�(9u?Xe���)}P�E�_P#"����=�q�d��5�{E���}:��p����|����qU��q0�6�lTK\�l�~('Ӯ&J=T��!�V#Թײ^&du�T�k���{àTMݵ+��\��T���	׿!T%5�C�U�N8mbT��?�o���c��Ql������F�������g�� �v �"St>�WJ�z7�hq*Do)%*�ے�š?Sl~G�"�I�i�3�iV�����8�k�<��R^b?'@��~>�@r�T��O���b�|�3�0��O��\�ח�v�Xv���Z-	�ŕE�YĹL ����Ջ0:�]���j��!���U���LU_�(�j�1�����U�5p���1+��{�z5�~8r_��;�Pv�|�����i��u�+ĩ=�U�VPf#r��܁V@�x�����}��E:|� �J��VHw��ZN	{gDɛ�����N�Xb��-x�*�����J�'Id!J ���ҝ&龖2������4  ��=�D?\\3mnOxZ�[Ǐa��o)PqT�U�ο�UU���2H~3��aR9[�x�KC\z�аP��3��4�\r�ϨN�����˕ą�ѳ0~q'��tU���U
�4p�D������.��4A�|������dGu�5i9?vEXY���=� �֧�^$��i�y������t5#릉.HCW�� Ea����)��Ͻ�/��a\�E.�`�,�͊A�}$b����͏JRT����=X��(סvhߋ]8c�޼}���������0���r-�Y�݈9d�	���F�rD���'���(�o�<O,�>��q��'������梦��"��8�S��͢0x���v�܍�T��`Ŕ�b�==TE��_T��S���cA�q�P׀�1�#�m�����I�n��zBj� }���9����Mka ��#q
�ԣ�I�yH�U��UEæ���x�7c ���b#�o
�GvTH�[��wF���g�/�q|RpU��$޾"v��x%��@zO���~�ow���G��O���x/�,�nި j�4m�q�EI��2
^�ˆ���#(ꉳ�k����垊���w��AOc�۟ʷU�f/��E��7ZŔؔfs����5�M��l.tڞ/Fɢh�a�r�?Q�'i;?����J�(	 �R�j�&�TZ}y�((�M�i�}�bel�4C?�>&i���)��o;A��g�/��[�se�F�1��P6�}!踌�jr�A����_P�$e�Ye��3� un�!gr9�/��`@���C�����(^P�c��h/�x�1��:�dTX�K$XH!�8�V�����H�6N��p�t �r@�Z�XrV�ŰHX{��ϙ��ai�\|`�E��f��Q`���(kCMG�(�9q?hBy�(��5;�(��-l�ڹr~2M�Ժ����$�ә�Ql�O���ů�X��p�P�Q
W�����Z�~H�(��,�"�J����R
��?Q��8��D�\�pd���}���	�+�;FhSQ�\�e�`�S��Z�D.�!+�j����<�<���T�����v��m��l� `��^[�3d��K�EC���\��Y�i��g�	���0����LG$_j��n����k
�'����#X-�,��(I�p~�R��E�8�	�լ�4W�ŁTc���Ϋ��`���O�,�q7MӒ+n~ 7O>��<���%s^dI�i ]g�T�<^@�AE���g34��Jt;tլ�)~
�ՃK�i�q���)y��hiw4>�؅%��Vc�� �%����WjͲ�|Q��d�l�TGGQ����eX�hȲ@����d���*r���>"�
�X@a���-�ԝ�g�Dp��[��Q^�o����ҵ Z��y `�aW���
��8I�I�p�Տ��r|wU��Ղ�\���[�V�S�u=��.��x���I�棌C��b�{(N�1����QB����Z���Ϭ���xeA=��/��y~�=��F�X.�qf/���(Q�1.�����u��gz�Pw�9��7�wX�$���x5M�Ŷiq�y?�,�2��|V�	�M��A��v1E(�,LK�Ծ����Ȩ&.o^w1��2��ǭ�]��qK��'c���S��g��Mu��/B�����7��'�pL�h�u��S�$*��Q̣�
��W����Q�w�����ԛ���T�|�'����t��?�9��玟��K�I^���qCUř�-�8x����K%�;�=�(n�<vb���` �\0m-�����wO$��(]��~�*,��܇y�r�q��M47۸f#�
�'˒$xK~�	�e'����X�e!U�`���]��
������ٌ�jۓ���q��쥜���<����;Wu?lE���d��D�r#�l]h�ҳ�q��Gr��8-겛�(��خv����>��x����*c�cR��PQ[�#1DD��ȭF:_L6:N�����v�Þβu�z@y]pS��fP��̅s'"BT��(�;��nK��֚�,�������,e�gI�!��ch.����ư�̀|�N҅|�ˣw��N4������ו,�g�;t���I�U�2x��̳�G�T�k�. Ъ�ben�SQ	�@%_b��U�]W&��Ĩ7���*�4�̸H|?�T�;MU�E�[M)_�8n�d5��b�d���f�IK"�HLR׋ťJ�[GM�Z׽�n��Q�'�?���&P�
�]��o�ص]��?OI�    :�N���n�Q�=��2(�/��Оs�Ϭ��S���Q�}ds���5!s �M�^'��;~P��R�/��8���w1-]j��R��D`JHy�Z�9���Pn�@գ�ғ�0���|J��'�p=�Ue�H�a���!L�$M��H�@Xwz���M����܂���b˽c��"�b0���n����(�&�i����L�
xe0�d+
о��샗�k\�&Mnޞ8.�*�淯iU�>K����v��e}vv�E�*��E����O��4�T�<lF��7O���rh��G��H�:�fi�/���})�Z�5�4���[w�dO��i<�x��XG\��!iN�pv���@T�.����Y����S�]a��k��C�!- P)}�$��;����@$�XL<T������Ґ.�*Rw��E���ى���,�}�/�M1����{��Z�T6lkɪ�`�mGH�\��_��U-�2I�O�6b�����d�o�J�^�ފ<�G�-՟��9����������$��Ƚ��#
�k�|�WQ�Ǉ˩��!T��Dո
��'6�y���=�y��>�y��IK8cO�rQ�֣X	�s͟���Y����Zp�RV������0�qP�}t4���մ�yrC\�y� �i�������MJE�E]HEj�\o��-3u��oӖ�n�[\wZ��~
�jynO�KO�x5��bPظ�����󲊭}���ա�=��'ѓ0�s?����p8b�
L����v9W��t�vq9^D\�q��OU�M+� Ȣ��{���6�����L��{���
4��=�a�kJ�d�Z���S�?̶���TQD����`(�@D�my�Y4�x!�L��7�Fc��"#�[��7I^� Re�U��Y|&��A��L�� p���h��L�;U��b2�W�.�E������s�e^� KYZ�������4Z��N�z�����ح�h��ԡ㺙��˪�"��Y| iD�dR��H�rg��:&q&��y�����P-;��H����R>Ù����-\m2?ٺ�1M�}ˉJ���ͦ�!�vo���W���XM�w�j�u�+��M��7��E�q���໗"�]��a�A: �*�>�t�k\�p�$2]��3Xm��XCҥu�ͽ��EJ�8�eSV��YM��A�c��sxlU�d��4g2U��v���s,�\�eϷ=�C��:���ɝb���_�vM\�/qa�UYV0�����p`�0���
�@�Ǽ��ߎ��o�[�H���,����(�����/�n4� 9�"�Á�raȻO����0>j3�%5�s��+�����G��Ł�'��v���x�e:H�*.z�m!�N2��Ùh�H�p_���Nl��H)vIb/nGƬ�
��qK0���-� �h�'�z�R����=�nq�o�Ony�kqVaS�>��	�i�������k��?�*H-n(��ET�Z�
��I���fl]�Ҫ��.�|�����ED����A	�T�Y�KÛC��G��v��(�*2�M�v�^���V8����C56a�|���>�kB�EG�E�;�9-J{��z$�������z���w\�3ķ]��¾��!��$OE;Z`�Å�p�b$����/�n��������J�p��h5e�:��E��>����RwXӤ�ap4��'��'�X���r�e7om�"
]Y̺�2lyx�t��o��}A��*5ZU�տ�Ѻ� �TQ��Q��<Z�������\�4?<qfjL��h�Og��D�?}��[w��P��9C�~�2�]ͯo�<71�,O�_���6߰7 �r�Z�k�Fe5�ee���O��K��.	]g�Q�z���-!���9Cx]����T�G�Un�Ռ�j����8�U<��%ia��<^�N#�n�t�l�4'M����C��Nl_�{��"_*�%a]U/�l�k�l���/{�r�٦c)2A�A�ڤM�XC1�o^-ܵ�}�Ͽ�iU���2��4�x�F��3b��1n������
�i�cx�k�Q�Iɫ�ڕX�y�'���������)��댺mW�����|�`��QAF`��c� T���O@�I-�F\� �њ[%���4��g4Ph����T����A,o�Mߢze��:ֵ�.�Tޑ�*̼���=�7�i�#~�j82�+� ~~:�F��,�MWa���������ښ�d�a\+���*�fR��)��������SuΫ�_�U�sP�t�e\Cd=;�.�Ė���X���T ��H
�c�z+��r5�Rl�$���g7��P_�"���_vMy(�5sV�dbD�y�z�=)J������[f����X��1��,��"z�� +P�h0��͠�X)X'[�@Ѓ��b�`M�H��T��
�xn�򉻼��l� Rg����	�9������6F���Rx�e��g-'���1:R��o��C�Z��4��D/q�Z��I���~��C�^�MEb1&���pO�2-_00��$�-S��Ι'�5�������/Cn��	ǸXMep�R;����
WoZ6Y�E��(��.S�<w���(�6��O~pL�\)��@�2��-2��ӹ�,����wQ&�q��<x���/j�.^��
e������I� 
��}��$��r6G8�+��f�JQ_0>���/��ߨR�ڶ����������"���ü��d����Dn��<ɲ����ea��YQzY7�s�4
A���8X��'�� +LtW��ܼf�A�v�m��"U#��������.K�0
-,�����D$�g���d�W�7o��I����*�b���0�U���o���;�{����T����e_�&"oš��2r�@j���X�X<�g�\�0�싼ؐB��ծ�R��$�d�A���\�i)c|7�yB���)lP�m��������Dc�W�n�0��I��n��H���Qhsh��dQ��Q"m !�P�{ ��tR��gT֫��$K3ۙҽ�%�3L>KZ��9��#W+��7�e���� l	w�=f�.ui��bX��pI��ʴP��{��N]��o�~����Ǔ"��Kg�CX�FH{�2Qx��ѥ��7=�avq�g|ʃ��e��^t�꿨]Q�T��)�i�#b]�ȡ'���t�rW����/��櫢iq�����,N�N�e�Z�\J�4)ö����̓��e��/�K����*-+h]��� �\���f�E��X<��d_~67OoKʲj��q����U��7̡ܱc��t� �����]�ɣZ��h9᧥#C�ݼbPR�q=��B�'afGLA���Ӧ?�Ö��JdA�{-�~��Hf?It5��, d ��k�Р��i3�0���ٖ�i��,��qM u�������n�a"��(�p<ۮ	�Q�Xk�����5b����I5C<?���0	��
����^@t�$�H����o�s .�8
�,�EO-&��z��!ɻE�!uWE9;^i�,\�f�L�c��BY!,��]m2�����K�;���}�H��9��-�M���ۗ�&�C��V�v�]^�޵��7�0d�<�e3���ۼ��u&�IA����o���Pt�pv��D�U����b`��)���_]CW�|X*h(
��1�ͽ��}r9�r��:�\!ǎ.��!���{?{��p�s���D���65B��=�k({.�}��(��N�����ȸRR������>�<a��Z�N@�ǘY�@���s�/L�[e˓b{��p��U��t��j�����^��_Fv��㣨o��	��&��;�������0�摬�I@}��@�j���,Β�o���6�R�UI�_��i�w ��LȮ�ܻ����s�l�Bzzx�]<j�X�>�1i�<��?y41�4��#0��@~RZ����{t0��&�n��xo��v���j�e�b�wIۅ}4?��YU�1w��<m�=6D�]����{gZD��">[��|�0+�����4ۂ��%�ݞ�����q�#�GY�	_��;q�&�������    MU������� ���{��A�zy�A5 ~���,!�p��:��l;<�+E�D��Ȑ�V�b:~���;�)�[V��_Rp��2`�����{e'杴T����D���b�{q��A�["B���ޜb�(�#B���y���ؗ�BH��(��{��-�ʽ(:{��զ��ju\�B�0���Gs����q�~vv�Hl`\��o���(��/m��i���>�lIY8?�_�N���
X�]}V�&�	( ��v�R�)�z�E����]ͮ�L�&�nR��t��=ݷ8x�R�Tt��^����W]�6xo�	�T\�Sy�<>S�k�����cQ���,��߷|X+�Պ.5$Q��� ��$�9С�f��T����7�y�nߪ.�ӪI�������@��jA�f�#�2&.�;�.���ǥ�9Y�`��q,�̓*調k��p�-�5`�ڞWI���������L^P��b�J!$������m��Ϣ�-8D.�QUD�����;����>�xR�z�ILZx!~9������jv񰇛�@ܽ��)\����¾�k��9��{U�s�̼��t<A�O��(�X0I�i�w��/R��5�y��/��o���P�H0>@��9���,��ӯ��� �3	��7��Q�%<B�:n"B�����^��UP5�;�,~��n>Q	�6갉<�gz�q<G�K^z�Zm �VuӬh�޲(�֔����ʺ�L/�vr�#����N�V�����<�f&����j�A�b�ΐg}:���2Q��<��/�Ys�fJF.f/6�z<�T0�%�
��`G���6<����?���ǖ��I�6����
��v"����`/��m�I�聻ϧ���nL��당5��<.-2I��<���?	���E��q�K�ox�1��-�"�O"�H��j|��b���e �*Ҙ�T��i���^���AD��gO��>�_��0 #��V�Rp�4�v�m��`�����,Pg�蠹9p&��9��^k���+���L�_�(Ns�6��g>c'���9��'�-��w��'�����P���P�0f���Өq%C=?fE��v\C�0y���n&uP�扆��˚|�)���S�EͿk1��
�����gV�\+�!�n�&ܼ5�͉�^����Ĉ7�$�ƕ�9�/c�gIkĪ�Ru釩P�4����R]�Ö,�))I@��}/	��y,\����?bIX�*��G�,4�%����3j��}��1|���쑥}i���E��L�O��wJTs�Վ{�ϱp�j��K͌��}P��i.�YY�[C��Q�D�o����,�DV��d�L/��/��BAcB��2�2�� L��Á;~�7�J]<�������]���uf�"��c���	�T�T���z�級��b�J�wC���eEkg%���Q �+���Q�FW�:��I�w���ֿ�A�Ӵo�j��͢�h�y���]���sƝ�a<�B'�`����lJ!��$V�4Z���MY%7ϡqǥ��/����,�B��M7�,�fڕM��ܱ�Q�2�Q�r� �Æ��%C���8���Y�w�����+�&��ß�*rO#D�m�!knxl>qO�w���E�He��b�<	�D*��(�HW�t�xz`�"����o�{ ��۩Z���H*�o�4������y�ĳ�WDq�Z�\Q�θ���.@h ��;
Jت���=ͷ�p��i�6���Pe��٫���Ŭ[F\]����n�^�R8���A��ۗM�6J���2,{��0�:>"OBtU�}�'�]o�:��'xqQ��&��} ��f���l�Ms�d58�bk�L��������Q��a�\-B�=,d��B����ke��]�]�]N�~k�x2:����w��n^�/-���_��
���q�
�,�)�g%9�g���!S'�G�Y���-fҘVa�u��rURU*����;|��5!�`��1/��*�>��$U%���4�P?7=�����_Uz.�����w�ާy4��Y�p�"����S@�5���Kq�(&�]�_�`ƴ� �*�ۮ�]��@��y�݋����Q���:�q|��Q�Dɩ����v���r3<sX�c; �L���= Һ���N��]�al����IM�z�ӘֳME���W���\�f�Dp�:�������ܼt�D�_����������BLF��4+^�z1��>� ���HNg��u�Zȃ���h����
?��
�^�+t��(o	6��Kʨ�MF�\͑x)�.��I>?JqR�������w�Wي��#��j'e)����<n������ 
(����j�?^ͱ�+�p��gKV�/*�лcHoޛ&mۦ��4��$34}���ϠK4ܹA��'_˽��O~ f���V�/�\�v�ˀ/N�r�����v�AX�G ~N�Qh�9�� L['��}/��j]�b㙮��p~љB��B����{��0 "6�w7�䜯H��Z�$t��j����i7�]>�-K3w(�Vf��g��m`���NT�O-)�F���K��X��Ԣ�l#���,�]\QZH��*^цZ~��ys�L��H�g����@�YH�ܯo�G�6�5�(Q�S��Ի�R�����Jh���ga���*MT���̀Q=Y�~��_@z)#F��j�K��w��]��u%/��`�L2������mwaC� H��+N�Hۭ�{�+t�.�!D^o�+e~��^�F# �n�(��7�w�<��DPH��s����Ѿ�t\�S$�5�~{�q��I)�.B��?JuI�ְ��J�v�E�BZ z*��	&��j�
��ًf6����z*X .ڏ���K@ �G#߃l���b�޵���r8K\A�����6. �������(V�Ը<�����F��-ET�|5np���E:�!,�j~�FZi�����Q�<A(���E�Sw���I���ݾG@:�E��/sV�I|n�o�{���;l��=��{����Y�xj���C�.�f(������5>��v$�Tj���p��m(�p�^dh���?mʳ0���KC)#W4��d�HP�>T2���.�\�6_EJ��ȍ��1���n^�0�z���"��(=� � b"�3P���������N��(I$)���C��N&�>���v�P�V���E��Ә����*��v���	�ڝo<�HJ��>@���[y;QÐ\���a��F����'������(�0�et����%�{da�����-YT�M5�*�����4I�൉�7����"�W�gӿsu,�Ȫ��J�G�ᄯ'79^��(��A+BD��r��x��F�0�ɍ�#�e���j�2�#�p�/z���B�xbLx�G�D)�L�O[���yQg,B��<���>���]��T\9X�1/n� �V��&Y<�x�u��f�(��ݥtƮv9�_r�>�Y44q4��)]�6�y��B�����{��r��?y��]05�=�yE^1�<2j�Z1Q����U�];SEeiC�hzl~�
�RO��.�px5D�R#�,n�|AD�*�mVZ_��͏4<7��d+-؎=5�\�}P�P����Yjm�:�<��v�l�R�Z��2xs�A>'�A�w�A$� >�A�νb�]H�1��x�Z�t>B��	N͓Y�Ile�:7�t�%E�φ���+I]��:-�w�ex�Pȯ��z쇝(͹����Yҥa���W�_�7>�����E�͐��B6���ږ�#ц�����XU7�ʗ����rv�"�?Aˢ��s�� �.c�*�ݵ|�vR�B�Iw>j��uX|�A"$y�g�hT���V�	�.����~�*K-&���*}�yM<�'��o�gZ̮	)0������B���)��T�����{sN\�������~�:!�U�cL��qE��a��v�'Nf�[�E9������#�^[���Y�U"�Zw<�7��\
�����L���AY|؊��"O���� z"���    G�7��;~&C�۞ϻ^�3��'�7������K���t���2�.�U\Dv�]�I�
Mf��u\K~��2��|E����*�������춭��C�-����z`�l�}(�YȺf�T��6���}��n�l@y����a���{t����uXCv�3��+B�4!��x�R���e�Ӓ��@�E��]x ��C[�w��_=�@�	3g1��T�^��1��x�W�_.�ɲ�����%Nܱ�0��I�b\Ϯ��蒺.��'����W.���{�¶��U�i`��r O7�-��q�Gݛ��)����ەQ��)G��̤���D�NőE�R�T��D��_�fG<bxk{f�]���j�p�ɷ���=�A���R�O�Qx)�X���&~�����Հ��Ƴ������
��j1�e��~k���Ͷ]��|��p�-���gQC�k2�JTha��f���}�H�����D�
^�Y|�S��ӓL%a�;^�_�ՄA �3��j��Q4�����^"�?/ʊ��y��V�����M#��o4�:o�u��s��Lb�F�8j㩰6�.�:�;�f.�@_N�qov�1�	��� H����o^�{����y&�������2���L�����Y�Ռ�lZ���ʍF~`UQ���_Ϥ.����r=w�<��D�ZT���f�r:�7�x �Ԡ@��M�<��������l�#wP!Pf%s|�U*?N�F2;1�-�J'u�T�ET�8܌Uq󴐬����4�K�*x��Vk9V�f|�!���쯈�ù�:�}��x��I�	�<�>+�6�=�t�s��H$y�^<cp��uH�M���B'ܽ�?�{����O�o�A��ݛ��+��C�wJ�,����5���H�WhQ��C%"y�(��J� Q�we�YN�T����4|� X�t��?S&���"��D��{#Eװ�������?���v�ե�
D�it!Re:���ūw��u���GWwY׳��.�O�S=`I�}���8��I��?�v΅��G̸�����\a1���<��Zg���u3w��r~����+�<G|8w�8��H��.�tɠ�9���������-ǫyx��
���L��qeJ`y|�\�ƹ:��0	8w!���ܪ��V��o�8#O]`z���E�Z�>�Մp����ʺ��@�1�E�ٰ:O��(�0哑��7���P^�@��ಟ��������%�uoN��S�e�s�>�[�c�Cܾ4��	4�����B�X�v�%�z/M��\��态A��f ��~�xr���2]5 R?�����Ȯ#6-UQ?Vz���M�1bĞ��x5�8h���{@��c60�"�0u:��k�c(W��Մ�-�|5hF�vM�HaTU����yV���� M���~|@�q����G$b�}n�	�4N���"}y�W�+,�*V.!��_�<�B�ϳ��%{1w"F�Y� ����HS)�G��k�︸��׺�8��({�b./�0�����O޸�l�S���J1���rW�P`���x��.�f����=���"�If���F�����š�_�����M&��/�sy~�PE���h����Ԡ�y���m�"��$*L_�!�HV�|R���k���Ƌ�����p�Ul��
���'��3�n�`����I��\m/��d��봟�T��{��Y�*j>Ҕ����4��;��)����}��Fl�>j9DTSC8�╥W�-��7@[�����\�Ja�u*;�ɢ�R�[�y��>�Qy�cv���Zg\��?���u�#��i����/�5�5d��Eu-��,M�	����*��{A���D�ދ&!8�"���e���>�~�6Γ͉�5٢��ol鱭���޵��.9t�)�)�N��Xc�;۳�1�'��l�ڗ]��)�ૼ������\������_�en����OD���#Bs������u@G� �:~r�F���Q�o�'�)�����Ը�/��pP��W|����0���I�������ؑ�o�yHR���a��S�7v��غ������9���`:�7���'�3o&�iͩ=�y�и����2�2��S��5C�IJA��캿)���ϵ7V=��D_c3��qNx�d�:ZMPq):[�Z���rU����E�$�܋#�����d��5GP,������WfϋSH�>��~AԶU3���3Q��L�4x�F�U&�ıl��wA=SFw���+eYU�A�G�o�Z뻘G��i���e�Ҝq�̽��ڈ��kJ�=�	�?�plj��S̙A���Ǔ�Dsx�R4]� j}# ����}f]���v~|!���"�����:ŗ��u�q������L�:X���(	n�Gڜ�1�X��s9�t�AP{v(�8I"��E�1>��x�� ��~m�Бo&�F<F)���O�r�N\	�.���2�/W�ڄJ����/�y�6h�%Te���������+�t~��0��� �csfJ(\�	Q��ЬP�C��R��Pf�k��I>�RW��P�0�D�\O�SqJþ�U��Yn�a�gtQ�é}L����b��ِ��0?��9d�5fQ���_{��;�r5�l�V�"���J�0���'aR}����x{���}x��A�����6�\�O�׫e�b����@���o�W	I�V��X&�'�<��=&Ѡz܂�������@^sӫ$<`yFn���b��ì)��EAR�q���2�nU���T#�q`D�y��M[_+�q��R�B���LV�KY�\4�6���4�sӥ,�@{l�f�h��>a��������������=�t������]�4�O�(C;�5Y#M��Ғ��6s�K��z��x����?���W���
���b�����/_N��@�� ������ ���*�g�(��#^+L1w����w�_N'���[Ȟ�O³�v�`�?oi��MH�� ��~^D h�-n���`�D<���lx�{�H8Ɋ}�� �s������� ���.��^��ʣ��U��ݴt�Q@e.����:O@h���#Gʛ��ݡ��{��W��?����}��(�U�
������!b'�i�l�y=�6:`3(�I���й�� f K"��a��p�E*W��M�M>�{ u����
HzF���R��P(�$f�<��v��;uy����;ch8�WOP�vI��ЯS��k�D-W�G���Q�vQ=��eq���S_��`�«f��Y2���!=�f�8�7�<��Q���fy�ҍƩ>�O��ڡ_Ab]���y^UC��GV�y2��"�ާS^�#'�n���c���GAj=2Z���S�����T�*c3����qTQ�CuU��ZD��߹[.�N�z�������Mt���3����͓�K_P)�'&56L�Nt��z�!;��nB��Uʯ�հ2�f�9�Q��$:g?�6�[5�5�nۣ
���\��~�w.JܨWڧ�,�儃�k49e ���VS�A7���@�X��lw����[���&Zԓ�Y�ju��)�@�^��&���ѻ�dd�k�������(��_f9!�Pԁ��=�qE��%X5xdf$(	k*��2\M�6�#�
j{��DwÓz�[�Of)�<q�U>U�ie~U|�,���@���"8����0�Ќ��,sѠ���P�2�+��n/�Oh|�J8y��E\�h�UJ��{�33�����i�x�&���~�'�4�貨�����W/�p#$�@��Ւ�R�y�ހj~�*Ӵ0��
�53*��k�#� -�8[��#ЊQ���<��E�-�`�[�I�L��|��/�[�b�=�/���H����UQ� !�P��;]�O����(���u����E���T��}�ޑ�޵��X{��w���g�!��j�f-��������;V�=u�~�d#��uz�"�~s������F�]^9q.���L��!=����r9^[��Ǯf�S����7a���G�EM[�/U�:��X�ʃ�dց�w�mJ�F)��J,w�\����rX�k3���\��C����{��    ��R+�<+��,�p��J�"xC��:�",���SLě��1S����BF.������y���Z�*��$U���!2�E���[LmE%T�>������@�AB(���!+�6����_�<)�쨪��";�U�y߬?�]̉mK�y�K~������P�4�	d`���&]ʩ'w}s=[P�5�IX�>��=\����,!3�X�YxP��mM��F�G�=��EK�ۀ�u	OJ1�y!���k�#�#�|�I#��ūeg�����k ���y�D)��Ve���� ���;�#�^mZ�G�a�=[$��nݯ���~EǨx� LTH+]�v o��Q�X���s�CN����Z}��z�c]"J2h��C6y�z��9|�T]�`�syNyt��Y�]^f����gq�ٍ�w��������b?�h���5ާ
���R�%_j����?��!j))伈���y˪J�Rc_��f�^�DڗQ:����F�Jt��+yQ���xu%��Ҩ$�'����(#0�狘.�p�#�8��g�O�4� X"�EJ.�����ݑe�Jρ�E�?'6���߮��W��N5��c���T�Vp W���������q���g:�P�6�rL�N	�`\�aUs9�_Ǻ���~�;�~�#ɷ�;&<���P.A�[��3˰�b�-ϟi,`UuVqn��>N\<����d��vI\���d�G���(�a6=�mԹR,l���UH��	��"`�Ej�CU�RU��F��?�y�<�mS�2Ɵ&�#����.�We�}�u�i���x/2I�����j�޹�s1��x�����ҁX�o���ڋ����7F����B�a`��JPc#��&�G����RF��p.6z�<�5�dL��yCi<����zg
t"i���L�U-���4_�_�N��(��C�Wp��t�;�J=����D�\HG�+=�H�vL�R�c��<h8/�����8ɒ"�c�W�V�EBizՆΝz�>su�H��
�
�ӅU-� JS�:�a\�ͼ�K^�M��O�q^�q�a,�ʜj��o��J4�<�V0�ϖG�~`�'��:�[6!��ݲgbk��v��y5E;?3%aR��2��[�]���/7��������NA��?��W��+87��ÓTYj��
ު%�T?���.=�ND�1��5o�������+ع��f�(� Մ�2=7�{ 5;@�(nD���[� �9�鈪������Y��]�3r1��N����Ҩ4��"����sF��f�x00��g`Z��\��G�N>����U�?on��{8�Ф�<l{�ʻ"D��x{"X���ݵ��3��w5�)�RXCWD=PF��ҍ�[�\��i;��
��]7�4�30�����T)��~�ZmȲ��k1�:����@D�H[E�0��f(	��q`]�F9?Ծ8�.w�jMt��� 
�:��T�ql&�4�yx���|y]�m9�YH�<��;�P�ː��+n�s"%���;lw�W#�.���������f�D��BݦX���S1f���1%�o�y���+x�B��1�'*Qc��0�����aޤQ�ί���5�:����w%����q�0_ A{lܽ�]�iF: �	͌�j�U��/�M�W��9a���P_DY��6'�Q�2���t�Z�� ���FQs�ZGW���+�x$4غ�"�\P%-����u�r�����9��8Ԧ.ʃπ����2ĔZ�|ӂ���e<��t�����wԼ #�
*��'<8YW��DՍ2Q�C��6 1NeTݘ����_=L���b�4��ˌ�Z����7/X��u����u/{d�-�?h�N+���1̸�c����b{�vȊ~���:Ϫ�[XZ���7������ t�Ո���,J��ɱ����hq|��6dJ.��{/�~P�=�3��ᵅl!`�jA�e�q5�r������_�E���eG�Gn���D1x�dTlJ)SY�Pt�<�����S��ǩ�)��2�+��+�8��c��;rgo�(W�^P�)�ͫ�3����d0�X��Y# j���O|$���.�����N��}6@��kG��W��}"oU!� m��E���#�b�t�4Y�����Q���� i?�( �����5��F6���PX셴�CH]0�{$Fe45�_$l/<��"/;b���6q�������%�.q�$i)���/\�6�p)�2̴�����4�PI3�̻�x��(/��y.���vT�t/�/W?^Mm1t��Q2?WQl��"NEp@�������I��"�^F��M��!K�n~�V�ai`��]�q�t��ck��Q=PM��J��N�=��!���,`X�0������p�޼(2eƦY�y�/5���MTD�b@�ZO3Hv���5�[��L
/��N-e��6�[
�P�I��%�#�ie��� &�Gǒ[�ɯ	˲ئ��ދ��Ė��@�T��w���`�2���>ԛga��o�o&*[�e�I��E F�jP#>�����*��������O|�A*��I�:��{���#(�Ɓ�]mG���MEQє��%�tS��^j��y�kh�]s��)��P.6�wٴ��z~8ʴ0tpo�ը��^Y}��݋Ц��7^�/�S�Q�K��[U�� �:��[��Ж���1N��^�$
�."h�a4�m�u&P۵�p
p��޿x��p�zK}�;~6kEm1$�{��d���V����$&@��H"�V=Li7i�`�G�"y���Npu��q�b�7n�r.!��+��\u�$	<��zm��qFt���R��S�C;��
/Q��"IO�1o*�ɝ\�F��w���Z#��A�U����!�K�oE���6`�>nE�x���ӧ������^�_�S1IgSpp�y-�"�p.�AK�ʟ�<�#O?�]E��<RtI���F���G���u}��n~SX��
�Ri��6�K��+v�����)�:I�^������?3���D�E
�}k�㋍?��g���eqU�b:)��Jo��>ٺıl��%�I���$%��P�&cq~���K!��,n�l���r��hȪ��E����1�$8�ꍧ�p���=����6{"�3����iF�,��s~8h���O��i�&1;$y�HNͪ�I���<�R��uh�JJ�H��;(y_�I�B9!�0��@��G�p7��(QR���M�"M��}�7�w\�a�v�Op��z�)(mc'�л��k�p����Kq6sC����@�;~j+��t�<������T�T�4v�_Fw�3�U�v6�@��s�Mz9�_�0 ����t�D��X+U/w��6˪���ˣq�=C�?���}$vcZȼ&uH�VJ�hjv��jr�˕0E\���Y[Q��%ޘ#8�3�7��N�nB���w�q��)�,wn�*yI|J��v������ `�
���C���i["�f=%���bh�a~�y2k��<��4z#��R�浨�{T�� /U�T�_�q�����Z�#�}�.��?AUXMOP�.��{D�ΖrB�� #�Z@��+J�,��Ѭ�8�uZ���'��=��D���y���Ӆ��c-'Ъ`����>��#��V��ql�*`�n�PWb� �۽VFIo�3�'���*?�՞󥀨EU'I;wt�ʛ�0u�"�O�P왂�t�{�#~A�ĳ�G�U�9y4.�����$]m��$U�.�](�(k�r~˴��Za?��&�W�}�ٸ��tMA>[`�[mu�oh�m[�eGm�͊�?�ը�K)2�慠zvx�8O+%7e�r�([�+��L���Q����4iy��My,MQ�I������W_�,	����84��K-��QԃR,��n�Ҙa�o�Z4i�7�m����i�r
?��LË�{P߫�{� N��r"e�j껋����X�3E�UE���I�W�'�b���2᧾�����0������0m�5��3�����aN���)?L ]����Ҙ�R�Y��t�mƻ۲@�tP�z>P��-�f�*R~��'3`U����)Z��=v� �!��ދ��jq�^�����&    
G��A��ɧ��71;�6]4�UT�v����k�i�rj�ZPQ��SN��6q��/X�[m�Ҧ]S/2�j�f6�,uߥ��"�c�d[�T��j���g���(�.��8��4̳�ʃ2p���?l����y_SSU���-��&����M�U���~���Ƹ�?	����]Y{�i��
f�.ՙ�����:j��mU��H�h�v!��r����EV�/8����וHm�T���Չ�h�Ԁ�����{6}�	,HKa1��ݧ{b�(����VEmS���=4�\������� ��8���.�e�u�T���?9��Q�a"����Ұ�Mz>�.��g��c3�!:��=�2��ʛ��(�(o^�i�QQ�>��P��'������ A
Xpɕ�bL6�_�p�U7�/�&i�v~�0�� ���^����ҕ�f����E.�TS��k���"�sS;���=m[�B��Q&��q��F��R4\M8�*�|�v�Zl��`^�\WO�kQ+�*v#5�ܭ��)�Z"�(S֜_Ͱ�X= �M2ebKA� ��yP������C8j�B��e9���o��y�m~��1����!�H����rI��ZM\�:K&���� K��y#\&~�F�?Y�bHA%�c�׷��Ϧ,���M�4O�j��z�2��$|����B'�P�(ͨ�ƭp��IH.Nj"#2�;���x�&`�>��]_
KZFy����.|u���O�w�t+S��K��zaa�oTZ�A�i���r�c��M��S�fj�P�Y�J�*�!�s28�F���<Rwȧ^&Ǩ��k��At�4�0��l�2.9mqv��kZ%�BQ��<����?*�H�4Uw�"ű���5���ڦ�"8ɏe59����2���	燭���^�"��Ǩ����m�^I%O�� �S�j��MS6D>��O���'�F1�y'�2��b�>�=�qfjy�咙\�����d�ce��B,8)�2/n~tR&E�UA|�0��U��z�ş�u��l��\�ޓQYM�a1s�U��`|E���'� ߇^�Ĕi��P���R���'�_�f��t"�ی�U`u�k�2�]��0��wED�.b'�A�ɜ͎�#%ޠ��z�cS_1�j��t�p���1� �_�2��Qw���j�t���i���(�m�_���?"��bT���a�sv�}N(�)�m�@*dԢ��K�s�Y��~��ȴ�-��%WT	C�����q���
�R.��g�YSV�����Yj<�"��Ut�(�R��I���;4 $��8���;�`%7?A*�i��r~���S��,�tM�F������vr�M�q�$U�ݯa�����m ��u"�4I/�[�
����F-�&,��|~t��2�q��4� �䳘<�"�a�1�9`�	(� �}�ʗku
�	��E��6ts�K��R뱢(��b#�3�{�?4é&yW�����՚��@�e�w���24���>Q586Q�Q�5�������=�Tu�l.n"B�*?@���6_��N���h��Oc��R�ɲh�.�[�8LK{�@Cf��݃��(<̠�b-t�ePIt�86=\� 莇��ћ�M6_E�
nO������V3���ĈA�p�ONV���<˪�Pަt��E�<|<���杰�Pe��'�$�Z�_�u�\����{�l�t۴4k�ڼT�K��5�Z����\!8�Ӷ�0���?�&%�b���A��_e�G�da-��GA�a]���\M�a1"kY&y\�/��<�
ݞ�a@Ej( ����� E�!F�*��P�K�8˲��j~ٜ�j�X�Q�I�` 2'D!w��ih�#� 5v�\�`���}RC�O'���*W�t��AU58�Gn}D�K1f�������z�<yh�m�\��l��"���;]б�������@W���;�	5�-֕�E�v1���U¦#ԕ���ploJ%�u㊯=�)����O��C�N���J�i7e��o��U1Q8?�Ǭ�=�����7	܀u����7�|��C$�G��j ��y�V{���*.��y��ftP��Vh����<{����`����#�G�>;�ho�C�q<���~�pn+]^��9��'և�^��r�.���Z���n����p�ĉIS�)`?��'��C�L )F��3þ6��}�6��'{-ك�+|e9����er�ڦe�Dy;��,��L�2/]CmT	O�������4(2"��j,�lU�U���r�U���M��C!b`ܱzp��݁�}���vF(,�E`���@�֯O�4��]�������2�RM/���ĆR��޸�?O���鴹v6 p�h<zՑK~Z~�".?���	+�4���c/WZ��-��]�$��Ke����BjI����F�%'���1�},ג�[�~_6u���sEg��-��O��8�@��d�]���d,�E��e� �o�l�o<���e o�X�e��s;3��p�����������4�/��Twg���=��|�E�jK��d�God�T7���U��UʶO�وK �������Y88��|ܡ�%xJ`���ؕ&�X������Ǯ?\[c
��p֮��a!M������{<���*K�VI�z��#�?\US(��j/i�j�>�S�yo��}`�l����Ѧ�P��?.ȝ`�pзٞ	��cV�1&�U��!���߮��I�2���*�L�XH�Ck�֓��&Ҹ���Y��m7��`RFw5�r��_X"`}�s��]��0�y�ʃ��h�k&8� g�|С�*YZBO��Uv�H��.�|�E��0K�/�7$���#n�� ܼW��Y?>1�;A+^�FɌ�Z�����/[�ۺ�}��"�+0�o)J�kJl�������V�X���{��{$��A���6��*l�ak��ZǾ���5�f�S��ŗ�d�u��']C�h/^��(���x��,gZ��k�׳���\�s���ɂ��]��u�%�G��N6�[�RΤp>`ЭR&�Ù�qQh�3�� ��x�KaS��,��k(�b��˪$������xx:?Q�Z�]�W��~OG
�#�"���$��ٺIR`�ņ}�k�x��\��p��YU��Y�I��!.�[�V|F�e-jeY�-����޼�����:���r_*��Y��������:J�C�/��DЂ
}7�����;l.)��di��H�L�Z�n�>n�A��ʬG0�0R�[���I�n��(1d��Ef�`rI���d�(���V$XQe�����82���e�j�P�R��yfHPM֑6��ݼt�K}=�Oߪ�O�R�f�K��"�����!w'Sa}:� ���r��+�Ak`j����kf���W�����ǜ�~�q�9�qPf��ۀ�j�=nσ_T=P��@(�lu��d�x�R9(�}���5��x�C����F0"��o|Rs� �wm��aG-S�j��;�w�$H�"�W��z�[�+�3Ț�%w��#�fcV:��e^w�z�h���^/nF�6�Ū ?3v;�	9�:}�M��L��� ����Y�1��Ğ��y\���ˉ�t�T�o��.O���ƞ}!M�Y�p�#	p۴ϲpz��̤x0#�X!6[J������y����}^Gj�y$�]�eO 9� ���`�,4w���wi���!Y���'��Ӫ� ����^���F��TS7��~����������l��1]���{�򢨒�a���R]G�����#ǡ�Ѱ��\ܒ�F���Qp��-��:|�n�	���פӛ�u�ߠ.�$c���6��5_����)�zǈ/����9͊�o��
Vq�qI9?�G�?��Vz���Q���Yzz�l@�����ڎTb۝�,�`��#�Ye���h�x�>�r���E/��yU"
��R�iN���c��(O��$�Y�p'ĝ���^	�ۿ�Šs)J�2��6���5CZ�j�U'9)R��N��1�G��	?�5G��� I�B�y�B��)E7��?����X�a.
�+]�Mu�F`����]��xv5Y���[d*^�    �ˈ�d��P~�b��J�a�l'�۠��ꤌޑ�c�BC#2��~�>ݖ�&� �ꊋ�g ���0��
�ۧ�������Ҥ̵�^'ըrJ�m C �@�����vU�e��ӗTZ�κ|I�-k���5�Ţ��f���E�Xl���4��8ݡ�2���U����B0�zh��h��.K��,�tw3����]cL�'�|�Bv�(b�!L�Z%_��[:W]<}�eH�M9ɹ<
�Z�f�r&T3h���ڻ���aE � �t\�����W�(�?.�{���J����ǁ�Q�/�1�D �C(��/�(�����@5�#�B���~0��,�|p��?�on��e��$=���^N��t.C����Y�jj��e[��p�d���p�7kkHS�%�_N֨�ڰ�EU*�T2�v��A��^*1[��$}�N_��?1m@�&��+QE8�A���S�)T���f0��;�ߛ�Gr�k�d��]z���i�P�=U���W��o��0$y��y��
�qY�� ���vK'���ir��|���_����0��-�Y�z�ݙ�ᾤ6�v��z~%A�-66����vI�/�2�	�F(��^�� Y~�	B�ʹ�[}8P�O.�����QM(n�Tj����R[�m9Y����\U�:0�K8I|�
����bz1<�D��$@��>��ϓu2U�*�7f�:�$ze"�qAA�w�U´�.��B��ǋ�΅Gr]�}:}���mXD���������}��8����_����Zi�4#���N0U�>�*�0�Ύ��m5qb���6r#j�B�T1����RaT���+�}����R� tOt��p��|��,9U�}fm��˳��shB�Cv�6T�F#��	���h����}�5����w:0P�Xj����<�J'��A�ƥ��(���=�J?����gZ��p���1U9�N/]�9K�J�)0����p�+�ײ�Ax}��h�3���¿-��yk0��E<�'���2VaI����oD���U�CijjB��HY-�}<ճV4w�X�b0���I�a��_�g�������ѻ]C�����N�Ҟ�)�@/�9�ޫ�]��ҧ:�M�S���b��](3�1
��������*,��$!���7(FG� �Y��zV�.e�<c'�_7�7��(b=Ი⹣85�;qI���n��JU�d0�o��خL�K��r�E���a��y��WuL+:��.�&ћ�@ȩ�y~��=?��a���O���T�E)v+���e,v!�-<OI:�I_M_s.Mk�f�5���.�� r����x��BF��H���d�3���:.�t�ZsEQ��W�e�I����]�$-�V�Q�C98rnp~: �h�LB�8�Ɉ-'�8�^�[�P4�1$PI�k�#�#Ps�A|�����7eʌ4h4)$g'��]�ջa����I���GJ�.˖jUΦ���}�&��>���O��͊�������L�H��Sq����^3r��oZk�d����5qV��7͟�]�%��bx ��s�D��8z�qs�M�]�yߩC�"��h��7ߗkbе���K�83`f��<tr�8Z����0��1ֽ������L6��02<��Dsz��F�=ԭ�_��[�]��q7I\MO�}x���,��#�=x}T�W�Y�ի���֗���%�O*���o�sp���z��ڔ�_w�4!��+�aD�CLY���}%/���v��Q��gp�_���o(=В�?�ZLJ�Wk�ZRT"S�j��R�K�%�5M�?Vˁ�kx��"�1(�B�{lj��H<�b�F�p~w���/����~"uq�Y�!�)-ε����xP2����.���E1�I\����K4M��i��^o��&Ip�8���3�y�e�^0�Á���=�h�iO���AH�ʱ
�5��Ug�r\PD!����e�1-�+T�7 �H7��kD�"�L�&#FN򊱪�g#��Jn���n
1-����3�A,�B��������ب�7ͧk/fC����k��XR.$#��¹ڂXi��\}sv�T�-n�cp+@�*ƛ�5Wp}�M�+��X[���<U��:�#tS���L��m��:�?X���Ctk��gj
�	�����fK��:]���U���:O"�a�s�q( �������7�H/{�3w���%_�"n6�A�%M�4��V�����@�U��l�5���(���͞I'���t�ݭgQA����SP�芓t�G�$Fx1����MV��zz����|͗�,2��F05~i������)�5 ��p����\;F?����+w�`�$���7��d�2Φ���ʝz��y����h��U����\��݋���
9�Y=	�}���J� �����f��5yQ���IS�dYbq,"�B�3&|�������"	�t���
���g�؇'�B�b�g�]:>_]7�GEQf:�����p�^ψ��`�?��
C9���M/�����UL"7��S�{��
~���+�3!�>�@��iQV)}+)�������8��Oe�ba�������	���E֜<�Y���d��RNg�~��5'sE�3�#u������M�v4ky��[�3WD����zTV/�gb@�q�M�䲠
�2f!�䲿r��>Ӻr3L&x���G�S�cy��b���l+�H�.��;)�9��U���`U7+A�8Ax�<S�@����RQ&	'z˅�) �,��bv��E�$������w��k�!��X�K��ܨ�kN�O�0�z������u2KnZ�v���X'��!4RH2�GX�H��2]D}�q(�mF��'����c��46�;XL�n�VhY��az�Y�UkY��������]����Q#K��	ubO��G�p�n��Քm[&ӯv_MV�.�"�~@qc��T�fk�J{�:��ӢOh���ZA��]u0��"D������?�G��x�W2��w��{��.ݾ���C%�e��o&.<�.�n�b92͔��ã�|U�߾��a7�	���qY���]�}�!�x��9�o�`��*���ۑT6��D�u��wz��(ԍI`|P�I��n�M|u/�2������vM��]>=����Ǌ4zI`�@ɲ�6��s�/F��b�TUQ��o�:�3����,ztY��+�0󙌿o9bh�e����߀�,#�޼�:n��.P�c�y�# FE7<�Uqv2e�qr3�y,�Q��`NF �$xcN͞qPb�L�>�(W�0�j>�3�@�b���� �+Z+(��b�݁�ޱ�-���?B���'#kv0�� �|eL�s/ �HV�5"�)ˆfOl�_I�Wd�{�ꢖm8�Z�$���W(>4K!�l%����AA3����X�����JԊ�"d��{����{p�'zhO�5ZQf(��h�,��a쒺rv���`��´������9�u���:ࠐ�Z��1_�]7�W>��cU榎R�����̓��ڕ�QXN�i.Q��Ů�LFA�Yt���.M�H.�js��is.�$*�W9b-�e�+c�I,9+6-�����w+�/�ä��
 �#{B:�d�bM�_ 	˒�8�+�1��G@C���B�A�W�&5,��ͯ������W	[t�X��L����=������aE�ؓ��GM<u��H�b2��vPs	 WZy��CW�ӽ��sqfl⢎^�%"���Ƃ�"�y�x�ʼy/�!i�!*�)4ׅ��r]�V6��"��9+�'^c��G��X-&h5�i�>���UI����e��K$#��)9AG�K�}��@��gٳ�A��M���}��|ONQ��
�{a���+;5M��'3�K@��L"))UtXf�؞H����1�rW�a*��w|U��ȹ�&Mm5=^iR��[ei�x��G|q�'�����*�ɼ���H��,�� ��S��>G7���[�4m���pB�e��S�E�*�'R?ɔ>��7���2��X|����`�T�!     O�$���͜���R��ʻ,N����<�@�0ye��0\*RiB����3�P�_��ZL�O�4�����VN�o�".*;�(��d���x�1�OZ6�"{��/W�yy�j���q]7�ÓǅS���4X	�����)������z?K��8A�K�� ��+n^�鋬����Ufļ��GA�Rb����:R�kA�/�t����Yh֊�I��`�K��#�U�	��\�=۱�f�O���ع���f10 ���(�@F�@=�����	bc���K�%�����;4�|	,u1�!��ggO:�����P$EQN�k���]�
� Y�&F�r���8���%�x��i? ��X-G���>t.�LE+��$�s�^�8zu<�\��1�I)�jz04M(T'��R��G���]�K��ֲ�vD��\L�i���:K�lz�Ry��(�J����{���3M�V�@�OH��$W_�bW�l�uݸ8���8	��*5�f��V�'�U�Bu�!�O�}h��.�#��1L��s���qZ6n�MR�o���W�9����������d��(]*���Ȃ�����������[O_xu�4�ʣ�2�2 ��/�� �ӳ6[UF�?�C�-��k^�&y��g�w���h���;���� �(ǎbΌ��@ۤ-�fz�����k�Q����x�8(��+���ȵ1��~<��6�1`��ÜZ�g�fzN�؅�U8���T���Rt"��2�R.��ha�<KTڦ�ܽ�xZT���HtDO�ރu2�B�z��5��΂]�yT�,LT5������I�h����:E�lu�=�6�\�鑭��ڕ�~Aj@��=�@h33	��i�l2E&�g�L�V���'����橚m��U9]�/�w��_��6[oJg��&�+�hN���w�6Z�>��5*`��@P�5��Un�cp.��6�!�==��8=���{� �$���HGJm��1U�����)�nr�R_��4�^<\�&O��*� ���T�,��ms3H����֒k�u�4�$u�pG�Eo��F&��5#3lOJ�������#5B�R`��uxF�������!�Q��J�]}* 	+e���i05?��� �#i�����n�'#��^ vk.�u����]����̕7�t��[� E�k���2{6v����0LZ������ԏ��v������D��𑝪�K�x�H���RGu����\=ζ(�U�ұq\z�y� �8�<�����b��z}�dg�W�Z����Y6u�WY>=!����p]D�!mA*�hxB�H黸Q�?ѹ�+1�u�~f�v�M�n�W{����WU�'E���6�5SP=���a�@�Rr�u�tlT��;@�cc+��p�����z<T�(�GY���8)�������Dc+�g�#��?q��*&��룞EP3�5��oR��q�?1�2� 6S�����e��Į@�?B���b�d�kR '�ϰ�����j�|���W��ۡ-�_Cy�9C%�Ud�4M85���n��]���ב*`*�b �f�Pnf<[^=���Դ�X��b�����*u��7Ĵva�]�>K�Xg�����h�R�?�_�z*BN[B�W��c��04f��oǰB����
�����gj��M����Eoa�Q��ݷ�f'85������'$�A�	V�<F���u�O/R
�8�gpq��c�\+�	��|U�I�T�4T��G����ۺ-�oXPe�?���%p�&���BV-��O���7���W��H�!���o�?7r�\��RC��`{�K�a==-,��<ǥ�¡��`�����?�QJ��)�df3j����Kn�����Ɂ���e�������CE����`}����� �߇�"�tȔ�ų����ME ��*!�?�)���]�-d���C]|Cl+�b�(\�� ��R\�}zxfa˚�ZǏ��9$�#5̈́�<p��@f���fG6eҦӛ�5��4�E���^���H��U�`?�~���6��ndQM��{(��U,�o�e�[L8k�^v��}�OgU業KU�r��k)���j�P�l��Ȫ�X��:�{�J	�	��ѿHQBk���(��(�������E�NOx�w;o�*��Ά���c�ұ)�W�������\l��m�>�~&������z�����;�%�D(��ag&�6�K��ý	\
��gތ]�X�v���˺n=uY�� ��L�؎@��8n��N�������p�n������@W�@p��ʙq����]�L�ZiP���˖�J��}�ۏT񕁒Z�̤j)�ޱc|>Y���#��&�}/��oɟ�����*m�{������Sf�W���w�'a����O>�B�n��[�r9~f)�Ix#�]�����B�A��P�QLlؠW2�1F��~I#.G��D�O�i��V5�)[irꍘ�(Z֣��*^Q�H֥���l�t����.�$�
[�I����#���Ǎ��Nd?StFnb�(Y��w\�%�sɤ�}�����9��4��4z��y�)(�����c��]b�SВe�����U�������91���f��i:6Rߥ�K����Ho�j"
#�vK��A��c�A-���O�B�e��
#�H��`^`��=��]�0r�Lpp}�o�]��ͣ6fiUq<��Y�c#[����6��]'�0䓃��q�u�����AI3NG��ݑ�,H����Z��|k+�%�߮]���7aVǵK5:e`R6��U?T�&a(s7~k�	m$J��#ܺ8�����(���(U�[�P��.�H���4�# �=��q�t�Q@���U�X�5[_���"K�ǪH�"�5Vu��xb��p
�PB8cӎ�rޭ~���qxM�� ��}�o�u�%u���K��N�P��.�$�:�z�Q�&׀�BD5��3S� Hz��K�Ќ�b��uQ~�7�_�]�dY�M�]�e��"]��v/J*�bP	E��(#�9�vs/����d���|D��c5�d8�� ��3���{�w�K�|�n.]����$b0��'8�D��� P+I��G�k�e�Jxy�8��a"���e���[*��#�ey�4�oڪpN�.I��~��)7DR�I4_��Iqmڂ��b�s��-���Ο�ӳ��g�fI�d���i=9�c+����v�b9�l�[�gm�O���8�?:��Z3j�XLT����\,"(�l�:�����B&�*i�	��}VNIv��~t�0�vI�J���_��ʜ���۾�!XԸ��Y���d�ǜ1 �-���������R�Q��D�®tE�DxzT�$�4}N�+YL�V;rꃝ��B��4l?'q������� �,xl�� 9�4]��
�n��x�0�B�
��e���D0����E����J�PL�0db�W�N�(D��>_dXX{R�̭��"Z��5�҈c|8�SxRՏ�a��0�D�8ty�T��{�����Z	4h�R]�ҺB�������D\�c}M<��ꃽ����[��&��M���>�K���*z�<��J�z�BA�	N�<8Abgү	,bLA���Vq[�z�i�?bFÈ�7��ӕi^Lf����������!!܃7C�a,�w�"j�\ޗ� c��h-'QV�,h��tI3����8��>@�@�6�����Pґc''�v�@��ǂ/�G����z1��\؎�|&�L�f��*�Lc }6�
^ق�e;�.����C����f���F�몢�oX�uV�Z��I�/+J���t�3���.��5!tq0��T`�R	��?|�N�2U�(�NQ�_��Iؓ_g�}h�)�'.�>��A� 騛��-�#O}�ц�R��e�:l}8�cVs�X��Æ>��)������k��0�Dfy�c5D�ݭf}rX6Q��Շ}{|�|����ܤ��l�ٌ�hod���q�(����S���U/�$���\Ng0�=���:�h��Z�.&��4M�T��4�����8�)��D����BEo����������+?*b��/��Ӄ���    ��?����S��[�v��I�L���!.3+U�,2��#e��"��Ѭʂ&e�B�(� &�у�@�s~/��s��\UL_�Y�e�E/�h��O�-����!�<L�����JR��x��V��>����2���s�O,���c�\����p��\�U.��6��\�Li��>"q���fخd"%�X��/(� FM+\;ku`�.�>8[��j��C��u�p0����A�������OA$N��nF�A�B��ܭ^�������H�$g��4G���S�ۺy����t/%�*R��� ��5������g����~���~uOa��������UXY�Q���g`˛W��<�&+���ֵd]ZG���ͮzi����{���&]%�5�ç�D@A���ֺ iu��q��~`iᬓ����E��*�pp������$l;��/�������=��=���0u��ɶ=�L��4����j/�4\���h�B�og���x��xp��C+��U�LD���P�  ��K��Y�H�Q�t��������/�R��ڞ��Mn�S���Y}�}��3�.<��� 7����f��Z��CUP���~��z��$+����bLM�Х��tg��vm\fn�Y[TeU�Y�ő�N"���K��,/Wq�0��������1ps,��:�k�y�LOH˴P"�˒Fk�m�y��eC
��W�W���'[L�e���ZWMo�eV;7fi����~�Z��t<�6�_m��^'o�oX�C���)���nv��e�NߝU�}�E�v�1�L.E4��Ť]�'�,�-c7��r��k���
)��"���"��[���-V�v
��OF�'s��`�;�f(+���={c:�����{V/������H�����_A�,�n���=�S�qQY� �8��?= �@����--�����.w��.��C]J�������QnK�cPV�]�r7�Hr7��f�UX��(��Ȫ�{����G	CS��4L�N��i �`i�c\L1tt��}!��ʖc����*�����d�EVi�g�~`�z}j E�G�����[CCd�i��Au�6�����oAx���){��[�y��n�.�޹q���m���'6	·?��5K-brG�����]`~��?���D�ΕoИ`��3?�%3��� q.��n]Y>�,Eޚf��,8����sG���I����+Cң"{7&�&X/)�B<��Š���u��U9=�e�d�"�I��Z�:p�WYD�X{�z:�`�w��@��w|7߭���ɓ���+�X�S�9)�0{՞������plREq�^a��q�
K�ȟ)��]fP�;�Z�?�����v��"���C{F���i魀v��f����.�w�!� �IR��Jnh���B���窭���t�ˣYb�]��V���,`�����
4Y���X7G��U��SW)��6m����4��B�l< յsH1�tӢ|��m.�U7e5U��pu�ٙ8	 g���+��q�'׊(�'
������{��V�@Mfstb�񩴵��)�ٿ����B����������6j�B\~�'.3�}���t./��B�t�?
Q��'���UH�0��UD����0���$����6�4�D���E2���|\C?��5}��7�QN1��N Ŝu#��!�~#�$6�(���ż���lv[}�u7L_�����y���%�i��?�O./;� ���*���Y;}pT����_Y0�-��6[�O�*n��Mi�^Kм�^�q�ҫc%Ӿ�{r�����1	 �l���o:���*V��1*i���� �o(#���є}24U�L���b�d�e��ؙ���$��OL�U{x��j"�+Nʎ���w��xS<�V��E��ú��,+*5�sy�|�'�C@WAGSz��Z�"�K+�m*x��蘒�1훭Ĳ��^H�vU�M��Y]%֬͡��u�/��� 2E^5��`f9B��ȼ��|����<��EO��ZD���DzhF�"+5��a�0oGt���4xT�X�b�b'k��rHQ81(bh+�8�2�9M�K�V<ܴ+cy���ӕ=2��)3���o��y�5��í(�T϶"�L8�V�OW���>q"�	�L��,�jy�>�ۃd&Er����y2}��>;�̤Ȣ�h-�n}$����pER����d%����������͕�,S�5�r M�d�O��G�S�X��4�U��*��߈�Aq/���[�e~/�i6�^H�ߋ����[I
x����|���)����{ ��QAZ��k�	���bz�{$iPH�̀�:=�Hn��+������D~�˖��؁x��Q *~����f*�d ��[�6\��ק�_,���!��)����5�k�+y��ۙ"�D�m.���_�� $&7q���$%�b���`�}ѥu<��-]�g
�,
�AGL����D� �X�q�i{�P�g�td��cl��.�9�K�Ӌު�S5e��CM@ĺg�OI4�c[�Pa:�g�,���q+�im�Uf��|a��Wt󄃾��T7=Q��Ma�~��16n��=O<�l�p�jß�b�^�~���x3}��k�DT�r��ɓr�e[eY�L?뼪*��u9�j��:n0&��❘(>	�Я�k��3���e����0�%j�p1��lc��r>���<k��/.z:��#4��	;�/�Q�Ac�'*�o�Ǳ�/V��}�9�����"�+�EN�ad4��)>)�޿T�z"s�5�<+t5�"$�3!�<��3������p��?�$ɤO�>��؏?+F�Z������Qö���FdeTJ7��ě�V���!�T8���U�^�\��b�p.��c����<в�8zl/�)c�*vT�gс]��?���q���w��7r�,FӜx��uYӷ�������2�~n�<��Q�v�=+�� �0�f��m^�O~�Q;�փ/��?������}�N'c6�����LAH���1����Oא�{�A�lt�yՖ)�Ŷ�lMW���j��QU�ްe�T���v���⩳r�����ԢH��^�ǣ?�&�V��gYR.6]���,q���J��x&٘�y$�)K��4��pӨ\�ו��kf�M�����_c��,���ZPO��!�Mw����%\q��sP�_��h��l�9=c��s��V��\[N�]�8+��2z�~���6'���-�M��'_EH� =@�R�s~~�PLʌyI|DOA�8zV��غ��::>��>�.��g1u��+t(i�G�q": i�	��Y�G�ꡣ�&i�fw���go�����i�'t���{J��yLaF\5�nvQ�H�2"/��$z3�l7�-��DX��F䄮��qO%����E���T�z��W�J@��G��G��k�Zc\��b����ʶ�+3����26ֲ�0!Q�^m�����V������~�Й�*p��;�[N�u.�ƾ�J7U�G,��7�Z\��y�Em�S�L;���6�PǇˤPC׃hD���r]ҷ�0=Ne�K����m�#b̌����P,��:T�f�JW�:�~���3TŰ顸1�N���6���40��ч� �Yb��b�������(ϋ@����;�Bl&���*���K�`d%i�u�����Y�%H�a_�tp��/⦜^>��c�&t�/��#��/��(Ô~�,�F���|�1���d/�Oa�*Fn9��Ra������Q���*��<J��zRW.��b��\R��t����U�V�<�u��$�3
�=7>�$qԅz�0y�i@��Q* 4i�v�ŝ��RR�,��*���E��)g��U�0��iCn*]7g��������;D�
΂���@�t�0���x�A��"�����s��Al��s�/�2w���We�B8�8�x�2T��JZ�Bd�r��;,_��;CW,��Kk�_giO��e]T�m�*��d��p���rkg�0���ܤO1D���eisI�����ܣ��D͍]UG?#����� �  Hz|���O�uԯ���o� �9��.-E m�0�z�J�x��" �g�G\��x�B?�$g�@2��8Yd��e�^�j�)�}"9.���&�í^ʏ����r������|؂YɉS�^�PID���^�,#H%@��Bp��F��q�j,}���_�G
xV->�'��o�p[��Eԗv1��l��'m\|Â���*��E�l����L|��ro�������'̻�쭫�`�,�I���겹ܲ��%�f�U]��6�:��{�5�Y��M(�S$3�q�&d���s"���	� @�r��-�+0WWtH�u���u'�o�cs`F��5�6{@^gSqI��<�4y xL�
��?����	v�	2_�b�ǹ�2CR'�7��\Z���Iu�L�n��������(�|F	gtL��!�n����}����rt� $���3���sf�d(�vzsʕun+�~�g�ˬ�z����`U�Xq���W�CZ�T�Ȼ$yi��e�?.
�YYxo����[�YC�)!vu��Gis��*C�X=��Y��!m�t��%XY�wq]D? ~gv['Jk���iّPT�ZO}B�Q��!�DI7��������|�Q����ʼ��~�^�&b��PL��$d?�pȁ��PL�x^�.n�^e���W^��kۂUq�����\A�o��[.޷������YFϥ�9d�$m��������:z5�����7��t��s��S�B��^����y%�!/�u5}�i�ֶ�ȎH�t�(�����j^_�.��,q_��:��K�I�6d8��|�ѭoޘw�a^>}!�Hj]G/��<ʰܴ��߹.�U9��Y�|�� +�d�g�M���韺$a��A:ѯ~Ү�hW? ��b��Qq�q���8"�Gj������͆�
�V&#<ӻ<KKS�vi��J��5$R(m0%q�R�B�U�4��Ķ����Vi��#��4�O&��,&��`���n觊�!(.v��?.�ފ����w}��F,�j��0�����dж@�T:��*a_�$�,n���|�Sݻd�����L���Y�h=.Z����6��V�p���c{O�+���!����Iw��;WM_�U�W�]��k&
F����
�y��0���������b��IQM��闤�!�AH��/���H��=���|�qʦ�j�z�Yݎ�N��\lk�%)��e�7����43
WG���%���ϩ��$��(�j�.�\��-ˮ�Ǩ�e�ݑ.�^8[�F����� B:)�,����֟�<5�����@�}0N4�4)���->�vȪ�N_�l�Wn�g�Y�֛Sw�݋V���k��o�&w���Z#��A���:N�.[w�2��7S�*v�~�5��,^��E�׸�+�,-�e�~H�$�,����뛯��y7qV���������k�_��Я��K�K㷻[��r��:JfT�]=n��������/��f(�.�ʯ}(I�x�҇��ve�\3�q��̥���7��]��I��i��i���I���?mZ���O��.�&��/�|���I��kj�������/@�ɏӘ$��/����ú̆�+��-��UwU\�q��_���_���گҴ̿���E7�ˏ�쭨'?�?'}A�g_��i��]��X��ŧ-�j��_U*��ϼ����!��/���H����|(Ys���ǭ����ɏ[�YU������6k��x��Vͳ�:)J�3/7k2W%ŗ��/�u���}+�����&�&?��Ӹ��/����e�V0���*ɝ|�uC�Ϟ6��8aF^����T���v�3/�,:ׯ��?�h(k�	�C]����$�q����|����*O��O����6U�NK\�/�����r��,�s�����|yR�����zg_��K��K��ǻ���/���Z      �   9  xڕ�;n!�z��G����,i���!�N�Lm��F��C���@���C�e q��U;^���B���о ������x�ވ���N�R��T�em�6����?��RВY���&B5�]�rd�a��xF#�!��n�q���Gs��!���f�9�p��P��H�d��<�`�P���?+�i�U�3�"�v�	k��mGB��r��)u�p�X����"��u]�����hd8>���]�%���t�}?ƍ�c]%_�Z�C�����g���F,g�O��(o9��۲̗sV�u�|�����!0      �      x�Ľ[s����}���b߿��·u�`0B�!���}����c�`w�i��V8�mp{B?g�?��2��d�#V�I+�IE%JU�,E���F�#bFD��?ߤd��MZ�8J��� LE8�B
*3�b��g�f�t?���ܙ�-��-:�Q��o��ܷE{�<�w��	��e�4J'�U;�,L1.࣌���1���xu���[Ψ�8.���پ��-yP4W����epv���7J77�)��)砬-ܲ���w^��y�A�}�k�^EAΝ"a�&]�q
��K�>��!�nP�U�N9_9����wD�ϡ���ݫ�G��|���]i��_�`'��I��?�B����?��;�C��G��WIɿ^�_�2BFY�*)�N�&�A�D�$�ķ�2�t��q�P1�	�*�>R�~+-�m���/�0w�=?,B���6��^>�������ǫ��]�E��<[͹���0���t��zС��^�ȪS��VK��[��-��R���?��iJ��K����b�� �4�����+M"ʨ�X򘥙�F�5�N"��o�ŝܜ?�V��N�/{��r�p[�"(W�[8��s
[��ׂ5��w��nD_X�d�7�cEɅ$e-�d��]��|��O���!w�'�����R&FI��R���`�41�Ɗ,#��4����`ZN=89�s}w��֗���e�ϰ�7h�u�@p���h%���mH�/^g&m�S&{���V?��>Gk�9^���0��2-�-FL,���%Z$IL�2�0�cMQ��$(˴���w�Z����b��x����
w��G8ȗ��jC�;l�E�w�Q��E�QwW��mT�|�Z����p;��$�Мk4�n�-��i��`}'��-����N�ddi�hq�pj���M�A�TD�D�����OU"#ű���t��Ε�>��{bI1>G~Ȼ�qN��I�҇ꢗ7�[VOn�0�3����!�cXX�A1"����_�G\8~3w��=a��\����Ic�ق=�	Y-��s������%������㏗]o�?x1B�����=w�^��g�觾�?7kQ6�� ��Y�h�5zR���rq����A�b�Kd��6x�����Oi�H�Q���ܷ���L1N�(C�#ۧ/��h�?nv�/�뿘V�44y5E�3�|ɜ����@���rGG�t�r���p�C?``�%�T��Ez9�ϖ��/`���wz�%���L����{.*(�zr
&�5�^�K�_��ߜ����S{�z����ঔ�_zo��P|{�z���X�L/K�LuLc�a�P�8�RD��HL�ov�券�G1:�c�A�.ࡃ1��a}����z�6}P��dz-e_]{��c�m�`wL���ʟtK僨���\��s&�����CC���E���N+��]��D�E��P��+�)�:Q$f'���/���é�@��k�6�E��������W��6/��w���B��!"9[�����r3���!��@́]�%�R��Vb��uZ&�i�0���Xgq�P��1�oa[���:����b�G�p[M���d�pm�Sp=���.�;��:��*��X��(:��O��p�x�K�%�FR�˴�;�,�<�|K+2 "��}�&)�(6E���Bx�D#Cu�L~p������wZ�#K�m��[@��=�9���]�(�@��i��S�Lw�aE��Py��x����´'�޳���|�"6J������-!�B��=�E"˾��`c"%b&�L�������Wجb<��qF������}$�j���~v[��el�#��",~^5�N��_��f�n��}c���<���f�ğ��m��Ջ�8�Z�`�#��o�T#�I�"*�&F	fhF��[�F�7z'��.�jt�sX�U�p�6ϞP�e�w�σյTc��Q�����y�6�E���i����u�6������.���e��T�Gz��i|�ȩ�D�p�eIJ�dQB��1|���z�H�|��ϕnk�r@���8�9D�����*���9`W=��&��i�P5��k�ސ��);���iW�����i\��%�m�}dK�����I��)Kٷ�bΩ�,�k�0U��̀���O�c�* JN	��-k|#p��<Y��m�k9ئd�>q.�A�E�V����rZ��j<w��q�M��s�	V��1���"�Z���</�R�4a_�F�N+#&��W� �Ƹ��3�#F����(3T���ˢ��rsP�9��3�-�����-�EP:����m�9EH�qp�iZt�.��c�T��As���`�$y��.ﳵ������EZ�o���V�Q��+T?�1�2��
/�H����������i9e�7(��)-18�|��*����cP6�a�-O�+s�s�|O�r��ՠ��H��p�Dƽ��N�f�a�lK�A.��m�Yb�2��կ{B$qN�Ei�U�K46�|�vZ��T�A>;�� [� G¼v�����j�����	u*����r�{�
�:��sL��cy������G��E��z��EZ���q��{Z?S��Q���*bLan�g�H�f<U&KoK�%���n�x��@`['׷���Mu��p���Z�����bV�,�<F��Ozu��V#���2P/�����HK"D�-�W�$F!����1��R!fTR,��n@�Sm�
�k�t��2�lQ�j��p@{�rJS:�!�^mjW�����!���|�m��*�7�sܜh�-�(je<!%wsͿ��~��2)�Q%1���{B0���0��L�������3hMn@룂��YXo�{� l�j�y�����?Y�+H�y�k_��
8xM�_x�^ڌ"@�����F5N�a:;��%N�}����ѹ@����eO�;�La�/��Xd�;R��Ȥ"e�V�E���JbB���
@d�^��h������ysp�z�~[�o��N�i�dcX���)���]�Z�i�ϟw�}Ш-�!��KZ)q;�<�5oy�V�p�=-L�V���i!N�8�\*�2�2����U�D���-�S���c�x#p|�����<B
�m��3��2��iqϴ���G&E�������
��F�~un���\���@j-/�z��*a������d��t+�������R�ca�X,�·�� ��>��8��R��[�S��� O��W��$$f�E���۲�9m�cY��]u>mO��}ϒq>O�y�Oj�}��H�=-�b�~t��S�0�1�*"�jr���ֲ2�3���� 	�bt
��	��Ww 9A��7����e�����>��'T���)%(�����t?HfԸn���p~�q����Jr�'�ﴨ$%�n[<�2aI�����&BÜ��D���A�~�tr�'�7�@ka��Kܹ�
x�3;��Z�����C}����i��߰J������������b�W*�'wH@���'�T��
ɱ��LR�K���2ND.�H�mi���e��$��CBl� P�>�A�'a=`/����x�����Ư�mo4�<�/��t5	L�m<��"X�#���i	�a?��F"�W8@�FFE1f�dq,! D#��ܸA)�S	��[!��0�]'�ڰ�,ܲO��}t��nG�Z��s�i<���ܿ�v^O5~f�]2?����}���\k���.�P	*C#��?K�1�JS�.�<���Ҁ�elp�4�q���sR����r�$��KAI,l9е]S~g�V#��	qP4N_�0'�͝�a��,-��
Y�	��N�����7R4�:^��Gt��]�.	��J8�2��%x�"N�S��פ2J)��u�ZI���֧._2:����J��r[��%͕S�s���ޫ��W�_��%5'>�k'9�/�n�_j�|�L���ʝ9�wfuN�Ga�R�P���.���3�!������T!2`*�a:���$p�X�T��֧.�ryv���uP�U    �9d�6��J�^���s�w��5�����6b�}!:����y���u���*�cvI��;"1�_(x�N+J�L��3D& ��3�p-Yl"�QLD�߶���x�^-ݼq�U�C�[wIA�m��Au��$����U�L���߯����A�9Y��*���h5��K�~�`[���}�x��wZ	��m�F�������h`�v�h@�"t[Z�:x��j���n>��q��-�><���#\���olkR��A���+���fP�j�4�>�ն�����z��	�ZY&Ez�<<U�m��|ն�ߨ�JpBoL˫���� 6����x��m�xg̱�ҫ�ɝk�:���<�FU�,%��4֏�Ng�2u��'�y�	�EZ��@�C���
� �KX�*�-E1�P��,��W���K�E�����P:��@.闐ӷ��h�˫)��q��"[�r�M6��C�G���m4�^�O�n�%��r.��Ls����a�M��_k�L�0����o��1�I� #S������o�Z�	�Y^9em���`[���z-w�C.v��u-Z�E����5�z}�.�Q&/ޫWrRk�{�3ޯj����H{ɕ�CvL��+ﯽ�b�dYtV����"
�Tf���͍!	�2���Y�Y��A��!s�A��55x�/�rc����d]�b��q���s���t�Q6u�I :4����(�c\���ˬ4G��;���DQ���֯�JHF����QƐ�$T�'qp��h}ȍ�z�p�*	l��_2��-�?��#����Wk�������^�vk��C�'���Xλ'�a�zg�$�@K�Ή"�i���Y�1g�ӊ3�\~�,Sb[?$XQlcۚ����S|�6���{?��A����i��y��:,:s{����>c���M�����>���:پN�����[��J�n�_��-��^��_�+}�'����<^��k��~�c38\\�[d }�M�#�T�cH�2�$t$��Hc���-_Zw���?��8A:����K{/�}�In��_�����`�?���h����roR������i�ڇ���x	�j�M�q�TLP�l�ӒkD2ESE��@�e�7��HH�OI��o�&�U�gz ������^ۦ`������6q�3��s���k����u��5�ǋv�k։9;�����(���p�Q8�����HOi{A��m��#=�a8�Bd�	�u�h��D �&cB�����S+��?��IȒ���?���Ǐ�qv�ѵ �]/�a�������@��u9��w�]�}���N�*E^}�^���Ҕ�ˑM�Ӣ�pE���S�_8JD�'Y�����)d�I�eb(�--�o.�b tg����qp��9���f�a�r� �r����y��ӡ���i�m�6�w�L�r��ʰ�w�q8�4.��\KB~@K)!�-������E����$X�,�C�-l�csh}�;�;z�sv--p}N}����� R���$�V�N��Q��dcw�jn���a>=��|Q�F�<�d1�����C
|�LK�ӊ��br�8f/zA�%��dL!}�41B#�I|[Z=�d��Ƽ6T"(E�an�Ni�xܩ/ONq��J�e=x}��U-"��~Ԛ���'��$����si�ݡ���fT��i�e�_���DSFR�cF�H�8�%�(	�S��i����a}F�2�zǎ�[�,o�	z}�įr�va�R==U���y��|S��!\�Q��v�MΜ��YԷ���"��2���H���xm1D��5�O��G�a	��d��,励46R"�ܐ�-��3�������	�7\����oP���	$c�j��ߒ�x��>uF~��d���FXM|"��cQ�Lgy��/�RTc�X\H)կ;B
��┤<3,�"�S�FTC S�rX����6]���tV���n��[4�\�U��~k��k�8Ws��Ž��ZK������jp)~�3tڶʊj>��%�"v�������I)�h��a%5iF(�����7�!d^D�¤�h}l۰���ye@p��g�ܱ&ղy�-4�y�7�uX9���T��ܛu���	��*^/=�[��T��Ѵ1UhQ[�˒��wZ
-�A��3͡$5	NP"d
�1��4�jq{����֧��b��u�R�����`nE�����I��a�w���D^�su\�IuБ�Z�W���f)W��>�G5���'�<aw�m	�.�bﴢ��~Ͷ@	�v�� �� 0�D�1��К�趴�����[sMY����>|�!�
�� Dr5�Z��#i&��ɓ�P9���[����<]�3u�n�_}�g_iQƘ��Ӳ����ϴ�Ġ4R��X�$1�B�d8�4!:�������Nk<���g��[����< 	s��R/�{��Z���i����%E����>�w���{$�~��UD2T�x&^�h�?�˴�;-�J�<!�*+�QA+֊�y
��1d^�mi9�C��@M����`���Y	R���`�V�=� ���'\<l�vY6���u�i��|�;�J��FI��$`Oq�"-��-�\��$�Ҙ��,b2�t"�45ʀ��qO��L@C$9x:�BH��y`���
b@���s
��]A9��n���x��6���_���k:L��ǯ��>͖��y�^H���#}U&|��e81��
eBp��YT&��D1XXqKq�T�ݖ��A����E��fU��9��6���>��/�cYH=yɋ���%�|�s/����q ��u�!�����EZ�^/�,�2���-iD���k�Kl-6JA-q$o �c�<q���߫G����j�a�����yrgȡ��n-��U�Y�֘�g���<��O�9�6���|S���g��%I(�������A5F �*�~P���.y�e��!�rI��X,(�A�����>�]�E�9��U��N{��z-;4���#O����V����$���+�bx��ΐ��)�SL�~rV������\r��HHS��;�W�����_��s,pdx�/cv� �2$g�%�mi�v �������­ϗ�aam�z
�����V�~G�i0i�F6-�����YO�� ���O��W��۹,�ii��?�eF&W(<b[Aea���k��4��<�|/�7��Iڡ`E��Lz�)	�Ȏj�(���7OW�Zoh�Wj�ic�g]���p��?���b��*�jgf~Ϧ{*�%O���B_ĭ�
�d�3d~=9�,U,�g&�Z���f�!�H��N�~��#O�}�y��i��S.A
������S�ոVr��ώ�|����,��{ä��� K����V�p�OZ�Q`�E�E�;-0�8����F���i�b����$!J
����rJP��T���ح/�Ӳ�[���2���[4����Z�fƧ�h�9��Z���}o2L��8�����[SY�H�2�B��/-sx�5�2��_�B�Щ&����^��
G���\���������z�oy�s;������@^��矖Xk�Wv�x�!����@L���ƺ��.����b{�HKs!�`Ŋ*~X )"BN`r�$�H*Ml%#Mn �c�	�D��A�\�cH��'67���A��[+�]�p�����b�r���q<8UM�Jy~���&���ѝ'D�ZI��X�3��e��>*MP�H�^��Z���"��
y��c�1�u��[hF�A5�!��ө7@T��E�m��Y��CoF��W�.ԙ?���txآ�6�>d����S��9w׹�g��?��Tc繓Kg���A5i���|)��T���H�Ǣe�a�����
�����Y�c�67�]%�/�`o�B�p��kђh�~�żZ��� q���#�>���y��O�����%Z�cN�L���	��
̈́��4�0fZ1�M�8�d<r�[�r�~�eh���K���7��3��^�0�,��Ay���u?�]�֖S�v+Y����x�4���]w�f�iQ�����.҂��$�-�&��������#��#�c�
��*��a~�    ~k���Pr���qȠp�>QΜz��j�����v�<�Աk�����W��~��*fxnF�q5�/��ԣVm��&�5wܫ��ѓ��El+���~��C8�~�-��������G[���J)�4S�(-����oo6,�d ��4c}��J�P�����;�2���6�7�փ�Л6�����g=ĭ�n?~�?O���s�-��`׿�MK"�6���i����<�ʔ$"fQę�*�I	8Jl$�$�u�<� ���|�(�Ж���0���%�9�ڨg�}iή�)��&O���Y#lσݢ��z�{3�"+E�q�?��<��_���0��m���1Qi�9f�
���#�aҤL� G��v�a�RI3z��������b@d��Ad[�I�Nn�=�������JS��n8�=N����p=Y�ω
��C�Zy��عH�#)/�m|�ţ�_?�B1U���o�FŌEYJ@�����gZ��ѫ7�<��P������/l�MX��J��e�s���h��� O^OG���vj���@_��~��g^�HK��F��@��8�B�<�ˡtQ"��$��*�� 	��Mh}�f�z�;��ۚѶ]X���Q�-~8�"���}q�"}Zo<�ƽʪz8o���so(�l���kV�礻n��E�_.�q�$��2,���]����EH1�pDb�hca(��n+��VN@�8����Bs �^�]��$A��E�%Ħk9��;�0fu8iz����\�Ӈ�*|P3N�E�^�����z��Zc�=�,� ��_w�����rD"�9�I`$(|��L�~Z�ο
���5=��{��ް�l�qʰ����u(�,̯��еZ��Oz�}@�N:��i�u�	�m��̓3'�>_�N(B�L���1x�?h���]�"�	�Ό��O�$�7'�E7����+\�~'��݅Dl���<wA�6u��3$h���Z]� [��G.F}ūOc�o�^x,�e�h���.f�S��Ze�R��� ��Ҕ~�%����_�� -��	3�L�X�$6hq�H��7��N=P9T���k�������l�ޮ (�6�aF^��e�R_�Ig�:z��ft���g��:�Ϗ�d>k_��&�� �D��a�MҌ'c;�K_	I!�F�ҿ�@e�>�e���`��q�c��������M��ֈ��:P��+O�3ͼu9Y��U����L͋�?t��qg05/�w��FH^��>�&ÑN�Bk(�R������ dq-�������X-�4W���,��y+ȏ�v��y�<��و]
e���t��~�����?t�j�������0-��A8|4Ө�� �q���r�b��V��Ȯp�ŒF�g6j)L�T%�S#�d�������`X�E��R�um�^Š5���{�> ��#�g�ZJ��NC��o��,�RA��}-����{�˴�dT��i�Ṭ_o䍣�4JS��eQ��Bg1FY�o@�c#o�\8�pؙ�e�h���?A$���D4 zWk�]������Zd�����y������Ν�,;{l����'Z�����wZr-��'��#{qKb5I�i'!1�?��>���V6���Js~��6�fn�\:E��`����<!�5�T����Y�S%jbX��7m��Ӯn6��i����-j/�(|����wZ��,Wh��(�o5e�0��(!�L��jx��mi��h'DA~L�X�-K) m��q�>e|uq򿷭	�?��ϕufN6��݅�wۃ��Ǟ;��?�&���jt��@����(�%W(�T�$��L��EA�B1�-�3����~Z+r�..|��ھkx��]�E2/����
!���,��Fe�z���8��lbڃ��uڦ��������f�(�_(2vG�2x�{�q"�+���g	���{E��S��<ɈV��e������G�Q+�#9,�v��9���/üͿ�w����MP���^�H3���Xn�;�ܯ_*���.�zY�EZ�!����8R�׻䱀<!�M�㊉��L�lף��O��=.����HH�����р�e�)/�Sv�е���r�bA$���Q�[�E��ۭ)�|Q�#U���&�wBq��������0��3��PR.H��I�$������Jo�	?�ts_��3l�e[7�v;�u]��ձ
�^�/���U�:ш��1�}D���^N7����K�HH�ʶ����Rr,�VD\>.a�V�i���	��$8�	�C�4�L��q�%D�����-��mwdȤo=��nZ;B�ݶ�6�����jG��6i��Qw�,S�
�ﹻ�N�h��p�H���8|9rs��FH��aq���Wh����9�
�e�FB�$(}(���� 	{�s�����6��-�	BB�\^p�?��ZW%�̴l���XN�����Y�a�q	´�r���S<�\(�2	��W�%�aE���1Jr*D�j�2&�Q;�ؑ��~��i�|�ڵ�v�Zϳ��};���;F#���CX��]mK�G+Q�;nv�� �>��9��/��A�#g��ζ�3��ζ���B����i	7����;��$�2dg��,���P"����ޖVh��[M���z}ȍ�"l5�R���n�� On]�.��;A㴷� 7���;���s����|��IL\�W�ؾH�I$(�-��FE���Z�Tc+
Y*S��qc�İ䶴@��6��M'o���)�lwZ(U������W����=��ۛ�r��=��2\N�r���y�����ҩ��i	!��1��!����]�&��H�F#�$�'��{LQ��G��m�u}Y�us
���Ɋ�9�׽�>w�������E�7��=ʚz�	k����be��tq�w�j��q�D��;L��h�W�iIc2�:-��@F�v�u�@ꔐH���miY2�ʷ+Ⱦ]�՜��jO�C���n
$_���u�>B����k�>�S�/��򙵛��8�ɰ����^��0�&�Z��I�NKB�y[�8@�/b�Ju�ql��m���Wnч�wi	���B��i;	��q
r[���ծi}D������u�y�y�ԍ<?L^�*��>��EZB�Z	��޶�!e߿�m�I,����
%P,�D,�F�Xޮ��-�uݥ�Q��a��lǺ:e� |�;*@zP�����v]��.Bk�E�ٺw��f�c�[��#�9�IFu�����G�WF�M�|�%�C�=����"6�4��l��C�G��7ؒ����7�L(�!E�a6-&2��qe�G<�n���q���)�o@���y���nxu�u��e�vb�����g�3������>=�*�Ջ�n�����6d%&�K���xk��?��C!�~�7�(���1�F3 �%��&���E�ݼG�=��	��H�)(KC>浩�<��x}t���`�+�M�;xe��I�܇��+m������1�T���Ez�����H� ��:=H�IF�r��bs�2ĥ&i��׌�B5~*L��m�1<z��������2��[�䐫�uF�����!��be�C�e|N��%sGM�~���x�^N�iq���B5�EKh-��i���ERe�h���^"Pl��mi���N�A{v�u����÷ƛ��j+0��M�k�Gl�9:���4&�r�Wܯ&g�7\������q�3j���?�ۆ��i�T�>��$M�Hy�Y��%�Ė3�xݠ�~:Z���˞� `��(�K���3d��� ��DO��N�_�i�	�c%�y���{zpj�^N|7�6�K��=�x־�N+�3�ů{B��1�#�@���B2�%�ud�--���x����eώ���Z�	���)���.����5׽VO��$^��<><�X4��ϣs�|4��������a��i�zS�{XEY�Я;�,J3jۡ���RD��Tb�eJ��?�pD?�-��0wߺ���� 4c��{�۞6s�����/F�Gh��W�	���*��]�B[Z,F�y�:O^g^{���pa  ��wID�H��;-! ����鑗2e�F    �!�j-�mc�R�8670�O���Zޫ�y����[�U;4�Չv׆m�Y��z�q�r�YR���N��\�/v������^�ݽ�U�����%I(�(�~��;-�b�ѯ;B��@�'��ױ����_���ƴl�"};����m�������0 H{^p�x-G�_��a�WJ�zَ@�����{ƏS��̛��~�z� 
����n������FE�H���lD��� ��9�/݀��n�:��S�W;�[G�m<�Ľk;|[���Z��<�M&ǡ#�}��Mu(��n��FnoҖ'>.����B]�%�,�/�|�'`�{X?��"e�	el�e8�S)tDiF�I��sl�A���dZ~`�j�I��cv��co"��=<��ZC��n�{�z:�4�����|�6�����NԮM'�:~�]�eWA1��eZ�'*2ՙ�ѯ��Hc��R���e,�B`m�n#��M��x��Z���[vB@��(4��-��q��~��{Ӛ6����_N0�� V���Us�s���c�i�;š��EZ�����>�R\a�}_��F^eR��^<�c��,"B��hCQ�[�}Z�9�/���]{��X��u8<�`_������p����G��x^��?X�����|�n�y_�[�a⻸LK��JD���uO�Li�SIS;�F�Ie��TI��+�Wʷ�"��d�O�y�����Q�4�����k�_����=a�>��������l���lUtf5+�C���H�]���\��Q�1��ȟ���F��~ݶ2�*o`�ہyi� de���KC��--xΫ^�m�4r���ļ�o���l�8��ā�\˶�.�;l-�ԛ�=I�ѝʴ��[���PdF���}N�����Z��7RH���q��8�,IblH��f	��rJ��h}L�}{�o�M�%�RnG�B"��緶���6�,��MrL���$�&h����!m�������Cw�����l[k'.����k��eZ��^:N����	V�I�8�bâ�Ķ���u$����r�9P]ز׎��ٙ'�m��ݖ]m���E������s���]]ws�j���r�i��95j��ʓ��\��1X���VD��U��k�?�$�I�D�v`��1I1A*J�oA�Srl��9���.�v���/�h�C�z�>���/���o��7Z��X��ϵ^SE�cg��a�6��4[�q���8���xBľ(<��Y�\VQ��P�<�vXWʰ`qq�$' yd�-T���8�m�ݱW��v����6����(Gg���5�/�U���n�]��v4������%�N7�D�o�:�x�1��T��Z�*%��z/��iZIj�p)3��İ{�3*F 	QF�a���
�� �
�6 @�U�V��U���an>;�՚C�à��3�����8<Ӈ��^פ.�#���������Z�HKQ;�{Z�TQ"ԯg�Ri����  2D�An2�Ȁ ����G����r�?8�o�/8���T�
�"�]��[%�����>;�&Do�y��ɠ��4�<��ƭz\���d�=t���Ÿ��f}A���ҩ�N�0�L�(cQ��YɘgHz��|��O\K&M�7{���5��Ԏ�q�q��l�?9̷��C1")�=i68,Z��\��Ƨb̣m�y>�G�<�CK����8AH��
�h�x���f�+�.,�dN��ִ�e�>^�κv��Eݷ�(��	l�䐫iB�@��1}5C������W���K-jc\'��|52i����J3��ӊ�ֱV	������	�	�"�h��w�~��+�>|��� ���J��3؜BlsWܽ[������Q:�GxǱ�x�ʾڹOj>�J���iqM�޶�홈�<a&��<cq��f7����"R$�}�Z�ie|�Ǟgp��
xE��5_-\b�{�|���C��jK5LpzH��g�Z��$�b;�~̘z~-j���#��	�eg�]�3)��E�sA��'�iBR)r�I&�['א�A��	��UĠOkܥݿ�v���[7�?zi���1{9ٽ�z!֪��7�:�<Ag{tj:���S�>L��N�<LO�%�;��I��;���i���J'D����H�4��Ԕ%�DHg�ĢJ�x�ϴ\�懫��-���0��c�ʠ裰eI��+�WsOh����+2ڱ���2��V�Hkߪa�J�r�y��EZ�cHS@�$1��{B�b�U��!��I�	;���0(2�4������ܪ�ڞ]U?��.ih���"��G�2����'��[b�ԝd���F��pm'�zK�9K�g�˧�u����A5zyꎗt��O�YO����Z��j��_Ħc�����M#Id��,�~�&n{�SFDL�b;s�2G�Q�����>^o�����e�.�rP��>9+���[�M��#���ӂ���z�w�t~��b<~�l��CQ�պ�}o��o��z6|��������U�el���k��D`�R�%� v�!�����n�'O>�����_�4�TX�)�xh����]�0�_�O��bu�[z6h'�ԙ9x�F��L8]^	+���9Q�"=�!����?҃�C�5n9��a.�M�����&6,����nن���ݼ�;ވ:�[Vvň�2���PXΪ�n~��zh�*��=�ˀn�ʞw��GߟDlPtz/;�ˋ�@ �Ed��$Ϙ�+�ɧ�]*	��ϚeH�Dhaxdn�?��#c; ��o��Vs�^^.��9�O@��ou���f�W��'E7қ,6�����x��麪Ko>/I��ȫEe7�HKk�/��|�e�H�k��3��J�g��D��&�\)1��o�Z��*�߷�4J'�î���4�?������۽�M��,���c8���#�V�yu·���i6?o|�XƗ<!��L��}���T��(~��Le�n��@���<e1RBc�����gZ���|��9�yv)����Zt[�#���Y]�6�<�ߍæ�Q|{F<U�C�ד`8馝�=���Cp�����{Z1�R��s�<a�FIb@�8��2Ƒ��I�~?-�����<�;˰����.*�,�z���4��j���-��j��u7S]v�j��]��;��r��M0�6��������22v'�V�Z��J���Fy-�Jc�El R
*C�H��a`�����Z�T�����]�����WVe��o�^����C+���/��Y-���S/�|~�Oq6��״�Y˚���c���¹@��Q,(��i�Wc�E:����#f�A8)�cRji�TFq��g8|���xe'w�`��vE��[���o��SڹW����C�)�[���A�p�u�b���\�:eO�i�j���.�qE��e��H_ἒkJ�X"!�c	����H�"���>un,AEtlO���dkS.����v锠!��O�J��,�x�\�7���6����MN���q��&�b��骹T�w�*�,�+�x���O��r��ғ4��0B���V2N���(�7���q��>y�w2�д�>ۺ�c�~��Җ��a~��P��e>ZD��F��3�6S�;t�����^w�Vb�{����/ʾ^k�	%鯛����xϒ2.�jl/�b{g�p�����Ȏr���䳭T�������3� m�L��٢�|x����2y�x{/�I�<�����2�ѾӸHKc�����h����f^�bDbI��JD\�ĤFRS���~��U�N����Ɲ����gniW.2���9�s��M����;�I�!\{�b�(��k_8k�A��6n��hu)9Vwrc�E)C��Ju��+\���R�E�Xc�r�R!�[g�f���֧k���Q;7�������C��i�o�(��%P��4��3���m��A،�k��˪���I���}J�٤�\�F���c�/h�W�RW��m%�-AKG�a�t�r#O�8N�8�-��mK����Ԯ���W�����8l@6�:��Z��ֺ���Ǵ֝���i�>���Y��ybd�k�V�^<    I�w�J7�?�%"e~�2~.9&q*x�3�Jќï���7����(�?&��C;��ޛ, �����"w=�a������j��*O����Y�=Lg�qP��a<zW�a��|���ӡ�OZ�.s������^iB�]�^���
��	O3�P��"��SiNnK�^�sʀ��
(l[EA�7��icT:�ph��]-ݺDq��9yL���<�L��k�
yZ	تI��4}���������_�2�Gѯ7���
b]�1NC�,3�H!�܂֧u��2�G''w�J���4z�����4!��)��4�瞷Gf|\�[�`L͛��}���{�q�<l�ym}��Fh�;	6q����+�<\�̯W੶^S��d�T�H�(��*a77���8�d�\o a�n���z-����
�8���ms���'�W�_�Ĵֽ^�ݏ�l�	^j��8%��k)f�Q䎁"��2���n�eLdW��0,�b��3����;E|�dt[Z �W�
���'�����[��-��4���)����jf�F����TQ�H���_����¹p�1�Ni��W��Y]�P���K���o�T3{%�������g{�ͰO�$^w����a4Fi\W�U8���$���hQCJ���c �<K21SEL%(�)Sr��y������fD�zr�H�Eb�_aќ����v����Z;/�����nV��u�8�A������F�㙵�O�k$�<H�Mr�9f�-������U�1N�d��5R.�^�06UN�;PB���0��]�?Է[��U[��� N q� �����H��0��h��l}h/k�Ѩ^g��)���<�ڳrpD�J���!̍�}C+KR7��CDeI��	uJ�4&@�!����^MA�
��T�ji��"����wt�!�}q�&�Vh53��3���uVs�Yg�l,i�gս�Y�[�����WѢ�JN~�2b��b+��d~����h,0��n� Bt_�� �z����?4�z���kW��B���Z��VhY�����n��8���c�j�?\������P�h�ۗ�U�8<�Oohql �Uk��/@$2���L�,5r�eND`��D_qQ��诲�!|(��7�v;�'|��פ�CN9={Z��ң�Z��s���e��(�j^�`�j��cޱm/�¦쏻	��rߜ���?<���?���)��(T���ZiL/g��$?���%��A�"�9�s�`����z�j�R���Ӕ�u��,Bxb�?d��8����K�9%��6�A��8ŭ�H5m�fM��F}�^��i���E��ߩ2�E�-� ��B�?Ec�
H<�)͡I&@��c�����W͏hA�{�5J�xǇ����TKG����*��y.���jp�y��(��'�vaWm�`?\Vn;>��Gs��J��\EK���	Z�̔�?ACJ�o8W��~H!�R�E�v��4C��N��C`�o$��s�r���	OˋT���<�]B�A�Հ�6<9{Hv!{*����-�7�*�����uk뼖�{�f3�F�}3�
r����u�TB9l=v�!<@=�*l&�a�$�6.�vJ�<)�b8�c->%RH`�i��f(���/�z'O����*�;3�6.Đ�A��h�zЈ������N��`[$bȎ֠�L^���qiU�xfF�}g�x��*�pZt����I���{�?¦���Q�	����BzLD�*�M)�#w��{�4��o��B�:zˆ�ӽsd��q�j�_�e��ʍt��;<vlޟ����sRoE���̃,MN��7e��K�
z���H1��JxU~y��D�^����e�ь2�+
�шi�-�~M�w�l���U�����T��g�]�^Q~��(�����t�eS��ӤD��f�?�� �A�뚚W6��&2f	y�$�U��L�W���	W<�)Z���'&Ҷ ���9I��8���q~_���!�ڎ�-=��}�V��P�a0�Agv֛���wa� ,,�Ī����:��z�^}v�ּw,#:b:�#w�W�*Z����X�r���)���)=My��tDe�IDιJ���[�*����-�dN��2̶҇�c����(��O�7m�vQL����t�������<��'��c�H��F���6���oh�*ffv�L�i&�he~f"�if�QC���}��i���-��tmw�j� K�ȇ_
�3�	�w�L��������ck���*�����Շ^�h?z�n%�6��e2��9Z\!��2�^Pĵ4T����% \*�c��w��9�⾖]\��aٟ}����n�,,�@!��-��dB7��|�)�/��&���gjӟ�Hbu�"�F��]�����)�N��/Z_EQ�Di�}�I'��j�57�!r�)C(H�F
�?�C�z��0ő��@�z礷ָ�l�Ub��j��_�L'o�QT�t6Y����ʹ�zƓ�/�����6�S"��"��%�D}[�-�n�6���LȠi�����0��s!�%K�#���E˅���B�����i�P��zi�n�B-(���*vƕ^��]L^+�N�ju�G�k�d�L�Mk;M������*ZIJ>AKi������S�8�@Z��?��a%cFͿ[��N�ɽ���k�������z[ͪ}rV�L���ļF�2�e
�G�j,6���I���6rߘ�E��	��8!��@��W�~�-����)���C��71�	���E��[�	3�i*��}�
���|��&�+|�?����j6�bG/G��<t(_�<`'�t�=���D��]uŶ����=�ƽ�U���	"��������c3�2ld��J%6�Ԇ�\eY��;���ΦR7�{��������g�\0�J��^r�VQq�;(I��;��r!��dX�l�n�/�hN<-�^�n�^A? �`����U��%�w}6@�1/6��2���T&,6$a�T��P4�7Z��qjG`+��t��~�H�2�7B����'V���-<|�S�>��&����*x-��<��TM�ۓ����4! �'h%�$$��L�`.�L2Ӕ��L~J!�1��h�߹�a@bH/��ˀ��/��N�y������wx�L8����_��~��ic�������b�E�kT�y=��L��ED�e���Rf�d��硕��E*e���H <��LBh�El���{)@��\��A_+�������B��!��cMoZ��jO�U���I��U�Q�e~Ѣ��m:e�df�0�|x,��0&&����H>��@��c�誅M}ZF���� i��������m�@2
�����ū�Ba��z�Z�ǅ�j���s;η�^yH_m���ת�|��~����v�,ëh���~���hŹ���-�q�S��<���!2˰���Z�(agᬆghrWn����8�8�S	�񬛵[=4�>��5?�a�)_I���ӊ��S4�g����=[_A�=�ӂ��:ZoC݄hw��P�t�<IS �H�(�ToR��J���,Q����v����_��~j.��"Z/��fd�"Zj+ �������gV��G+�r<�wg�jo��e�c��v Vɺ}�L�f�\\A�?��G$�mL�H �I��#��!Lp��M�Djɡ�^IL���hA�{r
���ѳ�	�@<T��r�eM1Zh[ ���j/Q��#���Py�%�^m�<���PM׽����`��i�*ZRr�?+�J�h�r��\Ii�ޭ /��D1V�;���#��)�Gs��
�_h���V��#|�����Y_0wo�S6���7;tz�:p�k����e���s�w�G��T�1B�A������dx�������<O1�#�ro0��4�$��ߡ�z7��օ�h����*�Ճp�'��f����g-P�o���hu�T��Ot5*�;�
F��a�N{�Bkb/_�V��[��N�C���:Zox��I��c+1L#�]i�R�1��<��^�*��}�
�ʶ�⿈���v��+����$��d���lo��7�V10��~s>��|?Zo�J���vչ�l<�fE�   �U��v�`���) q7@'Jy"�\Bolʘ�X�ŊBv�Z�^�[u�����bYq	h��j�R_w�i�²_DE�Vh_L{�s"6/�N9�p{&��q��/�.��{/({\���� ��� ��	|��z�5V���d���\M���3mhoИ�A��-�)T��2�n��b�\�"?�����,�Z�Z9AeSYZ�f��ɹ��]�j?7��Ǒ���μ3��U�(��K�-Aqf�[��E�T�ʄ����BŒ9����������.ߙ����������r�^�8P��Kh��$�Vg����>X�F�'��+�f��B��N�7��ܯ����v���~O�?L/����?�uy���X�k���he�����4V@.�o���@SAI�$wJ���ӻ��Uۀ�]hf�\�A�3/УM��h��pՙ�pJp|��,;u�v�7�;:�Al?m+dj6_Ɠ�^1��f��5�^���?2�}�kl�\�W-�in�1���Y�PM���㜣�)if2��hyV�伳��B��p����Zo
�J�sT�'`���ӥ�,�xn�6��p�3~*���n�n6�麂�v$��||�~�5�Aƃ X��_к����}����_���      �      xڋ���� � �      �   M  xڝ�[o���ǯ����]����6���B9A��+�!�9}��6�٫�ڙ�2�Tu~<��c�����;nm�'-�V�Ɏ��T�B�V'��I:���0��$E�������N�mIV�m��������� � }F�m���'6C�O$p����$`�?a@�8�|d�e{I���^Ƕ�%��w�e��.������J��r��g̞9ئ����G��ʜ��ܶ�M�t���P]v�kk�5Q���(M�sw3�r+[���G�򻆚��@�^�9�	r/k��\MOڈG/��q�� �����@u��}��S�Qh�=?�j�~v�E���;xY>q���m� z]�ӟ�F�^wG�a�ֳ��<���L�ב}=t�/�8K������lKl�W��.��������0�9?����/&YZ�Y�P�k#�0AMTT;��8H�� ��h�U�s�Z'Q���p�(ɡt�]�N�(��~�t%nm������\�p�R����j��3/+������m�Bms�MT��M�n:�f�)�fѝ�3������(-�EPV#��@U;�'��hTK��@�S��s� JE��G*���F����q��p�r�܄5�w�*I�
1K���
da���z��߅�����}�rt�Z��o�BD�
���3�w,#���S,v��We��T|[�B�D�HVN<k�I��f�M��ߪ���MV�>Q��c���f�fd00Չ1���k��o��w����>~����>��$���h�c�������.�{G1���f-��'�p��P8�91�>��b^��l}qt�Ww&۶��?w@�.?ت:�T�jJ��$@�Dd�3?��6!|����-�<m%�Q~]�,]�M��}j��Ϭ�g$���zLԩ9�jC�d�ڄ'��=� ��Y����t��Gցv��W�I9� �D�a�ު�$$[�2o��c�Z)��8K��xq&�GG������'�]G��i�u��N[�#�<��}�@�ߘ;�X���8;����/����?~bG�k=��A��w5��I�@���3�m*`�7��p%�؈���,�έKp50[3���бW�(��du�����5�}kJ�r��7;����>B��/�'��|4�⟢�ai_�w2�c��m��f5'I�ʺ�g���3�Y-����E�j��UF�g�,Ii1`��[<��C�(7«�>߰|�y�+Q����XZT�}�5d}�k׿��1?�|bI�Y'���\�ז�[�,��"��W�q�S�B���TwV���t����1��a������ߴ�QK�vQ\̬J�_Aq� �y$ ��t���^F�1s��;����~�G�e�\�;�Sq�6:��n7�k��w��L/������� .�,���/K���ſn?�M좌R�A���Ƶ	�И<.�
3���^*4�a���M��J��s���i�Djq�O����bY�咯UD9z3����gpn��]H�YٵZ,�4k�BmyH���EML4ˈnl�۠d��C�*S����J=��l�]˗˞몕}s�=O�ˑ��`r�"��y֜3<;=�����#��������p[��[#�KEEV���J\�y�ܹ�6:ng�:�;��O��N�8�0/�rˉ�l��c]	��E1�i�ǺK��/��.^YY6@�6��@F�o�s�&�M	
`�2�KX���0]�V��_�E�m3�Zӓ��BL�W��� >��.No�K���T5]WDXu�1�mu�ĥ�?xb7��Eva9u`k�El��N�;ڹF���L�������wi;1�Q"߱�πc7�ļ�|�>���w�G�O��,�6d��u��>�H� �h�ܩ�j��U����H�r�5��c��<�չ �8' �ݪ������+5;�D�lwH�q8��/Cr�!�FH�א��Lh��kT�h7��;M��Ʃ�ƭ�g�V��o̴���w\o�[s��'F,�g���[�f6ÐB�ː�=$j�D��M���fm����0/z��{�.P�Z�U��V�A6Th=��"Q-�G|�d]>H7��P��C:u���eH�7B�H�]�j�5np�Ń�B�\�l .zT..nkZ�F�s�h�E��ܬ�d�t�ɓNv�!���ś���g]nC(@�� �\�>טw%�~���v�r�`d��ԁ�6����:���Kx�G�3��g�F&�ͰE:ɥ���a����(�t�:M��Rz	�N��G������f|�����_����Gjq[Du�ɷ/{E�����u?��(��5��h� �w����.ؚR�Q6��`�f\���-�~��S{��v�ϷLڜқ�}�e'`��P��ѯ�C�wQ=�ͦ�g�_zv́�J7���^�T�Mܵ��^�cO!��"�'`���F�6x�*�Cʕ���[d��ɬ[��L~��)�#�c���v&�v�����Oz~���V
uk��Zc������7ns+mA!��Sk'�l:��~��(��</�.����HW�yd������=��T��6	�]��4��3Gې"4B:=m������R�{>�䭙39�8��i��T¨R��@�V�ܚKT�� ̙������{yʿw�z�	�;K��n�(jL�")�U��P���f��b��-i�r�3���B�/���O�a�߁�c�<_�"�v#B�}�
�oB~��Z��Ǩ�a�+�C����2��~�Mu3���h���1�����ězw�Xrr:�g!�c�P|����#���?#��)�|�2Z��>)t�F�A�0?��Z� ;]���ٔ��AKн����N�+����_��%�!�q#��c��`�WH	j�&��`��	�:��br�+e�҃�'�u�Ŗ�C�&��
G�A�S{c㒟��{�-B/G8cp?9�s=�&_)����'G��ay������x
m�����u糒�Ro�%�ݰ�-k�ΌK��
P�py9�%?K�ړsgԛ���n��� ǃv`�X�})0��>0��nK^�n��!i���Sɍ�����y`lJ'>�Z#3���l(��M���bS^aϔ��E"��X'⅏F� Z�Az�� �ː�{_G���-yѺ�7j�y��!��\U3扷ĥ��`�X�r��z�u�C��K2VJ����?v���J�P��q'j3����:-QH����ǟo�v��;��E9�8���0�M�=�Ē%�u]���U@l/�)�,��zpy�9�yX]{�:Ẃj�z�"�] ���ˡ�W-�~g�z�nK�1hS�q��m�����h�{����
�-�6�k/�i�/��s�2�%�ZxOzU��t^�4��7Hx����D�=d=��}��	��jה��i���p�=ΎdY�f�|�N7m��[E,�\��Pd���>��C^�e�>:��V`��I0Ǩ�j��p�t�5�&���74�����nr�Í�`p�j�k��iw��m�a]7+oK�r׶��Y�
��8����2��q�|O�c���<�/Cr,���%�CR� �1&c04g�n����z��R�壁�_���#2W��:�
��ۜ.
��{�t��J@������u���`�]b~��V4?&�iV$�� :n��&�U;Ƶz��o�������      �   �  xڕ�=�$8
��λ��C��AE��{sɚq[NE����/�L�ƿyO�]���"�tr�(�����������G�Ŷ�T;|x!��N]�p8\����	j�e�P���.�^��B]ԡ����M���ժ������^�M9���gy�( 	j�
�.�6�������UF#��ڝ�o
�>|ftU�eʅ��qg��.~�M@�T���E�Έ	6�9n=kW�>��ke�K�V��L������2�psW囮"%�+A��ۭnue�U۞~�k�QkI8���!r���Z�:�����dr���v��}��(z�@P�Q㷄{��yQ`��k�P�u�Z���\[1\��z�(�t��MU8A-�_�8V�\1����aT���]����j��}��U��i�*E֥
T�nIPP�������u����k��3��8�u�k)3�v�Y�����P��Y2�85n��2̈́�������xf{� �����!��P|▫FyI�EATn�ڊ����˖!esMu��!덊
L�+Np�rY��:c)�����*@�i5�Z�-�Q�`�L\ë\������.�F��"�؋�F����ZT)�J�*s��+ᨐ����)@��"bn��E�k��m�r�67'�Q���$���5�f�Nh���bQ3|�[qFsO|��]xċ�1�|��;Ľ�����?S# ֌x�C�G������^���$��τ���gj��9���i�=A��}ɵ����wjY!k�}G*mqżSq�J=�H%�&�ީQ�?[Ɖj���ѵ�P#@V=|���N��@=S�x��Ը�b����W�w*1!������p}�r%�~Qs����u��G�>1�a����opp={`���^�� �1�L-<Q�S�������"MP�@G��J4��
"@��Z�U�V�=򳻜���^�JE^�`N]O�5
{����OC�3��\�;��i�󟩢��;5�}nK�T���w�Ҷr���-�س��:g**�5I���Q;{ g�0��_+��LGjt�����gr���f�����4����~p���V��9�O�9���{� 0�+73�q�B��������7k��>��Z��ߩ=��ˏ#UhEK�w������u�M�_��RGo��%�ٺLN(0[øQ�T#@[�ײ���N�U��Q�c���P#���>|������? %6H      �      xڥ��n#�����O�P��M�2�$�A��`�r�r�������������} �L�k�`�]�ou�ڵ���UU���@��A�V1�vp*��������_v��O���X�i��'�ZQb^��w������ی����f��������K{}�O�_���AU���VU��|j���r���Pz0�-%�fFM��,t#�����mL�P(,r�R�%J�&R-�5�`�nc�d��nc*��,�m��8i���hϨ!*ۄnc�4b;npS�Y'r�f�68���F�J*MΘߺ������1���e����m.�8��3ޑ�m�ܲ�[܆T�2)�b�v�դzx�vk=��1�:��ncdým�I0gS��6���$
߹ݴ�̌j�m�L�-e��&U��(��m�k88#�I�)6*5������;��6�bU�]�I0��� o7_�	mFm��4�1r��nC*�uQ�؆�13Y�\��䝝���ilc�q֤��mL���d�qKR�I�v	��Y~*�f+�m�\����&U�+Y��q��5J2I]R�쌩�� �I@�����1WS�$�{�I0�l�)�n�B%*]Xo��QZ� �)���p�ꑃ �t����ӵ��g� Y�X6����a�D�$ה����&�Ԍ�EKk�\���Ti�&1��m��-����{��Q!̎�w�t�����w���UBf� �F��n�y��؃51
+@��I[��T<)�$7&7�޻��qv��t�� ��e�U��d]���7�D�dn�b�P��E�I0򘰵�P�r��g|t�N6����`�d�v���,�Q2��IP�@YK���� �ۣ�H�gT椥nc�fQU遢�q�q4,p���fǐ�Ra��9�ⷸ��Ĝ���p{�4jK�힙�d�+,I�%�U`��9���mL�h=�Z��m���id����xF��W%t#�(vh�ۘJ0c�.r��>]��vm%��i߭����WPg\��q�䬈����:�u݄nc�tؒI0�1qg�(�p�Rl�����9�_<Y�uL�e�$Jn����ۨ��*�m�k��n������P����m�l
��1[�R"�!�-&Il�T}�C������ƾ�$���h�EnC\O�,i��O�^�.�H.5��9�f�ۘJ��E��7�}��"efT��p%{�|��6�B�6�qcr5E��1��yF���D��V�%�`*�s��m��S3Z�9F��Z�Ҽ���ImpS�1�&r��8Jb�����4�^sɬL[jLE��d�q{kMIF�>j���Ψ��I�6F�<�3|�mLŎ"։܆��s����&�nF�ܪpv��N���	��Qi2��6Ƶc��$p�z]���IX���TԆWT%W+���\W�<	2:drEͨ�	GI�\k���mL�{kEy�mL�%�2�S��꥙#�j݆�T��	c��N^R�X�U�� �Ԙ^� ل�6�$���ZVbܜl��L�Ǵ)��ޜ}/R�1r!��*0�¾�j�˭k'�$\{n�cȽ�&�����ږL����d+���T���d��/������Qr3�-5	�R| ���f���m���S��C�G�� �_6����h��f��e���ͨ����������1vɈ*@�˽�}��C+l&���Z+CB�1�1�����X�^����J�m���!�l4J�6Fv��T���o,z�	��	j�CH��ۗ�'\��9�%�1�R���6�u��*x6ath�̪x�U�MXo���� AS�l.�q�w��팳LyF��'��~�6Fa����6���\㎒���tvֳk�׭0o�d���T��^�6�u]{�uI�5jR�8�4u�+H֖Ն5@P��Ƣ�ƥ��δ�!�fg�b�4�`��)o�$�
��EW n��g�x�v��Lg]��LV� 9%]7T��JI�J�M���R��f���PYU�pU
$����FU��*�m�kt�J��٨���Q��V�I@���7�۠�O�D��psH�j�g��AM�V5>4-�$(�W�p�U�d�}� �ؤ'WY�||�O����v���ï�㈒���+�V�+�����x:�>�/�__w��}�n�[јl�hvz2�������s>q�}�َ7�A�@��X������������8|m�Z����{�S������xjC�=�o�õ�NvT�
>�ؐ�\����~8ێ���^v����yx~y/MF� K�Z&����|y�?���/#�ve��u��������`[^O�_wO�߷��ܔ�dU�O��e?�����m�G��q�Q%rp�a�f����]�������2���O��IU�����>�.����yxۤ[IG���Vu�T����������{=^�}+Gc��:R��ޯ���N���e�_Z۽�h��w�a�@8�V
��~:���-g��������;�d�$X4e�g��_�h8�q��?�n����@��4{=	���T�o����<�m���:9K��'��������42�e�<\7ݭ�R�������$�|����r�n�(��rc��k���<�_����]����q�ƌe�`�l�y2T��t��Շ����֍�Z�D�",�S��m����x>��s+g| 8�:���(��/������V����z7�`��6*�Q���zٵo���ז�����n�OQ����u��G5�46o��Z	���IM�Z�!����yW�����n�Gi��{������/ߖѣ�6o�Ok�<~��a}�q	����aɣ����m����V�~�<{\��Qe��Z��.K��q���+�%O��gL��W��#��zn���8�,M�'c�ߗY\~�}�����G4FK�XQ~"�s��R���/��h���I��6�]��[����ח��/��eׯ���֭��Fi�������/�����2����z��1��ei��ai�F�YV�-,=
������e�����i�y4?7#�8���3,[t�����O{:y^��z�}������q�{P���?��t~��Zw��uxk��:&p<uE���:�Q�|�P��_���.�|�tT��oZ�~\Ł�q�p�������!k*�Wq nn^'���{���t0^���hSש�Y3C�X��W��P^�ҷ��a���m7�z���!��gԑ�"�܆ə"��6�ҩJ�����,p�5�ʣ�������lpT��m������m]M��J�.c%����n�*��1�
܆�6eNU�IF�J�Q�U]��ar����6��&�&q�:g�����c�U/O��F����U��uH���U+)���������!�Q{�y���m�̮%�J^sVɺ�~��פ��G�a�M�iyjF1��m�\s��6��v�U\�6ĵ.�������R�1J�6Jn���n�*�-���qOq�-�"�S*���)%��6�2�&���L�)�m2�4�)�,ߨ$r$G����n�Q�\���q{4�K�q�{(}} �Rc)Q�6H��m�$�J�f��>�p[�Z����蠊)jJ����m�܃�?��*�/ϓ�nCܮJ����!e&TV��"�a2+s&AU���Q�j*�<�,l^?�?��m�L��_�*�'u��!�����nF�X��]�QS�B�Qr�jCl�*�F-��׹1�E�\:8��������F����$�R��~p�z�k�������	�8�f��jߐIP���(� \���m.��_�u��Z�+�kkV��F����Ak�5�a�2BuU���j��8���A��Sj�$t$gg�����޳�m�B*���A�6Sj��enc�L�~�Q�@Z�7��Ow{t���R��J�6H6�z��mT%[��7{ө���}j3���6��Fɵws�۠��!(��������t�)5*�dn������T��K^�6�]�
���dt(��8��3މ�F�U�w�����Ƹ���N�n�V83���d�����n�ۨJ0�H܆��Je�g��CPnJe�0�Qr*��wU�jr�p�֢Z	x��t���U��n��<���n�*Fi%nCܑؕ���ݗECCSj Q  �M�6H����L���F���p�r�X�y{�ʺ�W*�#��(�uH��۰
E��!.y�c8��]z�PI-�|רg�����;\�9.�
�7�5��{[.���W�kTi�����w�Bܐ���酺R����r��m�\��n�*ݴ�$nC��j�%�n�*�6�6�+��F�䌹�mT�XG�!n
ѕeYu;��r�Sj���m����U��D��z]樨ۣC,�3j��4��(��!�A���a����*�2��`�Ҍ�M��m�����FU�'���7r�]�k&Ɉ�K���Z��i��o��?���$��ё�qV�=���7���ӧO�ǐ�~      �   I  xڭ�M�+9
FǕ��y��A!�Zz���/��t8k�:��<z����1|	׌�}�����"y|d�QF,! �߾Q������HY��� �ŕg�0.M05.x�P����/�Y +os�1�qf�}�8',�Ă��7�% ȋX`f���I�Vē�\��[�&�!��8!
pA�AJ�}b�$�$����Ou�mE<���� ��i?*$p�gTh�g�'�5��U�e�k��8şV�5-`8���!zX��V�I,ٷ�5H'q�X��q���*�ʬ+i�#q���$��〈
�qc^�[���&1� c<}\q�k��W��q3�>1G8�;�+஍�j��H�� �k�pE�y�����XWi����@r��iZ��?a��&��UPt�}Ԗ<>�'�*B��=��ĭ� �&Ff|�]�e�5�R\{�&@���0r�Ėv��8�����^
��bt���>���3�Gչ7�qȀ�ЊmE<�K�mbB{���L�!�a.�bΙ�~T$�����V!/`J)Ai�y���"n�z��Z�(��jAP�?@� �B'�8�s?��Ԙ�]�o��ty-�E�����b_u�#�S����CL�g_�G�b����C�ji�#�i�/�|����'��6|�c1��n����� ��>b�To�q҄�'�e��X�d_�r��8�uy>���b5
?����Rx��
��A�*+|�����	�O��u��ha��nB��c�>�3���-&�Ŧ$�@����.b���X$�߽X�ΦO+<;�-�D�_���{gS�G�O� >��r��c4N?�s/�Cl�G�������*���h�g/�Q���X-�T6�]� >�Qw} d��'��n>�>��}�`�����n�̅x�I⎏]=��8A_���cdV?�O�|�H��>��a��ľJ�GL���O�8�V�Vi1C�7���F��:Sq--��8 qD�٘�ǎ����!� N�%�ž��s4֘F���)C����Gl��7���x���>�<g�� �;>�B>bUh��tД5mıK�}�[�7�0o��U���;kڗ
Do9ve��P�E<e�~�aL�M��}e��ؾ|I7�ü���E, �Q)�"�G�>v�*4���~y�F~b��]�ZӍB�x'�g��'Ǟي&u0��1�UB� >9�wi7�y��}^ZS�O4y>`k�n4�dB�������E�!���ƔXq�Ǿ��[�n�1���r��e�l'{ ����c�TS�i��~'��F7�?38�j2��c�0ψ�BJ~b�V��qN��㌢�'vƱ�8�Yo�X2���c�1�_U$�ߙ6�}����Be��1s���g��G�uk���"�9�_�p���G|���y,��w,��a��+>`�F�Ǣ)��ط���9I��bU����K���x9���o�Gl������"��L}r�2m-����KJt�L#V]TN{�L[K=��rL*�g�=ľ��G�'�}���O��c_Y�#V%�/��7�<�>u�W�7�	%���اn>�f��b���V�+�\���x`��!dR�FT8��C�c�|���
���t�g �u�}�!Vy��{�}Q�#.�7��4�oA?�9�L*xF�[��������u��
zq/=��n�X"��}���xb�>f���'�m���h��9�F�*!q��V��A�WAľU�G5��5O�i��
_��#��g6�o�{�}������{�� ��w�=�|�� 4�Ս�Ol�l����<cN�l�����*6}7�&C���!b?�K�����E@���n�[_�A�%�C������<�O�~3�Z�^b��񽮉�*Jޔ����J������G�E�p�d}�������#&zk�}N��xEA�bem�O,`�y3�R2q��,f�a���,��XmE<�{�$����.;�{�;zlĔCx��fԉ��q�T�x`	�� F����6�9:�}��>b��{�� ��_�#G���p�80B��M��Y�K+�x�BH� �w��������@�'vE���V
��m�X9�S+B�1�|��&�WQ�b�qW������}N���#>v+�lc����LX?��
���(|�q��1���Y�:�'��	\i���:�s�E�O<bl��wq�fiw�;�C���?�f",6G�`X�J��8�X9��cT!�Ĺ��t�ԥ��ļ]�C��5�o&z��Ɲ�ؚ�k0bITK�'�����6�G�B0ּ򱨌ݷ���k��LO�HT�r��q�9nE>l!x5��̫ݺ����� io��ELA��>�.}�"ve�&.w�3��-if��G|��<i������X�rN/=�:Y{4B9e\�/f�C�%���O�O�'�֩�����:�����뤂���X�+�DI�ס�	�Ō�Y��������>�9�6�k�/��������S�pמ-�h��b�C8+���$����L�o�gHO8f_��fBT�}W&\զY�L+.,}�GJf���!-����3�4�\lz�0.-��K&\Y�"�4r�y������ ��_w��,]�p�%�H���W�����V�'}?la�WYq����҄��,e�vi��ʎn�k��g�~���I6�xiµ{|X
q�K���,r<��L'�A(�|���8��	�Y2ѡve�k����O�	�k��L�~\����f��ѻt�PT��'*�I�πN�^����L�]�p/,lÅ���4w�!�O:�6�T� 6����������������@�z��?�7��%/��lF��}jЧ^��	����0^X���b���P�GzB|�c��UV�X֜]��m�d��=���������� .��      �   c  xڭ��n7��w��E��t��(tt։ϛ8q�w/5�"��TW���O��9���E6��[�cj��^�q��j���ry��^_���������.����ǗϯO1�N�9��@�l�t=q��Q�3'a_[�I�`��B �1�A�!���z�����~�{�?�\�C}�ө���Ļ�2 �U��b�$��u*���h!���-�����D<����C$�~I�>�֜ũ2�G���:7��JH?ř�� X��VM_s>V?�5Է!
�5� jJ4�1x&�kE��Z��DS�c c욈�)����b"�C��B�p{B  ��i���:W&��*Cf�l�	k��A؅ 6�mP�ȇ�zy�}x�9�0��,���\�ePB2��*�VsLM��%��i��T���A��>8#�r}�A0�Q� B�g�`��[��ݨ�N� �N%�����B�j���P"��z��� �~̈}!i��)�փ|���.2�-�������]�B)1��U�VC<�|�V�Fֈʿ$bD
�6�A����y�"h�6�J��׫P�i�W��{�5ݾ���Cȸ$bD�U����e���b�28��a&a�����lt�N ��[����!Y!��!�sHy^�V����7N��xJIB��[��X+Ƃ�-P��[�G:6#>�w̈�>^z"vAx�Δ��3X��Q�;�8o�,�yL�����<Z�2�(D��L�F\�n]���b>&C���?�!�'�Ȱ���4�6��Z���M��.s�_.�c|���~�a�a��4S�,��>���Q�7��3	YD\���� �\ʱ��֖\����y����e����)5��[�j9V�/��=!�V�@�`��3e�:��,-�̂[�P�Tm��P�%o��m�I���W���~mx�[���@�tXt\%���{�]x*����+�8�靠R2ǺB}��x��s}R�[/�}W!�O_7}���!u�B�^��&vh�b�C/3§�mdm嘑�O�w߇��"�.���S�X�0�/�)5Hf��K'HE��<��CFZ��+���z#���P��We�x$㻍��R�v�����'Y��~
��"�CV�[p�{Cn��(��1�of\?�f�� �,ߖjpW��Q�s�ltM �B�'׳��E7�a�sw4�#`5��7k%����<$� ����L �����[���Zsy�\+RɱN#���x®�w��� ��2gL?�@��Z��V4�D.q�l��Y2N#plĐ_^����CvJJ`\X�J����p�4�W��5c��g/zب��C���TrV�(�e4K�Q�󟿝���c      �   �  xڥ�Ms�F���_�q�����cR�[�r�1�a���� �q~}z$pl/h�|�����w���F�P�brU*�Bn��\-�0n��]�҄ʻ������u/Y�s��+�������sf3����Kn�e?��Zkb��)A�W�-Q|R���y��:t��s� �;_ w!@Ȫ���.~�|���N�#Yn8M+a��1:l.�+��/�\���s�O}�m7�.����x#����("YR^�*�&yK[
-Vh���,��n�\�W�@�>B�����9/�� u�U�H�J���Bh-'u���ߤn�4�0c��=_"m�� �i����GYeQ���LL��.X�xh����_�/٥��*���k˥H"�(ף�S�,"�S{��ap�|����JN#2&���**��Z�Dt���ZOβ�꬏ }���jw�rޣР�I&�T�))7rz����g⫞%c��&Y��7@5��Q��WPE��Z��Cޖy��hCW�1��K5K�Ȟp6��a3����ص��[e?A�9|d�i�$�k>��Ś�@u�x��]ɞ�ȡ�3d���=��
�z�yM�9���W��F�wr���������;w�]�Bu�g�|���iu��I�5��\su8�d�<���߶�ҢRM9O3&�U��ۀ�6ڻE��aR�����=�< ���$GK�2�
n�5��[>�Ǯ([�>U��ͼ���x���@�J����G5��-�_ƭ��m5A>��-3Q�\Z�YRڱUEMK�dI˕#/����N�e�+��Y��O��G���TS(��T��@�"��/�c�coi�;V����]5�5�ȣ�aI�Ǩ哬�9j�J%y¨j�6���B�m���eu�)�?H�8��p�VZL�i��FƄ^����m�=�ݩ���St"Լ���T��MI�V.��B�
�Rl�u]��~K ��+��r���`5�I�}(@��t�X�K����9{p�]�7��?��8i����{�jɧ��7pQ���-�Y �:T��bT�X�>\��\d=^p�KK)�v�bS�>!��˻����r���g\�C]5_~�.'����ڕw�?�B+���1ʈ��F�¸�V�<�7TĤ�Ϻ���71� �ES�<El-շqu���Ⰽ�j"��{�~�<���S+	���1�m+2W��}`���nv�zvt�����F��*9��a�1�aL�`�_cW�[���;��g��� V�LBZɧ��%�
$ٴ�:��wH��1�9Uwq��&��r^0u�ؗ�Ns	In�������V�dvn�>k��qt��憪$��v�߷�"'���*[��8�ϝ);������[T��CZj|�e��$]��	����T5�{���l�]��:�C
�<�R�5,M�_x��I����o��d��<�������>F���U�q�Z~@T 'eĲ||�u�f,{��eWe��F��K("���a���J�O?F�ˑB[�� b���@潡fF��(�=X8P~��,f✪�����{閱�R-�X�~,J�����G��AJ�T L�Pb~��Ә�|�j
�r���Tp��|�:P�WBr�g�^��|�ŭ���� �>�Mq���z�*v�7o�nq��T�ۋ
f�qˈ.���o[��i:�Depc/	#�ʥ��%*.�謁��o�^������?}��7G#�     