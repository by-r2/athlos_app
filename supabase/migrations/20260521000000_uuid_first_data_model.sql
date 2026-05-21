-- UUID-first data model redesign.
-- Unifies exercises (catalog + custom), normalizes workout_exercises,
-- drops user_exercises, removes governance tables.

-- ═══════════════════════════════════════════════════════════════
-- 0. Helpers
-- ═══════════════════════════════════════════════════════════════

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA extensions;

-- Deterministic catalog exercise UUID v5 (matches AppDatabase.uuid5 / exercise_seeder).
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

-- ═══════════════════════════════════════════════════════════════
-- 1. New unified exercises table (UUID PK)
-- ═══════════════════════════════════════════════════════════════

CREATE TABLE public.exercises_new (
  id UUID PRIMARY KEY,
  created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  is_verified BOOLEAN NOT NULL DEFAULT FALSE,
  name TEXT NOT NULL,
  muscle_group TEXT NOT NULL,
  type TEXT NOT NULL DEFAULT 'strength',
  movement_pattern TEXT,
  description TEXT,
  default_load_mode TEXT NOT NULL DEFAULT 'weighted',
  bodyweight_load_factor DOUBLE PRECISION,
  is_isometric BOOLEAN NOT NULL DEFAULT FALSE,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at TIMESTAMPTZ
);

-- Migrate verified catalog exercises with deterministic UUID v5
INSERT INTO public.exercises_new (id, created_by, is_verified, name, muscle_group, type, movement_pattern, description, default_load_mode, updated_at)
SELECT
  athlos_exercise_uuid(e.name),
  NULL,
  TRUE,
  e.name,
  e.muscle_group,
  e.type,
  e.movement_pattern,
  e.description,
  'weighted',
  NOW()
FROM public.exercises e
WHERE e.is_verified = TRUE;

-- Migrate user-created exercises from user_exercises (custom only)
INSERT INTO public.exercises_new (id, created_by, is_verified, name, muscle_group, type, movement_pattern, description, default_load_mode, bodyweight_load_factor, is_isometric, updated_at, deleted_at)
SELECT
  ue.id,
  ue.user_id,
  FALSE,
  ue.name,
  ue.muscle_group,
  ue.type,
  ue.movement_pattern,
  ue.description,
  ue.default_load_mode,
  ue.bodyweight_load_factor,
  ue.is_isometric,
  ue.updated_at,
  ue.deleted_at
FROM public.user_exercises ue
WHERE ue.catalog_remote_id IS NULL
ON CONFLICT (id) DO NOTHING;

-- Unique indexes
CREATE UNIQUE INDEX exercises_verified_name_unique
  ON public.exercises_new (name) WHERE is_verified = TRUE;

CREATE UNIQUE INDEX exercises_user_name_unique
  ON public.exercises_new (created_by, name) WHERE is_verified = FALSE;

-- ═══════════════════════════════════════════════════════════════
-- 2. Recreate exercise_target_muscles with UUID FK
-- ═══════════════════════════════════════════════════════════════

CREATE TABLE public.exercise_target_muscles_new (
  exercise_id UUID NOT NULL REFERENCES public.exercises_new(id) ON DELETE CASCADE,
  target_muscle TEXT NOT NULL,
  muscle_region TEXT,
  role TEXT NOT NULL DEFAULT 'primary',
  PRIMARY KEY (exercise_id, target_muscle, role)
);

INSERT INTO public.exercise_target_muscles_new (exercise_id, target_muscle, muscle_region, role)
SELECT
  athlos_exercise_uuid(e.name),
  etm.target_muscle,
  etm.muscle_region,
  etm.role
FROM public.exercise_target_muscles etm
JOIN public.exercises e ON e.id = etm.exercise_id
WHERE e.is_verified = TRUE
ON CONFLICT DO NOTHING;

-- ═══════════════════════════════════════════════════════════════
-- 3. Recreate exercise_variations with UUID FK
-- ═══════════════════════════════════════════════════════════════

CREATE TABLE public.exercise_variations_new (
  exercise_id UUID NOT NULL REFERENCES public.exercises_new(id) ON DELETE CASCADE,
  variation_id UUID NOT NULL REFERENCES public.exercises_new(id) ON DELETE CASCADE,
  PRIMARY KEY (exercise_id, variation_id)
);

INSERT INTO public.exercise_variations_new (exercise_id, variation_id)
SELECT
  athlos_exercise_uuid(e1.name),
  athlos_exercise_uuid(e2.name)
FROM public.exercise_variations ev
JOIN public.exercises e1 ON e1.id = ev.exercise_id
JOIN public.exercises e2 ON e2.id = ev.variation_id
WHERE e1.is_verified = TRUE AND e2.is_verified = TRUE
ON CONFLICT DO NOTHING;

-- ═══════════════════════════════════════════════════════════════
-- 4. Rename user-owned tables (drop user_ prefix)
-- ═══════════════════════════════════════════════════════════════

ALTER TABLE public.user_workouts RENAME TO workouts;
ALTER TABLE public.user_programs RENAME TO programs;
ALTER TABLE public.user_progression_rules RENAME TO progression_rules;
ALTER TABLE public.user_cycle_steps RENAME TO cycle_steps;
ALTER TABLE public.user_workout_executions RENAME TO workout_executions;
ALTER TABLE public.user_execution_sets RENAME TO execution_sets;

-- Rename FK columns from *_remote_id to *_id (now same UUID space)
ALTER TABLE public.progression_rules RENAME COLUMN program_remote_id TO program_id;
ALTER TABLE public.progression_rules RENAME COLUMN exercise_remote_id TO exercise_id;
ALTER TABLE public.cycle_steps RENAME COLUMN program_remote_id TO program_id;
ALTER TABLE public.cycle_steps RENAME COLUMN workout_remote_id TO workout_id;
ALTER TABLE public.workout_executions RENAME COLUMN workout_remote_id TO workout_id;
ALTER TABLE public.workout_executions RENAME COLUMN program_remote_id TO program_id;
ALTER TABLE public.execution_sets RENAME COLUMN execution_remote_id TO execution_id;
ALTER TABLE public.execution_sets RENAME COLUMN exercise_remote_id TO exercise_id;

-- Rename duration/distance columns to match plan
ALTER TABLE public.execution_sets RENAME COLUMN duration TO duration_seconds;
ALTER TABLE public.execution_sets RENAME COLUMN distance TO distance_meters;

-- Drop JSONB columns that are now normalized
ALTER TABLE public.workouts DROP COLUMN IF EXISTS exercises_config;
ALTER TABLE public.execution_sets DROP COLUMN IF EXISTS segments_config;
ALTER TABLE public.workout_executions DROP COLUMN IF EXISTS exercise_config_snapshot;

-- ═══════════════════════════════════════════════════════════════
-- 5. Create workout_exercises (normalized from JSONB)
-- ═══════════════════════════════════════════════════════════════

CREATE TABLE public.workout_exercises (
  id UUID PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  workout_id UUID NOT NULL REFERENCES public.workouts(id) ON DELETE CASCADE,
  exercise_id UUID NOT NULL REFERENCES public.exercises_new(id),
  sort_order INTEGER NOT NULL,
  sets INTEGER NOT NULL DEFAULT 1,
  min_reps INTEGER,
  max_reps INTEGER,
  is_amrap BOOLEAN NOT NULL DEFAULT FALSE,
  rest_seconds INTEGER DEFAULT 60,
  duration_seconds INTEGER,
  group_id INTEGER,
  is_unilateral BOOLEAN NOT NULL DEFAULT FALSE,
  load_mode_override TEXT,
  notes TEXT,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at TIMESTAMPTZ
);

CREATE INDEX workout_exercises_workout_idx ON public.workout_exercises (workout_id);
CREATE INDEX workout_exercises_user_idx ON public.workout_exercises (user_id);

-- ═══════════════════════════════════════════════════════════════
-- 6. Create execution_set_segments (normalized from JSONB)
-- ═══════════════════════════════════════════════════════════════

CREATE TABLE public.execution_set_segments (
  id UUID PRIMARY KEY,
  execution_set_id UUID NOT NULL REFERENCES public.execution_sets(id) ON DELETE CASCADE,
  segment_order INTEGER NOT NULL,
  reps INTEGER NOT NULL,
  weight DOUBLE PRECISION
);

CREATE INDEX execution_set_segments_set_idx ON public.execution_set_segments (execution_set_id);

-- ═══════════════════════════════════════════════════════════════
-- 7. Drop old tables
-- ═══════════════════════════════════════════════════════════════

DROP TABLE IF EXISTS public.exercise_equipments CASCADE;
DROP TABLE IF EXISTS public.exercise_variations CASCADE;
DROP TABLE IF EXISTS public.exercise_target_muscles CASCADE;
DROP TABLE IF EXISTS public.user_exercises CASCADE;
DROP TABLE IF EXISTS public.exercises CASCADE;
DROP TABLE IF EXISTS public.equipments CASCADE;
DROP TABLE IF EXISTS public.catalog_version CASCADE;
DROP TABLE IF EXISTS public.catalog_governance_events CASCADE;
DROP TABLE IF EXISTS public.catalog_governance_rules CASCADE;

-- Rename new tables
ALTER TABLE public.exercises_new RENAME TO exercises;
ALTER TABLE public.exercise_target_muscles_new RENAME TO exercise_target_muscles;
ALTER TABLE public.exercise_variations_new RENAME TO exercise_variations;

-- ═══════════════════════════════════════════════════════════════
-- 8. RLS for exercises
-- ═══════════════════════════════════════════════════════════════

ALTER TABLE public.exercises ENABLE ROW LEVEL SECURITY;

CREATE POLICY "read_exercises" ON public.exercises FOR SELECT
  USING (is_verified = TRUE OR created_by = auth.uid());

CREATE POLICY "insert_exercises" ON public.exercises FOR INSERT
  TO authenticated
  WITH CHECK (created_by = auth.uid() AND is_verified = FALSE);

CREATE POLICY "update_exercises" ON public.exercises FOR UPDATE
  TO authenticated
  USING (created_by = auth.uid() AND is_verified = FALSE)
  WITH CHECK (created_by = auth.uid() AND is_verified = FALSE);

CREATE POLICY "delete_exercises" ON public.exercises FOR DELETE
  TO authenticated
  USING (created_by = auth.uid() AND is_verified = FALSE);

-- ═══════════════════════════════════════════════════════════════
-- 9. RLS for junction tables
-- ═══════════════════════════════════════════════════════════════

ALTER TABLE public.exercise_target_muscles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "read_exercise_target_muscles" ON public.exercise_target_muscles
  FOR SELECT USING (TRUE);

ALTER TABLE public.exercise_variations ENABLE ROW LEVEL SECURITY;
CREATE POLICY "read_exercise_variations" ON public.exercise_variations
  FOR SELECT USING (TRUE);

-- ═══════════════════════════════════════════════════════════════
-- 10. RLS for renamed user-owned tables
-- ═══════════════════════════════════════════════════════════════

DO $$
DECLARE
  tbl TEXT;
BEGIN
  FOREACH tbl IN ARRAY ARRAY[
    'workouts',
    'programs',
    'progression_rules',
    'cycle_steps',
    'workout_executions',
    'execution_sets',
    'workout_exercises'
  ]
  LOOP
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', tbl);

    EXECUTE format('DROP POLICY IF EXISTS "read_own_%s" ON public.%I', tbl, tbl);
    EXECUTE format(
      'CREATE POLICY "read_own_%s" ON public.%I FOR SELECT TO authenticated USING (user_id = auth.uid())',
      tbl, tbl
    );

    EXECUTE format('DROP POLICY IF EXISTS "insert_own_%s" ON public.%I', tbl, tbl);
    EXECUTE format(
      'CREATE POLICY "insert_own_%s" ON public.%I FOR INSERT TO authenticated WITH CHECK (user_id = auth.uid())',
      tbl, tbl
    );

    EXECUTE format('DROP POLICY IF EXISTS "update_own_%s" ON public.%I', tbl, tbl);
    EXECUTE format(
      'CREATE POLICY "update_own_%s" ON public.%I FOR UPDATE TO authenticated USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid())',
      tbl, tbl
    );

    EXECUTE format('DROP POLICY IF EXISTS "delete_own_%s" ON public.%I', tbl, tbl);
    EXECUTE format(
      'CREATE POLICY "delete_own_%s" ON public.%I FOR DELETE TO authenticated USING (user_id = auth.uid())',
      tbl, tbl
    );
  END LOOP;
END $$;

-- ═══════════════════════════════════════════════════════════════
-- 11. Triggers for updated_at
-- ═══════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DO $$
DECLARE
  tbl TEXT;
BEGIN
  FOREACH tbl IN ARRAY ARRAY[
    'exercises',
    'workouts',
    'programs',
    'progression_rules',
    'cycle_steps',
    'workout_executions',
    'execution_sets',
    'workout_exercises'
  ]
  LOOP
    EXECUTE format('DROP TRIGGER IF EXISTS set_%s_updated_at ON public.%I', tbl, tbl);
    EXECUTE format(
      'CREATE TRIGGER set_%s_updated_at BEFORE UPDATE ON public.%I FOR EACH ROW EXECUTE FUNCTION public.set_updated_at()',
      tbl, tbl
    );
  END LOOP;
END $$;

-- ═══════════════════════════════════════════════════════════════
-- 12. Indexes
-- ═══════════════════════════════════════════════════════════════

CREATE INDEX exercises_created_by_idx ON public.exercises (created_by) WHERE created_by IS NOT NULL;
CREATE INDEX workouts_user_idx ON public.workouts (user_id);
CREATE INDEX programs_user_idx ON public.programs (user_id);
CREATE INDEX progression_rules_program_idx ON public.progression_rules (program_id);
CREATE INDEX cycle_steps_program_idx ON public.cycle_steps (program_id);
CREATE INDEX workout_executions_user_idx ON public.workout_executions (user_id);
CREATE INDEX execution_sets_execution_idx ON public.execution_sets (execution_id);

-- Drop old indexes that referenced renamed tables
DROP INDEX IF EXISTS user_exercises_user_idx;
DROP INDEX IF EXISTS user_workouts_user_idx;
DROP INDEX IF EXISTS user_programs_user_idx;
DROP INDEX IF EXISTS user_workout_executions_user_idx;

-- Drop old RLS policies from renamed tables (they were created with user_ prefix)
DO $$
DECLARE
  tbl TEXT;
  old_tbl TEXT;
BEGIN
  FOREACH old_tbl IN ARRAY ARRAY[
    'user_workouts',
    'user_programs',
    'user_progression_rules',
    'user_cycle_steps',
    'user_workout_executions',
    'user_execution_sets'
  ]
  LOOP
    tbl := replace(old_tbl, 'user_', '');
    EXECUTE format('DROP POLICY IF EXISTS "read_own_%s" ON public.%I', old_tbl, tbl);
    EXECUTE format('DROP POLICY IF EXISTS "insert_own_%s" ON public.%I', old_tbl, tbl);
    EXECUTE format('DROP POLICY IF EXISTS "update_own_%s" ON public.%I', old_tbl, tbl);
    EXECUTE format('DROP POLICY IF EXISTS "delete_own_%s" ON public.%I', old_tbl, tbl);
  END LOOP;
END $$;

-- Drop old triggers with user_ prefix
DO $$
DECLARE
  tbl TEXT;
  old_tbl TEXT;
BEGIN
  FOREACH old_tbl IN ARRAY ARRAY[
    'user_workouts',
    'user_programs',
    'user_progression_rules',
    'user_cycle_steps',
    'user_workout_executions',
    'user_execution_sets'
  ]
  LOOP
    tbl := replace(old_tbl, 'user_', '');
    EXECUTE format('DROP TRIGGER IF EXISTS set_%s_updated_at ON public.%I', old_tbl, tbl);
  END LOOP;
END $$;

-- execution_set_segments has no user_id; ownership flows from execution_sets.
ALTER TABLE public.execution_set_segments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "read_own_execution_set_segments" ON public.execution_set_segments;
DROP POLICY IF EXISTS "insert_own_execution_set_segments" ON public.execution_set_segments;
DROP POLICY IF EXISTS "update_own_execution_set_segments" ON public.execution_set_segments;
DROP POLICY IF EXISTS "delete_own_execution_set_segments" ON public.execution_set_segments;

CREATE POLICY "read_own_execution_set_segments" ON public.execution_set_segments
  FOR SELECT TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.execution_sets es
    WHERE es.id = execution_set_id AND es.user_id = auth.uid()
  ));

CREATE POLICY "insert_own_execution_set_segments" ON public.execution_set_segments
  FOR INSERT TO authenticated
  WITH CHECK (EXISTS (
    SELECT 1 FROM public.execution_sets es
    WHERE es.id = execution_set_id AND es.user_id = auth.uid()
  ));

CREATE POLICY "update_own_execution_set_segments" ON public.execution_set_segments
  FOR UPDATE TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.execution_sets es
    WHERE es.id = execution_set_id AND es.user_id = auth.uid()
  ))
  WITH CHECK (EXISTS (
    SELECT 1 FROM public.execution_sets es
    WHERE es.id = execution_set_id AND es.user_id = auth.uid()
  ));

CREATE POLICY "delete_own_execution_set_segments" ON public.execution_set_segments
  FOR DELETE TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.execution_sets es
    WHERE es.id = execution_set_id AND es.user_id = auth.uid()
  ));

-- Remove helper function (only needed for migration)
DROP FUNCTION IF EXISTS public.athlos_exercise_uuid(TEXT);
