-- ============================================================================
-- SCRIPT BỔ SUNG CẤU TRÚC DATABASE (UPGRADE SCHEMA TO STARTUP-GRADE)
-- Copy toàn bộ nội dung script này dán vào Supabase SQL Editor và chạy.
-- ============================================================================

-- 1. KÍCH HOẠT EXTENSION MỚI (Cho chức năng tìm kiếm ngữ nghĩa và AI ở các Sprint sau)
CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS unaccent;

-- 2. BỔ SUNG CỘT CHO CÁC BẢNG ĐÃ CÓ
-- Thêm cột interests vào profiles để phục vụ Recommendation Engine ở Sprint 7
ALTER TABLE public.profiles 
  ADD COLUMN IF NOT EXISTS interests TEXT[] DEFAULT '{}';

-- Thêm cột embedding vào posts để phục vụ AI Semantic Search ở Sprint 8
ALTER TABLE public.posts 
  ADD COLUMN IF NOT EXISTS embedding vector(384);

-- 3. TẠO BẢNG CÒN THIẾU TRONG ĐẶC TẢ CHI TIẾT (Bảng message_reactions dùng cho thả emoji tin nhắn)
CREATE TABLE IF NOT EXISTS public.message_reactions (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  message_id  UUID REFERENCES public.messages(id) ON DELETE CASCADE NOT NULL,
  user_id     UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  emoji       TEXT NOT NULL,
  created_at  TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (message_id, user_id, emoji)
);

-- Kích hoạt RLS bảo mật cho bảng reactions
ALTER TABLE public.message_reactions ENABLE ROW LEVEL SECURITY;

-- Tạo chính sách xem và quản lý emoji tin nhắn
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'message_reactions' AND policyname = 'Participants view message reactions'
  ) THEN
    CREATE POLICY "Participants view message reactions" ON public.message_reactions
      FOR SELECT USING (
        EXISTS (
          SELECT 1 FROM public.messages m
          JOIN public.conversations c ON m.conversation_id = c.id
          WHERE m.id = message_reactions.message_id
          AND (auth.uid() = c.participant_1 OR auth.uid() = c.participant_2)
        )
      );
  END IF;
  
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'message_reactions' AND policyname = 'Users manage own reactions'
  ) THEN
    CREATE POLICY "Users manage own reactions" ON public.message_reactions
      FOR ALL USING (auth.uid() = user_id);
  END IF;
END
$$;

-- Thêm bảng message_reactions vào Realtime Replication
ALTER PUBLICATION supabase_realtime ADD TABLE message_reactions;

-- 4. TẠO BẢNG NHẬT KÝ BẢO MẬT (Cho Sprint 12 - Security & Audit Logs)
CREATE TABLE IF NOT EXISTS public.audit_logs (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  action      TEXT NOT NULL,
  ip_address  TEXT,
  user_agent  TEXT,
  payload     JSONB,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- Kích hoạt RLS bảo mật cho bảng audit_logs
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'audit_logs' AND policyname = 'Users view own audit logs'
  ) THEN
    CREATE POLICY "Users view own audit logs" ON public.audit_logs
      FOR SELECT USING (auth.uid() = user_id);
  END IF;
END
$$;

-- 5. BỔ SUNG CHÍNH SÁCH BẢO MẬT BUCKET COVERS (Storage)
-- (Trong file DATABASE_SCHEMA.md gốc bị thiếu RLS cho Covers, chỉ có Avatars)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'objects' AND schemaname = 'storage' AND policyname = 'Public read covers'
  ) THEN
    CREATE POLICY "Public read covers" ON storage.objects FOR SELECT USING (bucket_id = 'covers');
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'objects' AND schemaname = 'storage' AND policyname = 'Upload own cover'
  ) THEN
    CREATE POLICY "Upload own cover" ON storage.objects FOR INSERT WITH CHECK (
      bucket_id = 'covers' AND auth.uid()::text = (storage.foldername(name))[1]
    );
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'objects' AND schemaname = 'storage' AND policyname = 'Delete own cover'
  ) THEN
    CREATE POLICY "Delete own cover" ON storage.objects FOR DELETE USING (
      bucket_id = 'covers' AND auth.uid()::text = (storage.foldername(name))[1]
    );
  END IF;
END
$$;
