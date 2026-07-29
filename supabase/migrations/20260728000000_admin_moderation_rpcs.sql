-- =====================================================
-- Migration: Admin Moderation RPCs
-- Sprint 10 — Admin Dashboard
-- =====================================================

-- =====================================================
-- 1. DASHBOARD STATS
-- =====================================================
CREATE OR REPLACE FUNCTION get_moderation_dashboard_stats()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
AS $$
DECLARE
  v_result jsonb;
BEGIN
  SELECT jsonb_build_object(
    'reports_pending',   (SELECT COUNT(*) FROM moderation_reports WHERE status = 'pending'),
    'reports_resolved',  (SELECT COUNT(*) FROM moderation_reports WHERE status = 'resolved'),
    'reports_dismissed', (SELECT COUNT(*) FROM moderation_reports WHERE status = 'dismissed'),
    'reports_today',     (SELECT COUNT(*) FROM moderation_reports WHERE created_at >= NOW() - INTERVAL '24 hours'),
    'cases_pending',     (SELECT COUNT(*) FROM moderation_cases WHERE status = 'pending'),
    'cases_review',      (SELECT COUNT(*) FROM moderation_cases WHERE status = 'review'),
    'cases_blocked',     (SELECT COUNT(*) FROM moderation_cases WHERE status = 'blocked'),
    'high_urgency',      (SELECT COUNT(*) FROM moderation_reports WHERE urgency_level IN ('high', 'critical') AND status = 'pending'),
    'reports_7d', (
      SELECT jsonb_agg(day_data ORDER BY day)
      FROM (
        SELECT
          DATE(created_at) AS day,
          COUNT(*) AS count
        FROM moderation_reports
        WHERE created_at >= NOW() - INTERVAL '7 days'
        GROUP BY DATE(created_at)
      ) day_data
    )
  ) INTO v_result;

  RETURN v_result;
END;
$$;

-- RLS: Chỉ moderator mới được gọi
REVOKE ALL ON FUNCTION get_moderation_dashboard_stats() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION get_moderation_dashboard_stats() TO authenticated;


-- =====================================================
-- 2. REPORT QUEUE (full JOIN)
-- =====================================================
CREATE OR REPLACE FUNCTION get_admin_report_queue(
  p_status  text    DEFAULT 'pending',
  p_limit   int     DEFAULT 20,
  p_offset  int     DEFAULT 0
)
RETURNS TABLE (
  id                  uuid,
  reporter_id         uuid,
  reporter_username   text,
  reporter_avatar     text,
  reported_user_id    uuid,
  reported_username   text,
  reported_avatar     text,
  content_id          uuid,
  content_type        text,
  content_caption     text,
  category_name       text,
  reason_level1       text,
  reason_level2       text,
  reason_level3       text,
  description         text,
  urgency_level       text,
  status              text,
  resolved_at         timestamptz,
  admin_note          text,
  created_at          timestamptz,
  total_count         bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
AS $$
BEGIN
  RETURN QUERY
  SELECT
    r.id,
    r.reporter_id,
    rp.username         AS reporter_username,
    rp.avatar_url       AS reporter_avatar,
    r.reported_user_id,
    dp.username         AS reported_username,
    dp.avatar_url       AS reported_avatar,
    r.content_id,
    r.content_type,
    CASE r.content_type
      WHEN 'post'    THEN (SELECT caption FROM posts    WHERE id = r.content_id)
      WHEN 'comment' THEN (SELECT content FROM comments WHERE id = r.content_id)
      ELSE NULL
    END                 AS content_caption,
    mc.name             AS category_name,
    r.reason_level1,
    r.reason_level2,
    r.reason_level3,
    r.description,
    r.urgency_level,
    r.status,
    r.resolved_at,
    r.admin_note,
    r.created_at,
    COUNT(*) OVER ()    AS total_count
  FROM moderation_reports r
  LEFT JOIN profiles rp ON rp.id = r.reporter_id
  LEFT JOIN profiles dp ON dp.id = r.reported_user_id
  LEFT JOIN moderation_categories mc ON mc.id = r.category_id
  WHERE (p_status = 'all' OR r.status = p_status)
  ORDER BY
    CASE r.urgency_level
      WHEN 'critical' THEN 1
      WHEN 'high'     THEN 2
      WHEN 'medium'   THEN 3
      ELSE 4
    END,
    r.created_at DESC
  LIMIT  p_limit
  OFFSET p_offset;
END;
$$;

REVOKE ALL ON FUNCTION get_admin_report_queue(text, int, int) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION get_admin_report_queue(text, int, int) TO authenticated;


-- =====================================================
-- 3. RESOLVE REPORT
-- =====================================================
CREATE OR REPLACE FUNCTION admin_resolve_report(
  p_report_id   uuid,
  p_action_name text,   -- 'dismiss' | 'warn' | 'remove' | 'ban' | 'restrict' | ...
  p_note        text    DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_action_id   uuid;
  v_report      moderation_reports%ROWTYPE;
  v_case_id     uuid;
  v_new_status  text;
BEGIN
  -- 1. Kiểm tra quyền
  IF NOT is_moderator() THEN
    RAISE EXCEPTION 'Unauthorized: moderator role required';
  END IF;

  -- 2. Lấy report
  SELECT * INTO v_report FROM moderation_reports WHERE id = p_report_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Report not found: %', p_report_id;
  END IF;

  -- 3. Lấy action_id từ tên
  SELECT id INTO v_action_id
  FROM moderation_action_types
  WHERE name = p_action_name;

  -- 4. Xác định trạng thái mới
  v_new_status := CASE p_action_name
    WHEN 'allow'  THEN 'dismissed'
    WHEN 'flag'   THEN 'resolved'
    ELSE               'resolved'
  END;

  -- 5. Cập nhật moderation_reports
  UPDATE moderation_reports
  SET
    status      = v_new_status,
    resolved_at = NOW(),
    resolved_by = auth.uid(),
    admin_note  = p_note
  WHERE id = p_report_id;

  -- 6. Tạo / lấy moderation_case liên quan
  SELECT id INTO v_case_id
  FROM moderation_cases
  WHERE content_id = v_report.content_id
    AND content_type = v_report.content_type
  LIMIT 1;

  IF v_case_id IS NULL THEN
    INSERT INTO moderation_cases (content_id, content_type, user_id, status, final_action_id)
    VALUES (v_report.content_id, v_report.content_type, v_report.reported_user_id, 'pending', v_action_id)
    RETURNING id INTO v_case_id;
  END IF;

  -- 7. Ghi log vào moderation_actions
  INSERT INTO moderation_actions (case_id, admin_id, action_id, note)
  VALUES (v_case_id, auth.uid(), v_action_id, p_note);

  -- 8. Thực thi hành động thực tế
  IF p_action_name = 'remove' AND v_report.content_type = 'post' THEN
    UPDATE posts SET deleted_at = NOW() WHERE id = v_report.content_id;
  END IF;

  RETURN jsonb_build_object(
    'success',    true,
    'report_id',  p_report_id,
    'new_status', v_new_status,
    'case_id',    v_case_id
  );
END;
$$;

REVOKE ALL ON FUNCTION admin_resolve_report(uuid, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION admin_resolve_report(uuid, text, text) TO authenticated;


-- =====================================================
-- 4. GET CASES (with AI results)
-- =====================================================
CREATE OR REPLACE FUNCTION get_admin_cases(
  p_status text DEFAULT 'pending',
  p_limit  int  DEFAULT 20,
  p_offset int  DEFAULT 0
)
RETURNS TABLE (
  id              uuid,
  content_id      uuid,
  content_type    text,
  content_caption text,
  user_id         uuid,
  username        text,
  avatar_url      text,
  risk_score      int,
  status          text,
  created_at      timestamptz,
  -- AI scores
  toxicity_score  float,
  hate_score      float,
  scam_score      float,
  sexual_score    float,
  violence_score  float,
  total_count     bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
AS $$
BEGIN
  RETURN QUERY
  SELECT
    c.id,
    c.content_id,
    c.content_type,
    CASE c.content_type
      WHEN 'post'    THEN (SELECT caption FROM posts    WHERE id = c.content_id)
      WHEN 'comment' THEN (SELECT content FROM comments WHERE id = c.content_id)
      ELSE NULL
    END              AS content_caption,
    c.user_id,
    p.username,
    p.avatar_url,
    c.risk_score,
    c.status,
    c.created_at,
    mr.toxicity_score,
    mr.hate_score,
    mr.scam_score,
    mr.sexual_score,
    mr.violence_score,
    COUNT(*) OVER () AS total_count
  FROM moderation_cases c
  LEFT JOIN profiles p ON p.id = c.user_id
  LEFT JOIN LATERAL (
    SELECT toxicity_score, hate_score, scam_score, sexual_score, violence_score
    FROM moderation_results
    WHERE case_id = c.id
    ORDER BY created_at DESC
    LIMIT 1
  ) mr ON TRUE
  WHERE (p_status = 'all' OR c.status = p_status)
  ORDER BY c.risk_score DESC, c.created_at DESC
  LIMIT  p_limit
  OFFSET p_offset;
END;
$$;

REVOKE ALL ON FUNCTION get_admin_cases(text, int, int) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION get_admin_cases(text, int, int) TO authenticated;
