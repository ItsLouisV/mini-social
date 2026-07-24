-- ============================================================
-- Migration: Thêm các cột metadata (width, height, aspect_ratio, thumbnail_url) vào post_media
-- ============================================================

ALTER TABLE public.post_media ADD COLUMN IF NOT EXISTS width INT DEFAULT NULL;
ALTER TABLE public.post_media ADD COLUMN IF NOT EXISTS height INT DEFAULT NULL;
ALTER TABLE public.post_media ADD COLUMN IF NOT EXISTS aspect_ratio FLOAT DEFAULT NULL;
ALTER TABLE public.post_media ADD COLUMN IF NOT EXISTS thumbnail_url TEXT DEFAULT NULL;
