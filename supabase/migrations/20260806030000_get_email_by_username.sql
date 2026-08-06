-- Migration: 20260806030000_get_email_by_username.sql
-- Description: Add get_email_by_username RPC for username login support

create or replace function public.get_email_by_username(p_username text)
returns text
language plpgsql
security definer
as $$
declare
  v_email text;
begin
  select email into v_email
  from public.profiles
  where lower(username) = lower(p_username)
  limit 1;

  return v_email;
end;
$$;

-- Grant execution to anonymous (unauthenticated) and authenticated users
grant execute on function public.get_email_by_username(text) to anon, authenticated;
