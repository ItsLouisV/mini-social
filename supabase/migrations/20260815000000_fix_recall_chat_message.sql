-- Fix recall_chat_message after the messages schema moved from the legacy
-- media_url column to media_urls. PL/pgSQL validates the UPDATE at execution
-- time, so referencing media_url caused every recall to fail with 42703.

CREATE OR REPLACE FUNCTION public.recall_chat_message(p_message_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  target_message public.messages%ROWTYPE;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '28000';
  END IF;

  SELECT * INTO target_message
  FROM public.messages
  WHERE id = p_message_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Message not found' USING ERRCODE = 'P0002';
  END IF;

  IF target_message.sender_id <> auth.uid() THEN
    RAISE EXCEPTION 'Only the sender can recall this message'
      USING ERRCODE = '42501';
  END IF;

  IF target_message.message_type = 'recalled' THEN
    RETURN;
  END IF;

  UPDATE public.messages
  SET content = 'Tin nhắn đã thu hồi',
      message_type = 'recalled',
      media_urls = NULL
  WHERE id = p_message_id;
END;
$$;

REVOKE ALL ON FUNCTION public.recall_chat_message(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.recall_chat_message(UUID) TO authenticated;

