--
-- PostgreSQL database dump
--

SET statement_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;

--
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: 
--

-- CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: 
--

-- COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


SET search_path = public, pg_catalog;

--
-- Name: objects_textsearch_trigger(); Type: FUNCTION; Schema: public; Owner: labitrack
--

CREATE FUNCTION objects_textsearch_trigger() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
  new.textsearch :=
     setweight(to_tsvector('pg_catalog.english', new.id::text), 'A') ||
     setweight(to_tsvector('pg_catalog.english', new."name"), 'A') ||
     setweight(to_tsvector('pg_catalog.english', coalesce(new."tags"::text, '')), 'B') ||   
     setweight(to_tsvector('pg_catalog.english', new."desc"), 'D');
  return new;
end
$$;


ALTER FUNCTION public.objects_textsearch_trigger() OWNER TO labitrack;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: objects; Type: TABLE; Schema: public; Owner: labitrack; Tablespace: 
--

CREATE TABLE objects (
    id integer NOT NULL,
    name text NOT NULL,
    "desc" text,
    tags text[],
    created timestamp without time zone DEFAULT now() NOT NULL,
    updated timestamp without time zone DEFAULT now() NOT NULL,
    textsearch tsvector
);


ALTER TABLE public.objects OWNER TO labitrack;

--
-- Name: objects_id_seq; Type: SEQUENCE; Schema: public; Owner: labitrack
--

CREATE SEQUENCE objects_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.objects_id_seq OWNER TO labitrack;

--
-- Name: objects_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: labitrack
--

ALTER SEQUENCE objects_id_seq OWNED BY objects.id;


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: labitrack
--

ALTER TABLE ONLY objects ALTER COLUMN id SET DEFAULT nextval('objects_id_seq'::regclass);


--
-- Name: objects_pkey; Type: CONSTRAINT; Schema: public; Owner: labitrack; Tablespace: 
--

ALTER TABLE ONLY objects
    ADD CONSTRAINT objects_pkey PRIMARY KEY (id);


--
-- Name: textsearch_idx; Type: INDEX; Schema: public; Owner: labitrack; Tablespace: 
--

CREATE INDEX textsearch_idx ON objects USING gin (textsearch);


--
-- Name: objects_tsvectorupdate; Type: TRIGGER; Schema: public; Owner: labitrack
--

CREATE TRIGGER objects_tsvectorupdate BEFORE INSERT OR UPDATE ON objects FOR EACH ROW EXECUTE PROCEDURE objects_textsearch_trigger();


--
-- Name: public; Type: ACL; Schema: -; Owner: postgres
--

REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON SCHEMA public FROM postgres;
GRANT ALL ON SCHEMA public TO postgres;
GRANT ALL ON SCHEMA public TO PUBLIC;


--
-- Name: objects; Type: ACL; Schema: public; Owner: labitrack
--

REVOKE ALL ON TABLE objects FROM PUBLIC;
REVOKE ALL ON TABLE objects FROM labitrack;
GRANT ALL ON TABLE objects TO labitrack;
GRANT SELECT,INSERT,UPDATE ON TABLE objects TO labitrack;


--
-- Name: objects_id_seq; Type: ACL; Schema: public; Owner: labitrack
--

REVOKE ALL ON SEQUENCE objects_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE objects_id_seq FROM labitrack;
GRANT ALL ON SEQUENCE objects_id_seq TO labitrack;
GRANT SELECT,UPDATE ON SEQUENCE objects_id_seq TO labitrack;


--
-- PostgreSQL database dump complete
--

