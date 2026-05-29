-- Ad-hoc / draft workout support for in-session workout building.
-- Tables were renamed user_workouts → workouts in 20260521000000_uuid_first_data_model.sql.

ALTER TABLE public.workouts
  ADD COLUMN IF NOT EXISTS is_draft BOOLEAN NOT NULL DEFAULT FALSE;

ALTER TABLE public.workout_executions
  ADD COLUMN IF NOT EXISTS session_kind TEXT NOT NULL DEFAULT 'planned';
