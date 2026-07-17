-- ============================================================
-- Migration: Xóa hoàn toàn chức năng chặn người dùng (blocks)
--            Chỉ giữ lại chức năng chặn tin nhắn (chat_blocks)
-- ============================================================

-- 1. Xóa RLS policy cũ trên bảng profiles và tạo lại không kiểm tra bảng blocks
DROP POLICY IF EXISTS "Profiles viewable if not blocked and public/friends" ON public.profiles;

CREATE POLICY "Profiles viewable if public/friends" ON public.profiles
  FOR SELECT USING (
    profiles.is_private_profile = false
    OR profiles.id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM public.friend_requests fr
      WHERE fr.status = 'accepted'
        AND (
          (fr.sender_id = profiles.id AND fr.receiver_id = auth.uid())
          OR (fr.sender_id = auth.uid() AND fr.receiver_id = profiles.id)
        )
    )
  );

-- 2. Xóa RLS policy cũ trên bảng posts và tạo lại không kiểm tra bảng blocks
DROP POLICY IF EXISTS "Posts viewable if not blocked/muted and public/friends" ON public.posts;

CREATE POLICY "Posts viewable if not muted and public/friends" ON public.posts
  FOR SELECT USING (
    NOT EXISTS (
      SELECT 1 FROM public.mutes m
      WHERE m.muter_id = auth.uid() AND m.muted_id = posts.user_id
    )
    AND (
      (SELECT is_private_profile FROM public.profiles WHERE id = posts.user_id) = false
      OR posts.user_id = auth.uid()
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

-- 3. Gỡ bảng blocks khỏi Realtime Replication và Xóa bảng blocks
ALTER PUBLICATION supabase_realtime DROP TABLE IF EXISTS blocks;
DROP TABLE IF EXISTS public.blocks CASCADE;
