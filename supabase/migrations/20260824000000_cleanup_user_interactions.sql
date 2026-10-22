-- Keep recommendation interaction events for 30 days, then remove them daily.
-- These are short-lived behavior signals; durable likes/comments live in their
-- own tables and are not affected by this cleanup.

CREATE OR REPLACE FUNCTION public.purge_expired_user_interactions()
RETURNS INT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_deleted_count INT := 0;
BEGIN
  WITH deleted_rows AS (
    DELETE FROM public.user_interactions
    WHERE created_at < NOW() - INTERVAL '30 days'
    RETURNING id
  )
  SELECT COUNT(*) INTO v_deleted_count FROM deleted_rows;

  RETURN v_deleted_count;
END;
$$;

COMMENT ON FUNCTION public.purge_expired_user_interactions() IS
  'Deletes recommendation interaction events older than 30 days';

REVOKE ALL ON FUNCTION public.purge_expired_user_interactions() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.purge_expired_user_interactions() TO service_role;

-- Run once a day when pg_cron is enabled in the Supabase project.
DO $$
DECLARE
  v_existing_job BIGINT;
BEGIN
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    SELECT jobid INTO v_existing_job
    FROM cron.job
    WHERE jobname = 'purge-expired-user-interactions';

    IF v_existing_job IS NOT NULL THEN
      PERFORM cron.unschedule(v_existing_job);
    END IF;

    PERFORM cron.schedule(
      'purge-expired-user-interactions',
      '23 3 * * *',
      'SELECT public.purge_expired_user_interactions();'
    );
  END IF;
EXCEPTION
  WHEN OTHERS THEN
    RAISE NOTICE 'user_interactions cleanup schedule skipped: %', SQLERRM;
END
$$;
