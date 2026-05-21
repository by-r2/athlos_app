-- Fix RLS on execution_set_segments: table has no user_id column.
-- Ownership is derived from the parent execution_sets row.
-- Safe to re-run (drops policies before recreate).

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
