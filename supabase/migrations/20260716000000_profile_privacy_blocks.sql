-- 1. Thêm trường is_private_profile vào bảng profiles
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS is_private_profile BOOLEAN DEFAULT false;

-- 2. Tạo bảng blocks (Danh sách chặn)
CREATE TABLE IF NOT EXISTS public.blocks (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  blocker_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  blocked_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (blocker_id, blocked_id),
  CONSTRAINT cannot_block_self CHECK (blocker_id <> blocked_id)
);

-- 3. Tạo bảng mutes (Danh sách ẩn bài đăng)
CREATE TABLE IF NOT EXISTS public.mutes (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  muter_id   UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  muted_id   UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (muter_id, muted_id),
  CONSTRAINT cannot_mute_self CHECK (muter_id <> muted_id)
);

-- 4. Kích hoạt RLS cho blocks và mutes
ALTER TABLE public.blocks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.mutes ENABLE ROW LEVEL SECURITY;

-- 5. Tạo chính sách RLS cho blocks
CREATE POLICY "Users view own block list" ON public.blocks
  FOR SELECT USING (auth.uid() = blocker_id);

CREATE POLICY "Users manage own block list" ON public.blocks
  FOR ALL USING (auth.uid() = blocker_id);

-- 6. Tạo chính sách RLS cho mutes
CREATE POLICY "Users view own mute list" ON public.mutes
  FOR SELECT USING (auth.uid() = muter_id);

CREATE POLICY "Users manage own mute list" ON public.mutes
  FOR ALL USING (auth.uid() = muter_id);

-- 7. Cập nhật RLS trên bảng profiles (xử lý chặn & riêng tư)
DROP POLICY IF EXISTS "Profiles viewable by everyone" ON public.profiles;

CREATE POLICY "Profiles viewable if not blocked and public/friends" ON public.profiles
  FOR SELECT USING (
    -- Không nằm trong quan hệ chặn (block) giữa 2 bên
    NOT EXISTS (
      SELECT 1 FROM public.blocks b
      WHERE (b.blocker_id = profiles.id AND b.blocked_id = auth.uid())
         OR (b.blocker_id = auth.uid() AND b.blocked_id = profiles.id)
    )
    AND
    -- Nếu là tài khoản riêng tư, chỉ cho phép bản thân hoặc bạn bè xem
    (
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
    )
  );

-- 8. Cập nhật RLS trên bảng posts (xử lý chặn, ẩn & riêng tư)
DROP POLICY IF EXISTS "Posts viewable by everyone" ON public.posts;

CREATE POLICY "Posts viewable if not blocked/muted and public/friends" ON public.posts
  FOR SELECT USING (
    -- Không nằm trong quan hệ chặn (block) giữa 2 bên
    NOT EXISTS (
      SELECT 1 FROM public.blocks b
      WHERE (b.blocker_id = posts.user_id AND b.blocked_id = auth.uid())
         OR (b.blocker_id = auth.uid() AND b.blocked_id = posts.user_id)
    )
    -- Người dùng hiện tại không ẩn (mute) chủ bài viết
    AND NOT EXISTS (
      SELECT 1 FROM public.mutes m
      WHERE m.muter_id = auth.uid() AND m.muted_id = posts.user_id
    )
    -- Nếu chủ bài viết là tài khoản riêng tư, chỉ cho phép bản thân hoặc bạn bè xem
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

-- 9. Cập nhật RLS trên bảng conversations (chặn cuộc hội thoại nếu có block)
DROP POLICY IF EXISTS "Participants view conversations" ON public.conversations;
CREATE POLICY "Participants view conversations if not blocked" ON public.conversations
  FOR SELECT USING (
    (auth.uid() = participant_1 OR auth.uid() = participant_2)
    AND NOT EXISTS (
      SELECT 1 FROM public.blocks b
      WHERE (b.blocker_id = participant_1 AND b.blocked_id = participant_2)
         OR (b.blocker_id = participant_2 AND b.blocked_id = participant_1)
    )
  );

DROP POLICY IF EXISTS "Users create conversations" ON public.conversations;
CREATE POLICY "Users create conversations if not blocked" ON public.conversations
  FOR INSERT WITH CHECK (
    (auth.uid() = participant_1 OR auth.uid() = participant_2)
    AND NOT EXISTS (
      SELECT 1 FROM public.blocks b
      WHERE (b.blocker_id = participant_1 AND b.blocked_id = participant_2)
         OR (b.blocker_id = participant_2 AND b.blocked_id = participant_1)
    )
  );

-- 10. Cập nhật RLS trên bảng messages (xử lý ẩn tin nhắn cũ & từ chối gửi tin nhắn mới)
DROP POLICY IF EXISTS "Participants view messages" ON public.messages;
CREATE POLICY "Participants view messages if not blocked" ON public.messages
  FOR SELECT USING (
    (
      auth.uid() = sender_id OR
      auth.uid() IN (
        SELECT participant_1 FROM public.conversations WHERE id = conversation_id
        UNION
        SELECT participant_2 FROM public.conversations WHERE id = conversation_id
      )
    )
    AND NOT EXISTS (
      SELECT 1 FROM public.blocks b
      WHERE (
        b.blocker_id = auth.uid() AND b.blocked_id = (
          SELECT CASE WHEN participant_1 = auth.uid() THEN participant_2 ELSE participant_1 END
          FROM public.conversations WHERE id = conversation_id
        )
      ) OR (
        b.blocked_id = auth.uid() AND b.blocker_id = (
          SELECT CASE WHEN participant_1 = auth.uid() THEN participant_2 ELSE participant_1 END
          FROM public.conversations WHERE id = conversation_id
        )
      )
    )
  );

DROP POLICY IF EXISTS "Users send messages" ON public.messages;
CREATE POLICY "Users send messages if not blocked" ON public.messages
  FOR INSERT WITH CHECK (
    auth.uid() = sender_id
    AND NOT EXISTS (
      SELECT 1 FROM public.blocks b
      WHERE (
        b.blocker_id = auth.uid() AND b.blocked_id = (
          SELECT CASE WHEN participant_1 = auth.uid() THEN participant_2 ELSE participant_1 END
          FROM public.conversations WHERE id = conversation_id
        )
      ) OR (
        b.blocked_id = auth.uid() AND b.blocker_id = (
          SELECT CASE WHEN participant_1 = auth.uid() THEN participant_2 ELSE participant_1 END
          FROM public.conversations WHERE id = conversation_id
        )
      )
    )
  );

DROP POLICY IF EXISTS "Mark messages as seen" ON public.messages;
CREATE POLICY "Mark messages as seen if not blocked" ON public.messages
  FOR UPDATE USING (
    auth.uid() IN (
      SELECT participant_1 FROM public.conversations WHERE id = conversation_id
      UNION
      SELECT participant_2 FROM public.conversations WHERE id = conversation_id
    )
    AND NOT EXISTS (
      SELECT 1 FROM public.blocks b
      WHERE (
        b.blocker_id = auth.uid() AND b.blocked_id = (
          SELECT CASE WHEN participant_1 = auth.uid() THEN participant_2 ELSE participant_1 END
          FROM public.conversations WHERE id = conversation_id
        )
      ) OR (
        b.blocked_id = auth.uid() AND b.blocker_id = (
          SELECT CASE WHEN participant_1 = auth.uid() THEN participant_2 ELSE participant_1 END
          FROM public.conversations WHERE id = conversation_id
        )
      )
    )
  );

-- 11. Đăng ký Realtime Replication cho blocks và mutes để lắng nghe cập nhật tức thời ở client
ALTER PUBLICATION supabase_realtime ADD TABLE blocks;
ALTER PUBLICATION supabase_realtime ADD TABLE mutes;
