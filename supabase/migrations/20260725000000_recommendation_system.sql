-- ============================================================
-- Migration: Sprint 7 - Recommendation System (Đề xuất)
-- ============================================================

-- 1. Bảng lưu trữ tương tác ẩn (Implicit Interactions / Dwell time / Image Clicks)
CREATE TABLE IF NOT EXISTS public.user_interactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    post_id UUID REFERENCES public.posts(id) ON DELETE CASCADE NOT NULL,
    interaction_type TEXT NOT NULL CHECK (interaction_type IN ('view_dwell', 'image_click', 'like', 'comment', 'share')),
    duration_ms INT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_user_interactions_user_id ON public.user_interactions(user_id);
CREATE INDEX IF NOT EXISTS idx_user_interactions_post_id ON public.user_interactions(post_id);
CREATE INDEX IF NOT EXISTS idx_user_interactions_created_at ON public.user_interactions(created_at);

-- RLS Policies cho user_interactions
ALTER TABLE public.user_interactions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can insert their own interactions" ON public.user_interactions;
CREATE POLICY "Users can insert their own interactions" ON public.user_interactions
    FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can view their own interactions" ON public.user_interactions;
CREATE POLICY "Users can view their own interactions" ON public.user_interactions
    FOR SELECT USING (auth.uid() = user_id);


-- 2. Function RPC: get_people_you_may_know
-- Gợi ý người quen dựa trên số bạn chung và sở thích trùng lặp
CREATE OR REPLACE FUNCTION public.get_people_you_may_know(
    p_user_id UUID,
    p_limit INT DEFAULT 10
)
RETURNS TABLE (
    id UUID,
    username TEXT,
    full_name TEXT,
    avatar_url TEXT,
    bio TEXT,
    interests TEXT[],
    mutual_friends_count INT,
    shared_interests_count INT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    WITH my_friends AS (
        SELECT CASE WHEN sender_id = p_user_id THEN receiver_id ELSE sender_id END AS friend_id
        FROM public.friend_requests
        WHERE (sender_id = p_user_id OR receiver_id = p_user_id)
          AND status = 'accepted'
    ),
    my_blocks AS (
        SELECT blocked_id AS target_id FROM public.chat_blocks WHERE blocker_id = p_user_id
        UNION
        SELECT blocker_id AS target_id FROM public.chat_blocks WHERE blocked_id = p_user_id
    ),
    my_pending AS (
        SELECT CASE WHEN sender_id = p_user_id THEN receiver_id ELSE sender_id END AS target_id
        FROM public.friend_requests
        WHERE (sender_id = p_user_id OR receiver_id = p_user_id)
    ),
    my_info AS (
        SELECT COALESCE(pr.interests, '{}') AS interests FROM public.profiles pr WHERE pr.id = p_user_id
    )
    SELECT 
        p.id,
        p.username,
        p.full_name,
        p.avatar_url,
        p.bio,
        p.interests,
        COALESCE(mf.mutual_count, 0)::INT AS mutual_friends_count,
        COALESCE(si.shared_count, 0)::INT AS shared_interests_count
    FROM public.profiles p
    LEFT JOIN LATERAL (
        SELECT COUNT(DISTINCT candidate_friend.friend_id)::INT AS mutual_count
        FROM (
            SELECT CASE WHEN fr.sender_id = p.id THEN fr.receiver_id ELSE fr.sender_id END AS friend_id
            FROM public.friend_requests fr
            WHERE (fr.sender_id = p.id OR fr.receiver_id = p.id)
              AND fr.status = 'accepted'
        ) candidate_friend
        INNER JOIN my_friends mf_item ON candidate_friend.friend_id = mf_item.friend_id
    ) mf ON TRUE
    LEFT JOIN LATERAL (
        SELECT COALESCE(ARRAY_LENGTH(ARRAY(
            SELECT UNNEST(COALESCE(p.interests, '{}')) INTERSECT SELECT UNNEST(mi.interests)
        ), 1), 0)::INT AS shared_count
        FROM my_info mi
    ) si ON TRUE
    WHERE p.id <> p_user_id
      AND p.id NOT IN (SELECT friend_id FROM my_friends)
      AND p.id NOT IN (SELECT target_id FROM my_pending)
      AND p.id NOT IN (SELECT target_id FROM my_blocks)
    ORDER BY (COALESCE(mf.mutual_count, 0) * 3 + COALESCE(si.shared_count, 0) * 2) DESC, p.created_at DESC
    LIMIT p_limit;
END;
$$;


-- 3. Function RPC: get_recommended_feed
-- Xếp hạng Feed cho người dùng dựa trên mức độ thân thiết, độ tương tác và thời gian bài đăng
CREATE OR REPLACE FUNCTION public.get_recommended_feed(
    p_user_id UUID,
    p_limit INT DEFAULT 20,
    p_offset INT DEFAULT 0
)
RETURNS TABLE (
    post_id UUID,
    user_id UUID,
    caption TEXT,
    likes_count INT,
    comments_count INT,
    privacy TEXT,
    created_at TIMESTAMPTZ,
    score FLOAT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    WITH my_friends AS (
        SELECT CASE WHEN sender_id = p_user_id THEN receiver_id ELSE sender_id END AS friend_id
        FROM public.friend_requests
        WHERE (sender_id = p_user_id OR receiver_id = p_user_id)
          AND status = 'accepted'
    ),
    my_follows AS (
        SELECT following_id FROM public.follows WHERE follower_id = p_user_id
    ),
    my_blocks AS (
        SELECT blocked_id AS target_id FROM public.chat_blocks WHERE blocker_id = p_user_id
        UNION
        SELECT blocker_id AS target_id FROM public.chat_blocks WHERE blocked_id = p_user_id
    )
    SELECT 
        po.id AS post_id,
        po.user_id,
        po.caption,
        po.likes_count,
        po.comments_count,
        po.privacy,
        po.created_at,
        (
            -- Score 1: Connection Score
            (CASE 
                WHEN po.user_id = p_user_id THEN 50.0
                WHEN po.user_id IN (SELECT friend_id FROM my_friends) THEN 40.0
                WHEN po.user_id IN (SELECT following_id FROM my_follows) THEN 25.0
                ELSE 10.0
            END)
            -- Score 2: Engagement Score
            + (COALESCE(po.likes_count, 0) * 2.0 + COALESCE(po.comments_count, 0) * 3.0)
            -- Score 3: Recency Decay (Suy giảm theo thời gian)
            + (100.0 / POWER(GREATEST(0.1, EXTRACT(EPOCH FROM (NOW() - po.created_at)) / 3600.0) + 2.0, 1.3))
        )::FLOAT AS score
    FROM public.posts po
    WHERE po.deleted_at IS NULL
      AND po.user_id NOT IN (SELECT target_id FROM my_blocks)
      AND (
          po.privacy = 'public'
          OR po.user_id = p_user_id
          OR (po.privacy = 'friends' AND po.user_id IN (SELECT friend_id FROM my_friends))
      )
    ORDER BY score DESC, po.created_at DESC
    LIMIT p_limit OFFSET p_offset;
END;
$$;
