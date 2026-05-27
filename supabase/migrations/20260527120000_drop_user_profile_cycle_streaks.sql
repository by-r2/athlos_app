-- Remove cycle streak columns; session totals are derived from workout_executions.
ALTER TABLE public.user_profiles
  DROP COLUMN IF EXISTS current_cycle_streak,
  DROP COLUMN IF EXISTS best_cycle_streak;
