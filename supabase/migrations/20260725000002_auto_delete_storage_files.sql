-- ============================================================
-- Migration: Sửa trigger - KHÔNG xóa storage.objects trực tiếp
-- Supabase chỉ cho phép xóa file qua Storage API, không qua SQL
-- Thay vào đó: trigger chỉ log path cần xóa vào bảng storage_deletion_queue
-- để Edge Function hoặc Flutter SDK xử lý
-- ============================================================

-- 1. Drop các trigger cũ dùng DELETE FROM storage.objects
DROP TRIGGER IF EXISTS tr_delete_post_media_storage_file ON public.post_media;
DROP TRIGGER IF EXISTS tr_delete_message_storage_file ON public.messages;
DROP FUNCTION IF EXISTS public.delete_post_media_storage_file();
DROP FUNCTION IF EXISTS public.delete_message_storage_file();

-- 2. Tạo bảng hàng đợi xóa storage (storage_deletion_queue)
--    Khi post_media hoặc message bị xóa, trigger sẽ ghi path vào đây
--    Flutter app hoặc Edge Function sẽ đọc và xóa file thực tế qua Storage API
CREATE TABLE IF NOT EXISTS public.storage_deletion_queue (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  bucket       TEXT NOT NULL,
  path         TEXT NOT NULL,
  created_at   TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.storage_deletion_queue ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Service role only" ON public.storage_deletion_queue
  USING (false);

-- 3. Trigger cho post_media: Ghi path vào queue khi xóa media
CREATE OR REPLACE FUNCTION public.queue_post_media_deletion()
RETURNS TRIGGER AS $$
DECLARE
  target_path TEXT;
BEGIN
  target_path := OLD.path;
  IF target_path IS NULL OR target_path = '' THEN
    IF OLD.url LIKE '%/posts/%' THEN
      target_path := split_part(OLD.url, '/posts/', 2);
    END IF;
  END IF;

  IF target_path IS NOT NULL AND target_path != '' THEN
    INSERT INTO public.storage_deletion_queue (bucket, path)
    VALUES ('posts', target_path);
  END IF;

  RETURN OLD;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS tr_queue_post_media_deletion ON public.post_media;
CREATE TRIGGER tr_queue_post_media_deletion
AFTER DELETE ON public.post_media
FOR EACH ROW
EXECUTE FUNCTION public.queue_post_media_deletion();

-- 4. Trigger cho messages: Ghi path vào queue khi xóa tin nhắn có ảnh
CREATE OR REPLACE FUNCTION public.queue_message_media_deletion()
RETURNS TRIGGER AS $$
DECLARE
  target_path TEXT;
BEGIN
  IF OLD.media_url IS NOT NULL AND OLD.media_url != '' THEN
    target_path := OLD.media_url;
    IF target_path LIKE '%/messages/%' THEN
      target_path := split_part(target_path, '/messages/', 2);
    END IF;

    IF target_path IS NOT NULL AND target_path != '' AND target_path NOT LIKE 'http%' THEN
      INSERT INTO public.storage_deletion_queue (bucket, path)
      VALUES ('messages', target_path);
    END IF;
  END IF;

  RETURN OLD;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'messages') THEN
    EXECUTE 'DROP TRIGGER IF EXISTS tr_queue_message_media_deletion ON public.messages;';
    EXECUTE 'CREATE TRIGGER tr_queue_message_media_deletion AFTER DELETE ON public.messages FOR EACH ROW EXECUTE FUNCTION public.queue_message_media_deletion();';
  END IF;
END $$;
