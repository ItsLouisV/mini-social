-- ============================================================
-- Migration: Fix posts UPDATE policy and SELECT policy for Trash support
-- ============================================================

-- 1. Thêm RLS policy cho phép người dùng CẬP NHẬT (UPDATE) bài viết của chính mình (vd: chuyển vào thùng rác, sửa caption)
DROP POLICY IF EXISTS "Users update own posts" ON public.posts;

CREATE POLICY "Users update own posts" ON public.posts
  FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- 2. Cập nhật RLS policy SELECT để loại bỏ các bài viết đã bị chuyển vào thùng rác (deleted_at IS NOT NULL) khỏi Bảng tin (Feed)
DROP POLICY IF EXISTS "Posts viewable if not muted/deleted and public/friends" ON public.posts;

CREATE POLICY "Posts viewable if not muted/deleted and public/friends" ON public.posts
  FOR SELECT USING (
    -- CHỈ lấy bài viết CHƯA BỊ XÓA (deleted_at IS NULL)
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

-- 3. Tạo RLS policy SELECT riêng cho phép người dùng xem bài viết trong Thùng rác của CHÍNH MÌNH (deleted_at IS NOT NULL)
DROP POLICY IF EXISTS "Users view own trashed posts" ON public.posts;

CREATE POLICY "Users view own trashed posts" ON public.posts
  FOR SELECT USING (
    posts.user_id = auth.uid()
    AND deleted_at IS NOT NULL
  );
