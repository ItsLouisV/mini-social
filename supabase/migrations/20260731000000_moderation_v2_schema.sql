-- ============================================================
-- CONTENT MODERATION SCHEMA — v2
-- Hỗ trợ report cho 3 loại nội dung: post, comment, message
-- Supabase Postgres Migration
-- ============================================================

-- ------------------------------------------------------------
-- 0. CLEANUP OLD MODERATION SYSTEM TABLES & FUNCTIONS
-- ------------------------------------------------------------

DROP TRIGGER IF EXISTS trg_report_aggregation ON moderation_reports;
DROP TRIGGER IF EXISTS trg_strike_auto_ban ON user_violations;
DROP FUNCTION IF EXISTS handle_report_aggregation();
DROP FUNCTION IF EXISTS handle_strike_auto_ban();
DROP FUNCTION IF EXISTS get_priority_report_queue(text, int, int);
DROP FUNCTION IF EXISTS get_admin_report_queue(text, int, int);
DROP FUNCTION IF EXISTS get_admin_cases(text, int, int);
DROP FUNCTION IF EXISTS get_moderation_dashboard_stats();
DROP FUNCTION IF EXISTS admin_resolve_report(uuid, text, text);

DROP TABLE IF EXISTS mod_ai_agreement_log CASCADE;
DROP TABLE IF EXISTS user_violations CASCADE;
DROP TABLE IF EXISTS moderation_results CASCADE;
DROP TABLE IF EXISTS moderation_cases CASCADE;
DROP TABLE IF EXISTS moderation_reports CASCADE;
DROP TABLE IF EXISTS moderation_keywords CASCADE;
DROP TABLE IF EXISTS moderation_domains CASCADE;
DROP TABLE IF EXISTS moderation_phones CASCADE;
DROP TABLE IF EXISTS moderation_categories CASCADE;
DROP TABLE IF EXISTS moderation_action_types CASCADE;
DROP TABLE IF EXISTS moderator_accounts CASCADE;
DROP TABLE IF EXISTS appeals CASCADE;
DROP TABLE IF EXISTS moderation_actions CASCADE;
DROP TABLE IF EXISTS reports CASCADE;
DROP TABLE IF EXISTS banned_keywords CASCADE;

DROP TYPE IF EXISTS reportable_content_type CASCADE;
DROP TYPE IF EXISTS report_reason CASCADE;
DROP TYPE IF EXISTS report_status CASCADE;
DROP TYPE IF EXISTS moderation_status CASCADE;
DROP TYPE IF EXISTS moderation_action_type CASCADE;
DROP TYPE IF EXISTS appeal_status CASCADE;
DROP TYPE IF EXISTS keyword_severity CASCADE;
DROP TYPE IF EXISTS keyword_match_type CASCADE;


-- ------------------------------------------------------------
-- 1. ENUMS
-- ------------------------------------------------------------

CREATE TYPE reportable_content_type AS ENUM ('post', 'comment', 'message');

CREATE TYPE report_reason AS ENUM (
  'spam', 'harassment', 'nudity_sexual', 'violence_gore',
  'hate_speech', 'misinformation', 'self_harm',
  'intellectual_property', 'other'
);

CREATE TYPE report_status AS ENUM ('pending', 'in_review', 'resolved', 'dismissed');

CREATE TYPE moderation_status AS ENUM (
  'published', 'shadow_limited', 'under_review', 'hidden', 'removed'
);

CREATE TYPE moderation_action_type AS ENUM (
  'auto_block', 'auto_shadow_limit', 'restore',
  'hide', 'remove', 'warn_user', 'suspend_user', 'ban_user'
);

CREATE TYPE appeal_status AS ENUM ('pending', 'approved', 'rejected');

CREATE TYPE keyword_severity AS ENUM ('zero_tolerance', 'flag_for_review');
CREATE TYPE keyword_match_type AS ENUM ('exact', 'regex');


-- ------------------------------------------------------------
-- 2. THÊM CỘT MODERATION VÀO CẢ 3 BẢNG NỘI DUNG & PROFILES
-- ------------------------------------------------------------

ALTER TABLE posts
  ADD COLUMN IF NOT EXISTS moderation_status moderation_status NOT NULL DEFAULT 'published',
  ADD COLUMN IF NOT EXISTS ai_moderation_score NUMERIC(4,3),
  ADD COLUMN IF NOT EXISTS ai_moderation_labels JSONB,
  ADD COLUMN IF NOT EXISTS moderated_at TIMESTAMPTZ;

ALTER TABLE comments
  ADD COLUMN IF NOT EXISTS moderation_status moderation_status NOT NULL DEFAULT 'published',
  ADD COLUMN IF NOT EXISTS ai_moderation_score NUMERIC(4,3),
  ADD COLUMN IF NOT EXISTS ai_moderation_labels JSONB,
  ADD COLUMN IF NOT EXISTS moderated_at TIMESTAMPTZ;

ALTER TABLE messages
  ADD COLUMN IF NOT EXISTS moderation_status moderation_status NOT NULL DEFAULT 'published',
  ADD COLUMN IF NOT EXISTS ai_moderation_score NUMERIC(4,3),
  ADD COLUMN IF NOT EXISTS ai_moderation_labels JSONB,
  ADD COLUMN IF NOT EXISTS moderated_at TIMESTAMPTZ;

ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS trust_score NUMERIC(4,3) NOT NULL DEFAULT 0.500,
  ADD COLUMN IF NOT EXISTS violation_count INT NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS false_report_count INT NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS account_status TEXT NOT NULL DEFAULT 'active';

CREATE INDEX IF NOT EXISTS idx_posts_moderation_status ON posts (moderation_status);
CREATE INDEX IF NOT EXISTS idx_comments_moderation_status ON comments (moderation_status);
CREATE INDEX IF NOT EXISTS idx_messages_moderation_status ON messages (moderation_status);


-- ------------------------------------------------------------
-- 3. REPORTS
-- ------------------------------------------------------------

CREATE TABLE reports (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  content_type    reportable_content_type NOT NULL,
  post_id         UUID REFERENCES posts(id) ON DELETE CASCADE,
  comment_id      UUID REFERENCES comments(id) ON DELETE CASCADE,
  message_id      UUID REFERENCES messages(id) ON DELETE CASCADE,

  target_id       UUID GENERATED ALWAYS AS (
                    COALESCE(post_id, comment_id, message_id)
                  ) STORED,

  reporter_id     UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  reason          report_reason NOT NULL,
  description     TEXT,
  status          report_status NOT NULL DEFAULT 'pending',

  ai_severity_score NUMERIC(4,3),
  ai_labels          JSONB,
  priority        SMALLINT NOT NULL DEFAULT 0,

  reviewed_by     UUID REFERENCES profiles(id),
  reviewed_at     TIMESTAMPTZ,

  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),

  CONSTRAINT chk_report_target CHECK (
    (content_type = 'post'    AND post_id    IS NOT NULL AND comment_id IS NULL AND message_id IS NULL) OR
    (content_type = 'comment' AND comment_id IS NOT NULL AND post_id    IS NULL AND message_id IS NULL) OR
    (content_type = 'message' AND message_id IS NOT NULL AND post_id    IS NULL AND comment_id IS NULL)
  ),

  UNIQUE (content_type, target_id, reporter_id)
);

CREATE INDEX idx_reports_queue ON reports (status, priority DESC, created_at ASC)
  WHERE status IN ('pending', 'in_review');

CREATE INDEX idx_reports_post_id    ON reports (post_id)    WHERE post_id    IS NOT NULL;
CREATE INDEX idx_reports_comment_id ON reports (comment_id) WHERE comment_id IS NOT NULL;
CREATE INDEX idx_reports_message_id ON reports (message_id) WHERE message_id IS NOT NULL;


-- ------------------------------------------------------------
-- 4. MODERATION_ACTIONS
-- ------------------------------------------------------------

CREATE TABLE moderation_actions (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  content_type    reportable_content_type NOT NULL,
  post_id         UUID REFERENCES posts(id) ON DELETE CASCADE,
  comment_id      UUID REFERENCES comments(id) ON DELETE CASCADE,
  message_id      UUID REFERENCES messages(id) ON DELETE CASCADE,
  target_id       UUID GENERATED ALWAYS AS (
                    COALESCE(post_id, comment_id, message_id)
                  ) STORED,

  report_id       UUID REFERENCES reports(id),
  target_user_id  UUID REFERENCES profiles(id),

  action_type     moderation_action_type NOT NULL,
  reason          TEXT NOT NULL,
  is_automated    BOOLEAN NOT NULL DEFAULT false,
  moderator_id    UUID REFERENCES profiles(id),

  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),

  CONSTRAINT chk_action_target CHECK (
    (content_type = 'post'    AND post_id    IS NOT NULL AND comment_id IS NULL AND message_id IS NULL) OR
    (content_type = 'comment' AND comment_id IS NOT NULL AND post_id    IS NULL AND message_id IS NULL) OR
    (content_type = 'message' AND message_id IS NOT NULL AND post_id    IS NULL AND comment_id IS NULL)
  )
);

CREATE INDEX idx_moderation_actions_target ON moderation_actions (content_type, target_id);
CREATE INDEX idx_moderation_actions_target_user ON moderation_actions (target_user_id);


-- ------------------------------------------------------------
-- 5. APPEALS
-- ------------------------------------------------------------

CREATE TABLE appeals (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  moderation_action_id  UUID NOT NULL REFERENCES moderation_actions(id) ON DELETE CASCADE,
  user_id               UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  appeal_reason         TEXT NOT NULL,
  status                appeal_status NOT NULL DEFAULT 'pending',
  reviewed_by           UUID REFERENCES profiles(id),
  reviewer_note         TEXT,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
  resolved_at           TIMESTAMPTZ,
  UNIQUE (moderation_action_id)
);

CREATE INDEX idx_appeals_status ON appeals (status) WHERE status = 'pending';


-- ------------------------------------------------------------
-- 6. BANNED KEYWORDS
-- ------------------------------------------------------------

CREATE TABLE banned_keywords (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  pattern       TEXT NOT NULL,
  match_type    keyword_match_type NOT NULL DEFAULT 'exact',
  severity      keyword_severity NOT NULL,
  category      report_reason,
  language      TEXT NOT NULL DEFAULT 'vi',
  is_active     BOOLEAN NOT NULL DEFAULT true,
  created_by    UUID REFERENCES profiles(id),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_banned_keywords_active ON banned_keywords (is_active) WHERE is_active = true;

-- Sample Banned Keywords
INSERT INTO banned_keywords (pattern, match_type, severity, category) VALUES
  ('mua súng', 'exact', 'zero_tolerance', 'other'),
  ('bán súng', 'exact', 'zero_tolerance', 'other'),
  ('\d{9,11}.*(zalo|telegram).*(chuyển khoản|nạp tiền)', 'regex', 'flag_for_review', 'spam')
ON CONFLICT DO NOTHING;


-- ------------------------------------------------------------
-- 7. RLS POLICIES
-- ------------------------------------------------------------

ALTER TABLE reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE moderation_actions ENABLE ROW LEVEL SECURITY;
ALTER TABLE appeals ENABLE ROW LEVEL SECURITY;
ALTER TABLE banned_keywords ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users create reports" ON reports FOR INSERT WITH CHECK (auth.uid() = reporter_id);
CREATE POLICY "Users view own reports" ON reports FOR SELECT USING (auth.uid() = reporter_id);
CREATE POLICY "Users view own appeals" ON appeals FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users create appeals" ON appeals FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Public read active banned keywords" ON banned_keywords FOR SELECT USING (is_active = true);
CREATE POLICY "Admin manage banned keywords" ON banned_keywords FOR ALL USING (true);
CREATE POLICY "Admin manage reports" ON reports FOR ALL USING (true);
CREATE POLICY "Admin manage moderation_actions" ON moderation_actions FOR ALL USING (true);
CREATE POLICY "Admin manage appeals" ON appeals FOR ALL USING (true);
