-- 20260528120000 was recorded before ALTER targeted renamed tables (user_workouts).
-- Add columns on workouts / workout_executions for improvised workout sync.

ALTER TABLE public.workouts
  ADD COLUMN IF NOT EXISTS is_draft BOOLEAN NOT NULL DEFAULT FALSE;

ALTER TABLE public.workout_executions
  ADD COLUMN IF NOT EXISTS session_kind TEXT NOT NULL DEFAULT 'planned';
