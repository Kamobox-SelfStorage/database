# KamoBox Database

PostgreSQL 18+. This public repository stores the database schema only, never live customer, rental, or payment data.

## Environments

- **DEV:** `self_storage_test` — use this database for backend development and testing.
- **PROD:** `self_storage` — production data; never use it for development or routine tests.

Keep credentials in local environment variables or an untracked `.env` file. Never commit secrets or database rows.

## Current schema

- `db-export/schema.sql` is the current schema snapshot exported from DEV with `pg_dump --schema-only --no-owner --no-privileges`.
- Treat this file as the current reference for the schema. Do not restore a DEV data dump into PROD.
- Static facility seed data is intentionally not included in the schema snapshot.

## Workflow

1. Make schema changes in DEV (`self_storage_test`).
2. Test the schema and backend behavior locally.
3. Export a new schema-only snapshot to `db-export/schema.sql`.
4. Review the diff and commit the updated snapshot to `main`.
5. Plan and review the corresponding data-preserving PROD change before applying it. Never overwrite or recreate PROD just to synchronize its schema.

## Important invariants

- A unit can have at most one open reservation/rental at a time.
- Only one successful payment is allowed per rental and billing period; failed attempts can be retried.
- Reservation expiry is stored in `reservation_expires_at`.
- Rental status changes are written to `rental_status_history`.
- The audit trigger currently records `changed_by = 'system'`; the backend should later provide the real actor and a meaningful reason.
