-- KamoBox initial schema
-- PostgreSQL 18+
-- Schema only: static facility data lives in ../seeds/001_facility.sql.

BEGIN;

CREATE TABLE public.containers (
    id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    container_number varchar(20) NOT NULL UNIQUE
);

CREATE TABLE public.units (
    id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    unit_number varchar(20) NOT NULL UNIQUE,
    area_m2 numeric(5,2) NOT NULL CHECK (area_m2 > 0),
    status varchar(20) NOT NULL DEFAULT 'AVAILABLE'
        CHECK (status IN ('AVAILABLE', 'MAINTENANCE', 'UNAVAILABLE')),
    container_id integer NOT NULL REFERENCES public.containers(id) ON DELETE RESTRICT
);

CREATE TABLE public.customers (
    id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    email varchar(254) NOT NULL,
    phone varchar(30),
    first_name varchar(100) NOT NULL,
    last_name varchar(100) NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT customers_email_not_blank CHECK (length(trim(email)) > 0)
);

-- Treat email addresses as case-insensitive for uniqueness.
CREATE UNIQUE INDEX customers_email_lower_uidx ON public.customers (lower(email));

CREATE TABLE public.rentals (
    id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_id integer NOT NULL REFERENCES public.customers(id) ON DELETE RESTRICT,
    unit_id integer NOT NULL REFERENCES public.units(id) ON DELETE RESTRICT,
    status varchar(20) NOT NULL DEFAULT 'RESERVED'
        CHECK (status IN (
            'RESERVED', 'ACTIVE', 'PAST_DUE',
            'TERMINATION_PENDING', 'TERMINATED', 'CANCELLED'
        )),
    start_date date,
    next_billing_date date,
    monthly_price numeric(10,2) NOT NULL CHECK (monthly_price > 0),
    created_at timestamptz NOT NULL DEFAULT now(),
    reservation_expires_at timestamptz,
    CONSTRAINT rentals_required_dates CHECK (
        (status <> 'RESERVED' OR reservation_expires_at IS NOT NULL)
        AND (
            status NOT IN ('ACTIVE', 'PAST_DUE', 'TERMINATION_PENDING')
            OR (start_date IS NOT NULL AND next_billing_date IS NOT NULL)
        )
        AND (start_date IS NULL OR next_billing_date IS NULL OR next_billing_date >= start_date)
    )
);

-- A unit can have only one reservation/current rental at a time.
CREATE UNIQUE INDEX rentals_one_open_per_unit
    ON public.rentals (unit_id)
    WHERE status IN ('RESERVED', 'ACTIVE', 'PAST_DUE', 'TERMINATION_PENDING');

CREATE INDEX rentals_customer_id_idx ON public.rentals (customer_id);
CREATE INDEX rentals_status_next_billing_idx ON public.rentals (status, next_billing_date);
CREATE INDEX rentals_expired_reservations_idx ON public.rentals (reservation_expires_at)
    WHERE status = 'RESERVED';

CREATE TABLE public.payments (
    id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    rental_id integer NOT NULL REFERENCES public.rentals(id) ON DELETE RESTRICT,
    amount numeric(10,2) NOT NULL CHECK (amount > 0),
    currency char(3) NOT NULL DEFAULT 'CZK',
    status varchar(20) NOT NULL DEFAULT 'PENDING'
        CHECK (status IN ('PENDING', 'SUCCEEDED', 'FAILED', 'REFUNDED')),
    provider_payment_id varchar(255) UNIQUE,
    created_at timestamptz NOT NULL DEFAULT now(),
    paid_at timestamptz,
    billing_period_start date NOT NULL,
    billing_period_end date NOT NULL,
    CONSTRAINT payments_billing_period_valid
        CHECK (billing_period_end > billing_period_start),
    CONSTRAINT payments_paid_at_valid
        CHECK (status <> 'SUCCEEDED' OR paid_at IS NOT NULL)
);

-- Failed/retried payments are allowed; only one successful payment per period.
CREATE UNIQUE INDEX payments_one_success_per_period
    ON public.payments (rental_id, billing_period_start, billing_period_end)
    WHERE status = 'SUCCEEDED';

CREATE INDEX payments_rental_id_created_at_idx
    ON public.payments (rental_id, created_at DESC);
CREATE INDEX payments_pending_idx ON public.payments (created_at)
    WHERE status = 'PENDING';

CREATE TABLE public.rental_status_history (
    id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    rental_id integer NOT NULL REFERENCES public.rentals(id) ON DELETE RESTRICT,
    old_status varchar(30),
    new_status varchar(30) NOT NULL,
    reason text,
    changed_at timestamptz NOT NULL DEFAULT now(),
    changed_by varchar(100) NOT NULL DEFAULT 'system'
);

CREATE INDEX rental_status_history_rental_changed_idx
    ON public.rental_status_history (rental_id, changed_at DESC);

CREATE FUNCTION public.log_rental_status_change()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO public.rental_status_history
            (rental_id, old_status, new_status, reason, changed_by)
        VALUES
            (NEW.id, NULL, NEW.status, 'RENTAL_CREATED', 'system');
    ELSIF OLD.status IS DISTINCT FROM NEW.status THEN
        INSERT INTO public.rental_status_history
            (rental_id, old_status, new_status, reason, changed_by)
        VALUES
            (NEW.id, OLD.status, NEW.status, 'STATUS_CHANGED', 'system');
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER rental_status_audit
AFTER INSERT OR UPDATE ON public.rentals
FOR EACH ROW
EXECUTE FUNCTION public.log_rental_status_change();

COMMIT;
