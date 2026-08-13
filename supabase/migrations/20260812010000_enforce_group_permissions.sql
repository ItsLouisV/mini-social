-- Enforce group permissions at the database boundary.
-- UI checks are useful feedback, but RLS remains the source of truth.

create or replace function public.can_send_conversation_message(conv_id uuid)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1
    from public.conversations c
    join public.conversation_members cm on cm.conversation_id = c.id
    where c.id = conv_id
      and cm.user_id = auth.uid()
      and not exists (
        select 1
        from public.chat_blocks cb
        where c.type <> 'group'
          and (
            (cb.blocker_id = auth.uid()
              and cb.blocked_id = case
                when c.participant_1 = auth.uid() then c.participant_2
                else c.participant_1
              end)
            or
            (cb.blocked_id = auth.uid()
              and cb.blocker_id = case
                when c.participant_1 = auth.uid() then c.participant_2
                else c.participant_1
              end)
          )
      )
      and (
        c.type <> 'group'
        or (
          not (
            cm.is_muted_by_admin
            and (cm.muted_until is null or cm.muted_until > now())
          )
          and (
            cm.role in ('owner', 'admin')
            or not c.admin_only_messaging
          )
        )
      )
  );
$$;

create or replace function public.can_manage_conversation_pins(conv_id uuid)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1
    from public.conversations c
    join public.conversation_members cm on cm.conversation_id = c.id
    where c.id = conv_id
      and cm.user_id = auth.uid()
      and (
        c.type <> 'group'
        or cm.role in ('owner', 'admin')
        or c.allow_member_pin
      )
  );
$$;

create or replace function public.can_use_conversation_mention_all(
  conv_id uuid,
  message_body text
)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select
    coalesce(message_body, '') !~* '(^|[^[:alnum:]_])@(all|everyone)([^[:alnum:]_]|$)'
    or exists (
      select 1
      from public.conversations c
      join public.conversation_members cm on cm.conversation_id = c.id
      where c.id = conv_id
        and cm.user_id = auth.uid()
        and (
          c.type <> 'group'
          or cm.role in ('owner', 'admin')
          or c.allow_member_mention_all
        )
    );
$$;

create or replace function public.can_update_conversation_row(
  conv_id uuid,
  new_type text,
  new_created_by uuid,
  new_admin_only_messaging boolean,
  new_allow_member_invite boolean,
  new_allow_member_pin boolean,
  new_allow_member_mention_all boolean,
  new_allow_member_edit_info boolean
)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1
    from public.conversations c
    left join public.conversation_members actor
      on actor.conversation_id = c.id and actor.user_id = auth.uid()
    where c.id = conv_id
      and (
        (
          c.type <> 'group'
          and auth.uid() in (c.participant_1, c.participant_2)
        )
        or actor.role = 'owner'
        or (
          actor.role in ('admin', 'member')
          and (actor.role = 'admin' or c.allow_member_edit_info)
          and new_type is not distinct from c.type
          and new_created_by is not distinct from c.created_by
          and new_admin_only_messaging = c.admin_only_messaging
          and new_allow_member_invite = c.allow_member_invite
          and new_allow_member_pin = c.allow_member_pin
          and new_allow_member_mention_all = c.allow_member_mention_all
          and new_allow_member_edit_info = c.allow_member_edit_info
        )
        or (
          c.created_by = auth.uid()
          and new_created_by in (
            select owner_member.user_id
            from public.conversation_members owner_member
            where owner_member.conversation_id = c.id
              and owner_member.role = 'owner'
          )
        )
      )
  );
$$;

create or replace function public.can_invite_conversation_member(conv_id uuid)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1
    from public.conversations c
    join public.conversation_members cm on cm.conversation_id = c.id
    where c.id = conv_id
      and cm.user_id = auth.uid()
      and (
        c.type <> 'group'
        or cm.role in ('owner', 'admin')
        or c.allow_member_invite
      )
  );
$$;

create or replace function public.can_seed_conversation_member(
  conv_id uuid,
  target_user_id uuid,
  target_role text
)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1
    from public.conversations c
    where c.id = conv_id
      and not exists (
        select 1 from public.conversation_members existing
        where existing.conversation_id = c.id
      )
      and (
        (
          c.type = 'group'
          and c.created_by = auth.uid()
          and (
            (target_user_id = auth.uid() and target_role = 'owner')
            or target_role = 'member'
          )
        )
        or (
          c.type <> 'group'
          and auth.uid() in (c.participant_1, c.participant_2)
          and (
            (target_user_id = c.participant_1 and target_role = 'owner')
            or (target_user_id = c.participant_2 and target_role = 'member')
          )
        )
      )
  );
$$;

create or replace function public.can_remove_conversation_member(
  conv_id uuid,
  target_user_id uuid
)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select
    case
      when target_user_id = auth.uid() then
        exists (
          select 1 from public.conversation_members target
          where target.conversation_id = conv_id
            and target.user_id = target_user_id
            and (
              target.role <> 'owner'
              or not exists (
                select 1 from public.conversation_members other_member
                where other_member.conversation_id = conv_id
                  and other_member.user_id <> target_user_id
              )
            )
        )
      else exists (
        select 1
        from public.conversation_members actor
        join public.conversation_members target
          on target.conversation_id = actor.conversation_id
         and target.user_id = target_user_id
        where actor.conversation_id = conv_id
          and actor.user_id = auth.uid()
          and (
            actor.role = 'owner'
            or (actor.role = 'admin' and target.role = 'member')
          )
      )
    end;
$$;

drop policy if exists "Users send messages if not chat-blocked" on public.messages;
drop policy if exists "Users send permitted conversation messages" on public.messages;
create policy "Users send permitted conversation messages"
on public.messages for insert
with check (
  auth.uid() = sender_id
  and public.can_send_conversation_message(conversation_id)
  and public.can_use_conversation_mention_all(conversation_id, content)
);

drop policy if exists "Users can update conversations" on public.conversations;
drop policy if exists "Permitted users can update conversations" on public.conversations;
create policy "Permitted users can update conversations"
on public.conversations for update
using (
  public.can_update_conversation_row(
    id, type, created_by, admin_only_messaging, allow_member_invite,
    allow_member_pin, allow_member_mention_all, allow_member_edit_info
  )
)
with check (
  public.can_update_conversation_row(
    id, type, created_by, admin_only_messaging, allow_member_invite,
    allow_member_pin, allow_member_mention_all, allow_member_edit_info
  )
);

drop policy if exists "Participants pin messages" on public.pinned_messages;
drop policy if exists "Participants unpin messages" on public.pinned_messages;
drop policy if exists "Permitted members pin messages" on public.pinned_messages;
drop policy if exists "Permitted members unpin messages" on public.pinned_messages;

create policy "Permitted members pin messages"
on public.pinned_messages for insert
with check (public.can_manage_conversation_pins(conversation_id));

create policy "Permitted members unpin messages"
on public.pinned_messages for delete
using (public.can_manage_conversation_pins(conversation_id));

drop policy if exists "Users can insert conversation_members" on public.conversation_members;
drop policy if exists "Permitted users can insert conversation_members" on public.conversation_members;
create policy "Permitted users can insert conversation_members"
on public.conversation_members for insert
with check (
  public.can_seed_conversation_member(conversation_id, user_id, role)
  or (
    role = 'member'
    and public.can_invite_conversation_member(conversation_id)
  )
);

drop policy if exists "Users can delete conversation_members" on public.conversation_members;
drop policy if exists "Permitted users can delete conversation_members" on public.conversation_members;
create policy "Permitted users can delete conversation_members"
on public.conversation_members for delete
using (public.can_remove_conversation_member(conversation_id, user_id));

grant execute on function public.can_send_conversation_message(uuid) to authenticated;
grant execute on function public.can_manage_conversation_pins(uuid) to authenticated;
grant execute on function public.can_use_conversation_mention_all(uuid, text) to authenticated;
grant execute on function public.can_update_conversation_row(uuid, text, uuid, boolean, boolean, boolean, boolean, boolean) to authenticated;
grant execute on function public.can_invite_conversation_member(uuid) to authenticated;
grant execute on function public.can_seed_conversation_member(uuid, uuid, text) to authenticated;
grant execute on function public.can_remove_conversation_member(uuid, uuid) to authenticated;

-- Reliable message mutation RPCs. They avoid silent zero-row updates/deletes
-- caused by legacy RLS policies while keeping authorization server-side.
create or replace function public.recall_chat_message(p_message_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  target_message public.messages%rowtype;
begin
  select * into target_message
  from public.messages
  where id = p_message_id;

  if not found then
    raise exception 'Message not found';
  end if;
  if target_message.sender_id <> auth.uid() then
    raise exception 'Only the sender can recall this message';
  end if;

  update public.messages
  set content = 'Tin nhắn đã thu hồi',
      message_type = 'recalled',
      media_urls = null,
      media_url = null
  where id = p_message_id;
end;
$$;

create or replace function public.delete_chat_message(p_message_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  target_message public.messages%rowtype;
  is_participant boolean;
begin
  select * into target_message
  from public.messages
  where id = p_message_id;

  if not found then
    raise exception 'Message not found';
  end if;

  select exists (
    select 1 from public.conversations c
    where c.id = target_message.conversation_id
      and (
        auth.uid() in (c.participant_1, c.participant_2)
        or exists (
          select 1 from public.conversation_members cm
          where cm.conversation_id = c.id and cm.user_id = auth.uid()
        )
      )
  ) into is_participant;

  if not (
    (target_message.message_type = 'recalled' and is_participant)
    or exists (
      select 1
      from public.conversation_members actor
      join public.conversation_members sender
        on sender.conversation_id = actor.conversation_id
       and sender.user_id = target_message.sender_id
      where actor.conversation_id = target_message.conversation_id
        and actor.user_id = auth.uid()
        and actor.role in ('owner', 'admin')
        and sender.role = 'member'
        and sender.user_id <> actor.user_id
    )
  ) then
    raise exception 'You cannot delete this message';
  end if;

  delete from public.messages where id = p_message_id;
end;
$$;

revoke all on function public.recall_chat_message(uuid) from public;
revoke all on function public.delete_chat_message(uuid) from public;
grant execute on function public.recall_chat_message(uuid) to authenticated;
grant execute on function public.delete_chat_message(uuid) to authenticated;

-- Co-admins may revoke an existing ban, while creating bans remains owner-only.
drop policy if exists "group_bans_update_owner" on public.group_bans;
drop policy if exists "group_bans_update_admins" on public.group_bans;
create policy "group_bans_update_admins"
on public.group_bans for update
using (public.is_conversation_admin(conversation_id))
with check (public.is_conversation_admin(conversation_id));

-- Prevent users from changing protected membership fields on their own row.
-- Owner can moderate anyone below owner; co-admin can moderate members only.
create or replace function public.guard_conversation_member_protected_fields()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  actor_role text;
begin
  if new.is_muted_by_admin is not distinct from old.is_muted_by_admin
     and new.muted_until is not distinct from old.muted_until then
    return new;
  end if;

  select role into actor_role
  from public.conversation_members
  where conversation_id = old.conversation_id and user_id = auth.uid();

  if actor_role = 'owner' and old.role <> 'owner' then
    return new;
  end if;
  if actor_role = 'admin'
     and old.role = 'member'
     then
    return new;
  end if;

  raise exception 'You cannot change protected membership fields';
end;
$$;

drop trigger if exists guard_conversation_member_protected_fields
on public.conversation_members;
create trigger guard_conversation_member_protected_fields
before update on public.conversation_members
for each row execute function public.guard_conversation_member_protected_fields();
