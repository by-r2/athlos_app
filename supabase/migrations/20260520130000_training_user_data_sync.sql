-- User-owned training data (authenticated sync).

CREATE TABLE IF NOT EXISTS public.user_exercises (
  id UUID PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  catalog_remote_id TEXT,
  name TEXT NOT NULL,
  muscle_group TEXT NOT NULL,
  type TEXT NOT NULL,
  movement_pattern TEXT,
  description TEXT,
  default_load_mode TEXT NOT NULL,
  bodyweight_load_factor DOUBLE PRECISION,
  is_isometric BOOLEAN NOT NULL DEFAULT FALSE,
  target_muscles JSONB NOT NULL DEFAULT '[]',
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS public.user_workouts (
  id UUID PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  description TEXT,
  sort_order INTEGER,
  is_archived BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL,
  exercises_config JSONB NOT NULL DEFAULT '[]',
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS public.user_programs (
  id UUID PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  focus TEXT NOT NULL,
  duration_mode TEXT NOT NULL,
  duration_value INTEGER NOT NULL,
  default_rest_seconds INTEGER,
  is_active BOOLEAN NOT NULL DEFAULT FALSE,
  is_in_deload BOOLEAN NOT NULL DEFAULT FALSE,
  deload_frequency INTEGER,
  deload_strategy TEXT,
  deload_volume_multiplier DOUBLE PRECISION,
  deload_intensity_multiplier DOUBLE PRECISION,
  created_at TIMESTAMPTZ NOT NULL,
  archived_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS public.user_progression_rules (
  id UUID PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  program_remote_id UUID NOT NULL,
  exercise_remote_id UUID NOT NULL,
  type TEXT NOT NULL,
  value DOUBLE PRECISION NOT NULL,
  frequency TEXT NOT NULL,
  condition TEXT,
  condition_value DOUBLE PRECISION,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS public.user_cycle_steps (
  id UUID PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  program_remote_id UUID NOT NULL,
  order_index INTEGER NOT NULL,
  workout_remote_id UUID NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS public.user_workout_executions (
  id UUID PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  workout_remote_id UUID NOT NULL,
  program_remote_id UUID NOT NULL,
  started_at TIMESTAMPTZ NOT NULL,
  finished_at TIMESTAMPTZ,
  exercise_config_snapshot TEXT,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS public.user_execution_sets (
  id UUID PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  execution_remote_id UUID NOT NULL,
  exercise_remote_id UUID NOT NULL,
  set_number INTEGER NOT NULL,
  planned_reps INTEGER,
  planned_weight DOUBLE PRECISION,
  reps INTEGER,
  weight DOUBLE PRECISION,
  duration INTEGER,
  distance DOUBLE PRECISION,
  is_completed BOOLEAN NOT NULL DEFAULT FALSE,
  is_warmup BOOLEAN NOT NULL DEFAULT FALSE,
  rpe INTEGER,
  body_weight_snapshot DOUBLE PRECISION,
  load_mode_override TEXT,
  left_reps INTEGER,
  left_weight DOUBLE PRECISION,
  right_reps INTEGER,
  right_weight DOUBLE PRECISION,
  is_unilateral BOOLEAN,
  segments_config JSONB NOT NULL DEFAULT '[]',
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS user_exercises_user_idx ON public.user_exercises (user_id);
CREATE INDEX IF NOT EXISTS user_workouts_user_idx ON public.user_workouts (user_id);
CREATE INDEX IF NOT EXISTS user_programs_user_idx ON public.user_programs (user_id);
CREATE INDEX IF NOT EXISTS user_workout_executions_user_idx ON public.user_workout_executions (user_id);

DO $$
DECLARE
  tbl TEXT;
BEGIN
  FOREACH tbl IN ARRAY ARRAY[
    'user_exercises',
    'user_workouts',
    'user_programs',
    'user_progression_rules',
    'user_cycle_steps',
    'user_workout_executions',
    'user_execution_sets'
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

DO $$
DECLARE
  tbl TEXT;
BEGIN
  FOREACH tbl IN ARRAY ARRAY[
    'user_exercises',
    'user_workouts',
    'user_programs',
    'user_progression_rules',
    'user_cycle_steps',
    'user_workout_executions',
    'user_execution_sets'
  ]
  LOOP
    EXECUTE format('DROP TRIGGER IF EXISTS set_%s_updated_at ON public.%I', tbl, tbl);
    EXECUTE format(
      'CREATE TRIGGER set_%s_updated_at BEFORE UPDATE ON public.%I FOR EACH ROW EXECUTE FUNCTION public.set_updated_at()',
      tbl, tbl
    );
  END LOOP;
END $$;
