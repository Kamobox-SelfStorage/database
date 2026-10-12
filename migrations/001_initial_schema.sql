--
-- PostgreSQL database dump
--

\restrict ZEf3nadtdwcklLfOOu6aRbQVak5mBUfMUKT5WyIQuCJAuaGuYk7uX9Ebnk8ko1a

-- Dumped from database version 18.6
-- Dumped by pg_dump version 18.6

-- Started on 2026-10-13 00:17:39

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- TOC entry 231 (class 1255 OID 16507)
-- Name: log_rental_status_change(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.log_rental_status_change() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO rental_status_history (
            rental_id,
            old_status,
            new_status,
            reason,
            changed_by
        )
        VALUES (
            NEW.id,
            NULL,
            NEW.status,
            'RENTAL_CREATED',
            'system'
        );

    ELSIF OLD.status IS DISTINCT FROM NEW.status THEN
        INSERT INTO rental_status_history (
            rental_id,
            old_status,
            new_status,
            reason,
            changed_by
        )
        VALUES (
            NEW.id,
            OLD.status,
            NEW.status,
            'STATUS_CHANGED',
            'system'
        );
    END IF;

    RETURN NEW;
END;
$$;


ALTER FUNCTION public.log_rental_status_change() OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- TOC entry 222 (class 1259 OID 16403)
-- Name: containers; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.containers (
    id integer NOT NULL,
    container_number character varying(20) NOT NULL
);


ALTER TABLE public.containers OWNER TO postgres;

--
-- TOC entry 221 (class 1259 OID 16402)
-- Name: containers_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.containers ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.containers_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 224 (class 1259 OID 16421)
-- Name: customers; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.customers (
    id integer NOT NULL,
    email character varying(254) NOT NULL,
    phone character varying(30),
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    first_name character varying(100) NOT NULL,
    last_name character varying(100) NOT NULL
);


ALTER TABLE public.customers OWNER TO postgres;

--
-- TOC entry 223 (class 1259 OID 16420)
-- Name: customers_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.customers ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.customers_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 228 (class 1259 OID 16463)
-- Name: payments; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.payments (
    id integer NOT NULL,
    rental_id integer NOT NULL,
    amount numeric(10,2) NOT NULL,
    currency character(3) DEFAULT 'CZK'::bpchar NOT NULL,
    status character varying(20) DEFAULT 'PENDING'::character varying NOT NULL,
    provider_payment_id character varying(255),
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    paid_at timestamp with time zone,
    billing_period_start date NOT NULL,
    billing_period_end date NOT NULL,
    CONSTRAINT payments_amount_positive CHECK ((amount > (0)::numeric)),
    CONSTRAINT payments_billing_period_valid CHECK (((billing_period_start IS NULL) OR (billing_period_end IS NULL) OR (billing_period_end > billing_period_start))),
    CONSTRAINT payments_status_valid CHECK (((status)::text = ANY ((ARRAY['PENDING'::character varying, 'SUCCEEDED'::character varying, 'FAILED'::character varying, 'REFUNDED'::character varying])::text[])))
);


ALTER TABLE public.payments OWNER TO postgres;

--
-- TOC entry 227 (class 1259 OID 16462)
-- Name: payments_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.payments ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.payments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 230 (class 1259 OID 16489)
-- Name: rental_status_history; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.rental_status_history (
    id integer NOT NULL,
    rental_id integer NOT NULL,
    old_status character varying(30),
    new_status character varying(30) NOT NULL,
    reason text,
    changed_at timestamp with time zone DEFAULT now() NOT NULL,
    changed_by character varying(100)
);


ALTER TABLE public.rental_status_history OWNER TO postgres;

--
-- TOC entry 229 (class 1259 OID 16488)
-- Name: rental_status_history_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.rental_status_history ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.rental_status_history_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 226 (class 1259 OID 16436)
-- Name: rentals; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.rentals (
    id integer NOT NULL,
    customer_id integer NOT NULL,
    unit_id integer NOT NULL,
    status character varying(20) DEFAULT 'RESERVED'::character varying NOT NULL,
    start_date date,
    next_billing_date date,
    monthly_price numeric(10,2) NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    reservation_expires_at timestamp with time zone,
    CONSTRAINT rentals_price_positive CHECK ((monthly_price > (0)::numeric)),
    CONSTRAINT rentals_required_dates CHECK (((((status)::text <> 'RESERVED'::text) OR (reservation_expires_at IS NOT NULL)) AND (((status)::text <> ALL ((ARRAY['ACTIVE'::character varying, 'PAST_DUE'::character varying, 'TERMINATION_PENDING'::character varying])::text[])) OR ((start_date IS NOT NULL) AND (next_billing_date IS NOT NULL))))),
    CONSTRAINT rentals_status_valid CHECK (((status)::text = ANY ((ARRAY['RESERVED'::character varying, 'ACTIVE'::character varying, 'PAST_DUE'::character varying, 'TERMINATION_PENDING'::character varying, 'TERMINATED'::character varying, 'CANCELLED'::character varying])::text[])))
);


ALTER TABLE public.rentals OWNER TO postgres;

--
-- TOC entry 225 (class 1259 OID 16435)
-- Name: rentals_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.rentals ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.rentals_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 220 (class 1259 OID 16390)
-- Name: units; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.units (
    id integer NOT NULL,
    unit_number character varying(20) NOT NULL,
    area_m2 numeric(5,2) NOT NULL,
    status character varying(20) DEFAULT 'AVAILABLE'::character varying NOT NULL,
    container_id integer NOT NULL,
    CONSTRAINT units_area_positive CHECK ((area_m2 > (0)::numeric)),
    CONSTRAINT units_status_valid CHECK (((status)::text = ANY ((ARRAY['AVAILABLE'::character varying, 'MAINTENANCE'::character varying, 'UNAVAILABLE'::character varying])::text[])))
);


ALTER TABLE public.units OWNER TO postgres;

--
-- TOC entry 219 (class 1259 OID 16389)
-- Name: units_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.units ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.units_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 5076 (class 0 OID 16403)
-- Dependencies: 222
-- Data for Name: containers; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.containers (id, container_number) FROM stdin;
1	A
2	B
3	C
4	D
5	E
6	F
7	G
8	H
\.


--
-- TOC entry 5078 (class 0 OID 16421)
-- Dependencies: 224
-- Data for Name: customers; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.customers (id, email, phone, created_at, first_name, last_name) FROM stdin;
\.


--
-- TOC entry 5082 (class 0 OID 16463)
-- Dependencies: 228
-- Data for Name: payments; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.payments (id, rental_id, amount, currency, status, provider_payment_id, created_at, paid_at, billing_period_start, billing_period_end) FROM stdin;
\.


--
-- TOC entry 5084 (class 0 OID 16489)
-- Dependencies: 230
-- Data for Name: rental_status_history; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.rental_status_history (id, rental_id, old_status, new_status, reason, changed_at, changed_by) FROM stdin;
\.


--
-- TOC entry 5080 (class 0 OID 16436)
-- Dependencies: 226
-- Data for Name: rentals; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.rentals (id, customer_id, unit_id, status, start_date, next_billing_date, monthly_price, created_at, reservation_expires_at) FROM stdin;
\.


--
-- TOC entry 5074 (class 0 OID 16390)
-- Dependencies: 220
-- Data for Name: units; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.units (id, unit_number, area_m2, status, container_id) FROM stdin;
1	A-01	2.50	AVAILABLE	1
2	A-02	2.50	AVAILABLE	1
3	A-03	2.50	AVAILABLE	1
4	A-04	2.50	AVAILABLE	1
5	A-05	2.50	AVAILABLE	1
6	B-01	2.50	AVAILABLE	2
7	B-02	2.50	AVAILABLE	2
8	B-03	2.50	AVAILABLE	2
9	B-04	2.50	AVAILABLE	2
10	B-05	2.50	AVAILABLE	2
11	C-01	2.50	AVAILABLE	3
12	D-01	2.50	AVAILABLE	4
13	E-01	2.50	AVAILABLE	5
14	F-01	2.50	AVAILABLE	6
15	G-01	2.50	AVAILABLE	7
16	H-01	2.50	AVAILABLE	8
17	C-02	2.50	AVAILABLE	3
18	D-02	2.50	AVAILABLE	4
19	E-02	2.50	AVAILABLE	5
20	F-02	2.50	AVAILABLE	6
21	G-02	2.50	AVAILABLE	7
22	H-02	2.50	AVAILABLE	8
23	C-03	2.50	AVAILABLE	3
24	D-03	2.50	AVAILABLE	4
25	E-03	2.50	AVAILABLE	5
26	F-03	2.50	AVAILABLE	6
27	G-03	2.50	AVAILABLE	7
28	H-03	2.50	AVAILABLE	8
29	C-04	2.50	AVAILABLE	3
30	D-04	2.50	AVAILABLE	4
31	E-04	2.50	AVAILABLE	5
32	F-04	2.50	AVAILABLE	6
33	G-04	2.50	AVAILABLE	7
34	H-04	2.50	AVAILABLE	8
35	C-05	2.50	AVAILABLE	3
36	D-05	2.50	AVAILABLE	4
37	E-05	2.50	AVAILABLE	5
38	F-05	2.50	AVAILABLE	6
39	G-05	2.50	AVAILABLE	7
40	H-05	2.50	AVAILABLE	8
\.


--
-- TOC entry 5090 (class 0 OID 0)
-- Dependencies: 221
-- Name: containers_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.containers_id_seq', 8, true);


--
-- TOC entry 5091 (class 0 OID 0)
-- Dependencies: 223
-- Name: customers_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.customers_id_seq', 1, true);


--
-- TOC entry 5092 (class 0 OID 0)
-- Dependencies: 227
-- Name: payments_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.payments_id_seq', 1, false);


--
-- TOC entry 5093 (class 0 OID 0)
-- Dependencies: 229
-- Name: rental_status_history_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.rental_status_history_id_seq', 1, false);


--
-- TOC entry 5094 (class 0 OID 0)
-- Dependencies: 225
-- Name: rentals_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.rentals_id_seq', 2, true);


--
-- TOC entry 5095 (class 0 OID 0)
-- Dependencies: 219
-- Name: units_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.units_id_seq', 40, true);


--
-- TOC entry 4903 (class 2606 OID 16411)
-- Name: containers containers_container_number_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.containers
    ADD CONSTRAINT containers_container_number_key UNIQUE (container_number);


--
-- TOC entry 4905 (class 2606 OID 16409)
-- Name: containers containers_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.containers
    ADD CONSTRAINT containers_pkey PRIMARY KEY (id);


--
-- TOC entry 4907 (class 2606 OID 16432)
-- Name: customers customers_email_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.customers
    ADD CONSTRAINT customers_email_key UNIQUE (email);


--
-- TOC entry 4909 (class 2606 OID 16430)
-- Name: customers customers_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.customers
    ADD CONSTRAINT customers_pkey PRIMARY KEY (id);


--
-- TOC entry 4915 (class 2606 OID 16478)
-- Name: payments payments_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.payments
    ADD CONSTRAINT payments_pkey PRIMARY KEY (id);


--
-- TOC entry 4917 (class 2606 OID 16480)
-- Name: payments payments_provider_payment_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.payments
    ADD CONSTRAINT payments_provider_payment_id_key UNIQUE (provider_payment_id);


--
-- TOC entry 4919 (class 2606 OID 16500)
-- Name: rental_status_history rental_status_history_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.rental_status_history
    ADD CONSTRAINT rental_status_history_pkey PRIMARY KEY (id);


--
-- TOC entry 4912 (class 2606 OID 16450)
-- Name: rentals rentals_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.rentals
    ADD CONSTRAINT rentals_pkey PRIMARY KEY (id);


--
-- TOC entry 4899 (class 2606 OID 16399)
-- Name: units units_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.units
    ADD CONSTRAINT units_pkey PRIMARY KEY (id);


--
-- TOC entry 4901 (class 2606 OID 16401)
-- Name: units units_unit_number_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.units
    ADD CONSTRAINT units_unit_number_key UNIQUE (unit_number);


--
-- TOC entry 4913 (class 1259 OID 16487)
-- Name: payments_one_success_per_period; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX payments_one_success_per_period ON public.payments USING btree (rental_id, billing_period_start, billing_period_end) WHERE ((status)::text = 'SUCCEEDED'::text);


--
-- TOC entry 4910 (class 1259 OID 16461)
-- Name: rentals_one_open_per_unit; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX rentals_one_open_per_unit ON public.rentals USING btree (unit_id) WHERE ((status)::text = ANY ((ARRAY['RESERVED'::character varying, 'ACTIVE'::character varying, 'PAST_DUE'::character varying, 'TERMINATION_PENDING'::character varying])::text[]));


--
-- TOC entry 4925 (class 2620 OID 16508)
-- Name: rentals rental_status_audit; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER rental_status_audit AFTER INSERT OR UPDATE OF status ON public.rentals FOR EACH ROW EXECUTE FUNCTION public.log_rental_status_change();


--
-- TOC entry 4923 (class 2606 OID 16481)
-- Name: payments payments_rental_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.payments
    ADD CONSTRAINT payments_rental_id_fkey FOREIGN KEY (rental_id) REFERENCES public.rentals(id);


--
-- TOC entry 4924 (class 2606 OID 16501)
-- Name: rental_status_history rental_status_history_rental_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.rental_status_history
    ADD CONSTRAINT rental_status_history_rental_id_fkey FOREIGN KEY (rental_id) REFERENCES public.rentals(id);


--
-- TOC entry 4921 (class 2606 OID 16451)
-- Name: rentals rentals_customer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.rentals
    ADD CONSTRAINT rentals_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES public.customers(id);


--
-- TOC entry 4922 (class 2606 OID 16456)
-- Name: rentals rentals_unit_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.rentals
    ADD CONSTRAINT rentals_unit_id_fkey FOREIGN KEY (unit_id) REFERENCES public.units(id);


--
-- TOC entry 4920 (class 2606 OID 16412)
-- Name: units units_container_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.units
    ADD CONSTRAINT units_container_id_fkey FOREIGN KEY (container_id) REFERENCES public.containers(id);


-- Completed on 2026-10-13 00:17:40

--
-- PostgreSQL database dump complete
--

\unrestrict ZEf3nadtdwcklLfOOu6aRbQVak5mBUfMUKT5WyIQuCJAuaGuYk7uX9Ebnk8ko1a

