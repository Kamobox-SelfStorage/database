# KamoBox Database

Database engine: PostgreSQL 18+

## Structure

- `migrations/` — versioned SQL schema changes. Apply each migration once, in order.
- `seeds/` — repeatable development/facility reference data; never put customer or payment data here.

## Local database

- Database name: `self_storage`
- Main migration: `migrations/001_initial_schema.sql`
- Facility seed data: `seeds/001_facility.sql`

## Important behavior

- A unit can have at most one open reservation/rental at a time.
- Only one successful payment is allowed per rental and billing period; failed attempts can be retried.
- Reservation expiry is stored in `reservation_expires_at`; application logic must expire reservations and must not mark a unit available until its physical state has been checked.
- Rental status changes are written to `rental_status_history`.
- The audit trigger currently records `changed_by = 'system'`. The backend should later provide the real actor and a meaningful reason.

## Rules

- Never commit passwords, API keys, payment secrets, or real customer data.
- Schema changes must be saved as new version-controlled migrations.
- Test migrations and seeds against a clean database before deployment.
- Do not edit an already-applied migration in a deployed environment; add a new migration instead.
