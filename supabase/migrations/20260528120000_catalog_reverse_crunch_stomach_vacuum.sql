-- reverseCrunch, stomachVacuum (align with app Drift schema v44).

CREATE OR REPLACE FUNCTION public.athlos_exercise_uuid(canonical_name TEXT)
RETURNS UUID
LANGUAGE plpgsql
IMMUTABLE
STRICT
SET search_path = public, extensions
AS $$
DECLARE
  hash bytea;
  hex text;
BEGIN
  hash := extensions.digest(
    decode('6ba7b8109dad11d180b400c04fd430c8', 'hex')
      || convert_to(canonical_name, 'UTF8'),
    'sha1'
  );
  hash := set_byte(hash, 6, (get_byte(hash, 6) & 15) | 80);
  hash := set_byte(hash, 8, (get_byte(hash, 8) & 63) | 128);
  hex := encode(substring(hash FROM 1 FOR 16), 'hex');
  RETURN (
    substr(hex, 1, 8) || '-' ||
    substr(hex, 9, 4) || '-' ||
    substr(hex, 13, 4) || '-' ||
    substr(hex, 17, 4) || '-' ||
    substr(hex, 21, 12)
  )::uuid;
END;
$$;

INSERT INTO public.exercises (
  id, is_verified, name, muscle_group, type, movement_pattern,
  default_load_mode, is_isometric
)
VALUES
  (
    public.athlos_exercise_uuid('reverseCrunch'),
    TRUE,
    'reverseCrunch',
    'abs',
    'strength',
    'isolation',
    'bodyweight',
    FALSE
  ),
  (
    public.athlos_exercise_uuid('stomachVacuum'),
    TRUE,
    'stomachVacuum',
    'abs',
    'strength',
    NULL,
    'bodyweight',
    TRUE
  )
ON CONFLICT (id) DO NOTHING;

DO $$
DECLARE
  eid UUID;
BEGIN
  eid := public.athlos_exercise_uuid('reverseCrunch');
  IF EXISTS (SELECT 1 FROM public.exercises WHERE id = eid) THEN
    INSERT INTO public.exercise_target_muscles (exercise_id, target_muscle, muscle_region, role)
    SELECT eid, x.tm, x.mr, x.r
    FROM (VALUES
      ('rectusAbdominis', 'lower', 'primary'),
      ('hipFlexors', NULL::TEXT, 'secondary')
    ) AS x(tm, mr, r)
    ON CONFLICT (exercise_id, target_muscle, role) DO NOTHING;
  END IF;

  eid := public.athlos_exercise_uuid('stomachVacuum');
  IF EXISTS (SELECT 1 FROM public.exercises WHERE id = eid) THEN
    INSERT INTO public.exercise_target_muscles (exercise_id, target_muscle, muscle_region, role)
    SELECT eid, x.tm, NULL::TEXT, x.r
    FROM (VALUES
      ('transverseAbdominis', 'primary'),
      ('obliques', 'secondary')
    ) AS x(tm, r)
    ON CONFLICT (exercise_id, target_muscle, role) DO NOTHING;
  END IF;
END $$;

DROP FUNCTION IF EXISTS public.athlos_exercise_uuid(TEXT);
