create table if not exists public.hidden_passcode_recovery_codes (
  user_id uuid primary key references auth.users(id) on delete cascade,
  code_hash text not null,
  expires_at timestamptz not null,
  attempts smallint not null default 0 check (attempts between 0 and 5),
  last_sent_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

alter table public.hidden_passcode_recovery_codes enable row level security;

comment on table public.hidden_passcode_recovery_codes is
  'Server-only, short-lived codes used to recover a hidden-conversation PIN.';

