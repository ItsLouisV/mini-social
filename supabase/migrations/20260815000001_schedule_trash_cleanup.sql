-- Runs cleanup-trash every hour. The Edge Function deletes Storage objects
-- before deleting expired post rows, preventing orphaned media.
CREATE EXTENSION IF NOT EXISTS pg_cron WITH SCHEMA pg_catalog;
CREATE EXTENSION IF NOT EXISTS pg_net WITH SCHEMA extensions;

DO $$
DECLARE
  v_project_url TEXT;
  v_service_role_key TEXT;
  v_existing_job BIGINT;
BEGIN
  SELECT decrypted_secret INTO v_project_url
  FROM vault.decrypted_secrets
  WHERE name = 'project_url'
  LIMIT 1;

  SELECT decrypted_secret INTO v_service_role_key
  FROM vault.decrypted_secrets
  WHERE name = 'service_role_key'
  LIMIT 1;

  IF v_project_url IS NULL OR v_service_role_key IS NULL THEN
    RAISE NOTICE 'cleanup-trash schedule skipped: add project_url and service_role_key to Supabase Vault, then rerun this migration block.';
    RETURN;
  END IF;

  SELECT jobid INTO v_existing_job
  FROM cron.job
  WHERE jobname = 'cleanup-expired-trashed-posts';

  IF v_existing_job IS NOT NULL THEN
    PERFORM cron.unschedule(v_existing_job);
  END IF;

  PERFORM cron.schedule(
    'cleanup-expired-trashed-posts',
    '7 * * * *',
    format(
      $request$
      SELECT net.http_post(
        url := %L,
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'Authorization', %L
        ),
        body := '{}'::jsonb,
        timeout_milliseconds := 30000
      );
      $request$,
      rtrim(v_project_url, '/') || '/functions/v1/cleanup-trash',
      'Bearer ' || v_service_role_key
    )
  );
END
$$;
