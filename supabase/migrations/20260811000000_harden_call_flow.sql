-- Harden one-to-one calling. All mutations go through validated RPCs.
ALTER TABLE public.calls
  ADD COLUMN IF NOT EXISTS expires_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS answered_device_id TEXT,
  ADD COLUMN IF NOT EXISTS media_connected_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS ended_by UUID REFERENCES public.profiles(id),
  ADD COLUMN IF NOT EXISTS end_reason TEXT;

UPDATE public.calls
SET expires_at = started_at + INTERVAL '60 seconds'
WHERE expires_at IS NULL;

ALTER TABLE public.calls
  ALTER COLUMN expires_at SET DEFAULT (NOW() + INTERVAL '60 seconds');

CREATE OR REPLACE FUNCTION public.start_call(
  p_conversation_id UUID,
  p_callee_id UUID,
  p_type call_type DEFAULT 'voice'
)
RETURNS public.calls
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller UUID := auth.uid();
  v_conversation public.conversations;
  v_call public.calls;
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'unauthenticated' USING ERRCODE = '28000';
  END IF;
  IF p_callee_id = v_caller THEN
    RAISE EXCEPTION 'self_call_not_allowed' USING ERRCODE = '22023';
  END IF;

  SELECT * INTO v_conversation
  FROM public.conversations
  WHERE id = p_conversation_id;

  IF NOT FOUND OR v_conversation.type <> 'direct' OR NOT (
    (v_conversation.participant_1 = v_caller AND v_conversation.participant_2 = p_callee_id) OR
    (v_conversation.participant_2 = v_caller AND v_conversation.participant_1 = p_callee_id)
  ) THEN
    RAISE EXCEPTION 'invalid_call_participants' USING ERRCODE = '42501';
  END IF;

  -- Serialize competing calls between the same two users.
  PERFORM pg_advisory_xact_lock(
    hashtextextended(LEAST(v_caller::TEXT, p_callee_id::TEXT) || ':' ||
                     GREATEST(v_caller::TEXT, p_callee_id::TEXT), 0)
  );

  IF EXISTS (
    SELECT 1 FROM public.calls
    WHERE (status = 'accepted' OR (status = 'ringing' AND expires_at > NOW()))
      AND (caller_id IN (v_caller, p_callee_id) OR callee_id IN (v_caller, p_callee_id))
  ) THEN
    RAISE EXCEPTION 'participant_busy' USING ERRCODE = 'P0001';
  END IF;

  INSERT INTO public.calls (
    conversation_id, caller_id, callee_id, type, status, room_name, expires_at
  ) VALUES (
    p_conversation_id, v_caller, p_callee_id, p_type, 'ringing',
    gen_random_uuid()::TEXT, NOW() + INTERVAL '60 seconds'
  ) RETURNING * INTO v_call;

  RETURN v_call;
END;
$$;

CREATE OR REPLACE FUNCTION public.transition_call(
  p_call_id UUID,
  p_new_status call_status,
  p_device_id TEXT DEFAULT NULL,
  p_reason TEXT DEFAULT NULL
)
RETURNS public.calls
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user UUID := auth.uid();
  v_call public.calls;
BEGIN
  IF v_user IS NULL THEN
    RAISE EXCEPTION 'unauthenticated' USING ERRCODE = '28000';
  END IF;
  IF p_device_id IS NOT NULL AND p_device_id !~ '^[A-Za-z0-9_-]{8,128}$' THEN
    RAISE EXCEPTION 'invalid_device_id' USING ERRCODE = '22023';
  END IF;

  SELECT * INTO v_call FROM public.calls WHERE id = p_call_id FOR UPDATE;
  IF NOT FOUND OR v_user NOT IN (v_call.caller_id, v_call.callee_id) THEN
    RAISE EXCEPTION 'call_not_found' USING ERRCODE = '42501';
  END IF;

  IF v_call.status = p_new_status THEN
    RETURN v_call; -- Idempotent retry.
  END IF;

  IF p_new_status = 'accepted' THEN
    IF v_user <> v_call.callee_id OR v_call.status <> 'ringing' OR v_call.expires_at <= NOW() THEN
      RAISE EXCEPTION 'call_cannot_be_accepted' USING ERRCODE = 'P0001';
    END IF;
    IF p_device_id IS NULL THEN
      RAISE EXCEPTION 'device_id_required' USING ERRCODE = '22023';
    END IF;
    UPDATE public.calls SET
      status = 'accepted', connected_at = NOW(), answered_device_id = p_device_id
    WHERE id = p_call_id RETURNING * INTO v_call;
  ELSIF p_new_status = 'declined' THEN
    IF v_user <> v_call.callee_id OR v_call.status <> 'ringing' THEN
      RAISE EXCEPTION 'call_cannot_be_declined' USING ERRCODE = 'P0001';
    END IF;
    UPDATE public.calls SET status = 'declined', ended_at = NOW(), ended_by = v_user,
      end_reason = COALESCE(p_reason, 'declined')
    WHERE id = p_call_id RETURNING * INTO v_call;
  ELSIF p_new_status = 'cancelled' THEN
    IF v_user <> v_call.caller_id OR v_call.status <> 'ringing' THEN
      RAISE EXCEPTION 'call_cannot_be_cancelled' USING ERRCODE = 'P0001';
    END IF;
    UPDATE public.calls SET status = 'cancelled', ended_at = NOW(), ended_by = v_user,
      end_reason = COALESCE(p_reason, 'cancelled')
    WHERE id = p_call_id RETURNING * INTO v_call;
  ELSIF p_new_status = 'missed' THEN
    IF v_call.status <> 'ringing' OR v_call.expires_at > NOW() THEN
      RAISE EXCEPTION 'call_cannot_be_missed' USING ERRCODE = 'P0001';
    END IF;
    UPDATE public.calls SET status = 'missed', ended_at = NOW(),
      end_reason = COALESCE(p_reason, 'timeout')
    WHERE id = p_call_id RETURNING * INTO v_call;
  ELSIF p_new_status = 'ended' THEN
    IF v_call.status <> 'accepted' THEN
      RAISE EXCEPTION 'call_cannot_be_ended' USING ERRCODE = 'P0001';
    END IF;
    UPDATE public.calls SET status = 'ended', ended_at = NOW(), ended_by = v_user,
      end_reason = COALESCE(p_reason, 'hangup'),
      duration_sec = GREATEST(0, EXTRACT(EPOCH FROM (NOW() - COALESCE(media_connected_at, connected_at)))::INT)
    WHERE id = p_call_id RETURNING * INTO v_call;
  ELSE
    RAISE EXCEPTION 'unsupported_call_transition' USING ERRCODE = '22023';
  END IF;

  RETURN v_call;
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_call_connected(p_call_id UUID)
RETURNS public.calls
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user UUID := auth.uid();
  v_call public.calls;
BEGIN
  UPDATE public.calls
  SET media_connected_at = COALESCE(media_connected_at, NOW())
  WHERE id = p_call_id
    AND status = 'accepted'
    AND v_user IN (caller_id, callee_id)
  RETURNING * INTO v_call;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'call_not_connectable' USING ERRCODE = 'P0001';
  END IF;
  RETURN v_call;
END;
$$;

-- Clients may read calls but cannot mutate them without the validated RPCs.
REVOKE INSERT, UPDATE ON public.calls FROM authenticated;
GRANT EXECUTE ON FUNCTION public.start_call(UUID, UUID, call_type) TO authenticated;
GRANT EXECUTE ON FUNCTION public.transition_call(UUID, call_status, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_call_connected(UUID) TO authenticated;

CREATE INDEX IF NOT EXISTS calls_active_participants_idx
  ON public.calls (caller_id, callee_id, status, expires_at DESC);
