--
-- PostgreSQL database dump
--

\restrict XuEhiXEXREQGWvRhWBHJQAbSW4QwKKLwNmMQC5JZgz0grk5ABXzaQ4Iu1s8DMHS

-- Dumped from database version 15.14 (Debian 15.14-1.pgdg13+1)
-- Dumped by pg_dump version 15.14 (Debian 15.14-1.pgdg13+1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: hdb_catalog; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA hdb_catalog;


ALTER SCHEMA hdb_catalog OWNER TO postgres;

--
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;


--
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


--
-- Name: gen_hasura_uuid(); Type: FUNCTION; Schema: hdb_catalog; Owner: postgres
--

CREATE FUNCTION hdb_catalog.gen_hasura_uuid() RETURNS uuid
    LANGUAGE sql
    AS $$select gen_random_uuid()$$;


ALTER FUNCTION hdb_catalog.gen_hasura_uuid() OWNER TO postgres;

--
-- Name: auto_update_timestamp(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.auto_update_timestamp() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;


ALTER FUNCTION public.auto_update_timestamp() OWNER TO postgres;

--
-- Name: generate_transaction_id(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.generate_transaction_id() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF NEW.transaction_id IS NULL THEN
    NEW.transaction_id := 'TX-' || TO_CHAR(NOW(), 'YYYYMMDDHH24MISS') || '-' || SUBSTRING(gen_random_uuid()::TEXT, 1, 8);
  END IF;
  RETURN NEW;
END;
$$;


ALTER FUNCTION public.generate_transaction_id() OWNER TO postgres;

--
-- Name: set_delivery_timestamps(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.set_delivery_timestamps() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  -- When rider picks up the order
  IF NEW.status = 'picked_up' AND NEW.pickup_time IS NULL THEN
    NEW.pickup_time := NOW();
  END IF;

  -- When order is delivered
  IF NEW.status = 'delivered' AND NEW.delivered_time IS NULL THEN
    NEW.delivered_time := NOW();
  END IF;

  RETURN NEW;
END;
$$;


ALTER FUNCTION public.set_delivery_timestamps() OWNER TO postgres;

--
-- Name: set_paid_at_on_insert_or_update(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.set_paid_at_on_insert_or_update() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  -- When inserting or updating to 'paid'
  IF (NEW.status = 'paid') AND (NEW.paid_at IS NULL) THEN
    NEW.paid_at := NOW();
  END IF;
  RETURN NEW;
END;
$$;


ALTER FUNCTION public.set_paid_at_on_insert_or_update() OWNER TO postgres;

--
-- Name: set_paid_at_on_payment_status(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.set_paid_at_on_payment_status() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  -- If status is 'paid' or 'completed' and paid_at is not already set
  IF (NEW.status IN ('paid', 'completed')) AND (NEW.paid_at IS NULL) THEN
    NEW.paid_at := NOW();
  END IF;
  RETURN NEW;
END;
$$;


ALTER FUNCTION public.set_paid_at_on_payment_status() OWNER TO postgres;

--
-- Name: set_paid_at_on_status_change(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.set_paid_at_on_status_change() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF NEW.status = 'paid' AND OLD.status IS DISTINCT FROM 'paid' THEN
    NEW.paid_at := NOW();
  END IF;
  RETURN NEW;
END;
$$;


ALTER FUNCTION public.set_paid_at_on_status_change() OWNER TO postgres;

--
-- Name: set_started_at_on_preparing(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.set_started_at_on_preparing() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF (NEW.status = 'preparing') AND (NEW.started_at IS NULL) THEN
    NEW.started_at := NOW();
  END IF;
  RETURN NEW;
END;
$$;


ALTER FUNCTION public.set_started_at_on_preparing() OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: hdb_action_log; Type: TABLE; Schema: hdb_catalog; Owner: postgres
--

CREATE TABLE hdb_catalog.hdb_action_log (
    id uuid DEFAULT hdb_catalog.gen_hasura_uuid() NOT NULL,
    action_name text,
    input_payload jsonb NOT NULL,
    request_headers jsonb NOT NULL,
    session_variables jsonb NOT NULL,
    response_payload jsonb,
    errors jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    response_received_at timestamp with time zone,
    status text NOT NULL,
    CONSTRAINT hdb_action_log_status_check CHECK ((status = ANY (ARRAY['created'::text, 'processing'::text, 'completed'::text, 'error'::text])))
);


ALTER TABLE hdb_catalog.hdb_action_log OWNER TO postgres;

--
-- Name: hdb_cron_event_invocation_logs; Type: TABLE; Schema: hdb_catalog; Owner: postgres
--

CREATE TABLE hdb_catalog.hdb_cron_event_invocation_logs (
    id text DEFAULT hdb_catalog.gen_hasura_uuid() NOT NULL,
    event_id text,
    status integer,
    request json,
    response json,
    created_at timestamp with time zone DEFAULT now()
);


ALTER TABLE hdb_catalog.hdb_cron_event_invocation_logs OWNER TO postgres;

--
-- Name: hdb_cron_events; Type: TABLE; Schema: hdb_catalog; Owner: postgres
--

CREATE TABLE hdb_catalog.hdb_cron_events (
    id text DEFAULT hdb_catalog.gen_hasura_uuid() NOT NULL,
    trigger_name text NOT NULL,
    scheduled_time timestamp with time zone NOT NULL,
    status text DEFAULT 'scheduled'::text NOT NULL,
    tries integer DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    next_retry_at timestamp with time zone,
    CONSTRAINT valid_status CHECK ((status = ANY (ARRAY['scheduled'::text, 'locked'::text, 'delivered'::text, 'error'::text, 'dead'::text])))
);


ALTER TABLE hdb_catalog.hdb_cron_events OWNER TO postgres;

--
-- Name: hdb_metadata; Type: TABLE; Schema: hdb_catalog; Owner: postgres
--

CREATE TABLE hdb_catalog.hdb_metadata (
    id integer NOT NULL,
    metadata json NOT NULL,
    resource_version integer DEFAULT 1 NOT NULL
);


ALTER TABLE hdb_catalog.hdb_metadata OWNER TO postgres;

--
-- Name: hdb_scheduled_event_invocation_logs; Type: TABLE; Schema: hdb_catalog; Owner: postgres
--

CREATE TABLE hdb_catalog.hdb_scheduled_event_invocation_logs (
    id text DEFAULT hdb_catalog.gen_hasura_uuid() NOT NULL,
    event_id text,
    status integer,
    request json,
    response json,
    created_at timestamp with time zone DEFAULT now()
);


ALTER TABLE hdb_catalog.hdb_scheduled_event_invocation_logs OWNER TO postgres;

--
-- Name: hdb_scheduled_events; Type: TABLE; Schema: hdb_catalog; Owner: postgres
--

CREATE TABLE hdb_catalog.hdb_scheduled_events (
    id text DEFAULT hdb_catalog.gen_hasura_uuid() NOT NULL,
    webhook_conf json NOT NULL,
    scheduled_time timestamp with time zone NOT NULL,
    retry_conf json,
    payload json,
    header_conf json,
    status text DEFAULT 'scheduled'::text NOT NULL,
    tries integer DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    next_retry_at timestamp with time zone,
    comment text,
    CONSTRAINT valid_status CHECK ((status = ANY (ARRAY['scheduled'::text, 'locked'::text, 'delivered'::text, 'error'::text, 'dead'::text])))
);


ALTER TABLE hdb_catalog.hdb_scheduled_events OWNER TO postgres;

--
-- Name: hdb_schema_notifications; Type: TABLE; Schema: hdb_catalog; Owner: postgres
--

CREATE TABLE hdb_catalog.hdb_schema_notifications (
    id integer NOT NULL,
    notification json NOT NULL,
    resource_version integer DEFAULT 1 NOT NULL,
    instance_id uuid NOT NULL,
    updated_at timestamp with time zone DEFAULT now(),
    CONSTRAINT hdb_schema_notifications_id_check CHECK ((id = 1))
);


ALTER TABLE hdb_catalog.hdb_schema_notifications OWNER TO postgres;

--
-- Name: hdb_version; Type: TABLE; Schema: hdb_catalog; Owner: postgres
--

CREATE TABLE hdb_catalog.hdb_version (
    hasura_uuid uuid DEFAULT hdb_catalog.gen_hasura_uuid() NOT NULL,
    version text NOT NULL,
    upgraded_on timestamp with time zone NOT NULL,
    cli_state jsonb DEFAULT '{}'::jsonb NOT NULL,
    console_state jsonb DEFAULT '{}'::jsonb NOT NULL,
    ee_client_id text,
    ee_client_secret text
);


ALTER TABLE hdb_catalog.hdb_version OWNER TO postgres;

--
-- Name: address; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.address (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    customer_phone numeric NOT NULL,
    delivery_address text NOT NULL,
    apartment text,
    delivery_instructions text,
    place_type text DEFAULT 'home'::text NOT NULL,
    user_id uuid NOT NULL
);


ALTER TABLE public.address OWNER TO postgres;

--
-- Name: cart; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.cart (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    menu_item_id uuid NOT NULL,
    quantity integer NOT NULL,
    added_at timestamp with time zone DEFAULT now(),
    special_offer_id uuid,
    price_at_purchase numeric NOT NULL,
    CONSTRAINT cart_quantity_check CHECK ((quantity > 0))
);


ALTER TABLE public.cart OWNER TO postgres;

--
-- Name: deliveries; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.deliveries (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    order_id uuid NOT NULL,
    rider_id uuid NOT NULL,
    status text DEFAULT 'assigned'::text NOT NULL,
    pickup_time timestamp with time zone,
    delivered_time timestamp with time zone,
    estimated_delivery_time timestamp with time zone NOT NULL,
    CONSTRAINT delivery_status_check CHECK ((status = ANY (ARRAY['assigned'::text, 'picked_up'::text, 'delivered'::text, 'failed'::text])))
);


ALTER TABLE public.deliveries OWNER TO postgres;

--
-- Name: kitchen_orders; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.kitchen_orders (
    id uuid NOT NULL,
    order_id uuid NOT NULL,
    chef_id uuid NOT NULL,
    status text DEFAULT 'pending'::text NOT NULL,
    started_at timestamp with time zone,
    completed_at timestamp with time zone,
    CONSTRAINT kitchen_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'preparing'::text, 'ready'::text])))
);


ALTER TABLE public.kitchen_orders OWNER TO postgres;

--
-- Name: menu_categories; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.menu_categories (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    description text NOT NULL,
    image_url text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.menu_categories OWNER TO postgres;

--
-- Name: menu_items; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.menu_items (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    category_id uuid NOT NULL,
    name text NOT NULL,
    description text NOT NULL,
    price numeric NOT NULL,
    image_url text NOT NULL,
    is_available boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    ingredients text DEFAULT ''''::text NOT NULL,
    allergens jsonb DEFAULT '[]'::jsonb NOT NULL,
    calories numeric
);


ALTER TABLE public.menu_items OWNER TO postgres;

--
-- Name: order_items; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.order_items (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    order_id uuid NOT NULL,
    menu_item_id uuid NOT NULL,
    quantity integer NOT NULL,
    price_at_purchase numeric NOT NULL,
    total_price numeric(10,2) GENERATED ALWAYS AS (((quantity)::numeric * price_at_purchase)) STORED,
    CONSTRAINT quantity_check CHECK ((quantity > 0))
);


ALTER TABLE public.order_items OWNER TO postgres;

--
-- Name: orders; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.orders (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    total_amount numeric NOT NULL,
    status text DEFAULT 'pending'::text NOT NULL,
    payment_status text DEFAULT 'unpaid'::text NOT NULL,
    delivery_address text NOT NULL,
    delivery_instructions text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    phone text NOT NULL,
    delivery_time text DEFAULT 'asap'::text NOT NULL,
    scheduled_date text,
    scheduled_time text,
    promo_code text,
    CONSTRAINT order_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'confirmed'::text, 'preparing'::text, 'ready'::text, 'out_for_delivery'::text, 'delivered'::text, 'canceled'::text]))),
    CONSTRAINT payment_status_check CHECK ((payment_status = ANY (ARRAY['unpaid'::text, 'paid'::text, 'refunded'::text])))
);


ALTER TABLE public.orders OWNER TO postgres;

--
-- Name: payments; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.payments (
    id uuid NOT NULL,
    order_id uuid NOT NULL,
    amount numeric NOT NULL,
    method text NOT NULL,
    transaction_id text NOT NULL,
    status text DEFAULT 'pending'::text NOT NULL,
    paid_at timestamp with time zone,
    CONSTRAINT payment_method_check CHECK ((method = ANY (ARRAY['cash'::text, 'card'::text, 'online'::text]))),
    CONSTRAINT payment_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'paid'::text, 'failed'::text])))
);


ALTER TABLE public.payments OWNER TO postgres;

--
-- Name: reviews; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.reviews (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    order_id uuid NOT NULL,
    user_id uuid NOT NULL,
    rating integer NOT NULL,
    comment text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT rating_check CHECK (((rating >= 1) AND (rating <= 5)))
);


ALTER TABLE public.reviews OWNER TO postgres;

--
-- Name: special_offers; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.special_offers (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    title text NOT NULL,
    description text,
    discount_price numeric(5,2) NOT NULL,
    valid_until timestamp with time zone,
    banner_image text,
    menu_item_id uuid,
    created_at timestamp with time zone DEFAULT now(),
    terms text[] DEFAULT '{}'::text[]
);


ALTER TABLE public.special_offers OWNER TO postgres;

--
-- Name: users; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.users (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    email text NOT NULL,
    phone text,
    password text NOT NULL,
    role text DEFAULT 'user'::text NOT NULL,
    avatar_url text DEFAULT 'default.jpg'::text,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    username text
);


ALTER TABLE public.users OWNER TO postgres;

--
-- Data for Name: hdb_action_log; Type: TABLE DATA; Schema: hdb_catalog; Owner: postgres
--

COPY hdb_catalog.hdb_action_log (id, action_name, input_payload, request_headers, session_variables, response_payload, errors, created_at, response_received_at, status) FROM stdin;
\.


--
-- Data for Name: hdb_cron_event_invocation_logs; Type: TABLE DATA; Schema: hdb_catalog; Owner: postgres
--

COPY hdb_catalog.hdb_cron_event_invocation_logs (id, event_id, status, request, response, created_at) FROM stdin;
\.


--
-- Data for Name: hdb_cron_events; Type: TABLE DATA; Schema: hdb_catalog; Owner: postgres
--

COPY hdb_catalog.hdb_cron_events (id, trigger_name, scheduled_time, status, tries, created_at, next_retry_at) FROM stdin;
\.


--
-- Data for Name: hdb_metadata; Type: TABLE DATA; Schema: hdb_catalog; Owner: postgres
--

COPY hdb_catalog.hdb_metadata (id, metadata, resource_version) FROM stdin;
1	{"actions":[{"comment":"login","definition":{"arguments":[{"name":"email","type":"String!"},{"name":"password","type":"String!"}],"handler":"http://host.docker.internal:3000/api/login","ignored_client_headers":["Content-Length","Content-MD5","User-Agent","Host","Origin","Referer","Accept","Accept-Encoding","Accept-Language","Accept-Datetime","Cache-Control","Connection","DNT","Content-Type"],"kind":"synchronous","output_type":"LoginResponse","type":"mutation"},"name":"login"}],"backend_configs":{"dataconnector":{"athena":{"uri":"http://data-connector-agent:8081/api/v1/athena"},"mariadb":{"uri":"http://data-connector-agent:8081/api/v1/mariadb"},"mysql8":{"uri":"http://data-connector-agent:8081/api/v1/mysql"},"oracle":{"uri":"http://data-connector-agent:8081/api/v1/oracle"},"snowflake":{"uri":"http://data-connector-agent:8081/api/v1/snowflake"}}},"custom_types":{"objects":[{"fields":[{"name":"token","type":"String"},{"name":"user_id","type":"uuid"},{"name":"role","type":"String"}],"name":"LoginResponse"}]},"sources":[{"configuration":{"connection_info":{"database_url":{"from_env":"PG_DATABASE_URL"},"isolation_level":"read-committed","use_prepared_statements":false}},"kind":"postgres","name":"Taste of Addis","tables":[{"delete_permissions":[{"comment":"","permission":{"filter":{}},"role":"user"}],"table":{"name":"address","schema":"public"}},{"delete_permissions":[{"comment":"","permission":{"filter":{}},"role":"user"}],"insert_permissions":[{"comment":"","permission":{"check":{},"columns":["menu_item_id","price_at_purchase","quantity","special_offer_id","user_id"]},"role":"user"}],"object_relationships":[{"name":"menu_item","using":{"foreign_key_constraint_on":"menu_item_id"}},{"name":"special_offer","using":{"foreign_key_constraint_on":"special_offer_id"}},{"name":"user","using":{"foreign_key_constraint_on":"user_id"}}],"select_permissions":[{"comment":"","permission":{"columns":["added_at","id","menu_item_id","price_at_purchase","quantity","special_offer_id","user_id"],"filter":{}},"role":"user"}],"table":{"name":"cart","schema":"public"},"update_permissions":[{"comment":"","permission":{"check":{},"columns":["quantity"],"filter":{}},"role":"user"}]},{"table":{"name":"deliveries","schema":"public"}},{"table":{"name":"kitchen_orders","schema":"public"}},{"select_permissions":[{"comment":"","permission":{"columns":["description","image_url","name","created_at","id"],"filter":{}},"role":"anonymous"},{"comment":"","permission":{"columns":["description","image_url","name","created_at","id"],"filter":{}},"role":"user"}],"table":{"name":"menu_categories","schema":"public"}},{"select_permissions":[{"comment":"any one who is not auth(logged in) see menu items","permission":{"columns":["allergens","calories","category_id","created_at","description","id","image_url","ingredients","is_available","name","price","updated_at"],"filter":{}},"role":"anonymous"},{"comment":"","permission":{"columns":["is_available","allergens","calories","price","description","image_url","ingredients","name","created_at","updated_at","category_id","id"],"filter":{}},"role":"user"}],"table":{"name":"menu_items","schema":"public"}},{"table":{"name":"order_items","schema":"public"}},{"table":{"name":"orders","schema":"public"}},{"table":{"name":"payments","schema":"public"}},{"table":{"name":"reviews","schema":"public"}},{"object_relationships":[{"name":"menu_item","using":{"foreign_key_constraint_on":"menu_item_id"}}],"select_permissions":[{"comment":"","permission":{"columns":["terms","discount_price","banner_image","description","title","created_at","valid_until","id","menu_item_id"],"filter":{}},"role":"anonymous"},{"comment":"","permission":{"columns":["terms","discount_price","banner_image","description","title","created_at","valid_until","id","menu_item_id"],"filter":{}},"role":"user"}],"table":{"name":"special_offers","schema":"public"}},{"select_permissions":[{"comment":"","permission":{"columns":["avatar_url","email","id","name","phone","role","username"],"filter":{}},"role":"user"}],"table":{"name":"users","schema":"public"}}]}],"version":3}	111
\.


--
-- Data for Name: hdb_scheduled_event_invocation_logs; Type: TABLE DATA; Schema: hdb_catalog; Owner: postgres
--

COPY hdb_catalog.hdb_scheduled_event_invocation_logs (id, event_id, status, request, response, created_at) FROM stdin;
\.


--
-- Data for Name: hdb_scheduled_events; Type: TABLE DATA; Schema: hdb_catalog; Owner: postgres
--

COPY hdb_catalog.hdb_scheduled_events (id, webhook_conf, scheduled_time, retry_conf, payload, header_conf, status, tries, created_at, next_retry_at, comment) FROM stdin;
\.


--
-- Data for Name: hdb_schema_notifications; Type: TABLE DATA; Schema: hdb_catalog; Owner: postgres
--

COPY hdb_catalog.hdb_schema_notifications (id, notification, resource_version, instance_id, updated_at) FROM stdin;
1	{"metadata":false,"remote_schemas":[],"sources":["Taste of Addis"],"data_connectors":[]}	111	5da6de7d-cbf9-42b7-81f8-a5295b90bd47	2025-10-20 14:14:03.598851+00
\.


--
-- Data for Name: hdb_version; Type: TABLE DATA; Schema: hdb_catalog; Owner: postgres
--

COPY hdb_catalog.hdb_version (hasura_uuid, version, upgraded_on, cli_state, console_state, ee_client_id, ee_client_secret) FROM stdin;
f3ff653f-60e8-478f-9caa-b0b05cce5822	48	2025-10-20 08:18:32.028503+00	{}	{}	\N	\N
\.


--
-- Data for Name: address; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.address (id, customer_phone, delivery_address, apartment, delivery_instructions, place_type, user_id) FROM stdin;
a16e2d15-2777-4063-bcdd-d51920eda56b	934323213	123 Main Street, Apartment 4B, London, SW1A 1AA	Apt 4B, Floor 2	Ring the bell	Home	ee5b74bd-a337-4ef4-864e-95bd20b5f20a
\.


--
-- Data for Name: cart; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.cart (id, user_id, menu_item_id, quantity, added_at, special_offer_id, price_at_purchase) FROM stdin;
b98498fc-ce60-4d40-b3f2-8e0d6a6e8dfc	879d0399-111c-4ec6-a473-f03f1d10711c	76f8fe68-e951-4987-b103-53286307029a	1	2025-11-13 00:48:19.707896+00	f71bc3ca-7e19-4453-a0e1-fbe77d4b1faa	80.0
f358688e-9e3c-482a-af96-86db67b08dbd	879d0399-111c-4ec6-a473-f03f1d10711c	b1431758-8abf-42be-9821-48476d649fa5	2	2025-11-13 01:18:17.165471+00	\N	80.0
00784f2e-6077-4d98-a50b-0f4be34e7820	ee5b74bd-a337-4ef4-864e-95bd20b5f20a	370e0ee7-2571-49ed-bddd-abe122c1484b	1	2025-11-15 21:01:44.02532+00	45c24fe7-a04d-4631-a0a7-3596a2b31201	100.0
98087d0d-df8c-4920-b704-8614176bd272	ee5b74bd-a337-4ef4-864e-95bd20b5f20a	0ee81d93-f695-4d27-8c74-2d3aa24c8d1a	2	2025-12-01 10:55:47.480157+00	\N	50.0
\.


--
-- Data for Name: deliveries; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.deliveries (id, order_id, rider_id, status, pickup_time, delivered_time, estimated_delivery_time) FROM stdin;
\.


--
-- Data for Name: kitchen_orders; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.kitchen_orders (id, order_id, chef_id, status, started_at, completed_at) FROM stdin;
\.


--
-- Data for Name: menu_categories; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.menu_categories (id, name, description, image_url, created_at) FROM stdin;
9dfdb455-2160-4d47-b35d-96954ea26335	Traditional Arab	A mixed rice dish featuring meat.	small-meal.jpg	2025-10-22 19:39:24.671632+00
3d8e3ea9-9508-4e76-88d1-e651593312d4	Dessert/Snack	Sweet treats to end your meal	cookie.jpg	2025-10-22 19:39:24.671632+00
9b8c7f80-27d8-4198-88bc-bffbac0a3a2b	Sweet	usually sweet, made from flour, sugar, eggs, and fat.	sweet.jpg	2025-10-22 19:39:24.671632+00
\.


--
-- Data for Name: menu_items; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.menu_items (id, category_id, name, description, price, image_url, is_available, created_at, updated_at, ingredients, allergens, calories) FROM stdin;
b1431758-8abf-42be-9821-48476d649fa5	3d8e3ea9-9508-4e76-88d1-e651593312d4	Shakshuka	Rich chocolate layered cake	80.00	meal-6.jpg	t	2025-10-22 19:45:14.746176+00	2025-11-04 12:54:31.055402+00	Premium beef patty, sesame seed bun, cheddar cheese, lettuce, tomato	["Eggs", "Soy"]	850
0ee81d93-f695-4d27-8c74-2d3aa24c8d1a	9dfdb455-2160-4d47-b35d-96954ea26335	Mandi Bedouin	Freshly squeezed orange juice	50.00	meal-small.jpg	t	2025-10-22 19:45:14.746176+00	2025-11-07 21:01:31.483085+00	sesame seed bun, cheddar cheese, lettuce, tomato, onions, pickles	["Gluten", "Dairy", "Soy"]	850
ff00be43-baa4-4111-9f5d-d71d25768bf1	9b8c7f80-27d8-4198-88bc-bffbac0a3a2b	Baklava	Refreshing cold cola	40.00	meal-4.jpg	t	2025-10-22 19:45:14.746176+00	2025-11-07 21:09:42.945873+00	Premium beef patty, sesame seed bun, cheddar cheese, lettuce, tomato, onions, pickles, special sauce	["Gluten", "Dairy", "Eggs", "Soy"]	850
b96edfad-fd7e-4283-aedf-6a8669b1d5a5	3d8e3ea9-9508-4e76-88d1-e651593312d4	special cookie	Vanilla ice cream with chocolate syrup	60.00	meal-5.jpg	t	2025-10-22 19:45:14.746176+00	2025-11-07 21:11:14.530678+00	double cheddar cheese, lettuce, onions, pickles, ketchup	["Dairy", "Eggs", "Soy"]	850
76f8fe68-e951-4987-b103-53286307029a	3d8e3ea9-9508-4e76-88d1-e651593312d4	Cookie	A small, flat, baked dessert or snack food.	110.00	cookie.jpg	t	2025-10-22 19:45:14.746176+00	2025-11-12 23:10:30.865742+00	beef patty, sesame seed bun, cheddar cheese, lettuce, tomato, onions	["Eggs"]	850
370e0ee7-2571-49ed-bddd-abe122c1484b	9dfdb455-2160-4d47-b35d-96954ea26335	Special Mandi	Grilled beef patty with cheese and lettuce	120.00	meal-small.jpg	t	2025-10-22 19:45:14.746176+00	2025-11-04 12:54:16.870044+00	sesame seed bun, cheddar cheese, lettuce, tomato, onions, pickles	["Dairy", "Eggs", "Soy"]	858
\.


--
-- Data for Name: order_items; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.order_items (id, order_id, menu_item_id, quantity, price_at_purchase) FROM stdin;
\.


--
-- Data for Name: orders; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.orders (id, user_id, total_amount, status, payment_status, delivery_address, delivery_instructions, created_at, updated_at, phone, delivery_time, scheduled_date, scheduled_time, promo_code) FROM stdin;
\.


--
-- Data for Name: payments; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.payments (id, order_id, amount, method, transaction_id, status, paid_at) FROM stdin;
\.


--
-- Data for Name: reviews; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.reviews (id, order_id, user_id, rating, comment, created_at) FROM stdin;
\.


--
-- Data for Name: special_offers; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.special_offers (id, title, description, discount_price, valid_until, banner_image, menu_item_id, created_at, terms) FROM stdin;
45c24fe7-a04d-4631-a0a7-3596a2b31201	First Order Discount On Special Mandi	Get 20% off on your first order! Enjoy our delicious special mandi at a special price.	100.00	2025-11-12 00:00:00+00	offer-1.jpg	370e0ee7-2571-49ed-bddd-abe122c1484b	2025-11-08 10:57:51.822318+00	{"Valid on vegan items only","Available all day","No minimum order"}
f71bc3ca-7e19-4453-a0e1-fbe77d4b1faa	Sweet Cookie Discount 	Special discount on Sweet cookie!. Tasty!	80.00	2025-11-12 00:00:00+00	offer-2.jpg	76f8fe68-e951-4987-b103-53286307029a	2025-11-08 14:17:23.108278+00	{"Must purchase a combo meal","One per order","Subject to availability"}
c052bfe3-f561-42be-be46-12577969f746	Baklava Discount	Special discount on our baklava.	20.00	2025-12-12 00:00:00+00	offer-3.jpg	ff00be43-baa4-4111-9f5d-d71d25768bf1	2025-11-08 11:06:32.456304+00	{"Valid on vegan items only","Available all day","No minimum order"}
\.


--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.users (id, name, email, phone, password, role, avatar_url, created_at, updated_at, username) FROM stdin;
879d0399-111c-4ec6-a473-f03f1d10711c	jemal mana	jemal.mana59@gmail.com	09065432654	$2b$10$mBSfZhSojTUGEKG/feY.hOyGcFXekY.JE/wmIzqyc6kJnXU8CD7BS	admin	default.jpg	2025-10-27 22:35:18.847708	2025-10-29 14:21:51.165362+00	jemal
ee5b74bd-a337-4ef4-864e-95bd20b5f20a	anis abdosh	anisabdosh@gmail.com	0923435433	$2b$10$Lq5cIBMyW1rN1b4QI5hyZuHFt.oMZhmnrpuCQYVNM5CysZLXwB9La	user	default.jpg	2025-10-27 22:56:55.406942	2025-10-29 14:22:48.051035+00	@anis
5dd76a36-6d33-4e2b-9305-21f18e2f2b96	zuber abdulkadir	zubermana@gmail.com	0923254670	$2b$10$uuMX.NJI4BMAPDd1M/e1E.div30dLpQvZc982J0CK4wApiZYLmDE.	user	default.jpg	2025-10-27 14:55:04.553496	2025-10-29 14:23:09.185863+00	zuber45
0d3d1c68-9c2c-4d0e-bf50-9da01e666ed7	amina adem	amina@gmail.com	0987654532	$2b$10$1lkVxcuYPngGKtOVw.rhQOrflYx9sBvt0dReIOKGYPx9DGLmjNVwi	chef	default.jpg	2025-10-29 14:29:04.083645	2025-10-30 04:26:14.699319+00	@amina
ca1f462a-3a3b-47d7-9682-ecd34df1a205	beti dagem	betidagem@gmail.com	0927345321	$2b$10$eXDWJrYmUV2uorZH1MgdXegpX52pXBfSmko99iM.Afv4OadADke82	chef	default.jpg	2025-10-29 14:32:35.388251	2025-10-30 04:27:13.379459+00	@beti23
b39486b5-7da3-40d5-80d3-3f653a6feeb5	leul yonas	leulyonas@gmail.com	0956437643	$2b$10$5N4eTaDo4eHddbrXRDk.Quqp0hdUDH3A2nmMNXPPZF7PbbvnyY5yK	rider	default.jpg	2025-10-29 14:55:29.08433	2025-10-30 04:28:15.667852+00	leul
9741a15a-c881-4e9a-bd09-0d53efa6e44c	yonas leul	yonasleul@gmail.com	0954342211	$2b$10$O8WJUQn7jfPlG8Ji6BBsl.jW0hCpfkvk6N4fDEA.IMdnduOSc36i6	user	default.jpg	2025-10-29 15:02:42.46866	2025-10-30 04:29:20.633748+00	yonas32
ab12e169-7af4-4d0f-8bc6-3f17a3459c15	John doe	john.doe@gmail.com	096754565434	$2b$10$Y0ZIJuhnM1GaRetblWzmCu.WoL1iPLJnLkZZN47WIzPAYI0iA06Pa	user	default.jpg	2025-10-29 14:52:37.15444	2025-10-30 04:29:51.515653+00	john_doe
d45a75fd-fb8b-4863-b0ff-c7cf8ca9b041	dawit alemu	dawitalemu@gmail.com	0978678765	$2b$10$gZJ6XgbUeA4kdJMEmv2GkOmkqQKxIcQSAzIXZacU5b44SCja5pi1W	rider	default.jpg	2025-10-29 14:39:12.176162	2025-10-30 04:30:05.462792+00	dawit
e174720d-77ad-4de3-83a0-2ac9cda50e16	joni dawit	jonidawit@gmail.com	09767865456	$2b$10$gJNyIjP86qr2pL2Fl/n.wuMi/uIu/3svn0nzKEpN6k1/9XPGbBsam	rider	default.jpg	2025-10-29 14:37:30.794741	2025-10-30 04:30:23.209631+00	@joni
\.


--
-- Name: hdb_action_log hdb_action_log_pkey; Type: CONSTRAINT; Schema: hdb_catalog; Owner: postgres
--

ALTER TABLE ONLY hdb_catalog.hdb_action_log
    ADD CONSTRAINT hdb_action_log_pkey PRIMARY KEY (id);


--
-- Name: hdb_cron_event_invocation_logs hdb_cron_event_invocation_logs_pkey; Type: CONSTRAINT; Schema: hdb_catalog; Owner: postgres
--

ALTER TABLE ONLY hdb_catalog.hdb_cron_event_invocation_logs
    ADD CONSTRAINT hdb_cron_event_invocation_logs_pkey PRIMARY KEY (id);


--
-- Name: hdb_cron_events hdb_cron_events_pkey; Type: CONSTRAINT; Schema: hdb_catalog; Owner: postgres
--

ALTER TABLE ONLY hdb_catalog.hdb_cron_events
    ADD CONSTRAINT hdb_cron_events_pkey PRIMARY KEY (id);


--
-- Name: hdb_metadata hdb_metadata_pkey; Type: CONSTRAINT; Schema: hdb_catalog; Owner: postgres
--

ALTER TABLE ONLY hdb_catalog.hdb_metadata
    ADD CONSTRAINT hdb_metadata_pkey PRIMARY KEY (id);


--
-- Name: hdb_metadata hdb_metadata_resource_version_key; Type: CONSTRAINT; Schema: hdb_catalog; Owner: postgres
--

ALTER TABLE ONLY hdb_catalog.hdb_metadata
    ADD CONSTRAINT hdb_metadata_resource_version_key UNIQUE (resource_version);


--
-- Name: hdb_scheduled_event_invocation_logs hdb_scheduled_event_invocation_logs_pkey; Type: CONSTRAINT; Schema: hdb_catalog; Owner: postgres
--

ALTER TABLE ONLY hdb_catalog.hdb_scheduled_event_invocation_logs
    ADD CONSTRAINT hdb_scheduled_event_invocation_logs_pkey PRIMARY KEY (id);


--
-- Name: hdb_scheduled_events hdb_scheduled_events_pkey; Type: CONSTRAINT; Schema: hdb_catalog; Owner: postgres
--

ALTER TABLE ONLY hdb_catalog.hdb_scheduled_events
    ADD CONSTRAINT hdb_scheduled_events_pkey PRIMARY KEY (id);


--
-- Name: hdb_schema_notifications hdb_schema_notifications_pkey; Type: CONSTRAINT; Schema: hdb_catalog; Owner: postgres
--

ALTER TABLE ONLY hdb_catalog.hdb_schema_notifications
    ADD CONSTRAINT hdb_schema_notifications_pkey PRIMARY KEY (id);


--
-- Name: hdb_version hdb_version_pkey; Type: CONSTRAINT; Schema: hdb_catalog; Owner: postgres
--

ALTER TABLE ONLY hdb_catalog.hdb_version
    ADD CONSTRAINT hdb_version_pkey PRIMARY KEY (hasura_uuid);


--
-- Name: address address_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.address
    ADD CONSTRAINT address_pkey PRIMARY KEY (id);


--
-- Name: cart cart_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cart
    ADD CONSTRAINT cart_pkey PRIMARY KEY (id);


--
-- Name: cart cart_user_id_menu_item_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cart
    ADD CONSTRAINT cart_user_id_menu_item_id_key UNIQUE (user_id, menu_item_id);


--
-- Name: deliveries deliveries_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.deliveries
    ADD CONSTRAINT deliveries_pkey PRIMARY KEY (id);


--
-- Name: kitchen_orders kitchen_orders_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.kitchen_orders
    ADD CONSTRAINT kitchen_orders_pkey PRIMARY KEY (id);


--
-- Name: menu_categories menu_categories_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.menu_categories
    ADD CONSTRAINT menu_categories_pkey PRIMARY KEY (id);


--
-- Name: menu_items menu_items_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.menu_items
    ADD CONSTRAINT menu_items_pkey PRIMARY KEY (id);


--
-- Name: order_items order_items_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.order_items
    ADD CONSTRAINT order_items_pkey PRIMARY KEY (id);


--
-- Name: orders orders_phone_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT orders_phone_key UNIQUE (phone);


--
-- Name: orders orders_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT orders_pkey PRIMARY KEY (id);


--
-- Name: payments payments_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.payments
    ADD CONSTRAINT payments_pkey PRIMARY KEY (id);


--
-- Name: reviews reviews_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.reviews
    ADD CONSTRAINT reviews_pkey PRIMARY KEY (id);


--
-- Name: special_offers special_offers_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.special_offers
    ADD CONSTRAINT special_offers_pkey PRIMARY KEY (id);


--
-- Name: users users_email_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_email_key UNIQUE (email);


--
-- Name: users users_phone_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_phone_key UNIQUE (phone);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: hdb_cron_event_invocation_event_id; Type: INDEX; Schema: hdb_catalog; Owner: postgres
--

CREATE INDEX hdb_cron_event_invocation_event_id ON hdb_catalog.hdb_cron_event_invocation_logs USING btree (event_id);


--
-- Name: hdb_cron_event_status; Type: INDEX; Schema: hdb_catalog; Owner: postgres
--

CREATE INDEX hdb_cron_event_status ON hdb_catalog.hdb_cron_events USING btree (status);


--
-- Name: hdb_cron_events_unique_scheduled; Type: INDEX; Schema: hdb_catalog; Owner: postgres
--

CREATE UNIQUE INDEX hdb_cron_events_unique_scheduled ON hdb_catalog.hdb_cron_events USING btree (trigger_name, scheduled_time) WHERE (status = 'scheduled'::text);


--
-- Name: hdb_scheduled_event_status; Type: INDEX; Schema: hdb_catalog; Owner: postgres
--

CREATE INDEX hdb_scheduled_event_status ON hdb_catalog.hdb_scheduled_events USING btree (status);


--
-- Name: hdb_version_one_row; Type: INDEX; Schema: hdb_catalog; Owner: postgres
--

CREATE UNIQUE INDEX hdb_version_one_row ON hdb_catalog.hdb_version USING btree (((version IS NOT NULL)));


--
-- Name: deliveries set_delivery_timestamps_trigger; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER set_delivery_timestamps_trigger BEFORE INSERT OR UPDATE ON public.deliveries FOR EACH ROW EXECUTE FUNCTION public.set_delivery_timestamps();


--
-- Name: payments set_paid_at_trigger; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER set_paid_at_trigger BEFORE INSERT OR UPDATE ON public.payments FOR EACH ROW EXECUTE FUNCTION public.set_paid_at_on_payment_status();


--
-- Name: kitchen_orders set_started_at_trigger; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER set_started_at_trigger BEFORE INSERT OR UPDATE ON public.kitchen_orders FOR EACH ROW EXECUTE FUNCTION public.set_started_at_on_preparing();


--
-- Name: menu_items set_timestamp_menu_items; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER set_timestamp_menu_items BEFORE UPDATE ON public.menu_items FOR EACH ROW EXECUTE FUNCTION public.auto_update_timestamp();


--
-- Name: orders set_timestamp_orders; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER set_timestamp_orders BEFORE UPDATE ON public.orders FOR EACH ROW EXECUTE FUNCTION public.auto_update_timestamp();


--
-- Name: users set_timestamp_users; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER set_timestamp_users BEFORE UPDATE ON public.users FOR EACH ROW EXECUTE FUNCTION public.auto_update_timestamp();


--
-- Name: payments set_transaction_id; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER set_transaction_id BEFORE INSERT ON public.payments FOR EACH ROW EXECUTE FUNCTION public.generate_transaction_id();


--
-- Name: payments update_paid_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER update_paid_at BEFORE UPDATE ON public.payments FOR EACH ROW EXECUTE FUNCTION public.set_paid_at_on_status_change();


--
-- Name: hdb_cron_event_invocation_logs hdb_cron_event_invocation_logs_event_id_fkey; Type: FK CONSTRAINT; Schema: hdb_catalog; Owner: postgres
--

ALTER TABLE ONLY hdb_catalog.hdb_cron_event_invocation_logs
    ADD CONSTRAINT hdb_cron_event_invocation_logs_event_id_fkey FOREIGN KEY (event_id) REFERENCES hdb_catalog.hdb_cron_events(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: hdb_scheduled_event_invocation_logs hdb_scheduled_event_invocation_logs_event_id_fkey; Type: FK CONSTRAINT; Schema: hdb_catalog; Owner: postgres
--

ALTER TABLE ONLY hdb_catalog.hdb_scheduled_event_invocation_logs
    ADD CONSTRAINT hdb_scheduled_event_invocation_logs_event_id_fkey FOREIGN KEY (event_id) REFERENCES hdb_catalog.hdb_scheduled_events(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: address address_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.address
    ADD CONSTRAINT address_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: cart cart_menu_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cart
    ADD CONSTRAINT cart_menu_item_id_fkey FOREIGN KEY (menu_item_id) REFERENCES public.menu_items(id) ON DELETE CASCADE;


--
-- Name: cart cart_special_offer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cart
    ADD CONSTRAINT cart_special_offer_id_fkey FOREIGN KEY (special_offer_id) REFERENCES public.special_offers(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: cart cart_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cart
    ADD CONSTRAINT cart_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: deliveries deliveries_order_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.deliveries
    ADD CONSTRAINT deliveries_order_id_fkey FOREIGN KEY (order_id) REFERENCES public.orders(id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- Name: deliveries deliveries_rider_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.deliveries
    ADD CONSTRAINT deliveries_rider_id_fkey FOREIGN KEY (rider_id) REFERENCES public.users(id) ON UPDATE RESTRICT ON DELETE SET NULL;


--
-- Name: kitchen_orders kitchen_orders_chef_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.kitchen_orders
    ADD CONSTRAINT kitchen_orders_chef_id_fkey FOREIGN KEY (chef_id) REFERENCES public.users(id) ON UPDATE RESTRICT ON DELETE SET NULL;


--
-- Name: kitchen_orders kitchen_orders_order_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.kitchen_orders
    ADD CONSTRAINT kitchen_orders_order_id_fkey FOREIGN KEY (order_id) REFERENCES public.orders(id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- Name: menu_items menu_items_category_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.menu_items
    ADD CONSTRAINT menu_items_category_id_fkey FOREIGN KEY (category_id) REFERENCES public.menu_categories(id) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: order_items order_items_menu_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.order_items
    ADD CONSTRAINT order_items_menu_item_id_fkey FOREIGN KEY (menu_item_id) REFERENCES public.menu_items(id) ON UPDATE RESTRICT ON DELETE SET NULL;


--
-- Name: order_items order_items_order_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.order_items
    ADD CONSTRAINT order_items_order_id_fkey FOREIGN KEY (order_id) REFERENCES public.orders(id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- Name: orders orders_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT orders_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON UPDATE RESTRICT ON DELETE SET NULL;


--
-- Name: payments payments_order_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.payments
    ADD CONSTRAINT payments_order_id_fkey FOREIGN KEY (order_id) REFERENCES public.orders(id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- Name: reviews reviews_order_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.reviews
    ADD CONSTRAINT reviews_order_id_fkey FOREIGN KEY (order_id) REFERENCES public.orders(id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- Name: reviews reviews_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.reviews
    ADD CONSTRAINT reviews_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON UPDATE RESTRICT ON DELETE SET NULL;


--
-- Name: special_offers special_offers_menu_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.special_offers
    ADD CONSTRAINT special_offers_menu_item_id_fkey FOREIGN KEY (menu_item_id) REFERENCES public.menu_items(id) ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

\unrestrict XuEhiXEXREQGWvRhWBHJQAbSW4QwKKLwNmMQC5JZgz0grk5ABXzaQ4Iu1s8DMHS

