-- User-owned app profile data.
-- Auth identity lives in auth.users; this table stores Athlos profile fields.

CREATE TABLE IF NOT EXISTS public.user_profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT,
  height DOUBLE PRECISION,
  age INTEGER,
  goal TEXT,
  body_aesthetic TEXT,
  training_style TEXT,
  experience_level TEXT,
  gender TEXT,
  training_frequency INTEGER,
  available_workout_minutes INTEGER,
  trains_at_gym BOOLEAN,
  injuries TEXT,
  bio TEXT,
  owned_equipment_names TEXT[] NOT NULL DEFAULT '{}',
  last_active_module TEXT NOT NULL DEFAULT 'training',
  current_cycle_streak INTEGER NOT NULL DEFAULT 0,
  best_cycle_streak INTEGER NOT NULL DEFAULT 0,
  current_frequency_streak INTEGER NOT NULL DEFAULT 0,
  best_frequency_streak INTEGER NOT NULL DEFAULT 0,
  training_streaks_schema INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can read their own profile"
  ON public.user_profiles;
CREATE POLICY "Users can read their own profile"
  ON public.user_profiles
  FOR SELECT
  TO authenticated
  USING (id = auth.uid());

DROP POLICY IF EXISTS "Users can insert their own profile"
  ON public.user_profiles;
CREATE POLICY "Users can insert their own profile"
  ON public.user_profiles
  FOR INSERT
  TO authenticated
  WITH CHECK (id = auth.uid());

DROP POLICY IF EXISTS "Users can update their own profile"
  ON public.user_profiles;
CREATE POLICY "Users can update their own profile"
  ON public.user_profiles
  FOR UPDATE
  TO authenticated
  USING (id = auth.uid())
  WITH CHECK (id = auth.uid());

DROP POLICY IF EXISTS "Users can delete their own profile"
  ON public.user_profiles;
CREATE POLICY "Users can delete their own profile"
  ON public.user_profiles
  FOR DELETE
  TO authenticated
  USING (id = auth.uid());

CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS set_user_profiles_updated_at
  ON public.user_profiles;
CREATE TRIGGER set_user_profiles_updated_at
  BEFORE UPDATE ON public.user_profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();
