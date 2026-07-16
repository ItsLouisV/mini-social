-- ============================================================
-- Migration: Tách chức năng chặn tin nhắn (chat_blocks)
--            khỏi bảng blocks dùng cho profile/feed privacy
--
-- Hành vi:
--   - Cả 2 vẫn thấy nhau, xem được tin nhắn cũ
--   - Chỉ không thể gửi tin nhắn mới cho nhau
-- ============================================================

-- 1. Tạo bảng chat_blocks riêng cho việc chặn tin nhắn
CREATE TABLE IF NOT EXISTS public.chat_blocks (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  blocker_id  UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  blocked_id  UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  created_at  TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (blocker_id, blocked_id),
  CONSTRAINT chat_cannot_block_self CHECK (blocker_id <> blocked_id)
);

-- 2. Kích hoạt RLS
ALTER TABLE public.chat_blocks ENABLE ROW LEVEL SECURITY;

-- 3. RLS cho chat_blocks:
--    - blocker quản lý danh sách của mình (ALL)
--    - blocked_id được phép đọc để biết mình đang bị chặn (SELECT)
CREATE POLICY "Users manage own chat block list" ON public.chat_blocks
  FOR ALL USING (auth.uid() = blocker_id);

CREATE POLICY "Users see if they are blocked in chat" ON public.chat_blocks
  FOR SELECT USING (auth.uid() = blocked_id);

-- 4. KHÔNG thay đổi RLS SELECT conversations/messages
--    (cả 2 vẫn thấy nhau và xem được tin nhắn cũ)

-- 5. Chỉ chặn INSERT messages khi có chat_block (1 trong 2 chiều đều chặn được)
DROP POLICY IF EXISTS "Users send messages if not blocked" ON public.messages;
DROP POLICY IF EXISTS "Users send messages if not chat-blocked" ON public.messages;

CREATE POLICY "Users send messages if not chat-blocked" ON public.messages
  FOR INSERT WITH CHECK (
    auth.uid() = sender_id
    AND NOT EXISTS (
      SELECT 1 FROM public.chat_blocks cb
      WHERE
        -- Tôi đã chặn chat người kia
        (cb.blocker_id = auth.uid() AND cb.blocked_id = (
          SELECT CASE WHEN participant_1 = auth.uid() THEN participant_2 ELSE participant_1 END
          FROM public.conversations WHERE id = conversation_id
        ))
        OR
        -- Người kia đã chặn chat tôi
        (cb.blocked_id = auth.uid() AND cb.blocker_id = (
          SELECT CASE WHEN participant_1 = auth.uid() THEN participant_2 ELSE participant_1 END
          FROM public.conversations WHERE id = conversation_id
        ))
    )
  );

-- 6. Khôi phục lại các policy cũ cho conversations/messages
--    (xoá các policy cũ đã thay đổi ở migration trước nếu có)
DROP POLICY IF EXISTS "Participants view conversations if not chat-blocked" ON public.conversations;
DROP POLICY IF EXISTS "Users create conversations if not chat-blocked" ON public.conversations;

-- Khôi phục policy conversations gốc (chỉ cần là participant)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'conversations'
      AND policyname = 'Participants view conversations'
  ) THEN
    CREATE POLICY "Participants view conversations" ON public.conversations
      FOR SELECT USING (auth.uid() = participant_1 OR auth.uid() = participant_2);
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'conversations'
      AND policyname = 'Users create conversations'
  ) THEN
    CREATE POLICY "Users create conversations" ON public.conversations
      FOR INSERT WITH CHECK (auth.uid() = participant_1 OR auth.uid() = participant_2);
  END IF;
END $$;

-- Khôi phục policy messages SELECT gốc (participant hoặc sender được xem)
DROP POLICY IF EXISTS "Participants view messages if not chat-blocked" ON public.messages;
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'messages'
      AND policyname = 'Participants view messages'
  ) THEN
    CREATE POLICY "Participants view messages" ON public.messages
      FOR SELECT USING (
        auth.uid() = sender_id OR
        auth.uid() IN (
          SELECT participant_1 FROM public.conversations WHERE id = conversation_id
          UNION
          SELECT participant_2 FROM public.conversations WHERE id = conversation_id
        )
      );
  END IF;
END $$;

-- 7. Đăng ký Realtime cho chat_blocks
ALTER PUBLICATION supabase_realtime ADD TABLE chat_blocks;
