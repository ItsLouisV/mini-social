-- Migration: Story reactions table and RLS policies
CREATE TABLE IF NOT EXISTS public.story_reactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    story_id UUID NOT NULL REFERENCES public.stories(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    reaction TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Unique constraint: A user can only store one record per emoji type on a story
ALTER TABLE public.story_reactions
    DROP CONSTRAINT IF EXISTS uq_story_user_reaction;
ALTER TABLE public.story_reactions
    ADD CONSTRAINT uq_story_user_reaction UNIQUE (story_id, user_id, reaction);

CREATE INDEX IF NOT EXISTS idx_story_reactions_story_id ON public.story_reactions(story_id);
CREATE INDEX IF NOT EXISTS idx_story_reactions_user_story ON public.story_reactions(story_id, user_id);

ALTER TABLE public.story_reactions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone can read story reactions" ON public.story_reactions;
CREATE POLICY "Anyone can read story reactions" ON public.story_reactions
    FOR SELECT USING (true);

DROP POLICY IF EXISTS "Authenticated users can insert reactions" ON public.story_reactions;
CREATE POLICY "Authenticated users can insert reactions" ON public.story_reactions
    FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Authenticated users can update own reactions" ON public.story_reactions;
CREATE POLICY "Authenticated users can update own reactions" ON public.story_reactions
    FOR UPDATE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete own reactions" ON public.story_reactions;
CREATE POLICY "Users can delete own reactions" ON public.story_reactions
    FOR DELETE USING (auth.uid() = user_id);
