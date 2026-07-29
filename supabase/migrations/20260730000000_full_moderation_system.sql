-- =====================================================
-- Migration: Full Moderation System
-- Sprint 10+ — Enhanced Moderation Architecture
-- =====================================================

-- 1. Bổ sung cột cho bảng posts nếu chưa có
ALTER TABLE posts ADD COLUMN IF NOT EXISTS status text DEFAULT 'published';
ALTER TABLE posts ADD COLUMN IF NOT EXISTS report_count int DEFAULT 0;

-- 2. BẢNG USER_VIOLATIONS (Theo dõi Strike của người dùng)
CREATE TABLE IF NOT EXISTS user_violations (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    violation_type text NOT NULL,
    related_action_id uuid REFERENCES moderation_actions(id) ON DELETE SET NULL,
    strike_count_at_time int DEFAULT 1,
    is_active boolean DEFAULT true,
    created_at timestamptz DEFAULT now()
);

-- 3. BẢNG APPEALS (Đơn kháng cáo)
CREATE TABLE IF NOT EXISTS appeals (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    action_id uuid REFERENCES moderation_actions(id) ON DELETE CASCADE,
    user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    reason text NOT NULL,
    status text DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
    resolved_by uuid REFERENCES auth.users(id),
    resolved_at timestamptz,
    admin_note text,
    created_at timestamptz DEFAULT now()
);

-- 4. BẢNG MOD_AI_AGREEMENT_LOG (Đánh giá mức độ khớp giữa AI và Mod)
CREATE TABLE IF NOT EXISTS mod_ai_agreement_log (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    case_id uuid REFERENCES moderation_cases(id) ON DELETE CASCADE,
    ai_suggestion text,
    mod_decision text NOT NULL,
    agreed boolean NOT NULL,
    moderator_id uuid REFERENCES auth.users(id),
    created_at timestamptz DEFAULT now()
);

-- 5. FUNCTION & TRIGGER: Tự động đếm report_count & Tạm ẩn bài viết khi đạt ngưỡng (>= 5 reports)
CREATE OR REPLACE FUNCTION handle_report_aggregation()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_count int;
BEGIN
  IF NEW.content_type = 'post' THEN
    -- Đếm số report chưa xử lý cho post này
    SELECT COUNT(*) INTO v_count
    FROM moderation_reports
    WHERE content_id = NEW.content_id
      AND content_type = 'post'
      AND status = 'pending';

    -- Cập nhật report_count trên bảng posts
    UPDATE posts
    SET report_count = v_count
    WHERE id = NEW.content_id;

    -- Nếu số lượng báo cáo >= 5, chuyển trạng thái bài viết thành pending_review
    IF v_count >= 5 THEN
      UPDATE posts
      SET status = 'pending_review'
      WHERE id = NEW.content_id AND status = 'published';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_report_aggregation ON moderation_reports;
CREATE TRIGGER trg_report_aggregation
  AFTER INSERT ON moderation_reports
  FOR EACH ROW
  EXECUTE FUNCTION handle_report_aggregation();


-- 6. FUNCTION & TRIGGER: Tự động Ban người dùng khi dính từ 3 Strikes trở lên
CREATE OR REPLACE FUNCTION handle_strike_auto_ban()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_active_strikes int;
BEGIN
  -- Đếm tổng số Strike đang có hiệu lực của user
  SELECT COUNT(*) INTO v_active_strikes
  FROM user_violations
  WHERE user_id = NEW.user_id AND is_active = true;

  -- Nếu >= 3 Strike, cập nhật profiles/auth tài khoản bị khóa
  IF v_active_strikes >= 3 THEN
    -- Khóa tài khoản trong bảng profiles (nếu có cột is_banned)
    BEGIN
      ALTER TABLE profiles ADD COLUMN IF NOT EXISTS is_banned boolean DEFAULT false;
      UPDATE profiles SET is_banned = true WHERE id = NEW.user_id;
    EXCEPTION WHEN OTHERS THEN
      NULL;
    END;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_strike_auto_ban ON user_violations;
CREATE TRIGGER trg_strike_auto_ban
  AFTER INSERT ON user_violations
  FOR EACH ROW
  EXECUTE FUNCTION handle_strike_auto_ban();


-- 7. FUNCTION RPC: Tính Priority Score cho hàng đợi báo cáo (Queue Sort)
CREATE OR REPLACE FUNCTION get_priority_report_queue(
  p_status text DEFAULT 'pending',
  p_limit int DEFAULT 20,
  p_offset int DEFAULT 0
)
RETURNS TABLE (
  id uuid,
  reporter_id uuid,
  reporter_username text,
  reported_user_id uuid,
  reported_username text,
  content_id uuid,
  content_type text,
  content_caption text,
  category_name text,
  reason_level1 text,
  urgency_level text,
  status text,
  created_at timestamptz,
  priority_score int,
  total_count bigint
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
    rp.username AS reporter_username,
    r.reported_user_id,
    dp.username AS reported_username,
    r.content_id,
    r.content_type,
    CASE r.content_type
      WHEN 'post' THEN (SELECT caption FROM posts WHERE id = r.content_id)
      WHEN 'comment' THEN (SELECT content FROM comments WHERE id = r.content_id)
      ELSE NULL
    END AS content_caption,
    mc.name AS category_name,
    r.reason_level1,
    r.urgency_level,
    r.status,
    r.created_at,
    -- Công thức Priority Score
    (
      CASE r.urgency_level
        WHEN 'critical' THEN 50
        WHEN 'high' THEN 35
        WHEN 'medium' THEN 20
        ELSE 10
      END +
      COALESCE((SELECT report_count * 5 FROM posts WHERE id = r.content_id AND r.content_type = 'post'), 0)
    )::int AS priority_score,
    COUNT(*) OVER () AS total_count
  FROM moderation_reports r
  LEFT JOIN profiles rp ON rp.id = r.reporter_id
  LEFT JOIN profiles dp ON dp.id = r.reported_user_id
  LEFT JOIN moderation_categories mc ON mc.id = r.category_id
  WHERE (p_status = 'all' OR r.status = p_status)
  ORDER BY priority_score DESC, r.created_at DESC
  LIMIT p_limit OFFSET p_offset;
END;
$$;


-- 8. RLS POLICIES DÀNH CHO CÁC BẢNG MỚI
ALTER TABLE user_violations ENABLE ROW LEVEL SECURITY;
ALTER TABLE appeals ENABLE ROW LEVEL SECURITY;
ALTER TABLE mod_ai_agreement_log ENABLE ROW LEVEL SECURITY;

-- User xem được vi phạm & đơn kháng cáo của chính mình
CREATE POLICY "users view own violations" ON user_violations FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "users manage own appeals" ON appeals FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- Moderator/Admin toàn quyền quản lý
CREATE POLICY "moderator manage user_violations" ON user_violations FOR ALL USING (is_moderator()) WITH CHECK (is_moderator());
CREATE POLICY "moderator manage appeals" ON appeals FOR ALL USING (is_moderator()) WITH CHECK (is_moderator());
CREATE POLICY "moderator manage ai_agreement_log" ON mod_ai_agreement_log FOR ALL USING (is_moderator()) WITH CHECK (is_moderator());
