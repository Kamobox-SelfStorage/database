-- KamoBox facility seed data
-- Safe to re-run: existing container/unit identifiers are not duplicated.
-- Confirm the physical layout before using this data in production.

BEGIN;

INSERT INTO public.containers (container_number)
VALUES ('A'), ('B'), ('C'), ('D'), ('E'), ('F'), ('G'), ('H')
ON CONFLICT (container_number) DO NOTHING;

INSERT INTO public.units (unit_number, area_m2, status, container_id)
SELECT
    c.container_number || '-' || lpad(n.unit_no::text, 2, '0'),
    2.50,
    'AVAILABLE',
    c.id
FROM public.containers AS c
CROSS JOIN generate_series(1, 5) AS n(unit_no)
WHERE c.container_number IN ('A', 'B', 'C', 'D', 'E', 'F', 'G', 'H')
ON CONFLICT (unit_number) DO NOTHING;

COMMIT;
