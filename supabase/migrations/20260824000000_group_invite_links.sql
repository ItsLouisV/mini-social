-- Private invite links for group conversations. The client cannot read or
-- mutate invite rows directly; authenticated RPCs enforce owner-only control.
CREATE TABLE IF NOT EXISTS public.group_invite_links (
  conversation_id UUID PRIMARY KEY
    REFERENCES public.conversations(id) ON DELETE CASCADE,
  invite_code TEXT NOT NULL UNIQUE,
  is_enabled BOOLEAN NOT NULL DEFAULT FALSE,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.group_invite_links ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.group_invite_links FROM anon, authenticated;

CREATE OR REPLACE FUNCTION public.get_group_invite_link(p_conversation_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_is_owner BOOLEAN;
  v_enabled BOOLEAN := FALSE;
  v_code TEXT;
BEGIN
  SELECT EXISTS (
    SELECT 1
    FROM public.conversation_members cm
    JOIN public.conversations c ON c.id = cm.conversation_id
    WHERE cm.conversation_id = p_conversation_id
      AND cm.user_id = v_user_id
      AND cm.role = 'owner'
      AND c.type = 'group'
  ) INTO v_is_owner;

  IF NOT v_is_owner THEN
    RAISE EXCEPTION 'Only the group owner can manage its invite link';
  END IF;

  SELECT gil.is_enabled, gil.invite_code
    INTO v_enabled, v_code
  FROM public.group_invite_links gil
  WHERE gil.conversation_id = p_conversation_id;

  RETURN jsonb_build_object(
    'is_enabled', COALESCE(v_enabled, FALSE),
    'invite_code', CASE WHEN COALESCE(v_enabled, FALSE) THEN v_code ELSE NULL END
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.set_group_invite_link_enabled(
  p_conversation_id UUID,
  p_enabled BOOLEAN
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user_id UUID := auth.uid();
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM public.conversation_members cm
    JOIN public.conversations c ON c.id = cm.conversation_id
    WHERE cm.conversation_id = p_conversation_id
      AND cm.user_id = v_user_id
      AND cm.role = 'owner'
      AND c.type = 'group'
  ) THEN
    RAISE EXCEPTION 'Only the group owner can manage its invite link';
  END IF;

  IF p_enabled THEN
    -- Rotate the code every time the link is enabled so a disabled link cannot
    -- be revived by someone holding a previously copied URL or QR image.
    INSERT INTO public.group_invite_links (
      conversation_id, invite_code, is_enabled, updated_at
    ) VALUES (
      p_conversation_id, REPLACE(gen_random_uuid()::TEXT, '-', ''), TRUE, NOW()
    )
    ON CONFLICT (conversation_id) DO UPDATE
      SET invite_code = EXCLUDED.invite_code,
          is_enabled = TRUE,
          updated_at = NOW();
  ELSE
    UPDATE public.group_invite_links
    SET is_enabled = FALSE, updated_at = NOW()
    WHERE conversation_id = p_conversation_id;
  END IF;

  RETURN public.get_group_invite_link(p_conversation_id);
END;
$$;

CREATE OR REPLACE FUNCTION public.join_group_by_invite(p_invite_code TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_conversation_id UUID;
  v_group_name TEXT;
  v_already_member BOOLEAN;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Sign in to join this group';
  END IF;

  SELECT c.id, c.name
    INTO v_conversation_id, v_group_name
  FROM public.group_invite_links gil
  JOIN public.conversations c ON c.id = gil.conversation_id
  WHERE gil.invite_code = LOWER(TRIM(p_invite_code))
    AND gil.is_enabled = TRUE
    AND c.type = 'group'
  FOR UPDATE OF gil;

  IF v_conversation_id IS NULL THEN
    RAISE EXCEPTION 'This group invite link is invalid or disabled';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.group_bans gb
    WHERE gb.conversation_id = v_conversation_id
      AND gb.user_id = v_user_id
      AND gb.is_active = TRUE
  ) THEN
    RAISE EXCEPTION 'You are not allowed to join this group';
  END IF;

  SELECT EXISTS (
    SELECT 1 FROM public.conversation_members cm
    WHERE cm.conversation_id = v_conversation_id AND cm.user_id = v_user_id
  ) INTO v_already_member;

  IF NOT v_already_member THEN
    INSERT INTO public.conversation_members (conversation_id, user_id, role)
    VALUES (v_conversation_id, v_user_id, 'member');
  END IF;

  RETURN jsonb_build_object(
    'conversation_id', v_conversation_id,
    'group_name', v_group_name,
    'already_member', v_already_member
  );
END;
$$;

REVOKE ALL ON FUNCTION public.get_group_invite_link(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.set_group_invite_link_enabled(UUID, BOOLEAN) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.join_group_by_invite(TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_group_invite_link(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.set_group_invite_link_enabled(UUID, BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION public.join_group_by_invite(TEXT) TO authenticated;
