-- Add music_track JSONB column to profiles and posts tables
-- Format of JSONB: { "id": "123", "title": "...", "artist": "...", "preview_url": "...", "artwork_url": "...", "album": "..." }

ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS music_track JSONB DEFAULT NULL;

ALTER TABLE public.posts
ADD COLUMN IF NOT EXISTS music_track JSONB DEFAULT NULL;
