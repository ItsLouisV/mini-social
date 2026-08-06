-- Migration: 20260806010000_conversations_refactor.sql
-- Description: Refactor conversations table, create conversation_members, migrate data and drop deprecated columns.

-- 1. Add new columns to public.conversations if not exist & drop NOT NULL on participant columns
alter table public.conversations 
  add column if not exists type text default 'direct',
  add column if not exists name text,
  add column if not exists avatar_url text,
  add column if not exists created_by uuid references profiles(id) on delete set null,
  add column if not exists last_message_id uuid references messages(id) on delete set null,
  add column if not exists last_message_sender_id uuid references profiles(id) on delete set null;

alter table public.conversations 
  alter column participant_1 drop not null,
  alter column participant_2 drop not null;

-- 2. Migrate existing group data from old columns (is_group, group_name, group_avatar_url, group_admin_id)
do $$ 
begin
  -- Update type to 'group' for old group conversations
  if exists (select 1 from information_schema.columns where table_schema='public' and table_name='conversations' and column_name='is_group') then
    execute 'update public.conversations set type = ''group'' where is_group = true';
  end if;

  if exists (select 1 from information_schema.columns where table_schema='public' and table_name='conversations' and column_name='group_name') then
    execute 'update public.conversations set name = group_name where name is null and group_name is not null';
  end if;

  if exists (select 1 from information_schema.columns where table_schema='public' and table_name='conversations' and column_name='group_avatar_url') then
    execute 'update public.conversations set avatar_url = group_avatar_url where avatar_url is null and group_avatar_url is not null';
  end if;

  if exists (select 1 from information_schema.columns where table_schema='public' and table_name='conversations' and column_name='group_admin_id') then
    execute 'update public.conversations set created_by = group_admin_id where created_by is null and group_admin_id is not null';
  end if;
end $$;

-- Set type check constraint
alter table public.conversations drop constraint if exists conversations_type_check;
alter table public.conversations add constraint conversations_type_check check (type in ('direct', 'group'));

-- 3. Create conversation_members table
create table if not exists public.conversation_members (
    id uuid primary key default gen_random_uuid(),
    conversation_id uuid not null references conversations(id) on delete cascade,
    user_id uuid not null references profiles(id) on delete cascade,
    role text default 'member' check (role in ('owner', 'admin', 'member')),
    joined_at timestamptz default now(),
    left_at timestamptz,
    unread_count integer default 0,
    last_read_message_id uuid,
    last_read_at timestamptz,
    is_hidden boolean default false,
    is_pinned boolean default false,
    is_muted boolean default false,
    nickname text,

    constraint unique_member unique(conversation_id, user_id)
);

-- 4. Migrate member records from old group_members or direct chats into conversation_members
do $$
begin
  if exists (select 1 from information_schema.tables where table_schema='public' and table_name='group_members') then
    execute '
      insert into public.conversation_members (conversation_id, user_id, role, joined_at)
      select 
        conversation_id, 
        user_id, 
        case 
          when role = ''admin'' then ''owner''
          when role = ''co_admin'' then ''admin''
          else ''member''
        end as role,
        joined_at
      from public.group_members
      on conflict (conversation_id, user_id) do nothing;
    ';
  end if;

  -- Migrate members for 1-1 direct chats
  insert into public.conversation_members (conversation_id, user_id, role)
  select id, participant_1, 'owner' from public.conversations where type = 'direct' and participant_1 is not null
  on conflict (conversation_id, user_id) do nothing;

  insert into public.conversation_members (conversation_id, user_id, role)
  select id, participant_2, 'member' from public.conversations where type = 'direct' and participant_2 is not null
  on conflict (conversation_id, user_id) do nothing;
end $$;

-- Now drop old group_members table if exists
drop table if exists public.group_members cascade;

-- 5. Deduplicate 1-1 direct conversations before creating unique index
delete from public.conversations a
using public.conversations b
where a.type = 'direct'
  and b.type = 'direct'
  and a.participant_1 = b.participant_1
  and a.participant_2 = b.participant_2
  and a.id < b.id;

-- 6. Drop deprecated columns from conversations table (per Section 6 of design plan)
alter table public.conversations
  drop column if exists is_group,
  drop column if exists group_admin_id,
  drop column if exists member_ids,
  drop column if exists group_name,
  drop column if exists group_avatar_url,
  drop column if exists p1_unread_count,
  drop column if exists p2_unread_count,
  drop column if exists p1_is_hidden,
  drop column if exists p2_is_hidden,
  drop column if exists p1_is_pinned,
  drop column if exists p2_is_pinned;

-- 7. Add constraints & indexes to conversations
alter table public.conversations drop constraint if exists conversations_check;
alter table public.conversations drop constraint if exists direct_check;
alter table public.conversations drop constraint if exists participant_order;

alter table public.conversations add constraint direct_check check (
    (type='direct' and participant_1 is not null and participant_2 is not null)
    or
    (type='group')
);

alter table public.conversations add constraint participant_order check (
    type='group' or participant_1 < participant_2
);

drop index if exists conversations_participant_1_participant_2_key;
drop index if exists conversations_unique_direct;

create unique index conversations_unique_direct
on conversations(participant_1, participant_2)
where type='direct';

create index if not exists idx_conv_p1 on conversations(participant_1);
create index if not exists idx_conv_p2 on conversations(participant_2);
create index if not exists idx_conv_last_message on conversations(last_message_at desc);

create index if not exists idx_cm_user on conversation_members(user_id);
create index if not exists idx_cm_conversation on conversation_members(conversation_id);
create index if not exists idx_cm_user_hidden on conversation_members(user_id, is_hidden);

-- 8. Enable RLS & Policies
alter table public.conversations enable row level security;
alter table public.conversation_members enable row level security;

-- Helper function: check if current user is member of a conversation (security definer to bypass RLS)
create or replace function public.is_conversation_member(conv_id uuid)
returns boolean
language sql
security definer
stable
as $$
  select exists (
    select 1 from public.conversation_members
    where conversation_id = conv_id
      and user_id = auth.uid()
  );
$$;

-- Helper function: check if current user is owner/admin of a conversation
create or replace function public.is_conversation_admin(conv_id uuid)
returns boolean
language sql
security definer
stable
as $$
  select exists (
    select 1 from public.conversation_members
    where conversation_id = conv_id
      and user_id = auth.uid()
      and role in ('owner', 'admin')
  );
$$;

-- SELECT: user can see own membership record OR records of conversations they belong to
drop policy if exists "Users can view conversation_members" on public.conversation_members;
create policy "Users can view conversation_members"
on public.conversation_members for select
using (
  auth.uid() = user_id
  or public.is_conversation_member(conversation_id)
);

-- INSERT: allow (server-side logic controls who gets inserted)
drop policy if exists "Users can insert conversation_members" on public.conversation_members;
create policy "Users can insert conversation_members"
on public.conversation_members for insert
with check (true);

-- UPDATE: user can update own record, or admin/owner can update any member in their conversation
drop policy if exists "Users can update conversation_members" on public.conversation_members;
create policy "Users can update conversation_members"
on public.conversation_members for update
using (
  auth.uid() = user_id
  or public.is_conversation_admin(conversation_id)
);

-- DELETE: user can remove themselves, or admin/owner can remove others
drop policy if exists "Users can delete conversation_members" on public.conversation_members;
create policy "Users can delete conversation_members"
on public.conversation_members for delete
using (
  auth.uid() = user_id
  or public.is_conversation_admin(conversation_id)
);

-- RLS Policies for public.conversations
drop policy if exists "Users can view conversations" on public.conversations;
create policy "Users can view conversations"
on public.conversations for select
using (
  created_by = auth.uid()
  or participant_1 = auth.uid()
  or participant_2 = auth.uid()
  or public.is_conversation_member(id)
);

drop policy if exists "Users can insert conversations" on public.conversations;
create policy "Users can insert conversations"
on public.conversations for insert
with check (true);

drop policy if exists "Users can update conversations" on public.conversations;
create policy "Users can update conversations"
on public.conversations for update
using (
  created_by = auth.uid()
  or participant_1 = auth.uid()
  or participant_2 = auth.uid()
  or public.is_conversation_member(id)
);

drop policy if exists "Users can delete conversations" on public.conversations;
create policy "Users can delete conversations"
on public.conversations for delete
using (
  created_by = auth.uid()
  or participant_1 = auth.uid()
  or participant_2 = auth.uid()
  or public.is_conversation_admin(id)
);

-- 9. Update Database Trigger for new message creation to use conversation_members
create or replace function public.update_last_message()
returns trigger as $$
begin
  -- Update last_message fields on conversations table
  update public.conversations
  set 
    last_message_id = new.id,
    last_message = new.content,
    last_message_at = new.created_at,
    last_message_sender_id = new.sender_id
  where id = new.conversation_id;

  -- Increment unread_count for all other members of the conversation in conversation_members
  update public.conversation_members
  set unread_count = unread_count + 1
  where conversation_id = new.conversation_id
    and user_id != new.sender_id;

  return new;
end;
$$ language plpgsql security definer;

-- Re-attach trigger on messages table
drop trigger if exists on_message_created on public.messages;
create trigger on_message_created
  after insert on public.messages
  for each row execute procedure public.update_last_message();

-- Remove obsolete set_seen_at trigger if it references p1_unread_count
drop trigger if exists on_message_seen on public.messages;
drop function if exists public.set_seen_at();

-- 10. Helper function to mark conversation as read for current user
create or replace function public.mark_conversation_read(p_conversation_id uuid)
returns void
language plpgsql
security definer
as $$
begin
  update public.conversation_members
  set 
    unread_count = 0,
    last_read_at = now()
  where conversation_id = p_conversation_id
    and user_id = auth.uid();

  update public.messages
  set is_seen = true
  where conversation_id = p_conversation_id
    and sender_id != auth.uid()
    and is_seen = false;
end;
$$;

-- 11. Update RLS Policies for pinned_messages table
alter table public.pinned_messages enable row level security;

drop policy if exists "Participants view pinned messages" on public.pinned_messages;
create policy "Participants view pinned messages" on public.pinned_messages for select using (
  public.is_conversation_member(conversation_id)
);

drop policy if exists "Participants pin messages" on public.pinned_messages;
create policy "Participants pin messages" on public.pinned_messages for insert with check (
  public.is_conversation_member(conversation_id)
);

drop policy if exists "Participants unpin messages" on public.pinned_messages;
create policy "Participants unpin messages" on public.pinned_messages for delete using (
  public.is_conversation_member(conversation_id)
);

-- 12. Add conversation_members to Realtime Publication
do $$
begin
  if not exists (
    select 1 from pg_publication_tables 
    where pubname = 'supabase_realtime' 
      and schemaname = 'public' 
      and tablename = 'conversation_members'
  ) then
    alter publication supabase_realtime add table public.conversation_members;
  end if;
end $$;
