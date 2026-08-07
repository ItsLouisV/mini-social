-- ============================================================
-- Migration: Fix trigger queue_message_media_deletion & queue_post_media_deletion
-- Sửa lỗi: record "old" has no field "media_url" (Postgres Error 42703)
-- Sử dụng to_jsonb(OLD) để kiểm tra linh hoạt sự tồn tại của cột
-- ============================================================

-- 1. Tạo bảng hàng đợi xóa storage (nếu chưa có)
CREATE TABLE IF NOT EXISTS public.storage_deletion_queue (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  bucket       TEXT NOT NULL,
  path         TEXT NOT NULL,
  created_at   TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.storage_deletion_queue ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'storage_deletion_queue' AND policyname = 'Service role only'
  ) THEN
    CREATE POLICY "Service role only" ON public.storage_deletion_queue USING (false);
  END IF;
END $$;

-- 2. Trigger hàm cho post_media
CREATE OR REPLACE FUNCTION public.queue_post_media_deletion()
RETURNS TRIGGER AS $$
DECLARE
  old_json JSONB;
  target_path TEXT;
  url_val TEXT;
BEGIN
  old_json := to_jsonb(OLD);
  
  IF old_json ? 'path' AND old_json->>'path' IS NOT NULL AND old_json->>'path' != '' THEN
    target_path := old_json->>'path';
  ELSIF old_json ? 'url' AND old_json->>'url' IS NOT NULL THEN
    url_val := old_json->>'url';
    IF url_val LIKE '%/posts/%' THEN
      target_path := split_part(url_val, '/posts/', 2);
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

-- 3. Trigger hàm cho messages: Sử dụng to_jsonb(OLD) an toàn tuyệt đối với mọi cấu trúc cột (media_urls mảng hoặc media_url string)
CREATE OR REPLACE FUNCTION public.queue_message_media_deletion()
RETURNS TRIGGER AS $$
DECLARE
  old_json JSONB;
  url_val TEXT;
  target_path TEXT;
  elem JSONB;
BEGIN
  old_json := to_jsonb(OLD);

  -- Case A: Cột media_urls (mảng JSONB hoặc mảng văn bản)
  IF old_json ? 'media_urls' AND old_json->'media_urls' IS NOT NULL THEN
    IF jsonb_typeof(old_json->'media_urls') = 'array' THEN
      FOR elem IN SELECT * FROM jsonb_array_elements(old_json->'media_urls') LOOP
        url_val := elem->>0;
        IF url_val IS NOT NULL AND url_val != '' AND url_val NOT LIKE 'http%' THEN
          target_path := url_val;
          IF target_path LIKE '%/messages/%' THEN
            target_path := split_part(target_path, '/messages/', 2);
          END IF;
          IF target_path IS NOT NULL AND target_path != '' THEN
            INSERT INTO public.storage_deletion_queue (bucket, path)
            VALUES ('messages', target_path);
          END IF;
        END IF;
      END LOOP;
    END IF;
  END IF;

  -- Case B: Cột media_url đơn cũ (nếu bảng còn lưu)
  IF old_json ? 'media_url' AND old_json->>'media_url' IS NOT NULL THEN
    url_val := old_json->>'media_url';
    IF url_val IS NOT NULL AND url_val != '' AND url_val NOT LIKE 'http%' THEN
      target_path := url_val;
      IF target_path LIKE '%/messages/%' THEN
        target_path := split_part(target_path, '/messages/', 2);
      END IF;
      IF target_path IS NOT NULL AND target_path != '' THEN
        INSERT INTO public.storage_deletion_queue (bucket, path)
        VALUES ('messages', target_path);
      END IF;
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
