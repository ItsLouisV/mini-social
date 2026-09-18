-- ============================================================
-- Migration: 20260821000000_robust_trash_cleanup.sql
-- Mục tiêu: Dọn dẹp triệt để bài viết trong thùng rác quá 30 ngày
-- Giải quyết: Không phụ thuộc Supabase Vault secrets hay pg_net HTTP.
-- ============================================================

-- 1. Hàm hệ thống dọn dẹp tất cả bài viết quá hạn trong thùng rác
CREATE OR REPLACE FUNCTION public.purge_expired_trashed_posts(retention_days INT DEFAULT 30)
RETURNS INT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_deleted_count INT := 0;
BEGIN
  -- Xóa các bài viết quá hạn.
  -- Do FK post_media, likes, comments có ON DELETE CASCADE,
  -- và trigger tr_queue_post_media_deletion tự động đẩy files vào storage_deletion_queue.
  WITH deleted_rows AS (
    DELETE FROM public.posts
    WHERE deleted_at IS NOT NULL
      AND deleted_at <= (NOW() - (retention_days || ' days')::INTERVAL)
    RETURNING id
  )
  SELECT COUNT(*) INTO v_deleted_count FROM deleted_rows;

  RETURN v_deleted_count;
END;
$$;

COMMENT ON FUNCTION public.purge_expired_trashed_posts(INT) IS
  'Xóa vĩnh viễn các bài viết trong thùng rác đã quá số ngày chỉ định (mặc định 30 ngày)';

-- 2. Hàm RPC dành cho người dùng hiện tại dọn dẹp các bài quá hạn của chính mình
CREATE OR REPLACE FUNCTION public.cleanup_my_expired_trashed_posts(retention_days INT DEFAULT 30)
RETURNS INT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_deleted_count INT := 0;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN 0;
  END IF;

  WITH deleted_rows AS (
    DELETE FROM public.posts
    WHERE user_id = v_user_id
      AND deleted_at IS NOT NULL
      AND deleted_at <= (NOW() - (retention_days || ' days')::INTERVAL)
    RETURNING id
  )
  SELECT COUNT(*) INTO v_deleted_count FROM deleted_rows;

  RETURN v_deleted_count;
END;
$$;

COMMENT ON FUNCTION public.cleanup_my_expired_trashed_posts(INT) IS
  'Cho phép người dùng đã xác thực tự dọn dẹp các bài viết trong thùng rác quá hạn 30 ngày của mình';

-- Phân quyền thực thi
GRANT EXECUTE ON FUNCTION public.purge_expired_trashed_posts(INT) TO service_role;
GRANT EXECUTE ON FUNCTION public.cleanup_my_expired_trashed_posts(INT) TO authenticated;

-- 3. Đăng ký pg_cron chạy định kỳ trực tiếp bằng SQL (nếu extension pg_cron khả dụng)
DO $$
DECLARE
  v_job_exists BOOLEAN := false;
BEGIN
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    -- Hủy job cũ nếu đã có để cập nhật
    SELECT EXISTS (
      SELECT 1 FROM cron.job WHERE jobname = 'purge-expired-posts-direct'
    ) INTO v_job_exists;

    IF v_job_exists THEN
      PERFORM cron.unschedule('purge-expired-posts-direct');
    END IF;

    -- Lên lịch chạy mỗi giờ vào phút thứ 15
    PERFORM cron.schedule(
      'purge-expired-posts-direct',
      '15 * * * *',
      'SELECT public.purge_expired_trashed_posts(30);'
    );
  END IF;
EXCEPTION
  WHEN OTHERS THEN
    RAISE NOTICE 'pg_cron direct schedule skipped: %', SQLERRM;
END
$$;
