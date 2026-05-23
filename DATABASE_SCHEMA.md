# 🗄 Database Schema — Supabase (v2)

> Tất cả các bảng chạy trên PostgreSQL qua Supabase.  
> UUID dùng `gen_random_uuid()`. `created_at` mặc định `now()`.

---

## Tổng quan thay đổi so với v1

| Vấn đề cũ                                              | Giải pháp mới                                                            |
| ------------------------------------------------------ | ------------------------------------------------------------------------ |
| `posts.media_urls text[]` — không query được từng file | Tách thành bảng `post_media` riêng                                       |
| Thiếu `friend_requests` — không có add friend / cancel | Thêm bảng `friend_requests` với `status` enum                            |
| `comments` không có reply                              | Thêm `parent_id` tự tham chiếu                                           |
| `conversations.last_message text` — dễ lệch dữ liệu    | Đổi thành `last_message_id FK` trỏ vào `messages`                        |
| `notifications` không biết comment nào trigger         | Thêm `comment_id FK` + type `reply` / `friend_request` / `friend_accept` |
| `messages` thiếu thời điểm đã xem                      | Thêm `seen_at timestamptz`                                               |

---

## 1. `profiles` — Thông tin người dùng

```sql
create table profiles (
  id          uuid primary key references auth.users(id) on delete cascade,
  email       text,
  username    text unique not null,
  full_name   text,
  bio         text,
  avatar_url  text,
  cover_url   text,
  created_at  timestamptz default now()
);

-- Trigger: tự tạo profile khi user đăng ký
create extension if not exists unaccent;

create or replace function handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
  base_username  text;
  final_username text;
begin
  -- lấy phần trước @
  base_username := split_part(new.email, '@', 1);

  -- bỏ dấu tiếng Việt
  base_username := public.unaccent(base_username);

  -- lowercase
  base_username := lower(base_username);

  -- chỉ giữ a-z 0-9 . _
  base_username := regexp_replace(
    base_username,
    '[^a-z0-9._]',
    '',
    'g'
  );

  -- fallback nếu quá ngắn
  if length(base_username) < 3 then
    base_username := 'user';
  end if;

  -- giới hạn độ dài
  base_username := left(base_username, 20);

  final_username := base_username;

  -- loop tới khi insert thành công
  loop
    begin
      insert into public.profiles (
        id,
        email,
        username,
        full_name
      )
      values (
        new.id,
        new.email,
        final_username,
        coalesce(
          new.raw_user_meta_data->>'full_name',
          base_username
        )
      );

      exit;

    exception when unique_violation then
      final_username :=
        base_username || '.' ||
        left(
          encode(gen_random_bytes(4), 'hex'),
          6
        );
    end;
  end loop;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure handle_new_user();
```

---

## 2. `posts` — Bài viết

```sql
create table posts (
  id             uuid primary key default gen_random_uuid(),
  user_id        uuid references profiles(id) on delete cascade not null,
  caption        text,
  likes_count    int default 0,
  comments_count int default 0,
  created_at     timestamptz default now()
);
```

> `media_urls` và `media_type` đã bỏ — chuyển sang bảng `post_media`.

---

## 3. `post_media` — File đính kèm của bài viết ⭐ mới

> Tách riêng để query từng file, lưu thứ tự, phân biệt ảnh/video.

```sql
create table post_media (
  id          uuid primary key default gen_random_uuid(),
  post_id     uuid references posts(id) on delete cascade not null,
  url         text not null,
  type        text not null default 'image',  -- 'image' | 'video'
  order_index int  not null default 0,        -- thứ tự hiển thị (0-based)
  created_at  timestamptz default now()
);

create index on post_media (post_id, order_index);
```

**Cách dùng:**

```sql
-- Lấy toàn bộ media của 1 post, đúng thứ tự
select * from post_media
where post_id = '...'
order by order_index asc;
```

---

## 4. `likes` — Like bài viết

```sql
create table likes (
  id         uuid primary key default gen_random_uuid(),
  post_id    uuid references posts(id) on delete cascade not null,
  user_id    uuid references profiles(id) on delete cascade not null,
  created_at timestamptz default now(),
  unique (post_id, user_id)
);

-- Trigger: cập nhật likes_count trên posts
create or replace function update_likes_count()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  if TG_OP = 'INSERT' then
    update posts set likes_count = coalesce(likes_count, 0) + 1 where id = NEW.post_id;
  elsif TG_OP = 'DELETE' then
    update posts set likes_count = greatest(coalesce(likes_count, 0) - 1, 0) where id = OLD.post_id;
  end if;
  return null;
end;
$$;

create trigger likes_count_trigger
  after insert or delete on likes
  for each row execute procedure update_likes_count();
```

---

## 5. `comments` — Bình luận (có reply) ⭐ cập nhật

```sql
create table comments (
  id          uuid primary key default gen_random_uuid(),
  post_id     uuid references posts(id) on delete cascade not null,
  user_id     uuid references profiles(id) on delete cascade not null,
  parent_id   uuid references comments(id) on delete cascade,  -- null = top-level, có giá trị = reply
  content     text not null,
  likes_count int default 0,
  created_at  timestamptz default now()
);

-- Index để lấy replies của 1 comment nhanh
create index on comments (parent_id) where parent_id is not null;
-- Index để lấy top-level comments của 1 post
create index on comments (post_id, created_at) where parent_id is null;

-- Trigger: cộng comments_count cho TẤT CẢ comment (bao gồm cả reply)
create or replace function update_comments_count()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  if TG_OP = 'INSERT' then
    update posts set comments_count = coalesce(comments_count, 0) + 1 where id = NEW.post_id;
  elsif TG_OP = 'DELETE' then
    update posts set comments_count = greatest(coalesce(comments_count, 0) - 1, 0) where id = OLD.post_id;
  end if;
  return null;
end;
$$;

create trigger comments_count_trigger
  after insert or delete on comments
  for each row execute procedure update_comments_count();
```

**Cách dùng:**

```sql
-- Lấy top-level comments của 1 post
select * from comments
where post_id = '...' and parent_id is null
order by created_at asc;

-- Lấy replies của 1 comment
select * from comments
where parent_id = '...'
order by created_at asc;
```

---

## 5b. `comment_likes` — Like bình luận ⭐ mới

```sql
create table comment_likes (
  id         uuid primary key default gen_random_uuid(),
  comment_id uuid references comments(id) on delete cascade not null,
  user_id    uuid references profiles(id) on delete cascade not null,
  created_at timestamptz default now(),
  unique (comment_id, user_id)
);

-- Trigger: tự động tăng/giảm likes_count mỗi khi có người like/unlike
create or replace function update_comment_likes_count()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  if TG_OP = 'INSERT' then
    update comments set likes_count = coalesce(likes_count, 0) + 1 where id = NEW.comment_id;
  elsif TG_OP = 'DELETE' then
    update comments set likes_count = greatest(coalesce(likes_count, 0) - 1, 0) where id = OLD.comment_id;
  end if;
  return null;
end;
$$;

create trigger comment_likes_count_trigger
  after insert or delete on comment_likes
  for each row execute procedure update_comment_likes_count();

-- Row Level Security
alter table comment_likes enable row level security;

create policy "Cho phép xem lượt thích bình luận"
on comment_likes for select using (true);

create policy "Cho phép thêm lượt thích"
on comment_likes for insert with check (auth.uid() = user_id);

create policy "Cho phép huỷ lượt thích"
on comment_likes for delete using (auth.uid() = user_id);
```

---

## 6. `follows` — Follow / Unfollow (một chiều)

> Quan hệ follow kiểu Instagram — không cần xác nhận.

```sql
create table follows (
  id           uuid primary key default gen_random_uuid(),
  follower_id  uuid references profiles(id) on delete cascade not null,
  following_id uuid references profiles(id) on delete cascade not null,
  created_at   timestamptz default now(),
  unique (follower_id, following_id),
  check (follower_id <> following_id)
);

create index on follows (follower_id);
create index on follows (following_id);
```

---

## 7. `friend_requests` — Kết bạn (hai chiều) ⭐ mới

> Quan hệ bạn bè kiểu Facebook — cần xác nhận hai chiều, có trạng thái.

```sql
create type friend_request_status as enum (
  'pending',    -- đã gửi, chờ phản hồi
  'accepted',   -- đã chấp nhận → là bạn bè
  'rejected',   -- đã từ chối
  'cancelled'   -- người gửi tự huỷ trước khi được chấp nhận
);

create table friend_requests (
  id          uuid primary key default gen_random_uuid(),
  sender_id   uuid references profiles(id) on delete cascade not null,
  receiver_id uuid references profiles(id) on delete cascade not null,
  status      friend_request_status not null default 'pending',
  created_at  timestamptz default now(),
  updated_at  timestamptz default now(),
  unique (sender_id, receiver_id),
  check (sender_id <> receiver_id)
);

create index on friend_requests (receiver_id, status);
create index on friend_requests (sender_id, status);

-- Trigger: tự cập nhật updated_at khi đổi status
create or replace function set_updated_at()
returns trigger as $$
begin
  NEW.updated_at = now();
  return NEW;
end;
$$ language plpgsql;

create trigger friend_requests_updated_at
  before update on friend_requests
  for each row execute procedure set_updated_at();
```

**Cách dùng:**

```sql
-- Gửi lời mời kết bạn
insert into friend_requests (sender_id, receiver_id)
values ('userA', 'userB');

-- Chấp nhận
update friend_requests
set status = 'accepted'
where sender_id = 'userA' and receiver_id = 'userB';

-- Huỷ lời mời (người gửi tự huỷ)
update friend_requests
set status = 'cancelled'
where sender_id = 'userA' and receiver_id = 'userB';

-- Kiểm tra 2 người có phải bạn bè không
select exists (
  select 1 from friend_requests
  where status = 'accepted'
    and (
      (sender_id = 'userA' and receiver_id = 'userB') or
      (sender_id = 'userB' and receiver_id = 'userA')
    )
);

-- Lấy danh sách bạn bè của 1 user
select
  case when sender_id = 'userA' then receiver_id else sender_id end as friend_id
from friend_requests
where status = 'accepted'
  and (sender_id = 'userA' or receiver_id = 'userA');
```

---

## 8. `notifications` — Thông báo ⭐ cập nhật

> **Thiết kế:** Flat table với đúng 3 cột nullable — mỗi loại thông báo chỉ dùng cột cần thiết, còn lại để `null`. Không cần bảng trung gian, query 1 lần là đủ.

```
type             post_id   comment_id   navigate đến
────────────────────────────────────────────────────────────────────────
like           │   ✓    │    null    │ PostDetailScreen
comment        │   ✓    │     ✓      │ PostDetailScreen (cuộn đến comment)
reply          │   ✓    │     ✓      │ PostDetailScreen (cuộn đến reply)
follow         │  null  │    null    │ ProfileScreen (sender_id)
friend_request │  null  │    null    │ ProfileScreen (sender_id)
friend_accept  │  null  │    null    │ ProfileScreen (sender_id)
```

```sql
create type notification_type as enum (
  'like',
  'comment',
  'reply',           -- reply vào comment của mình
  'follow',
  'friend_request',  -- có người gửi lời mời kết bạn
  'friend_accept'    -- lời mời kết bạn được chấp nhận
);

create table notifications (
  id              uuid primary key default gen_random_uuid(),
  receiver_id     uuid references profiles(id) on delete cascade not null,
  sender_id       uuid references profiles(id) on delete cascade not null,
  type            notification_type not null,

  -- Các cột nullable — mỗi loại chỉ dùng đúng cột cần thiết
  post_id         uuid references posts(id)         on delete cascade,
  comment_id      uuid references comments(id)      on delete cascade,
  content         text,                             -- Nội dung thông báo (vd: nội dung comment)

  is_read         boolean default false,
  created_at      timestamptz default now()
);

create index on notifications (receiver_id, is_read, created_at desc);
```

**Query phía Flutter — chỉ 1 lần, lấy đủ mọi thứ:**

```sql
select
  n.*,
  p.username,
  p.full_name,
  p.avatar_url
from notifications n
join profiles p on p.id = n.sender_id
where n.receiver_id = auth.uid()
order by n.created_at desc
limit 20;
```

**DB Functions tự tạo notification:**

```sql
-- Khi có like mới
create or replace function notify_on_like()
returns trigger as $$
declare post_owner uuid;
begin
  select user_id into post_owner from posts where id = NEW.post_id;
  -- Không thông báo khi tự like bài của mình
  if post_owner <> NEW.user_id then
    insert into notifications (receiver_id, sender_id, type, post_id)
    values (post_owner, NEW.user_id, 'like', NEW.post_id);
  end if;
  return NEW;
end;
$$ language plpgsql security definer;

create trigger on_like_created
  after insert on likes
  for each row execute procedure notify_on_like();

-- Khi có comment / reply mới
create or replace function notify_on_comment()
returns trigger as $$
declare
  post_owner   uuid;
  parent_owner uuid;
begin
  select user_id into post_owner from posts where id = NEW.post_id;

  if NEW.parent_id is null then
    -- Comment gốc → thông báo chủ bài
    if post_owner <> NEW.user_id then
      insert into notifications (receiver_id, sender_id, type, post_id, comment_id)
      values (post_owner, NEW.user_id, 'comment', NEW.post_id, NEW.id);
    end if;
  else
    -- Reply → thông báo người viết comment gốc
    select user_id into parent_owner from comments where id = NEW.parent_id;
    if parent_owner <> NEW.user_id then
      insert into notifications (receiver_id, sender_id, type, post_id, comment_id)
      values (parent_owner, NEW.user_id, 'reply', NEW.post_id, NEW.id);
    end if;
  end if;
  return NEW;
end;
$$ language plpgsql security definer;

create trigger on_comment_created
  after insert on comments
  for each row execute procedure notify_on_comment();

-- Khi có follow mới
create or replace function notify_on_follow()
returns trigger as $$
begin
  -- sender_id đã có đủ thông tin để navigate đến profile → không cần thêm cột
  insert into notifications (receiver_id, sender_id, type)
  values (NEW.following_id, NEW.follower_id, 'follow');
  return NEW;
end;
$$ language plpgsql security definer;

create trigger on_follow_created
  after insert on follows
  for each row execute procedure notify_on_follow();

-- Khi có friend_request / friend_accept
create or replace function notify_on_friend_request()
returns trigger as $$
begin
  if TG_OP = 'INSERT' then
    insert into notifications (receiver_id, sender_id, type)
    values (NEW.receiver_id, NEW.sender_id, 'friend_request');
  elsif TG_OP = 'UPDATE' and NEW.status = 'accepted' and OLD.status = 'pending' then
    insert into notifications (receiver_id, sender_id, type)
    values (NEW.sender_id, NEW.receiver_id, 'friend_accept');
  end if;
  return NEW;
end;
$$ language plpgsql security definer;

create trigger on_friend_request_changed
  after insert or update on friend_requests
  for each row execute procedure notify_on_friend_request();

```

**Phía Flutter — navigate khi nhấn thông báo:**

````dart
void onTapNotification(NotificationModel n) {
  switch (n.type) {
    case 'like':
    case 'comment':
    case 'reply':
      context.push('/feed/post/${n.postId}');

    case 'follow':
    case 'friend_request':
    case 'friend_accept':
      context.push('/profile/${n.senderId}');
  }
}

---

## 9. `conversations` — Cuộc trò chuyện ⭐ cập nhật

```sql
create table conversations (
  id              uuid primary key default gen_random_uuid(),
  participant_1   uuid references profiles(id) on delete cascade not null,
  participant_2   uuid references profiles(id) on delete cascade not null,
  last_message    text,               -- nội dung tin nhắn cuối ⭐
  last_message_at timestamptz,        -- thời điểm tin nhắn cuối ⭐
  last_message_id uuid,               -- FK trỏ vào messages
  p1_unread_count int default 0,      -- đếm tin nhắn chưa đọc của người 1
  p2_unread_count int default 0,      -- đếm tin nhắn chưa đọc của người 2
  p1_is_pinned    boolean default false, -- ghim hội thoại cho người 1
  p2_is_pinned    boolean default false, -- ghim hội thoại cho người 2
  p1_is_hidden    boolean default false, -- ẩn hội thoại cho người 1
  p2_is_hidden    boolean default false, -- ẩn hội thoại cho người 2
  created_at      timestamptz default now(),
  unique (participant_1, participant_2),
  check (participant_1 < participant_2)  -- enforce thứ tự để tránh duplicate (A,B) vs (B,A)
);

create index on conversations (participant_1);
create index on conversations (participant_2);
````

> Khi insert luôn dùng `least()` / `greatest()` để đảm bảo thứ tự UUID:

```sql
insert into conversations (participant_1, participant_2)
values (least('userA'::uuid, 'userB'::uuid), greatest('userA'::uuid, 'userB'::uuid))
on conflict do nothing;
```

---

## 10. `messages` — Tin nhắn ⭐ cập nhật

```sql
create table messages (
  id              uuid primary key default gen_random_uuid(),
  conversation_id uuid references conversations(id) on delete cascade not null,
  sender_id       uuid references profiles(id) on delete cascade not null,
  content         text,
  media_url       text,
  message_type    text not null default 'text',  -- 'text' | 'image' | 'voice'
  is_seen         boolean default false,
  seen_at         timestamptz,                   -- thời điểm đã xem ⭐
  reply_to_message_id uuid references messages(id) on delete set null, -- reply tin nhắn ⭐
  created_at      timestamptz default now()
);

create index on messages (conversation_id, created_at desc);

-- Thêm FK last_message_id sau khi tạo bảng messages
alter table conversations
  add constraint fk_last_message
  foreign key (last_message_id) references messages(id) on delete set null;

-- Trigger: tự cập nhật last_message_id và đếm số chưa đọc
create or replace function update_last_message()
returns trigger as $$
declare
  conv_p1 uuid;
  conv_p2 uuid;
begin
  select participant_1, participant_2 into conv_p1, conv_p2 
  from conversations where id = NEW.conversation_id;

  update conversations
  set 
    last_message_id = NEW.id,
    last_message = NEW.content,
    last_message_at = NEW.created_at,
    p1_unread_count = case when NEW.sender_id = conv_p2 then p1_unread_count + 1 else p1_unread_count end,
    p2_unread_count = case when NEW.sender_id = conv_p1 then p2_unread_count + 1 else p2_unread_count end
  where id = NEW.conversation_id;
  
  return NEW;
end;
$$ language plpgsql;

create trigger on_message_created
  after insert on messages
  for each row execute procedure update_last_message();

-- Trigger: tự set seen_at và reset số lượng chưa đọc khi mark as seen
create or replace function set_seen_at()
returns trigger as $$
declare
  conv_p1 uuid;
  conv_p2 uuid;
begin
  if NEW.is_seen = true and OLD.is_seen = false then
    NEW.seen_at = now();
    
    select participant_1, participant_2 into conv_p1, conv_p2 
    from conversations where id = NEW.conversation_id;

    update conversations
    set 
      p1_unread_count = case when NEW.sender_id = conv_p2 then 0 else p1_unread_count end,
      p2_unread_count = case when NEW.sender_id = conv_p1 then 0 else p2_unread_count end
    where id = NEW.conversation_id;
  end if;
  return NEW;
end;
$$ language plpgsql;

create trigger on_message_seen
  before update on messages
  for each row execute procedure set_seen_at();
```

## 9b. `conversation_settings` — Ghim conversation (per user)

> Mỗi người có thể ghim/bỏ ghim conv độc lập với nhau.  
> Tách ra bảng riêng vì đây là dữ liệu **per-user**, không phải dữ liệu chung của conv.

```sql
create table conversation_settings (
  user_id         uuid references profiles(id)      on delete cascade,
  conversation_id uuid references conversations(id) on delete cascade,
  is_pinned       boolean default false,
  pinned_at       timestamptz,          -- để sort conv ghim theo thứ tự ghim
  primary key (user_id, conversation_id)
);

create index on conversation_settings (user_id, is_pinned, pinned_at desc);

-- Trigger: tự set pinned_at khi ghim / xoá khi bỏ ghim
create or replace function set_conv_pinned_at()
returns trigger as $$
begin
  if NEW.is_pinned = true and (OLD.is_pinned is distinct from true) then
    NEW.pinned_at = now();
  elsif NEW.is_pinned = false then
    NEW.pinned_at = null;
  end if;
  return NEW;
end;
$$ language plpgsql;

create trigger conversation_settings_pinned_at
  before insert or update on conversation_settings
  for each row execute procedure set_conv_pinned_at();
```

**Ghim / bỏ ghim conv:**

```sql
-- Ghim conv
insert into conversation_settings (user_id, conversation_id, is_pinned)
values (auth.uid(), 'conv_id', true)
on conflict (user_id, conversation_id)
do update set is_pinned = true;

-- Bỏ ghim conv
update conversation_settings
set is_pinned = false
where user_id = auth.uid() and conversation_id = 'conv_id';
```

**RLS:**

```sql
alter table conversation_settings enable row level security;

create policy "Users manage own conversation settings" on conversation_settings
  for all using (auth.uid() = user_id);
```

---

## 9c. `pinned_messages` — Ghim tin nhắn trong conv ⭐ mới

> Mỗi conv có thể ghim **nhiều tin nhắn**.  
> `unique (conversation_id, message_id)` đảm bảo 1 tin không bị ghim 2 lần.  
> Chung cho cả 2 người trong conv — ai cũng thấy danh sách ghim như nhau.

```sql
create table pinned_messages (
  id              uuid primary key default gen_random_uuid(),
  conversation_id uuid references conversations(id) on delete cascade not null,
  message_id      uuid references messages(id)      on delete cascade not null,
  pinned_by       uuid references profiles(id)      on delete cascade not null,
  pinned_at       timestamptz default now(),
  unique (conversation_id, message_id)   -- 1 tin chỉ được ghim 1 lần trong conv
);

create index on pinned_messages (conversation_id, pinned_at desc);
```

**Ghim / bỏ ghim tin nhắn:**

```sql
-- Ghim tin nhắn
insert into pinned_messages (conversation_id, message_id, pinned_by)
values ('conv_id', 'message_id', auth.uid())
on conflict do nothing;

-- Bỏ ghim tin nhắn
delete from pinned_messages
where conversation_id = 'conv_id' and message_id = 'message_id';
```

**Lấy danh sách tin nhắn đã ghim trong 1 conv:**

```sql
select
  pm.id,
  pm.pinned_at,
  m.content,
  m.message_type,
  m.created_at     as message_created_at,
  p.username       as sender_username,
  p.avatar_url     as sender_avatar,
  pb.username      as pinned_by_username
from pinned_messages pm
join messages  m  on m.id  = pm.message_id
join profiles  p  on p.id  = m.sender_id
join profiles  pb on pb.id = pm.pinned_by
where pm.conversation_id = 'conv_id'
order by pm.pinned_at desc;
```

**RLS:**

```sql
alter table pinned_messages enable row level security;

create policy "Participants view pinned messages" on pinned_messages
  for select using (
    auth.uid() in (
      select participant_1 from conversations where id = conversation_id
      union
      select participant_2 from conversations where id = conversation_id
    )
  );

create policy "Participants pin messages" on pinned_messages
  for insert with check (
    auth.uid() = pinned_by and
    auth.uid() in (
      select participant_1 from conversations where id = conversation_id
      union
      select participant_2 from conversations where id = conversation_id
    )
  );

create policy "Participants unpin messages" on pinned_messages
  for delete using (
    auth.uid() in (
      select participant_1 from conversations where id = conversation_id
      union
      select participant_2 from conversations where id = conversation_id
    )
  );
```

---

## 11. Storage Buckets

```sql
insert into storage.buckets (id, name, public) values
  ('avatars',  'avatars',  true),
  ('covers',   'covers',   true),
  ('posts',    'posts',    true),
  ('messages', 'messages', true);  -- public=true để getPublicUrl() hoạt động
```

### Quy ước đường dẫn file

| Bucket   | Path                               | Ví dụ                  |
| -------- | ---------------------------------- | ---------------------- |
| avatars  | `{userId}/avatar.jpg`              | `abc123/avatar.jpg`    |
| covers   | `{userId}/cover.jpg`               | `abc123/cover.jpg`     |
| posts    | `{userId}/{postId}/{index}.jpg`    | `abc123/post456/0.jpg` |
| messages | `{userId}/{conversationId}/{messageId}.jpg` | `abc123/conv789/msg012.jpg` |

### Storage Policies (RLS)

```sql
-- Avatars: public read, chủ sở hữu mới upload/delete
create policy "Public read avatars"  on storage.objects for select using (bucket_id = 'avatars');
create policy "Upload own avatar"    on storage.objects for insert with check (
  bucket_id = 'avatars' and auth.uid()::text = (storage.foldername(name))[1]
);
create policy "Delete own avatar"    on storage.objects for delete using (
  bucket_id = 'avatars' and auth.uid()::text = (storage.foldername(name))[1]
);

-- Posts: public read, chủ sở hữu mới upload/delete
create policy "Public read posts"       on storage.objects for select using (bucket_id = 'posts');
create policy "Upload own post media"   on storage.objects for insert with check (
  bucket_id = 'posts' and auth.uid()::text = (storage.foldername(name))[1]
);
create policy "Delete own post media"   on storage.objects for delete using (
  bucket_id = 'posts' and auth.uid()::text = (storage.foldername(name))[1]
);

-- Messages: public read, chỉ participant (folder = userId) mới upload/xoá
create policy "Public read message files" on storage.objects for select using (
  bucket_id = 'messages'
);
create policy "Users upload message images" on storage.objects for insert with check (
  bucket_id = 'messages' and auth.uid()::text = (storage.foldername(name))[1]
);
create policy "Users update own message files" on storage.objects for update using (
  bucket_id = 'messages' and auth.uid()::text = (storage.foldername(name))[1]
);
create policy "Users delete own message files" on storage.objects for delete using (
  bucket_id = 'messages' and auth.uid()::text = (storage.foldername(name))[1]
);
```

---

## 12. Row Level Security (RLS)

```sql
-- profiles
alter table profiles enable row level security;
create policy "Profiles viewable by everyone" on profiles for select using (true);
create policy "Users update own profile"      on profiles for update using (auth.uid() = id);

-- posts
alter table posts enable row level security;
create policy "Posts viewable by everyone" on posts for select using (true);
create policy "Users create own posts"     on posts for insert with check (auth.uid() = user_id);
create policy "Users delete own posts"     on posts for delete using (auth.uid() = user_id);

-- post_media
alter table post_media enable row level security;
create policy "Post media viewable by everyone" on post_media for select using (true);
create policy "Users insert own post media"     on post_media for insert with check (
  auth.uid() = (select user_id from posts where id = post_id)
);
create policy "Users delete own post media"     on post_media for delete using (
  auth.uid() = (select user_id from posts where id = post_id)
);

-- likes
alter table likes enable row level security;
create policy "Likes viewable by everyone" on likes for select using (true);
create policy "Users manage own likes"     on likes for all   using (auth.uid() = user_id);

-- comments
alter table comments enable row level security;
create policy "Comments viewable by everyone" on comments for select using (true);
create policy "Users create comments"         on comments for insert with check (auth.uid() = user_id);
create policy "Users delete own comments"     on comments for delete using (auth.uid() = user_id);

-- comment_likes
alter table comment_likes enable row level security;
create policy "Comment likes viewable by everyone" on comment_likes for select using (true);
create policy "Users manage own comment likes"     on comment_likes for all   using (auth.uid() = user_id);

-- follows
alter table follows enable row level security;
create policy "Follows viewable by everyone" on follows for select using (true);
create policy "Users manage own follows"     on follows for all   using (auth.uid() = follower_id);

-- friend_requests
alter table friend_requests enable row level security;
create policy "Users view own friend requests"   on friend_requests
  for select using (auth.uid() = sender_id or auth.uid() = receiver_id);
create policy "Users send friend requests"       on friend_requests
  for insert with check (auth.uid() = sender_id);
create policy "Users respond to friend requests" on friend_requests
  for update using (auth.uid() = sender_id or auth.uid() = receiver_id);

-- notifications
alter table notifications enable row level security;
create policy "Users view own notifications"       on notifications
  for select using (auth.uid() = receiver_id);
create policy "Users mark notifications as read"   on notifications
  for update using (auth.uid() = receiver_id);

-- conversations
alter table conversations enable row level security;
create policy "Participants view conversations" on conversations
  for select using (auth.uid() = participant_1 or auth.uid() = participant_2);
create policy "Users create conversations"      on conversations
  for insert with check (auth.uid() = participant_1 or auth.uid() = participant_2);

-- messages
alter table messages enable row level security;
create policy "Participants view messages" on messages
  for select using (
    auth.uid() = sender_id or
    auth.uid() in (
      select participant_1 from conversations where id = conversation_id
      union
      select participant_2 from conversations where id = conversation_id
    )
  );
create policy "Users send messages"    on messages
  for insert with check (auth.uid() = sender_id);
create policy "Mark messages as seen"  on messages
  for update using (
    auth.uid() in (
      select participant_1 from conversations where id = conversation_id
      union
      select participant_2 from conversations where id = conversation_id
    )
  );

-- calls
alter table calls enable row level security;
create policy "Participants view calls" on calls
  for select using (auth.uid() = caller_id or auth.uid() = callee_id);
create policy "Users create calls" on calls
  for insert with check (auth.uid() = caller_id);
create policy "Participants update call status" on calls
  for update using (auth.uid() = caller_id or auth.uid() = callee_id);
```

---

## 13. Realtime

```sql
-- Thêm các bảng cần đồng bộ realtime vào publication
alter publication supabase_realtime add table posts;
alter publication supabase_realtime add table likes;
alter publication supabase_realtime add table comments;
alter publication supabase_realtime add table comment_likes;
alter publication supabase_realtime add table conversations;
alter publication supabase_realtime add table messages;
alter publication supabase_realtime add table notifications;
alter publication supabase_realtime add table calls;
```

---

## 14. Sơ đồ quan hệ tóm tắt

```
profiles ──< posts ──< post_media
         ──< likes        >── posts
         ──< comments     >── posts  (self-ref: parent_id cho reply)
         ──< follows      >── profiles
         ──< friend_requests >── profiles  (pending/accepted/rejected/cancelled)
         ──< notifications
         ──< messages     >── conversations >── profiles (x2)
         ──< calls        >── conversations >── profiles (x2)
```

| Quan hệ             | Bảng                     | Cardinality                |
| ------------------- | ------------------------ | -------------------------- |
| User viết bài       | profiles → posts         | 1:N                        |
| Bài có media        | posts → post_media       | 1:N                        |
| User like bài       | likes                    | N:M (unique constraint)    |
| User comment bài    | comments → posts         | N:1                        |
| Comment có reply    | comments → comments      | 1:N (parent_id)            |
| User follow user    | follows                  | N:M (một chiều)            |
| User kết bạn user   | friend_requests          | N:M (hai chiều, có status) |
| User nhận thông báo | notifications            | N:1                        |
| User chat user      | conversations + messages | N:M                        |
| User gọi user       | calls                    | N:M                        |

---

## 15. `calls` — Cuộc gọi thoại & Video

```sql
create type call_status as enum (
  'ringing',   -- đang đổ chuông
  'accepted',  -- đã chấp nhận, đang kết nối
  'declined',  -- bị từ chối
  'ended',     -- đã kết thúc
  'missed',    -- không nhấc máy (timeout 60s)
  'cancelled'  -- người gọi tự huỷ trước khi được nhấc
);

create type call_type as enum ('voice', 'video');

create table calls (
  id              uuid primary key default gen_random_uuid(),
  conversation_id uuid references conversations(id) on delete cascade not null,
  caller_id       uuid references profiles(id)      on delete cascade not null,
  callee_id       uuid references profiles(id)      on delete cascade not null,
  type            call_type   not null default 'voice',
  status          call_status not null default 'ringing',
  room_name       text        not null,         -- Tên phòng LiveKit (UUID duy nhất)
  started_at      timestamptz default now(),    -- lúc bắt đầu đổ chuông
  connected_at    timestamptz,                  -- lúc callee nhấc máy
  ended_at        timestamptz,                  -- lúc kết thúc cuộc gọi
  duration_sec    int                           -- thời lượng (giây)
);

create index on calls (callee_id, status, started_at desc);
create index on calls (caller_id, started_at desc);
create index on calls (conversation_id, started_at desc);
```
