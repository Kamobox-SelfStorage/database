--
-- PostgreSQL database dump
--

\restrict AmdDuzasXPcIBsCvni1by2OS1RYx1XhujzcSHUhJlbBkkgm4eIs2p2ZO6BB2xQ2

-- Dumped from database version 18.6
-- Dumped by pg_dump version 18.6

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
-- Name: log_rental_status_change(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.log_rental_status_change() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    status_reason text;
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO public.rental_status_history
            (rental_id, old_status, new_status, reason, changed_by)
        VALUES
            (NEW.id, NULL, NEW.status, 'RENTAL_CREATED', 'system');

    ELSIF OLD.status IS DISTINCT FROM NEW.status THEN
        status_reason := COALESCE(
            NULLIF(
                current_setting('app.rental_status_reason', true),
                ''
            ),
            'STATUS_CHANGED'
        );

        INSERT INTO public.rental_status_history
            (rental_id, old_status, new_status, reason, changed_by)
        VALUES
            (NEW.id, OLD.status, NEW.status, status_reason, 'system');
    END IF;

    RETURN NEW;
END;
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: containers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.containers (
    id integer NOT NULL,
    container_number character varying(20) NOT NULL
);


--
-- Name: containers_id_seq; Type: SEQUENCE; Schema: public; Owner: -
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
-- Name: customers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.customers (
    id integer NOT NULL,
    email character varying(254) NOT NULL,
    phone character varying(30),
    first_name character varying(100) NOT NULL,
    last_name character varying(100) NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT customers_email_not_blank CHECK ((length(TRIM(BOTH FROM email)) > 0))
);


--
-- Name: customers_id_seq; Type: SEQUENCE; Schema: public; Owner: -
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
-- Name: payments; Type: TABLE; Schema: public; Owner: -
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
    CONSTRAINT payments_amount_check CHECK ((amount > (0)::numeric)),
    CONSTRAINT payments_billing_period_valid CHECK ((billing_period_end > billing_period_start)),
    CONSTRAINT payments_paid_at_valid CHECK ((((status)::text <> 'SUCCEEDED'::text) OR (paid_at IS NOT NULL))),
    CONSTRAINT payments_status_check CHECK (((status)::text = ANY ((ARRAY['PENDING'::character varying, 'SUCCEEDED'::character varying, 'FAILED'::character varying, 'REFUNDED'::character varying])::text[])))
);


--
-- Name: payments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
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
-- Name: rental_status_history; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.rental_status_history (
    id integer NOT NULL,
    rental_id integer NOT NULL,
    old_status character varying(30),
    new_status character varying(30) NOT NULL,
    reason text,
    changed_at timestamp with time zone DEFAULT now() NOT NULL,
    changed_by character varying(100) DEFAULT 'system'::character varying NOT NULL
);


--
-- Name: rental_status_history_id_seq; Type: SEQUENCE; Schema: public; Owner: -
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
-- Name: rentals; Type: TABLE; Schema: public; Owner: -
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
    CONSTRAINT rentals_monthly_price_check CHECK ((monthly_price > (0)::numeric)),
    CONSTRAINT rentals_required_dates CHECK (((((status)::text <> 'RESERVED'::text) OR (reservation_expires_at IS NOT NULL)) AND (((status)::text <> ALL ((ARRAY['ACTIVE'::character varying, 'PAST_DUE'::character varying, 'TERMINATION_PENDING'::character varying])::text[])) OR ((start_date IS NOT NULL) AND (next_billing_date IS NOT NULL))) AND ((start_date IS NULL) OR (next_billing_date IS NULL) OR (next_billing_date >= start_date)))),
    CONSTRAINT rentals_status_check CHECK (((status)::text = ANY ((ARRAY['RESERVED'::character varying, 'ACTIVE'::character varying, 'PAST_DUE'::character varying, 'TERMINATION_PENDING'::character varying, 'TERMINATED'::character varying, 'CANCELLED'::character varying])::text[])))
);


--
-- Name: rentals_id_seq; Type: SEQUENCE; Schema: public; Owner: -
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
-- Name: units; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.units (
    id integer NOT NULL,
    unit_number character varying(20) NOT NULL,
    area_m2 numeric(5,2) NOT NULL,
    status character varying(20) DEFAULT 'AVAILABLE'::character varying NOT NULL,
    container_id integer NOT NULL,
    CONSTRAINT units_area_m2_check CHECK ((area_m2 > (0)::numeric)),
    CONSTRAINT units_status_check CHECK (((status)::text = ANY ((ARRAY['AVAILABLE'::character varying, 'MAINTENANCE'::character varying, 'UNAVAILABLE'::character varying])::text[])))
);


--
-- Name: units_id_seq; Type: SEQUENCE; Schema: public; Owner: -
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
-- Name: containers containers_container_number_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.containers
    ADD CONSTRAINT containers_container_number_key UNIQUE (container_number);


--
-- Name: containers containers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.containers
    ADD CONSTRAINT containers_pkey PRIMARY KEY (id);


--
-- Name: customers customers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.customers
    ADD CONSTRAINT customers_pkey PRIMARY KEY (id);


--
-- Name: payments payments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payments
    ADD CONSTRAINT payments_pkey PRIMARY KEY (id);


--
-- Name: payments payments_provider_payment_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payments
    ADD CONSTRAINT payments_provider_payment_id_key UNIQUE (provider_payment_id);


--
-- Name: rental_status_history rental_status_history_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rental_status_history
    ADD CONSTRAINT rental_status_history_pkey PRIMARY KEY (id);


--
-- Name: rentals rentals_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rentals
    ADD CONSTRAINT rentals_pkey PRIMARY KEY (id);


--
-- Name: units units_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.units
    ADD CONSTRAINT units_pkey PRIMARY KEY (id);


--
-- Name: units units_unit_number_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.units
    ADD CONSTRAINT units_unit_number_key UNIQUE (unit_number);


--
-- Name: customers_email_lower_uidx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX customers_email_lower_uidx ON public.customers USING btree (lower((email)::text));


--
-- Name: payments_one_success_per_period; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX payments_one_success_per_period ON public.payments USING btree (rental_id, billing_period_start, billing_period_end) WHERE ((status)::text = 'SUCCEEDED'::text);


--
-- Name: payments_pending_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX payments_pending_idx ON public.payments USING btree (created_at) WHERE ((status)::text = 'PENDING'::text);


--
-- Name: payments_rental_id_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX payments_rental_id_created_at_idx ON public.payments USING btree (rental_id, created_at DESC);


--
-- Name: rental_status_history_rental_changed_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX rental_status_history_rental_changed_idx ON public.rental_status_history USING btree (rental_id, changed_at DESC);


--
-- Name: rentals_customer_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX rentals_customer_id_idx ON public.rentals USING btree (customer_id);


--
-- Name: rentals_expired_reservations_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX rentals_expired_reservations_idx ON public.rentals USING btree (reservation_expires_at) WHERE ((status)::text = 'RESERVED'::text);


--
-- Name: rentals_one_open_per_unit; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX rentals_one_open_per_unit ON public.rentals USING btree (unit_id) WHERE ((status)::text = ANY ((ARRAY['RESERVED'::character varying, 'ACTIVE'::character varying, 'PAST_DUE'::character varying, 'TERMINATION_PENDING'::character varying])::text[]));


--
-- Name: rentals_status_next_billing_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX rentals_status_next_billing_idx ON public.rentals USING btree (status, next_billing_date);


--
-- Name: rentals rental_status_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER rental_status_audit AFTER INSERT OR UPDATE ON public.rentals FOR EACH ROW EXECUTE FUNCTION public.log_rental_status_change();


--
-- Name: payments payments_rental_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payments
    ADD CONSTRAINT payments_rental_id_fkey FOREIGN KEY (rental_id) REFERENCES public.rentals(id) ON DELETE RESTRICT;


--
-- Name: rental_status_history rental_status_history_rental_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rental_status_history
    ADD CONSTRAINT rental_status_history_rental_id_fkey FOREIGN KEY (rental_id) REFERENCES public.rentals(id) ON DELETE RESTRICT;


--
-- Name: rentals rentals_customer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rentals
    ADD CONSTRAINT rentals_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES public.customers(id) ON DELETE RESTRICT;


--
-- Name: rentals rentals_unit_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rentals
    ADD CONSTRAINT rentals_unit_id_fkey FOREIGN KEY (unit_id) REFERENCES public.units(id) ON DELETE RESTRICT;


--
-- Name: units units_container_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.units
    ADD CONSTRAINT units_container_id_fkey FOREIGN KEY (container_id) REFERENCES public.containers(id) ON DELETE RESTRICT;


--
-- PostgreSQL database dump complete
--

\unrestrict AmdDuzasXPcIBsCvni1by2OS1RYx1XhujzcSHUhJlbBkkgm4eIs2p2ZO6BB2xQ2
