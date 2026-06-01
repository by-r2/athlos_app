-- Links each execution set to a workout template line for faithful history after substitution.
ALTER TABLE public.execution_sets
  ADD COLUMN IF NOT EXISTS workout_exercise_id UUID NULL;

CREATE INDEX IF NOT EXISTS execution_sets_workout_exercise_idx
  ON public.execution_sets (execution_id, workout_exercise_id)
  WHERE deleted_at IS NULL;
