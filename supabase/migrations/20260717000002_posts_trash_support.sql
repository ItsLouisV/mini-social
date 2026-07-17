-- ============================================================
-- Migration: Hỗ trợ thùng rác (Trash) cho posts
--            Thêm cột deleted_at vào bảng posts
-- ============================================================

-- 1. Thêm cột deleted_at vào bảng posts
ALTER TABLE public.posts ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ DEFAULT NULL;

-- 2. Cập nhật RLS policy trên bảng posts để loại bỏ các bài viết đã xóa (deleted_at IS NOT NULL)
DROP POLICY IF EXISTS "Posts viewable if not muted and public/friends" ON public.posts;

CREATE POLICY "Posts viewable if not muted/deleted and public/friends" ON public.posts
  FOR SELECT USING (
    deleted_at IS NULL
    AND NOT EXISTS (
      SELECT 1 FROM public.mutes m
      WHERE m.muter_id = auth.uid() AND m.muted_id = posts.user_id
    )
    AND (
      posts.user_id = auth.uid()
      OR (SELECT is_private_profile FROM public.profiles WHERE id = posts.user_id) = false
      OR EXISTS (
        SELECT 1 FROM public.friend_requests fr
        WHERE fr.status = 'accepted'
          AND (
            (fr.sender_id = posts.user_id AND fr.receiver_id = auth.uid())
            OR (fr.sender_id = auth.uid() AND fr.receiver_id = posts.user_id)
          )
      )
    )
  );
