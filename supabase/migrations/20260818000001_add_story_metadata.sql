-- Add metadata JSONB column to public.stories for text positioning, font styles, and custom text colors
ALTER TABLE public.stories ADD COLUMN IF NOT EXISTS metadata JSONB DEFAULT '{}'::jsonb;
