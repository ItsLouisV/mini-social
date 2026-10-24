-- Let every current group member view an enabled invite link. Only the owner
-- may enable or disable it (enforced by set_group_invite_link_enabled).
CREATE OR REPLACE FUNCTION public.get_group_invite_link(p_conversation_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_is_member BOOLEAN;
  v_is_owner BOOLEAN;
  v_enabled BOOLEAN := FALSE;
  v_code TEXT;
BEGIN
  SELECT
    EXISTS (
      SELECT 1
      FROM public.conversation_members cm
      JOIN public.conversations c ON c.id = cm.conversation_id
      WHERE cm.conversation_id = p_conversation_id
        AND cm.user_id = v_user_id
        AND c.type = 'group'
    ),
    EXISTS (
      SELECT 1
      FROM public.conversation_members cm
      JOIN public.conversations c ON c.id = cm.conversation_id
      WHERE cm.conversation_id = p_conversation_id
        AND cm.user_id = v_user_id
        AND cm.role = 'owner'
        AND c.type = 'group'
    )
  INTO v_is_member, v_is_owner;

  IF NOT v_is_member THEN
    RAISE EXCEPTION 'Only group members can view its invite link';
  END IF;

  SELECT gil.is_enabled, gil.invite_code
    INTO v_enabled, v_code
  FROM public.group_invite_links gil
  WHERE gil.conversation_id = p_conversation_id;

  RETURN jsonb_build_object(
    'is_enabled', COALESCE(v_enabled, FALSE),
    'invite_code', CASE WHEN COALESCE(v_enabled, FALSE) THEN v_code ELSE NULL END,
    'is_owner', v_is_owner
  );
END;
$$;

REVOKE ALL ON FUNCTION public.get_group_invite_link(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_group_invite_link(UUID) TO authenticated;
