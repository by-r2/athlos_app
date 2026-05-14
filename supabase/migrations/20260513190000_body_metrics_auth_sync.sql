-- User-owned body weight / composition timeline.

CREATE TABLE IF NOT EXISTS public.body_metrics (
  id UUID PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  weight DOUBLE PRECISION NOT NULL,
  body_fat_percent DOUBLE PRECISION,
  recorded_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS body_metrics_user_recorded_at_idx
  ON public.body_metrics (user_id, recorded_at DESC);

ALTER TABLE public.body_metrics ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can read their own body metrics"
  ON public.body_metrics;
CREATE POLICY "Users can read their own body metrics"
  ON public.body_metrics
  FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can insert their own body metrics"
  ON public.body_metrics;
CREATE POLICY "Users can insert their own body metrics"
  ON public.body_metrics
  FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can update their own body metrics"
  ON public.body_metrics;
CREATE POLICY "Users can update their own body metrics"
  ON public.body_metrics
  FOR UPDATE
  TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can delete their own body metrics"
  ON public.body_metrics;
CREATE POLICY "Users can delete their own body metrics"
  ON public.body_metrics
  FOR DELETE
  TO authenticated
  USING (user_id = auth.uid());

DROP TRIGGER IF EXISTS set_body_metrics_updated_at
  ON public.body_metrics;
CREATE TRIGGER set_body_metrics_updated_at
  BEFORE UPDATE ON public.body_metrics
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();
