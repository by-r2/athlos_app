-- Minimal execution context fallback for history when templates/catalog change.

DO $$
BEGIN
  -- Migration compatibility:
  -- - pre-UUID-first sync used user-owned tables (user_workout_executions)
  -- - UUID-first model renamed them to drop the user_ prefix (workout_executions)
  IF to_regclass('public.workout_executions') IS NOT NULL THEN
    ALTER TABLE public.workout_executions
      ADD COLUMN IF NOT EXISTS workout_name_snapshot TEXT,
      ADD COLUMN IF NOT EXISTS program_name_snapshot TEXT,
      ADD COLUMN IF NOT EXISTS context_fallback JSONB;

    COMMENT ON COLUMN public.workout_executions.workout_name_snapshot IS
      'Workout display name frozen at finish; used when workouts row is deleted.';
    COMMENT ON COLUMN public.workout_executions.program_name_snapshot IS
      'Program display name frozen at finish; used when programs row is removed.';
    COMMENT ON COLUMN public.workout_executions.context_fallback IS
      'Per-exercise metadata (names, load mode, template flags) for history fallback.';
  ELSIF to_regclass('public.user_workout_executions') IS NOT NULL THEN
    ALTER TABLE public.user_workout_executions
      ADD COLUMN IF NOT EXISTS workout_name_snapshot TEXT,
      ADD COLUMN IF NOT EXISTS program_name_snapshot TEXT,
      ADD COLUMN IF NOT EXISTS context_fallback JSONB;

    COMMENT ON COLUMN public.user_workout_executions.workout_name_snapshot IS
      'Workout display name frozen at finish; used when user_workouts row is deleted.';
    COMMENT ON COLUMN public.user_workout_executions.program_name_snapshot IS
      'Program display name frozen at finish; used when user_programs row is removed.';
    COMMENT ON COLUMN public.user_workout_executions.context_fallback IS
      'Per-exercise metadata (names, load mode, template flags) for history fallback.';
  ELSE
    RAISE EXCEPTION 'Expected workout_executions (or user_workout_executions) table to exist';
  END IF;
END $$;
