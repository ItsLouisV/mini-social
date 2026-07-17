-- ============================================================
-- Migration: Tạo bảng reports (Báo cáo bài viết)
-- ============================================================

CREATE TABLE IF NOT EXISTS public.reports (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  reporter_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  post_id     UUID REFERENCES public.posts(id) ON DELETE CASCADE NOT NULL,
  reason      TEXT NOT NULL,
  created_at  TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (reporter_id, post_id)
);

-- Kích hoạt RLS
ALTER TABLE public.reports ENABLE ROW LEVEL SECURITY;

-- Tạo RLS policies cho reports
CREATE POLICY "Users view own reports" ON public.reports
  FOR SELECT USING (auth.uid() = reporter_id);

CREATE POLICY "Users create own reports" ON public.reports
  FOR INSERT WITH CHECK (auth.uid() = reporter_id);

CREATE POLICY "Users delete own reports" ON public.reports
  FOR DELETE USING (auth.uid() = reporter_id);
