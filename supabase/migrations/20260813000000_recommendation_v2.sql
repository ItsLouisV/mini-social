-- Recommendation v2: authenticated ranking, durable feedback and event hygiene.

CREATE TABLE IF NOT EXISTS public.recommendation_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id UUID NOT NULL UNIQUE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    post_id UUID REFERENCES public.posts(id) ON DELETE CASCADE,
    event_type TEXT NOT NULL CHECK (event_type IN (
        'impression', 'view_dwell', 'image_click', 'like', 'comment',
        'share', 'hide', 'not_interested', 'report'
    )),
    session_id UUID,
    request_id UUID,
    position INT CHECK (position IS NULL OR position >= 0),
    source TEXT,
    visible_ratio REAL CHECK (visible_ratio IS NULL OR (visible_ratio >= 0 AND visible_ratio <= 1)),
    duration_ms INT NOT NULL DEFAULT 0 CHECK (duration_ms >= 0 AND duration_ms <= 600000),
    metadata JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_recommendation_events_user_created
    ON public.recommendation_events(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_recommendation_events_user_post_created
    ON public.recommendation_events(user_id, post_id, created_at DESC);

ALTER TABLE public.recommendation_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can insert own recommendation events" ON public.recommendation_events;
CREATE POLICY "Users can insert own recommendation events"
    ON public.recommendation_events FOR INSERT
    WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can read own recommendation events" ON public.recommendation_events;
CREATE POLICY "Users can read own recommendation events"
    ON public.recommendation_events FOR SELECT
    USING (auth.uid() = user_id);

CREATE TABLE IF NOT EXISTS public.recommendation_dismissals (
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    entity_type TEXT NOT NULL CHECK (entity_type IN ('post', 'author', 'profile')),
    entity_id UUID NOT NULL,
    reason TEXT NOT NULL DEFAULT 'not_interested',
    expires_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (user_id, entity_type, entity_id)
);

CREATE INDEX IF NOT EXISTS idx_recommendation_dismissals_active
    ON public.recommendation_dismissals(user_id, entity_type, expires_at);

ALTER TABLE public.recommendation_dismissals ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users manage own recommendation dismissals" ON public.recommendation_dismissals;
CREATE POLICY "Users manage own recommendation dismissals"
    ON public.recommendation_dismissals FOR ALL
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE OR REPLACE FUNCTION public.get_recommended_feed_v2(
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
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required' USING ERRCODE = '28000';
    END IF;

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
    consumed AS (
        -- Một bài đã được tiêu thụ sẽ rời candidate feed trong một khoảng
        -- cooldown. Event vẫn được giữ để học affinity cho tác giả/chủ đề.
        SELECT DISTINCT re.post_id
        FROM public.recommendation_events re
        WHERE re.user_id = v_user_id
          AND re.post_id IS NOT NULL
          AND (
            (re.event_type IN ('like', 'comment', 'share')
              AND re.created_at >= NOW() - INTERVAL '30 days')
            OR (re.event_type = 'image_click'
              AND re.created_at >= NOW() - INTERVAL '14 days')
            OR (re.event_type = 'view_dwell' AND re.duration_ms >= 2000
              AND re.created_at >= NOW() - INTERVAL '7 days')
          )
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
                CASE WHEN EXISTS (SELECT 1 FROM my_interests mi WHERE lower(COALESCE(po.caption, '')) LIKE '%' || mi.interest || '%') THEN 'matching_interest' END,
                CASE WHEN COALESCE(po.likes_count, 0) + COALESCE(po.comments_count, 0) >= 10 THEN 'popular' END,
                CASE WHEN po.created_at >= NOW() - INTERVAL '24 hours' THEN 'recent' END
            ], NULL)::TEXT[] AS reason_codes,
            (
                CASE WHEN po.user_id IN (SELECT friend_id FROM my_friends) THEN 32.0
                     WHEN po.user_id IN (SELECT following_id FROM my_follows) THEN 24.0
                     WHEN po.user_id = v_user_id THEN 8.0 ELSE 6.0 END
                + COALESCE(aa.affinity, 0.0)
                + CASE WHEN EXISTS (
                    SELECT 1 FROM my_interests mi
                    WHERE lower(COALESCE(po.caption, '')) LIKE '%' || mi.interest || '%'
                  ) THEN 14.0 ELSE 0.0 END
                + LN(1.0 + GREATEST(COALESCE(po.likes_count, 0), 0)) * 3.0
                + LN(1.0 + GREATEST(COALESCE(po.comments_count, 0), 0)) * 5.0
                + 42.0 / POWER(2.0 + GREATEST(0.0, EXTRACT(EPOCH FROM (NOW() - po.created_at)) / 3600.0), 0.85)
                - LEAST(24.0, COALESCE(s.impression_count, 0) * 6.0)
                - CASE WHEN s.last_impression >= NOW() - INTERVAL '6 hours' THEN 20.0 ELSE 0.0 END
                - CASE WHEN po.moderation_status = 'shadow_limited' THEN 1000000.0 ELSE 0.0 END
            )::DOUBLE PRECISION AS score
        FROM public.posts po
        LEFT JOIN author_affinity aa ON aa.author_id = po.user_id
        LEFT JOIN seen s ON s.post_id = po.id
        WHERE po.deleted_at IS NULL
          AND COALESCE(po.moderation_status, 'published') IN ('published', 'shadow_limited')
          AND COALESCE(s.negative, FALSE) = FALSE
          AND po.id NOT IN (SELECT c.post_id FROM consumed c)
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

CREATE OR REPLACE FUNCTION public.get_people_you_may_know_v2(p_limit INT DEFAULT 10)
RETURNS TABLE (
    id UUID, username TEXT, full_name TEXT, avatar_url TEXT, bio TEXT,
    interests TEXT[], mutual_friends_count INT, shared_interests_count INT,
    score DOUBLE PRECISION, reason_codes TEXT[]
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID := auth.uid();
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required' USING ERRCODE = '28000';
    END IF;

    RETURN QUERY
    WITH my_friends AS (
        SELECT CASE WHEN fr.sender_id = v_user_id THEN fr.receiver_id ELSE fr.sender_id END friend_id
        FROM public.friend_requests fr
        WHERE (fr.sender_id = v_user_id OR fr.receiver_id = v_user_id) AND fr.status = 'accepted'
    ), my_pending AS (
        SELECT CASE WHEN fr.sender_id = v_user_id THEN fr.receiver_id ELSE fr.sender_id END target_id
        FROM public.friend_requests fr
        WHERE fr.sender_id = v_user_id OR fr.receiver_id = v_user_id
    ), my_blocks AS (
        SELECT cb.blocked_id target_id FROM public.chat_blocks cb WHERE cb.blocker_id = v_user_id
        UNION SELECT cb.blocker_id FROM public.chat_blocks cb WHERE cb.blocked_id = v_user_id
    ), my_info AS (
        SELECT COALESCE(pr.interests, '{}'::TEXT[]) interests FROM public.profiles pr WHERE pr.id = v_user_id
    ), candidates AS (
        SELECT p.*,
          (SELECT COUNT(DISTINCT cf.friend_id) FROM (
              SELECT CASE WHEN fr.sender_id = p.id THEN fr.receiver_id ELSE fr.sender_id END friend_id
              FROM public.friend_requests fr
              WHERE (fr.sender_id = p.id OR fr.receiver_id = p.id) AND fr.status = 'accepted'
          ) cf JOIN my_friends mf ON mf.friend_id = cf.friend_id)::INT mutual_count,
          (SELECT COUNT(*) FROM (
              SELECT lower(trim(unnest(COALESCE(p.interests, '{}'::TEXT[]))))
              INTERSECT SELECT lower(trim(unnest(mi.interests))) FROM my_info mi
          ) x)::INT shared_count
        FROM public.profiles p
        WHERE p.id <> v_user_id
          AND p.id NOT IN (SELECT friend_id FROM my_friends)
          AND p.id NOT IN (SELECT target_id FROM my_pending)
          AND p.id NOT IN (SELECT target_id FROM my_blocks)
          AND NOT EXISTS (SELECT 1 FROM public.recommendation_dismissals rd
            WHERE rd.user_id = v_user_id AND rd.entity_type = 'profile' AND rd.entity_id = p.id
              AND (rd.expires_at IS NULL OR rd.expires_at > NOW()))
    )
    SELECT c.id, c.username, c.full_name, c.avatar_url, c.bio, c.interests,
      c.mutual_count, c.shared_count,
      (c.mutual_count * 6.0 + c.shared_count * 3.0 + 1.0)::DOUBLE PRECISION,
      ARRAY_REMOVE(ARRAY[
        CASE WHEN c.mutual_count > 0 THEN 'mutual_friends' END,
        CASE WHEN c.shared_count > 0 THEN 'shared_interests' END
      ], NULL)::TEXT[]
    FROM candidates c
    ORDER BY c.mutual_count DESC, c.shared_count DESC, c.created_at DESC
    LIMIT LEAST(GREATEST(COALESCE(p_limit, 10), 1), 30);
END;
$$;

REVOKE ALL ON FUNCTION public.get_recommended_feed_v2(INT, DOUBLE PRECISION, TIMESTAMPTZ, UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_recommended_feed_v2(INT, DOUBLE PRECISION, TIMESTAMPTZ, UUID) TO authenticated;
REVOKE ALL ON FUNCTION public.get_people_you_may_know_v2(INT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_people_you_may_know_v2(INT) TO authenticated;
