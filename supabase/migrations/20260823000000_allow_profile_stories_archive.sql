-- Migration: Allow reading all user stories for profile story archive
DROP POLICY IF EXISTS "Public stories read access" ON public.stories;
DROP POLICY IF EXISTS "Stories read access" ON public.stories;

CREATE POLICY "Stories read access" ON public.stories
    FOR SELECT USING (true);
