-- 0. EXTENSIONS
CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS unaccent;

-- 1. ENUMS
CREATE TYPE friend_request_status AS ENUM (
  'pending',
  'accepted',
  'rejected',
  'cancelled'
);

CREATE TYPE notification_type AS ENUM (
  'like',
  'comment',
  'reply',
  'follow',
  'friend_request',
  'friend_accept'
);

CREATE TYPE call_status AS ENUM (
  'ringing',
  'accepted',
  'declined',
  'ended',
  'missed',
  'cancelled'
);

CREATE TYPE call_type AS ENUM (
  'voice',
  'video'
);

-- 2. TABLES

-- profiles: Thông tin người dùng
CREATE TABLE profiles (
  id          UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email       TEXT,
  username    TEXT UNIQUE NOT NULL,
  full_name   TEXT,
  bio         TEXT,
  avatar_url  TEXT,
  cover_url   TEXT,
  interests   TEXT[] DEFAULT '{}',
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- posts: Bài viết
CREATE TABLE posts (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id        UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  caption        TEXT,
  likes_count    INT DEFAULT 0,
  comments_count INT DEFAULT 0,
  privacy        TEXT NOT NULL DEFAULT 'public',
  embedding      vector(384), -- Cột lưu trữ vector embeddings (cho Sprint 8)
  created_at     TIMESTAMPTZ DEFAULT NOW()
);

-- post_media: File đính kèm bài viết
CREATE TABLE post_media (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id     UUID REFERENCES posts(id) ON DELETE CASCADE NOT NULL,
  url         TEXT NOT NULL,
  type        TEXT NOT NULL DEFAULT 'image', -- 'image' | 'video'
  order_index INT NOT NULL DEFAULT 0,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX ON post_media (post_id, order_index);

-- likes: Lượt thích bài viết
CREATE TABLE likes (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id    UUID REFERENCES posts(id) ON DELETE CASCADE NOT NULL,
  user_id    UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (post_id, user_id)
);

-- comments: Bình luận
CREATE TABLE comments (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id     UUID REFERENCES posts(id) ON DELETE CASCADE NOT NULL,
  user_id     UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  parent_id   UUID REFERENCES comments(id) ON DELETE CASCADE,
  content     TEXT NOT NULL,
  likes_count INT DEFAULT 0,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX ON comments (parent_id) WHERE parent_id IS NOT NULL;
CREATE INDEX ON comments (post_id, created_at) WHERE parent_id IS NULL;

-- comment_likes: Lượt thích bình luận
CREATE TABLE comment_likes (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  comment_id UUID REFERENCES comments(id) ON DELETE CASCADE NOT NULL,
  user_id    UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (comment_id, user_id)
);

-- follows: Quan hệ theo dõi (1 chiều)
CREATE TABLE follows (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  follower_id  UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  following_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  created_at   TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (follower_id, following_id),
  CHECK (follower_id <> following_id)
);

CREATE INDEX ON follows (follower_id);
CREATE INDEX ON follows (following_id);

-- friend_requests: Kết bạn (2 chiều)
CREATE TABLE friend_requests (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  sender_id   UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  receiver_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  status      friend_request_status NOT NULL DEFAULT 'pending',
  created_at  TIMESTAMPTZ DEFAULT NOW(),
  updated_at  TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (sender_id, receiver_id),
  CHECK (sender_id <> receiver_id)
);

CREATE INDEX ON friend_requests (receiver_id, status);
CREATE INDEX ON friend_requests (sender_id, status);

-- notifications: Thông báo
CREATE TABLE notifications (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  receiver_id     UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  sender_id       UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  type            notification_type NOT NULL,
  post_id         UUID REFERENCES posts(id) ON DELETE CASCADE,
  comment_id      UUID REFERENCES comments(id) ON DELETE CASCADE,
  content         TEXT,
  is_read         BOOLEAN DEFAULT FALSE,
  created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX ON notifications (receiver_id, is_read, created_at DESC);

-- conversations: Phòng chat
CREATE TABLE conversations (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  participant_1   UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  participant_2   UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  last_message    TEXT,
  last_message_at TIMESTAMPTZ,
  last_message_id UUID,
  p1_unread_count INT DEFAULT 0,
  p2_unread_count INT DEFAULT 0,
  p1_is_pinned    BOOLEAN DEFAULT FALSE,
  p2_is_pinned    BOOLEAN DEFAULT FALSE,
  p1_is_hidden    BOOLEAN DEFAULT FALSE,
  p2_is_hidden    BOOLEAN DEFAULT FALSE,
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (participant_1, participant_2),
  CHECK (participant_1 < participant_2)
);

CREATE INDEX ON conversations (participant_1);
CREATE INDEX ON conversations (participant_2);

-- messages: Tin nhắn
CREATE TABLE messages (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id     UUID REFERENCES conversations(id) ON DELETE CASCADE NOT NULL,
  sender_id           UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  content             TEXT,
  media_url           TEXT,
  message_type        TEXT NOT NULL DEFAULT 'text',
  is_seen             BOOLEAN DEFAULT FALSE,
  seen_at             TIMESTAMPTZ,
  reply_to_message_id UUID REFERENCES messages(id) ON DELETE SET NULL,
  created_at          TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX ON messages (conversation_id, created_at DESC);

ALTER TABLE conversations
  ADD CONSTRAINT fk_last_message
  FOREIGN KEY (last_message_id) REFERENCES messages(id) ON DELETE SET NULL;

-- conversation_settings: Ghim hội thoại theo người dùng
CREATE TABLE conversation_settings (
  user_id         UUID REFERENCES profiles(id) ON DELETE CASCADE,
  conversation_id UUID REFERENCES conversations(id) ON DELETE CASCADE,
  is_pinned       BOOLEAN DEFAULT FALSE,
  pinned_at       TIMESTAMPTZ,
  PRIMARY KEY (user_id, conversation_id)
);

CREATE INDEX ON conversation_settings (user_id, is_pinned, pinned_at DESC);

-- pinned_messages: Tin nhắn được ghim trong cuộc trò chuyện
CREATE TABLE pinned_messages (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id UUID REFERENCES conversations(id) ON DELETE CASCADE NOT NULL,
  message_id      UUID REFERENCES messages(id) ON DELETE CASCADE NOT NULL,
  pinned_by       UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  pinned_at       TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (conversation_id, message_id)
);

CREATE INDEX ON pinned_messages (conversation_id, pinned_at DESC);

-- calls: Cuộc gọi WebRTC
CREATE TABLE calls (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id UUID REFERENCES conversations(id) ON DELETE CASCADE NOT NULL,
  caller_id       UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  callee_id       UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  type            call_type NOT NULL DEFAULT 'voice',
  status          call_status NOT NULL DEFAULT 'ringing',
  room_name       TEXT NOT NULL,
  started_at      TIMESTAMPTZ DEFAULT NOW(),
  connected_at    TIMESTAMPTZ,
  ended_at        TIMESTAMPTZ,
  duration_sec    INT
);

CREATE INDEX ON calls (callee_id, status, started_at DESC);
CREATE INDEX ON calls (caller_id, started_at DESC);
CREATE INDEX ON calls (conversation_id, started_at DESC);

-- 3. TRIGGERS & FUNCTIONS

-- Tự động tạo profile khi đăng ký tài khoản
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  base_username  TEXT;
  final_username TEXT;
BEGIN
  base_username := split_part(NEW.email, '@', 1);
  base_username := public.unaccent(base_username);
  base_username := lower(base_username);
  base_username := regexp_replace(base_username, '[^a-z0-9._]', '', 'g');

  IF length(base_username) < 3 THEN
    base_username := 'user';
  END IF;

  base_username := left(base_username, 20);
  final_username := base_username;

  LOOP
    BEGIN
      INSERT INTO public.profiles (id, email, username, full_name)
      VALUES (
        NEW.id,
        NEW.email,
        final_username,
        coalesce(NEW.raw_user_meta_data->>'full_name', base_username)
      );
      EXIT;
    EXCEPTION WHEN unique_violation THEN
      final_username := base_username || '.' || left(encode(gen_random_bytes(4), 'hex'), 6);
    END;
  END LOOP;

  RETURN NEW;
END;
$$;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE handle_new_user();

-- Cập nhật số lượt thích bài đăng
CREATE OR REPLACE FUNCTION update_likes_count()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE posts SET likes_count = coalesce(likes_count, 0) + 1 WHERE id = NEW.post_id;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE posts SET likes_count = greatest(coalesce(likes_count, 0) - 1, 0) WHERE id = OLD.post_id;
  END IF;
  RETURN NULL;
END;
$$;

CREATE TRIGGER likes_count_trigger
  AFTER INSERT OR DELETE ON likes
  FOR EACH ROW EXECUTE PROCEDURE update_likes_count();

-- Cập nhật số lượng bình luận bài đăng
CREATE OR REPLACE FUNCTION update_comments_count()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE posts SET comments_count = coalesce(comments_count, 0) + 1 WHERE id = NEW.post_id;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE posts SET comments_count = greatest(coalesce(comments_count, 0) - 1, 0) WHERE id = OLD.post_id;
  END IF;
  RETURN NULL;
END;
$$;

CREATE TRIGGER comments_count_trigger
  AFTER INSERT OR DELETE ON comments
  FOR EACH ROW EXECUTE PROCEDURE update_comments_count();

-- Cập nhật số lượt thích bình luận
CREATE OR REPLACE FUNCTION update_comment_likes_count()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE comments SET likes_count = coalesce(likes_count, 0) + 1 WHERE id = NEW.comment_id;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE comments SET likes_count = greatest(coalesce(likes_count, 0) - 1, 0) WHERE id = OLD.comment_id;
  END IF;
  RETURN NULL;
END;
$$;

CREATE TRIGGER comment_likes_count_trigger
  AFTER INSERT OR DELETE ON comment_likes
  FOR EACH ROW EXECUTE PROCEDURE update_comment_likes_count();

-- Cập nhật updated_at của friend_requests
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER friend_requests_updated_at
  BEFORE UPDATE ON friend_requests
  FOR EACH ROW EXECUTE PROCEDURE set_updated_at();

-- Gửi thông báo khi thích bài viết
CREATE OR REPLACE FUNCTION notify_on_like()
RETURNS TRIGGER AS $$
DECLARE post_owner UUID;
BEGIN
  SELECT user_id INTO post_owner FROM posts WHERE id = NEW.post_id;
  IF post_owner <> NEW.user_id THEN
    INSERT INTO notifications (receiver_id, sender_id, type, post_id)
    VALUES (post_owner, NEW.user_id, 'like', NEW.post_id);
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_like_created
  AFTER INSERT ON likes
  FOR EACH ROW EXECUTE PROCEDURE notify_on_like();

-- Gửi thông báo khi viết bình luận / trả lời bình luận
CREATE OR REPLACE FUNCTION notify_on_comment()
RETURNS TRIGGER AS $$
DECLARE
  post_owner   UUID;
  parent_owner UUID;
BEGIN
  SELECT user_id INTO post_owner FROM posts WHERE id = NEW.post_id;

  IF NEW.parent_id IS NULL THEN
    IF post_owner <> NEW.user_id THEN
      INSERT INTO notifications (receiver_id, sender_id, type, post_id, comment_id)
      VALUES (post_owner, NEW.user_id, 'comment', NEW.post_id, NEW.id);
    END IF;
  ELSE
    SELECT user_id INTO parent_owner FROM comments WHERE id = NEW.parent_id;
    IF parent_owner <> NEW.user_id THEN
      INSERT INTO notifications (receiver_id, sender_id, type, post_id, comment_id)
      VALUES (parent_owner, NEW.user_id, 'reply', NEW.post_id, NEW.id);
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_comment_created
  AFTER INSERT ON comments
  FOR EACH ROW EXECUTE PROCEDURE notify_on_comment();

-- Gửi thông báo khi có người follow
CREATE OR REPLACE FUNCTION notify_on_follow()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO notifications (receiver_id, sender_id, type)
  VALUES (NEW.following_id, NEW.follower_id, 'follow');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_follow_created
  AFTER INSERT ON follows
  FOR EACH ROW EXECUTE PROCEDURE notify_on_follow();

-- Gửi thông báo khi có lời mời kết bạn / chấp nhận lời mời
CREATE OR REPLACE FUNCTION notify_on_friend_request()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    INSERT INTO notifications (receiver_id, sender_id, type)
    VALUES (NEW.receiver_id, NEW.sender_id, 'friend_request');
  ELSIF TG_OP = 'UPDATE' AND NEW.status = 'accepted' AND OLD.status = 'pending' THEN
    INSERT INTO notifications (receiver_id, sender_id, type)
    VALUES (NEW.sender_id, NEW.receiver_id, 'friend_accept');
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_friend_request_changed
  AFTER INSERT OR UPDATE ON friend_requests
  FOR EACH ROW EXECUTE PROCEDURE notify_on_friend_request();

-- Cập nhật tin nhắn cuối trong cuộc hội thoại và tăng đếm tin nhắn chưa đọc
CREATE OR REPLACE FUNCTION update_last_message()
RETURNS TRIGGER AS $$
DECLARE
  conv_p1 UUID;
  conv_p2 UUID;
BEGIN
  SELECT participant_1, participant_2 INTO conv_p1, conv_p2 
  FROM conversations WHERE id = NEW.conversation_id;

  UPDATE conversations
  SET 
    last_message_id = NEW.id,
    last_message = NEW.content,
    last_message_at = NEW.created_at,
    p1_unread_count = CASE WHEN NEW.sender_id = conv_p2 THEN p1_unread_count + 1 ELSE p1_unread_count END,
    p2_unread_count = CASE WHEN NEW.sender_id = conv_p1 THEN p2_unread_count + 1 ELSE p2_unread_count END
  WHERE id = NEW.conversation_id;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER on_message_created
  AFTER INSERT ON messages
  FOR EACH ROW EXECUTE PROCEDURE update_last_message();

-- Đánh dấu đã xem và reset đếm tin nhắn chưa đọc
CREATE OR REPLACE FUNCTION set_seen_at()
RETURNS TRIGGER AS $$
DECLARE
  conv_p1 UUID;
  conv_p2 UUID;
BEGIN
  IF NEW.is_seen = TRUE AND OLD.is_seen = FALSE THEN
    NEW.seen_at = NOW();
    
    SELECT participant_1, participant_2 INTO conv_p1, conv_p2 
    FROM conversations WHERE id = NEW.conversation_id;

    UPDATE conversations
    SET 
      p1_unread_count = CASE WHEN NEW.sender_id = conv_p2 THEN 0 ELSE p1_unread_count END,
      p2_unread_count = CASE WHEN NEW.sender_id = conv_p1 THEN 0 ELSE p2_unread_count END
    WHERE id = NEW.conversation_id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER on_message_seen
  BEFORE UPDATE ON messages
  FOR EACH ROW EXECUTE PROCEDURE set_seen_at();

-- Đặt pinned_at khi ghim cuộc trò chuyện
CREATE OR REPLACE FUNCTION set_conv_pinned_at()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.is_pinned = TRUE AND (OLD.is_pinned IS DISTINCT FROM TRUE) THEN
    NEW.pinned_at = NOW();
  ELSIF NEW.is_pinned = FALSE THEN
    NEW.pinned_at = NULL;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER conversation_settings_pinned_at
  BEFORE INSERT OR UPDATE ON conversation_settings
  FOR EACH ROW EXECUTE PROCEDURE set_conv_pinned_at();

-- 4. ROW LEVEL SECURITY (RLS) & POLICIES

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Profiles viewable by everyone" ON profiles FOR SELECT USING (true);
CREATE POLICY "Users update own profile" ON profiles FOR UPDATE USING (auth.uid() = id);

ALTER TABLE posts ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Posts viewable by everyone" ON posts FOR SELECT USING (true);
CREATE POLICY "Users create own posts" ON posts FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users delete own posts" ON posts FOR DELETE USING (auth.uid() = user_id);

ALTER TABLE post_media ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Post media viewable by everyone" ON post_media FOR SELECT USING (true);
CREATE POLICY "Users insert own post media" ON post_media FOR INSERT WITH CHECK (
  auth.uid() = (SELECT user_id FROM posts WHERE id = post_id)
);
CREATE POLICY "Users delete own post media" ON post_media FOR DELETE USING (
  auth.uid() = (SELECT user_id FROM posts WHERE id = post_id)
);

ALTER TABLE likes ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Likes viewable by everyone" ON likes FOR SELECT USING (true);
CREATE POLICY "Users manage own likes" ON likes FOR ALL USING (auth.uid() = user_id);

ALTER TABLE comments ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Comments viewable by everyone" ON comments FOR SELECT USING (true);
CREATE POLICY "Users create comments" ON comments FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users delete own comments" ON comments FOR DELETE USING (auth.uid() = user_id);

ALTER TABLE comment_likes ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Comment likes viewable by everyone" ON comment_likes FOR SELECT USING (true);
CREATE POLICY "Users manage own comment likes" ON comment_likes FOR ALL USING (auth.uid() = user_id);

ALTER TABLE follows ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Follows viewable by everyone" ON follows FOR SELECT USING (true);
CREATE POLICY "Users manage own follows" ON follows FOR ALL USING (auth.uid() = follower_id);

ALTER TABLE friend_requests ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users view own friend requests" ON friend_requests FOR SELECT USING (auth.uid() = sender_id OR auth.uid() = receiver_id);
CREATE POLICY "Users send friend requests" ON friend_requests FOR INSERT WITH CHECK (auth.uid() = sender_id);
CREATE POLICY "Users respond to friend requests" ON friend_requests FOR UPDATE USING (auth.uid() = sender_id OR auth.uid() = receiver_id);
CREATE POLICY "Users delete own friend requests" ON friend_requests FOR DELETE USING (auth.uid() = sender_id OR auth.uid() = receiver_id);

ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users view own notifications" ON notifications FOR SELECT USING (auth.uid() = receiver_id);
CREATE POLICY "Users mark notifications as read" ON notifications FOR UPDATE USING (auth.uid() = receiver_id);

ALTER TABLE conversations ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Participants view conversations" ON conversations FOR SELECT USING (auth.uid() = participant_1 OR auth.uid() = participant_2);
CREATE POLICY "Users create conversations" ON conversations FOR INSERT WITH CHECK (auth.uid() = participant_1 OR auth.uid() = participant_2);

ALTER TABLE messages ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Participants view messages" ON messages FOR SELECT USING (
  auth.uid() = sender_id OR
  auth.uid() IN (
    SELECT participant_1 FROM conversations WHERE id = conversation_id
    UNION
    SELECT participant_2 FROM conversations WHERE id = conversation_id
  )
);
CREATE POLICY "Users send messages" ON messages FOR INSERT WITH CHECK (auth.uid() = sender_id);
CREATE POLICY "Mark messages as seen" ON messages FOR UPDATE USING (
  auth.uid() IN (
    SELECT participant_1 FROM conversations WHERE id = conversation_id
    UNION
    SELECT participant_2 FROM conversations WHERE id = conversation_id
  )
);

ALTER TABLE conversation_settings ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users manage own conversation settings" ON conversation_settings FOR ALL USING (auth.uid() = user_id);

ALTER TABLE pinned_messages ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Participants view pinned messages" ON pinned_messages FOR SELECT USING (
  auth.uid() IN (
    SELECT participant_1 FROM conversations WHERE id = conversation_id
    UNION
    SELECT participant_2 FROM conversations WHERE id = conversation_id
  )
);
CREATE POLICY "Participants pin messages" ON pinned_messages FOR INSERT WITH CHECK (
  auth.uid() = pinned_by AND
  auth.uid() IN (
    SELECT participant_1 FROM conversations WHERE id = conversation_id
    UNION
    SELECT participant_2 FROM conversations WHERE id = conversation_id
  )
);
CREATE POLICY "Participants unpin messages" ON pinned_messages FOR DELETE USING (
  auth.uid() IN (
    SELECT participant_1 FROM conversations WHERE id = conversation_id
    UNION
    SELECT participant_2 FROM conversations WHERE id = conversation_id
  )
);

ALTER TABLE calls ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Participants view calls" ON calls FOR SELECT USING (auth.uid() = caller_id OR auth.uid() = callee_id);
CREATE POLICY "Users create calls" ON calls FOR INSERT WITH CHECK (auth.uid() = caller_id);
CREATE POLICY "Participants update call status" ON calls FOR UPDATE USING (auth.uid() = caller_id OR auth.uid() = callee_id);

-- 5. STORAGE BUCKETS INITIALIZATION
-- Tạo các bucket lưu trữ mặc định
INSERT INTO storage.buckets (id, name, public) VALUES
  ('avatars',  'avatars',  true),
  ('covers',   'covers',   true),
  ('posts',    'posts',    true),
  ('messages', 'messages', true)
ON CONFLICT (id) DO NOTHING;

-- 6. STORAGE OBJECTS RLS POLICIES

-- Avatars RLS Policies
CREATE POLICY "Public read avatars" ON storage.objects FOR SELECT USING (bucket_id = 'avatars');
CREATE POLICY "Upload own avatar" ON storage.objects FOR INSERT WITH CHECK (
  bucket_id = 'avatars' AND auth.uid()::text = (storage.foldername(name))[1]
);
CREATE POLICY "Delete own avatar" ON storage.objects FOR DELETE USING (
  bucket_id = 'avatars' AND auth.uid()::text = (storage.foldername(name))[1]
);

-- Covers RLS Policies
CREATE POLICY "Public read covers" ON storage.objects FOR SELECT USING (bucket_id = 'covers');
CREATE POLICY "Upload own cover" ON storage.objects FOR INSERT WITH CHECK (
  bucket_id = 'covers' AND auth.uid()::text = (storage.foldername(name))[1]
);
CREATE POLICY "Delete own cover" ON storage.objects FOR DELETE USING (
  bucket_id = 'covers' AND auth.uid()::text = (storage.foldername(name))[1]
);

-- Posts RLS Policies
CREATE POLICY "Public read posts" ON storage.objects FOR SELECT USING (bucket_id = 'posts');
CREATE POLICY "Upload own post media" ON storage.objects FOR INSERT WITH CHECK (
  bucket_id = 'posts' AND auth.uid()::text = (storage.foldername(name))[1]
);
CREATE POLICY "Delete own post media" ON storage.objects FOR DELETE USING (
  bucket_id = 'posts' AND auth.uid()::text = (storage.foldername(name))[1]
);

-- Messages RLS Policies
CREATE POLICY "Public read message files" ON storage.objects FOR SELECT USING (bucket_id = 'messages');
CREATE POLICY "Users upload message images" ON storage.objects FOR INSERT WITH CHECK (
  bucket_id = 'messages' AND auth.uid()::text = (storage.foldername(name))[1]
);
CREATE POLICY "Users update own message files" ON storage.objects FOR UPDATE USING (
  bucket_id = 'messages' AND auth.uid()::text = (storage.foldername(name))[1]
);
CREATE POLICY "Users delete own message files" ON storage.objects FOR DELETE USING (
  bucket_id = 'messages' AND auth.uid()::text = (storage.foldername(name))[1]
);

-- 7. REALTIME PUBLICATION
ALTER PUBLICATION supabase_realtime ADD TABLE posts;
ALTER PUBLICATION supabase_realtime ADD TABLE likes;
ALTER PUBLICATION supabase_realtime ADD TABLE comments;
ALTER PUBLICATION supabase_realtime ADD TABLE comment_likes;
ALTER PUBLICATION supabase_realtime ADD TABLE conversations;
ALTER PUBLICATION supabase_realtime ADD TABLE messages;
ALTER PUBLICATION supabase_realtime ADD TABLE notifications;
ALTER PUBLICATION supabase_realtime ADD TABLE calls;
