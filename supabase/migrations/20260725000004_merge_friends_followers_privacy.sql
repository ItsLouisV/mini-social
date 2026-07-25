-- ============================================================
-- Migration: Cập nhật RLS & Functions hỗ trợ gộp "Bạn bè & Người theo dõi"
-- ============================================================

-- 1. Cập nhật function get_recommended_feed hỗ trợ cả 'friends' và 'followers'
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
            -- Score 3: Recency Decay
            + (100.0 / POWER(GREATEST(0.1, EXTRACT(EPOCH FROM (NOW() - po.created_at)) / 3600.0) + 2.0, 1.3))
        )::FLOAT AS score
    FROM public.posts po
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
