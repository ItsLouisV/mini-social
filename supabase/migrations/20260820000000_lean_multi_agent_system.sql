-- ============================================================
-- MIGRATION: LEAN MULTI-AGENT SYSTEM & DATABASE OPTIMIZATION
-- Sprint 12+ — Content Moderation Multi-Agents & Recommendation v3
-- ============================================================

-- ------------------------------------------------------------
-- 1. DỌN DẸP CỘT THỪA LỊCH SỬ (CLEANUP)
-- ------------------------------------------------------------
-- posts.status bị thừa (thay bằng moderation_status)
ALTER TABLE public.posts DROP COLUMN IF EXISTS status;

-- posts.report_count bị thừa (chuyển sang đếm động trên bảng reports)
ALTER TABLE public.posts DROP COLUMN IF EXISTS report_count;

-- profiles.is_banned bị thừa (thay bằng account_status)
ALTER TABLE public.profiles DROP COLUMN IF EXISTS is_banned;


-- ------------------------------------------------------------
-- 2. KHẮC PHỤC LỖI KÍCH THƯỚC VECTOR POSTS (384 -> 768)
-- ------------------------------------------------------------
-- Xóa index cũ để sửa type an toàn
DROP INDEX IF EXISTS public.posts_embedding_hnsw_idx;

-- Reset embedding cũ về NULL và chuyển kiểu sang vector(768) cho Gemini text-embedding-004
ALTER TABLE public.posts ALTER COLUMN embedding DROP DEFAULT;
ALTER TABLE public.posts ALTER COLUMN embedding TYPE vector(768) USING NULL;

-- Tạo lại chỉ mục HNSW cho vector cosine ops
CREATE INDEX IF NOT EXISTS posts_embedding_hnsw_idx 
ON public.posts USING hnsw (embedding vector_cosine_ops);


-- ------------------------------------------------------------
-- 3. BỔ SUNG VECTOR GU SỞ THÍCH CHO PROFILES (AGENT R2)
-- ------------------------------------------------------------
ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS taste_embedding vector(768);

CREATE INDEX IF NOT EXISTS profiles_taste_embedding_hnsw_idx 
ON public.profiles USING hnsw (taste_embedding vector_cosine_ops);


-- ------------------------------------------------------------
-- 4. BẢNG AUDIT LOG MINH BẠCH CHO MULTI-AGENTS
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.moderation_agent_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    content_type TEXT NOT NULL CHECK (content_type IN ('post', 'comment', 'message')),
    content_id UUID NOT NULL,
    pipeline_run_id UUID NOT NULL,
    agent_name TEXT NOT NULL, 
    verdict TEXT NOT NULL CHECK (verdict IN ('pass', 'flag', 'reject', 'needs_review')),
    confidence NUMERIC(4,3),
    reasons JSONB DEFAULT '{}'::JSONB,
    raw_response TEXT,
    execution_time_ms INT,
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_mod_agent_logs_lookup 
ON public.moderation_agent_logs (content_type, content_id);

CREATE INDEX IF NOT EXISTS idx_mod_agent_logs_created 
ON public.moderation_agent_logs (created_at DESC);

ALTER TABLE public.moderation_agent_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admins view moderation agent logs" ON public.moderation_agent_logs;
CREATE POLICY "Admins view moderation agent logs" 
ON public.moderation_agent_logs FOR SELECT USING (true);


-- ------------------------------------------------------------
-- 5. TRIGGER SERVER-SIDE: BẢO VỆ TRẠNG THÁI KIỂM DUYỆT (CHỐNG BYPASS)
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.handle_enforce_moderation_guard()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Nếu được tạo bởi người dùng bình thường (không phải service_role)
  -- Luôn bắt đầu ở trạng thái 'under_review' để chờ Multi-Agents duyệt ngầm
  IF TG_OP = 'INSERT' THEN
    IF current_setting('request.jwt.claim.role', true) <> 'service_role' THEN
      NEW.moderation_status := 'under_review'::moderation_status;
      NEW.ai_moderation_score := NULL;
      NEW.moderated_at := NULL;
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_posts_moderation_guard ON public.posts;
CREATE TRIGGER trg_posts_moderation_guard
  BEFORE INSERT ON public.posts
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_enforce_moderation_guard();


-- ------------------------------------------------------------
-- 6. TRIGGER TỰ ĐỘNG CẬP NHẬT STRIKE & TRUST SCORE
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.handle_moderation_action_strike()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  IF NEW.action_type IN ('auto_block', 'hide', 'ban_user', 'suspend_user') AND NEW.target_user_id IS NOT NULL THEN
    UPDATE public.profiles
    SET violation_count = COALESCE(violation_count, 0) + 1,
        trust_score = GREATEST(0.0, COALESCE(trust_score, 0.500) - 0.150)
    WHERE id = NEW.target_user_id;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_moderation_action_strike ON public.moderation_actions;
CREATE TRIGGER trg_moderation_action_strike
  AFTER INSERT ON public.moderation_actions
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_moderation_action_strike();


-- ------------------------------------------------------------
-- 7. DATABASE RPC: get_recommended_feed_v3
-- Kết hợp Heuristic v2 + Semantic pgvector Matching + Diversity Guard
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_recommended_feed_v3(
    p_limit INT DEFAULT 20,
    p_cursor_score DOUBLE PRECISION DEFAULT NULL,
    p_cursor_created_at TIMESTAMPTZ DEFAULT NULL,
    p_cursor_post_id UUID DEFAULT NULL
)
RETURNS TABLE (
    post_id UUID,
    user_id UUID,
    caption TEXT,
    likes_count INT,
    comments_count INT,
    privacy TEXT,
    created_at TIMESTAMPTZ,
    score DOUBLE PRECISION,
    source TEXT,
    reason_codes TEXT[]
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_limit INT := LEAST(GREATEST(COALESCE(p_limit, 20), 1), 50);
    v_user_taste vector(768);
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required' USING ERRCODE = '28000';
    END IF;

    -- Lấy vector gu sở thích của user hiện tại
    SELECT pr.taste_embedding INTO v_user_taste
    FROM public.profiles pr
    WHERE pr.id = v_user_id;

    RETURN QUERY
    WITH my_friends AS (
        SELECT CASE WHEN fr.sender_id = v_user_id THEN fr.receiver_id ELSE fr.sender_id END AS friend_id
        FROM public.friend_requests fr
        WHERE (fr.sender_id = v_user_id OR fr.receiver_id = v_user_id)
          AND fr.status = 'accepted'
    ),
    my_follows AS (
        SELECT f.following_id FROM public.follows f WHERE f.follower_id = v_user_id
    ),
    my_blocks AS (
        SELECT cb.blocked_id AS target_id FROM public.chat_blocks cb WHERE cb.blocker_id = v_user_id
        UNION
        SELECT cb.blocker_id FROM public.chat_blocks cb WHERE cb.blocked_id = v_user_id
    ),
    my_interests AS (
        SELECT lower(trim(i)) AS interest
        FROM public.profiles pr, unnest(COALESCE(pr.interests, '{}'::TEXT[])) i
        WHERE pr.id = v_user_id AND length(trim(i)) >= 2
    ),
    author_affinity AS (
        SELECT po.user_id AS author_id,
            LEAST(18.0, SUM(
                CASE re.event_type
                    WHEN 'comment' THEN 4.0 WHEN 'share' THEN 4.0 WHEN 'like' THEN 2.5
                    WHEN 'image_click' THEN 1.0 WHEN 'view_dwell' THEN LEAST(re.duration_ms / 5000.0, 1.5)
                    ELSE 0.0
                END * EXP(-EXTRACT(EPOCH FROM (NOW() - re.created_at)) / 2592000.0)
            ))::DOUBLE PRECISION AS affinity
        FROM public.recommendation_events re
        JOIN public.posts po ON po.id = re.post_id
        WHERE re.user_id = v_user_id AND re.created_at >= NOW() - INTERVAL '90 days'
        GROUP BY po.user_id
    ),
    seen AS (
        SELECT re.post_id,
            COUNT(*) FILTER (WHERE re.event_type = 'impression') AS impression_count,
            MAX(re.created_at) FILTER (WHERE re.event_type = 'impression') AS last_impression,
            BOOL_OR(re.event_type IN ('hide', 'not_interested', 'report')) AS negative
        FROM public.recommendation_events re
        WHERE re.user_id = v_user_id AND re.created_at >= NOW() - INTERVAL '30 days'
        GROUP BY re.post_id
    ),
    scored_base AS (
        SELECT po.id AS post_id, po.user_id, po.caption, po.likes_count, po.comments_count,
            po.privacy, po.created_at,
            CASE
                WHEN po.user_id IN (SELECT friend_id FROM my_friends) THEN 'friends'
                WHEN po.user_id IN (SELECT following_id FROM my_follows) THEN 'following'
                WHEN po.user_id = v_user_id THEN 'own'
                ELSE 'discovery'
            END AS source,
            ARRAY_REMOVE(ARRAY[
                CASE WHEN po.user_id IN (SELECT friend_id FROM my_friends) THEN 'friend' END,
                CASE WHEN po.user_id IN (SELECT following_id FROM my_follows) THEN 'following' END,
                CASE WHEN aa.affinity > 2 THEN 'frequent_author' END,
                CASE WHEN v_user_taste IS NOT NULL AND po.embedding IS NOT NULL AND (1.0 - (po.embedding <=> v_user_taste)) > 0.60 
                     THEN 'matching_taste' END,
                CASE WHEN EXISTS (SELECT 1 FROM my_interests mi WHERE lower(COALESCE(po.caption, '')) LIKE '%' || mi.interest || '%') 
                     THEN 'matching_interest' END,
                CASE WHEN COALESCE(po.likes_count, 0) + COALESCE(po.comments_count, 0) >= 10 THEN 'popular' END,
                CASE WHEN po.created_at >= NOW() - INTERVAL '24 hours' THEN 'recent' END
            ], NULL)::TEXT[] AS reason_codes,
            (
                CASE WHEN po.user_id IN (SELECT friend_id FROM my_friends) THEN 32.0
                     WHEN po.user_id IN (SELECT following_id FROM my_follows) THEN 24.0
                     WHEN po.user_id = v_user_id THEN 8.0 ELSE 6.0 END
                + COALESCE(aa.affinity, 0.0)
                -- ── Semantic Taste Matching qua pgvector (Agent R2) ──
                + CASE 
                    WHEN v_user_taste IS NOT NULL AND po.embedding IS NOT NULL 
                    THEN GREATEST(0.0, (1.0 - (po.embedding <=> v_user_taste))) * 22.0
                    -- Fallback nếu chưa có vector taste
                    WHEN EXISTS (
                        SELECT 1 FROM my_interests mi
                        WHERE lower(COALESCE(po.caption, '')) LIKE '%' || mi.interest || '%'
                    ) THEN 14.0 
                    ELSE 0.0 
                  END
                -- ── Topics Matching từ JSONB ai_moderation_labels (Agent R1) ──
                + CASE 
                    WHEN po.ai_moderation_labels ? 'topics' AND EXISTS (
                        SELECT 1 FROM jsonb_array_elements_text(po.ai_moderation_labels->'topics') t
                        JOIN my_interests mi ON lower(trim(t)) = mi.interest
                    ) THEN 8.0 
                    ELSE 0.0 
                  END
                + LN(1.0 + GREATEST(COALESCE(po.likes_count, 0), 0)) * 3.0
                + LN(1.0 + GREATEST(COALESCE(po.comments_count, 0), 0)) * 5.0
                + 42.0 / POWER(2.0 + GREATEST(0.0, EXTRACT(EPOCH FROM (NOW() - po.created_at)) / 3600.0), 0.85)
                - CASE WHEN po.moderation_status = 'shadow_limited' THEN 1000000.0 ELSE 0.0 END
            )::DOUBLE PRECISION AS score
        FROM public.posts po
        LEFT JOIN author_affinity aa ON aa.author_id = po.user_id
        LEFT JOIN seen s ON s.post_id = po.id
        WHERE po.deleted_at IS NULL
          AND COALESCE(po.moderation_status, 'published') IN ('published', 'shadow_limited')
          AND COALESCE(s.negative, FALSE) = FALSE
          AND po.user_id NOT IN (SELECT target_id FROM my_blocks)
          AND NOT EXISTS (
              SELECT 1 FROM public.recommendation_dismissals rd
              WHERE rd.user_id = v_user_id
                AND (rd.expires_at IS NULL OR rd.expires_at > NOW())
                AND ((rd.entity_type = 'post' AND rd.entity_id = po.id)
                  OR (rd.entity_type = 'author' AND rd.entity_id = po.user_id))
          )
          AND (po.privacy = 'public' OR po.user_id = v_user_id
            OR (po.privacy = 'friends' AND po.user_id IN (SELECT friend_id FROM my_friends))
            OR (po.privacy = 'followers' AND (po.user_id IN (SELECT following_id FROM my_follows)
              OR po.user_id IN (SELECT friend_id FROM my_friends))))
    ),
    author_ranked AS (
        SELECT s.*,
            ROW_NUMBER() OVER (PARTITION BY s.user_id ORDER BY s.score DESC, s.created_at DESC) AS author_position
        FROM scored_base s
    ),
    scored AS (
        SELECT a.post_id, a.user_id, a.caption, a.likes_count, a.comments_count,
            a.privacy, a.created_at,
            (a.score - GREATEST(a.author_position - 2, 0) * 12.0)::DOUBLE PRECISION AS score,
            a.source, a.reason_codes
        FROM author_ranked a
    ),
    paged AS (
        SELECT s.* FROM scored s
        WHERE p_cursor_score IS NULL
           OR (s.score, s.created_at, s.post_id) < (p_cursor_score, p_cursor_created_at, p_cursor_post_id)
        ORDER BY s.score DESC, s.created_at DESC, s.post_id DESC
        LIMIT v_limit
    )
    SELECT p.post_id, p.user_id, p.caption, p.likes_count, p.comments_count,
        p.privacy, p.created_at, p.score, p.source, p.reason_codes
    FROM paged p
    ORDER BY p.score DESC, p.created_at DESC, p.post_id DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.get_recommended_feed_v3(INT, DOUBLE PRECISION, TIMESTAMPTZ, UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_recommended_feed_v3(INT, DOUBLE PRECISION, TIMESTAMPTZ, UUID) TO authenticated;
