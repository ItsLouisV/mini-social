ALTER TABLE public.group_invite_links
  ADD COLUMN IF NOT EXISTS approval_required BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS join_rules TEXT NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS join_question TEXT NOT NULL DEFAULT '';

CREATE TABLE IF NOT EXISTS public.group_join_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id UUID NOT NULL REFERENCES public.conversations(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  answer TEXT NOT NULL DEFAULT '',
  accepted_rules BOOLEAN NOT NULL DEFAULT FALSE,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  reviewed_at TIMESTAMPTZ,
  reviewed_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  UNIQUE (conversation_id, user_id)
);

ALTER TABLE public.group_join_requests ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.group_join_requests FROM anon, authenticated;

CREATE OR REPLACE FUNCTION public.get_group_invite_link(p_conversation_id UUID)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_is_member BOOLEAN;
  v_is_owner BOOLEAN;
  v_enabled BOOLEAN := FALSE;
  v_code TEXT;
  v_approval BOOLEAN := FALSE;
  v_rules TEXT := '';
  v_question TEXT := '';
BEGIN
  SELECT EXISTS (
    SELECT 1 FROM public.conversation_members cm JOIN public.conversations c
      ON c.id = cm.conversation_id
    WHERE cm.conversation_id = p_conversation_id AND cm.user_id = v_user_id AND c.type = 'group'
  ), EXISTS (
    SELECT 1 FROM public.conversation_members cm JOIN public.conversations c
      ON c.id = cm.conversation_id
    WHERE cm.conversation_id = p_conversation_id AND cm.user_id = v_user_id
      AND cm.role = 'owner' AND c.type = 'group'
  ) INTO v_is_member, v_is_owner;
  IF NOT v_is_member THEN RAISE EXCEPTION 'Only group members can view its invite link'; END IF;
  SELECT gil.is_enabled, gil.invite_code, gil.approval_required,
         gil.join_rules, gil.join_question
    INTO v_enabled, v_code, v_approval, v_rules, v_question
  FROM public.group_invite_links gil WHERE gil.conversation_id = p_conversation_id;
  RETURN jsonb_build_object(
    'is_enabled', COALESCE(v_enabled, FALSE),
    'invite_code', CASE WHEN COALESCE(v_enabled, FALSE) THEN v_code ELSE NULL END,
    'is_owner', v_is_owner,
    'approval_required', COALESCE(v_approval, FALSE),
    'join_rules', COALESCE(v_rules, ''),
    'join_question', COALESCE(v_question, '')
  );
END; $$;

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
    join_question = LEFT(COALESCE(p_join_question, ''), 500),
    updated_at = NOW()
  WHERE conversation_id = p_conversation_id;
  RETURN public.get_group_invite_link(p_conversation_id);
END; $$;

CREATE OR REPLACE FUNCTION public.join_group_by_invite(p_invite_code TEXT)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp AS $$
DECLARE
  v_user_id UUID := auth.uid(); v_conversation_id UUID; v_group_name TEXT;
  v_already_member BOOLEAN; v_approval BOOLEAN; v_rules TEXT; v_question TEXT;
BEGIN
  IF v_user_id IS NULL THEN RAISE EXCEPTION 'Sign in to join this group'; END IF;
  SELECT c.id, c.name, gil.approval_required, gil.join_rules, gil.join_question
    INTO v_conversation_id, v_group_name, v_approval, v_rules, v_question
  FROM public.group_invite_links gil JOIN public.conversations c ON c.id = gil.conversation_id
  WHERE gil.invite_code = LOWER(TRIM(p_invite_code)) AND gil.is_enabled = TRUE AND c.type = 'group'
  FOR UPDATE OF gil;
  IF v_conversation_id IS NULL THEN RAISE EXCEPTION 'This group invite link is invalid or disabled'; END IF;
  IF EXISTS (SELECT 1 FROM public.group_bans gb WHERE gb.conversation_id = v_conversation_id
      AND gb.user_id = v_user_id AND gb.is_active = TRUE) THEN
    RAISE EXCEPTION 'You are not allowed to join this group';
  END IF;
  SELECT EXISTS (SELECT 1 FROM public.conversation_members cm
      WHERE cm.conversation_id = v_conversation_id AND cm.user_id = v_user_id)
    INTO v_already_member;
  IF v_already_member THEN
    RETURN jsonb_build_object('conversation_id', v_conversation_id, 'group_name', v_group_name,
      'already_member', TRUE, 'requires_request', FALSE);
  END IF;
  IF COALESCE(v_approval, FALSE) OR NULLIF(TRIM(COALESCE(v_rules, '')), '') IS NOT NULL
      OR NULLIF(TRIM(COALESCE(v_question, '')), '') IS NOT NULL THEN
    RETURN jsonb_build_object('conversation_id', v_conversation_id, 'group_name', v_group_name,
      'already_member', FALSE, 'requires_request', TRUE, 'approval_required', COALESCE(v_approval, FALSE),
      'join_rules', COALESCE(v_rules, ''), 'join_question', COALESCE(v_question, ''));
  END IF;
  INSERT INTO public.conversation_members (conversation_id, user_id, role)
    VALUES (v_conversation_id, v_user_id, 'member');
  RETURN jsonb_build_object('conversation_id', v_conversation_id, 'group_name', v_group_name,
    'already_member', FALSE, 'requires_request', FALSE);
END; $$;

CREATE OR REPLACE FUNCTION public.submit_group_join_request(
  p_invite_code TEXT, p_answer TEXT, p_accepted_rules BOOLEAN
) RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp AS $$
DECLARE
  v_user_id UUID := auth.uid(); v_conversation_id UUID; v_group_name TEXT;
  v_rules TEXT; v_question TEXT; v_approval BOOLEAN; v_request_id UUID; v_status TEXT;
BEGIN
  IF v_user_id IS NULL THEN RAISE EXCEPTION 'Sign in to request joining'; END IF;
  SELECT c.id, c.name, gil.join_rules, gil.join_question, gil.approval_required
    INTO v_conversation_id, v_group_name, v_rules, v_question, v_approval
  FROM public.group_invite_links gil JOIN public.conversations c ON c.id = gil.conversation_id
  WHERE gil.invite_code = LOWER(TRIM(p_invite_code)) AND gil.is_enabled AND c.type = 'group';
  IF v_conversation_id IS NULL THEN RAISE EXCEPTION 'This group invite link is invalid or disabled'; END IF;
  IF EXISTS (SELECT 1 FROM public.group_bans gb WHERE gb.conversation_id = v_conversation_id
      AND gb.user_id = v_user_id AND gb.is_active) THEN RAISE EXCEPTION 'You are not allowed to join this group'; END IF;
  IF EXISTS (SELECT 1 FROM public.conversation_members cm WHERE cm.conversation_id = v_conversation_id AND cm.user_id = v_user_id)
    THEN RAISE EXCEPTION 'You are already a member of this group'; END IF;
  IF NULLIF(TRIM(COALESCE(v_rules, '')), '') IS NOT NULL AND NOT COALESCE(p_accepted_rules, FALSE)
    THEN RAISE EXCEPTION 'You must accept the group rules'; END IF;
  IF NULLIF(TRIM(COALESCE(v_question, '')), '') IS NOT NULL AND NULLIF(TRIM(COALESCE(p_answer, '')), '') IS NULL
    THEN RAISE EXCEPTION 'Please answer the group question'; END IF;
  INSERT INTO public.group_join_requests (conversation_id, user_id, answer, accepted_rules, status)
  VALUES (v_conversation_id, v_user_id, LEFT(COALESCE(p_answer, ''), 2000), COALESCE(p_accepted_rules, FALSE),
    CASE WHEN COALESCE(v_approval, FALSE)
      OR NULLIF(TRIM(COALESCE(v_rules, '')), '') IS NOT NULL
      OR NULLIF(TRIM(COALESCE(v_question, '')), '') IS NOT NULL
      THEN 'pending' ELSE 'approved' END)
  ON CONFLICT (conversation_id, user_id) DO UPDATE SET answer = EXCLUDED.answer,
    accepted_rules = EXCLUDED.accepted_rules, status = EXCLUDED.status, created_at = NOW(), reviewed_at = NULL, reviewed_by = NULL
  RETURNING id, status INTO v_request_id, v_status;
  IF v_status = 'approved' THEN
    INSERT INTO public.conversation_members (conversation_id, user_id, role)
      VALUES (v_conversation_id, v_user_id, 'member') ON CONFLICT DO NOTHING;
  END IF;
  RETURN jsonb_build_object('request_id', v_request_id, 'conversation_id', v_conversation_id,
    'group_name', v_group_name, 'status', v_status);
END; $$;

CREATE OR REPLACE FUNCTION public.list_group_join_requests(p_conversation_id UUID)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp AS $$
DECLARE v_actor_role TEXT; v_result JSONB;
BEGIN
  SELECT cm.role INTO v_actor_role FROM public.conversation_members cm
    WHERE cm.conversation_id = p_conversation_id AND cm.user_id = auth.uid();
  IF COALESCE(v_actor_role, '') NOT IN ('owner', 'admin') THEN RAISE EXCEPTION 'Only group admins can review join requests'; END IF;
  SELECT COALESCE(jsonb_agg(jsonb_build_object('id', r.id, 'user_id', r.user_id,
      'answer', r.answer, 'accepted_rules', r.accepted_rules, 'created_at', r.created_at,
      'display_name', COALESCE(p.full_name, p.username), 'avatar_url', p.avatar_url) ORDER BY r.created_at), '[]'::jsonb)
    INTO v_result FROM public.group_join_requests r LEFT JOIN public.profiles p ON p.id = r.user_id
    WHERE r.conversation_id = p_conversation_id AND r.status = 'pending';
  RETURN v_result;
END; $$;

CREATE OR REPLACE FUNCTION public.review_group_join_request(p_request_id UUID, p_approve BOOLEAN)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp AS $$
DECLARE v_conversation_id UUID; v_user_id UUID; v_actor_role TEXT;
BEGIN
  SELECT conversation_id, user_id INTO v_conversation_id, v_user_id FROM public.group_join_requests
    WHERE id = p_request_id AND status = 'pending' FOR UPDATE;
  IF v_conversation_id IS NULL THEN RAISE EXCEPTION 'Join request not found'; END IF;
  SELECT role INTO v_actor_role FROM public.conversation_members
    WHERE conversation_id = v_conversation_id AND user_id = auth.uid();
  IF COALESCE(v_actor_role, '') NOT IN ('owner', 'admin') THEN RAISE EXCEPTION 'Only group admins can review join requests'; END IF;
  UPDATE public.group_join_requests SET status = CASE WHEN p_approve THEN 'approved' ELSE 'rejected' END,
    reviewed_at = NOW(), reviewed_by = auth.uid() WHERE id = p_request_id;
  IF p_approve THEN
    INSERT INTO public.conversation_members (conversation_id, user_id, role)
      VALUES (v_conversation_id, v_user_id, 'member') ON CONFLICT DO NOTHING;
  END IF;
  RETURN jsonb_build_object('conversation_id', v_conversation_id, 'user_id', v_user_id, 'approved', p_approve);
END; $$;

REVOKE ALL ON FUNCTION public.get_group_invite_link(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.configure_group_invite_requirements(UUID, BOOLEAN, TEXT, TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.join_group_by_invite(TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.submit_group_join_request(TEXT, TEXT, BOOLEAN) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.list_group_join_requests(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.review_group_join_request(UUID, BOOLEAN) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_group_invite_link(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.configure_group_invite_requirements(UUID, BOOLEAN, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.join_group_by_invite(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.submit_group_join_request(TEXT, TEXT, BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_group_join_requests(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.review_group_join_request(UUID, BOOLEAN) TO authenticated;
