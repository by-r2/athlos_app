-- Remove strict FK on workout_exercises.exercise_id → exercises.id
-- The exercise catalog is seeded client-side and may contain exercises
-- not yet present in the remote exercises table. The FK constraint causes
-- sync failures (23503) when pushing workout_exercises that reference
-- newly-seeded verified exercises.
-- Ownership and integrity are enforced by the app logic and RLS.

ALTER TABLE public.workout_exercises
  DROP CONSTRAINT IF EXISTS workout_exercises_exercise_id_fkey;
