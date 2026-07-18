-- ============================================================
-- Migration: Tự động cập nhật conversations.last_message khi tin nhắn bị sửa (thu hồi) hoặc bị xóa
-- ============================================================

CREATE OR REPLACE FUNCTION sync_last_message_on_change()
RETURNS TRIGGER AS $$
DECLARE
  target_conv_id UUID;
  latest_msg RECORD;
BEGIN
  IF TG_OP = 'DELETE' THEN
    target_conv_id := OLD.conversation_id;
  ELSE
    target_conv_id := NEW.conversation_id;
  END IF;

  -- 1. Tìm tin nhắn mới nhất còn tồn tại trong cuộc hội thoại này
  SELECT id, content, created_at, message_type
  INTO latest_msg
  FROM public.messages
  WHERE conversation_id = target_conv_id
  ORDER BY created_at DESC
  LIMIT 1;

  -- 2. Cập nhật thông tin tin nhắn cuối của cuộc hội thoại
  IF latest_msg.id IS NOT NULL THEN
    UPDATE public.conversations
    SET 
      last_message_id = latest_msg.id,
      last_message = CASE 
        WHEN latest_msg.message_type = 'recalled' THEN 'Tin nhắn đã thu hồi'
        WHEN latest_msg.message_type = 'image' THEN 'Hình ảnh'
        WHEN latest_msg.message_type = 'video' THEN 'Video'
        WHEN latest_msg.message_type = 'audio' THEN 'Tin nhắn thoại'
        ELSE latest_msg.content
      END,
      last_message_at = latest_msg.created_at
    WHERE id = target_conv_id;
  ELSE
    -- Nếu cuộc hội thoại không còn tin nhắn nào
    UPDATE public.conversations
    SET 
      last_message_id = NULL,
      last_message = NULL,
      last_message_at = NULL
    WHERE id = target_conv_id;
  END IF;

  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- 3. Đăng ký Trigger cho sự kiện UPDATE (Thu hồi tin nhắn)
DROP TRIGGER IF EXISTS on_message_updated ON public.messages;
CREATE TRIGGER on_message_updated
  AFTER UPDATE ON public.messages
  FOR EACH ROW EXECUTE PROCEDURE sync_last_message_on_change();

-- 4. Đăng ký Trigger cho sự kiện DELETE (Xóa tin nhắn)
DROP TRIGGER IF EXISTS on_message_deleted ON public.messages;
CREATE TRIGGER on_message_deleted
  AFTER DELETE ON public.messages
  FOR EACH ROW EXECUTE PROCEDURE sync_last_message_on_change();
