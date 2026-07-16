-- Cập nhật chính sách RLS trên bảng profiles
-- Cho phép người thực hiện chặn (blocker) xem được thông tin của người bị chặn (blocked) để thực hiện bỏ chặn nếu cần,
-- nhưng người bị chặn (blocked) vẫn không thể xem thông tin của người chặn (blocker).

DROP POLICY IF EXISTS "Profiles viewable if not blocked and public/friends" ON public.profiles;

CREATE POLICY "Profiles viewable if not blocked and public/friends" ON public.profiles
  FOR SELECT USING (
    -- Người thực hiện truy vấn (auth.uid()) không bị chủ tài khoản (profiles.id) chặn
    NOT EXISTS (
      SELECT 1 FROM public.blocks b
      WHERE b.blocker_id = profiles.id AND b.blocked_id = auth.uid()
    )
    AND
    -- Các điều kiện được phép xem profile:
    (
      profiles.is_private_profile = false
      OR profiles.id = auth.uid()
      -- Viewer đã kết bạn với chủ tài khoản
      OR EXISTS (
        SELECT 1 FROM public.friend_requests fr
        WHERE fr.status = 'accepted'
          AND (
            (fr.sender_id = profiles.id AND fr.receiver_id = auth.uid())
            OR (fr.sender_id = auth.uid() AND fr.receiver_id = profiles.id)
          )
      )
      -- Viewer đã chặn chủ tài khoản (cho phép xem thông tin cơ bản để bỏ chặn)
      OR EXISTS (
        SELECT 1 FROM public.blocks b
        WHERE b.blocker_id = auth.uid() AND b.blocked_id = profiles.id
      )
    )
  );
