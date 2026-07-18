-- ============================================================
-- Migration: Fix conversation_settings RLS and columns for Chat Wallpaper
-- ============================================================

-- 1. Bổ sung các cột wallpaper và wallpaper_history vào bảng conversation_settings nếu chưa có
ALTER TABLE public.conversation_settings
  ADD COLUMN IF NOT EXISTS wallpaper TEXT DEFAULT '',
  ADD COLUMN IF NOT EXISTS wallpaper_history JSONB DEFAULT '[]'::jsonb;

-- 2. Cập nhật RLS policy trên bảng conversation_settings để hỗ trợ INSERT, UPDATE, UPSERT
DROP POLICY IF EXISTS "Users manage own conversation settings" ON public.conversation_settings;

CREATE POLICY "Users manage own conversation settings" ON public.conversation_settings
  FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);
