-- Migration: Sprint 8 - AI Hybrid Search (pgvector + Full-Text Search + RRF)

-- 1. Kích hoạt extension pgvector
CREATE EXTENSION IF NOT EXISTS vector WITH SCHEMA public;

-- 2. Thêm cột embedding (768 chiều cho Gemini text-embedding-004) và cột fts (Full-Text Search)
ALTER TABLE public.posts ADD COLUMN IF NOT EXISTS embedding vector(768);
ALTER TABLE public.posts ADD COLUMN IF NOT EXISTS fts tsvector GENERATED ALWAYS AS (to_tsvector('simple', COALESCE(caption, ''))) STORED;

-- 3. Tạo chỉ mục HNSW cho vector similarity search
CREATE INDEX IF NOT EXISTS posts_embedding_hnsw_idx 
ON public.posts USING hnsw (embedding vector_cosine_ops);

-- 4. Tạo chỉ mục GIN cho Full-Text Search
CREATE INDEX IF NOT EXISTS posts_fts_idx 
ON public.posts USING gin (fts);

-- 5. Database RPC Function: hybrid_search_posts
-- Thực hiện kết hợp tìm kiếm từ khóa (FTS) và tìm kiếm ngữ nghĩa (Cosine Similarity)
-- Xếp hạng tổng hợp bằng thuật toán Reciprocal Rank Fusion (RRF)
CREATE OR REPLACE FUNCTION public.hybrid_search_posts(
    p_query_text TEXT,
    p_query_embedding vector(768),
    p_match_count INT DEFAULT 30,
    p_rrf_k INT DEFAULT 60
)
RETURNS TABLE (
    post_id UUID,
    user_id UUID,
    caption TEXT,
    created_at TIMESTAMPTZ,
    likes_count INT,
    comments_count INT,
    privacy TEXT,
    score FLOAT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    WITH fts_matches AS (
        SELECT 
            p.id,
            ROW_NUMBER() OVER (ORDER BY ts_rank(p.fts, websearch_to_tsquery('simple', p_query_text)) DESC) AS rank
        FROM public.posts p
        WHERE p.deleted_at IS NULL
          AND (p.fts @@ websearch_to_tsquery('simple', p_query_text) OR p.caption ILIKE '%' || p_query_text || '%')
        LIMIT p_match_count
    ),
    vector_matches AS (
        SELECT 
            p.id,
            ROW_NUMBER() OVER (ORDER BY (p.embedding <=> p_query_embedding) ASC) AS rank
        FROM public.posts p
        WHERE p.deleted_at IS NULL
          AND p.embedding IS NOT NULL
        LIMIT p_match_count
    ),
    combined_ranks AS (
        SELECT 
            COALESCE(f.id, v.id) AS id,
            (COALESCE(1.0 / (p_rrf_k + f.rank), 0.0) + COALESCE(1.0 / (p_rrf_k + v.rank), 0.0))::FLOAT AS combined_score
        FROM fts_matches f
        FULL OUTER JOIN vector_matches v ON f.id = v.id
    )
    SELECT 
        p.id AS post_id,
        p.user_id,
        p.caption,
        p.created_at,
        p.likes_count,
        p.comments_count,
        p.privacy,
        cr.combined_score AS score
    FROM combined_ranks cr
    JOIN public.posts p ON p.id = cr.id
    WHERE p.deleted_at IS NULL
    ORDER BY cr.combined_score DESC
    LIMIT p_match_count;
END;
$$;
