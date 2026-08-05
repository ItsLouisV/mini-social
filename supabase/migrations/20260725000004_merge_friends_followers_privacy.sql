-- ============================================================
-- Migration: Cập nhật RLS & Functions hỗ trợ gộp "Bạn bè & Người theo dõi" & Multi-Factor Recommendation Engine
-- ============================================================

-- 1. Cập nhật function get_recommended_feed nâng cấp Thuật toán Đề xuất Đa tầng
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
    ),
    my_interests AS (
        SELECT COALESCE(interests, '{}') AS interest_list
        FROM public.profiles
        WHERE id = p_user_id
    ),
    implicit_signals AS (
        SELECT 
            ui.post_id,
            SUM(CASE WHEN ui.interaction_type = 'view_dwell' THEN LEAST(ui.duration_ms / 1000.0, 10.0) * 0.5 ELSE 0 END) +
            SUM(CASE WHEN ui.interaction_type = 'image_click' THEN 2.0 ELSE 0 END) AS implicit_score
        FROM public.user_interactions ui
        WHERE ui.user_id = p_user_id
        GROUP BY ui.post_id
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
            -- Score 1: Connection Score (Mối quan hệ)
            (CASE 
                WHEN po.user_id IN (SELECT friend_id FROM my_friends) THEN 40.0
                WHEN po.user_id IN (SELECT following_id FROM my_follows) THEN 30.0
                WHEN po.user_id = p_user_id THEN 15.0
                ELSE 10.0
            END)
            -- Score 2: Engagement Score (Tương tác chủ động)
            + (COALESCE(po.likes_count, 0) * 2.0 + COALESCE(po.comments_count, 0) * 3.5)
            -- Score 3: Implicit Score (Tương tác ngầm: Dwell time & Image clicks)
            + COALESCE(imp.implicit_score, 0.0)
            -- Score 4: Topic Score (Trùng khớp sở thích cá nhân)
            + (CASE 
                WHEN po.caption IS NOT NULL AND EXISTS (
                    SELECT 1 FROM my_interests mi, UNNEST(mi.interest_list) interest
                    WHERE po.caption ILIKE '%' || interest || '%'
                ) THEN 15.0 
                ELSE 0.0 
            END)
            -- Score 5: Gravity Recency Decay (Suy giảm thời gian tự nhiên)
            + (120.0 / POWER(GREATEST(0.1, EXTRACT(EPOCH FROM (NOW() - po.created_at)) / 3600.0) + 2.0, 1.4))
        )::FLOAT AS score
    FROM public.posts po
    LEFT JOIN implicit_signals imp ON imp.post_id = po.id
    WHERE po.deleted_at IS NULL
      AND po.user_id NOT IN (SELECT target_id FROM my_blocks)
      AND (
          po.privacy = 'public'
          OR po.user_id = p_user_id
          OR (po.privacy IN ('friends', 'followers') AND (
              po.user_id IN (SELECT friend_id FROM my_friends)
              OR po.user_id IN (SELECT following_id FROM my_follows)
          ))
      )
    ORDER BY score DESC, po.created_at DESC
    LIMIT p_limit OFFSET p_offset;
END;
$$;

