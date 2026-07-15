-- ============================================================================
-- MIGRATION: AUTH DEVICE SESSION MANAGEMENT
-- ============================================================================

-- Hàm lấy danh sách các phiên đăng nhập (active sessions) của user hiện tại
CREATE OR REPLACE FUNCTION public.get_active_sessions()
RETURNS TABLE (
  id UUID,
  created_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ,
  user_agent TEXT,
  ip TEXT
) LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  RETURN QUERY
  SELECT s.id, s.created_at, s.updated_at, s.user_agent, s.ip::text
  FROM auth.sessions s
  WHERE s.user_id = auth.uid()
  ORDER BY s.updated_at DESC;
END;
$$;

-- Phân quyền thực thi: chỉ cho phép user đã đăng nhập gọi hàm này
REVOKE EXECUTE ON FUNCTION public.get_active_sessions() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_active_sessions() TO authenticated;

-- Hàm thu hồi / đăng xuất từ xa phiên đăng nhập dựa trên session_id
CREATE OR REPLACE FUNCTION public.revoke_session(session_id UUID)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  DELETE FROM auth.sessions
  WHERE id = session_id AND user_id = auth.uid();
END;
$$;

-- Phân quyền thực thi: chỉ cho phép user đã đăng nhập gọi hàm này
REVOKE EXECUTE ON FUNCTION public.revoke_session(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.revoke_session(UUID) TO authenticated;
