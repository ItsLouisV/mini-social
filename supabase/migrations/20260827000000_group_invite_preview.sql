-- 1. Nâng giới hạn ký tự join_question lên 2000 trong configure_group_invite_requirements
-- để hỗ trợ lưu tối đa 3 câu hỏi (mỗi câu tối đa 500 ký tự) cách nhau bằng delimiter '\n---\n'.

CREATE OR REPLACE FUNCTION public.configure_group_invite_requirements(
  p_conversation_id UUID, p_approval_required BOOLEAN, p_join_rules TEXT, p_join_question TEXT
) RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.conversation_members cm JOIN public.conversations c
      ON c.id = cm.conversation_id
    WHERE cm.conversation_id = p_conversation_id AND cm.user_id = auth.uid()
      AND cm.role = 'owner' AND c.type = 'group'
  ) THEN RAISE EXCEPTION 'Only the group owner can configure join requirements'; END IF;

  INSERT INTO public.group_invite_links (conversation_id, invite_code, is_enabled)
  VALUES (p_conversation_id, REPLACE(gen_random_uuid()::TEXT, '-', ''), FALSE)
  ON CONFLICT (conversation_id) DO NOTHING;

  UPDATE public.group_invite_links SET
    approval_required = COALESCE(p_approval_required, FALSE),
    join_rules = LEFT(COALESCE(p_join_rules, ''), 4000),
    join_question = LEFT(COALESCE(p_join_question, ''), 2000),
    updated_at = NOW()
  WHERE conversation_id = p_conversation_id;

  RETURN public.get_group_invite_link(p_conversation_id);
END; $$;

REVOKE ALL ON FUNCTION public.configure_group_invite_requirements(UUID, BOOLEAN, TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.configure_group_invite_requirements(UUID, BOOLEAN, TEXT, TEXT) TO authenticated;

-- 2. Function lấy thông tin preview của link mời nhóm (thành viên, bạn bè, quy định, câu hỏi)
CREATE OR REPLACE FUNCTION public.get_group_invite_preview(p_invite_code TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_conversation_id UUID;
  v_result JSONB;
BEGIN
  IF v_user_id IS NULL THEN RAISE EXCEPTION 'Sign in to view this group'; END IF;

  SELECT c.id INTO v_conversation_id
  FROM public.group_invite_links gil
  JOIN public.conversations c ON c.id = gil.conversation_id
  WHERE gil.invite_code = LOWER(TRIM(p_invite_code))
    AND gil.is_enabled = TRUE AND c.type = 'group';
  IF v_conversation_id IS NULL THEN RAISE EXCEPTION 'This group invite link is invalid or disabled'; END IF;
  IF EXISTS (SELECT 1 FROM public.group_bans gb WHERE gb.conversation_id = v_conversation_id
      AND gb.user_id = v_user_id AND gb.is_active = TRUE) THEN
    RAISE EXCEPTION 'You are not allowed to join this group';
  END IF;

  SELECT jsonb_build_object(
    'conversation_id', c.id,
    'group_name', COALESCE(c.name, 'Nhóm trò chuyện'),
    'avatar_url', c.avatar_url,
    'member_count', (SELECT COUNT(*) FROM public.conversation_members cm
      WHERE cm.conversation_id = c.id AND cm.left_at IS NULL),
    'created_at', c.created_at,
    'creator_name', COALESCE(creator.full_name, creator.username, 'Thành viên'),
    'creator_avatar_url', creator.avatar_url,
    'friends_count', (
      SELECT COUNT(DISTINCT cm.user_id)
      FROM public.conversation_members cm
      JOIN public.friend_requests fr ON fr.status = 'accepted'
        AND ((fr.sender_id = v_user_id AND fr.receiver_id = cm.user_id)
          OR (fr.receiver_id = v_user_id AND fr.sender_id = cm.user_id))
      WHERE cm.conversation_id = c.id AND cm.left_at IS NULL AND cm.user_id <> v_user_id
    ),
    'join_rules', COALESCE(gil.join_rules, ''),
    'join_question', COALESCE(gil.join_question, ''),
    'approval_required', COALESCE(gil.approval_required, FALSE),
    'already_member', EXISTS (SELECT 1 FROM public.conversation_members cm
      WHERE cm.conversation_id = c.id AND cm.user_id = v_user_id AND cm.left_at IS NULL),
    'request_pending', EXISTS (SELECT 1 FROM public.group_join_requests r
      WHERE r.conversation_id = c.id AND r.user_id = v_user_id AND r.status = 'pending'),
    'friends', COALESCE((
      SELECT jsonb_agg(jsonb_build_object('id', f.id, 'name', COALESCE(f.full_name, f.username),
        'avatar_url', f.avatar_url) ORDER BY f.username)
      FROM (
        SELECT DISTINCT p.id, p.username, p.full_name, p.avatar_url
        FROM public.conversation_members cm
        JOIN public.profiles p ON p.id = cm.user_id
        JOIN public.friend_requests fr ON fr.status = 'accepted'
          AND ((fr.sender_id = v_user_id AND fr.receiver_id = cm.user_id)
            OR (fr.receiver_id = v_user_id AND fr.sender_id = cm.user_id))
        WHERE cm.conversation_id = c.id AND cm.left_at IS NULL AND cm.user_id <> v_user_id
        LIMIT 8
      ) f
    ), '[]'::jsonb)
  ) INTO v_result
  FROM public.conversations c
  JOIN public.group_invite_links gil ON gil.conversation_id = c.id
  LEFT JOIN public.profiles creator ON creator.id = c.created_by
  WHERE c.id = v_conversation_id;

  RETURN v_result;
END;
$$;

REVOKE ALL ON FUNCTION public.get_group_invite_preview(TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_group_invite_preview(TEXT) TO authenticated;
