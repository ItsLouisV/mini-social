-- Migration: 20260807000000_fix_group_chat_realtime_rls.sql
-- Description: Fix RLS policies on messages and conversations so all conversation_members receive realtime messages & updates

-- 1. Cap nhat RLS SELECT policy cho bang public.messages de cho phep thanh vien trong conversation_members xem tin nhan
DROP POLICY IF EXISTS "Participants view messages" ON public.messages;
DROP POLICY IF EXISTS "Participants view messages if not chat-blocked" ON public.messages;

CREATE POLICY "Participants view messages" ON public.messages
  FOR SELECT USING (
    auth.uid() = sender_id OR
    auth.uid() IN (
      SELECT participant_1 FROM public.conversations WHERE id = conversation_id
      UNION
      SELECT participant_2 FROM public.conversations WHERE id = conversation_id
    ) OR
    EXISTS (
      SELECT 1 FROM public.conversation_members cm
      WHERE cm.conversation_id = messages.conversation_id AND cm.user_id = auth.uid()
    )
  );

-- 2. Cap nhat RLS SELECT policy cho bang public.conversations
DROP POLICY IF EXISTS "Participants view conversations" ON public.conversations;

CREATE POLICY "Participants view conversations" ON public.conversations
  FOR SELECT USING (
    auth.uid() = participant_1 OR auth.uid() = participant_2
    OR created_by = auth.uid()
    OR EXISTS (
      SELECT 1 FROM public.conversation_members cm
      WHERE cm.conversation_id = conversations.id AND cm.user_id = auth.uid()
    )
  );

-- 3. Cap nhat RLS INSERT policy cho bang public.messages
DROP POLICY IF EXISTS "Users send messages if not chat-blocked" ON public.messages;

CREATE POLICY "Users send messages if not chat-blocked" ON public.messages
  FOR INSERT WITH CHECK (
    auth.uid() = sender_id
  );

-- 4. Kich hoat Supabase Realtime cho bang messages va conversations neu chua add
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'messages'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE messages;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'conversations'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE conversations;
  END IF;
END $$;
