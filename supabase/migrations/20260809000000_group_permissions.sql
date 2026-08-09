-- =============================================================================
-- Migration: Group Permissions System
-- =============================================================================
-- Adds permission control columns to conversations and conversation_members,
-- and creates the group_bans table for tracking banned members.
-- =============================================================================

-- ── 1. conversations — permission toggle columns ──────────────────────────────

ALTER TABLE conversations
  ADD COLUMN IF NOT EXISTS admin_only_messaging     BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS allow_member_invite      BOOLEAN NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS allow_member_pin         BOOLEAN NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS allow_member_mention_all BOOLEAN NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS allow_member_edit_info   BOOLEAN NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS description              TEXT;

COMMENT ON COLUMN conversations.admin_only_messaging     IS 'When true, only owner/admin can send messages';
COMMENT ON COLUMN conversations.allow_member_invite      IS 'Whether regular members can invite new members';
COMMENT ON COLUMN conversations.allow_member_pin         IS 'Whether regular members can pin/unpin messages';
COMMENT ON COLUMN conversations.allow_member_mention_all IS 'Whether regular members can use @everyone/@all';
COMMENT ON COLUMN conversations.allow_member_edit_info   IS 'Whether regular members can edit group name/avatar/description';
COMMENT ON COLUMN conversations.description              IS 'Group description text';

-- ── 2. conversation_members — admin mute columns ─────────────────────────────

ALTER TABLE conversation_members
  ADD COLUMN IF NOT EXISTS is_muted_by_admin BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS muted_until       TIMESTAMPTZ;

COMMENT ON COLUMN conversation_members.is_muted_by_admin IS 'Muted by group admin (different from user self-mute notifications)';
COMMENT ON COLUMN conversation_members.muted_until       IS 'NULL = permanent mute; future timestamp = timed mute';

-- ── 3. group_bans — banned members table ─────────────────────────────────────

CREATE TABLE IF NOT EXISTS group_bans (
  id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id UUID        NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
  user_id         UUID        NOT NULL REFERENCES profiles(id)      ON DELETE CASCADE,
  banned_by       UUID        REFERENCES profiles(id) ON DELETE SET NULL,
  reason          TEXT,
  banned_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  unbanned_at     TIMESTAMPTZ,
  is_active       BOOLEAN     NOT NULL DEFAULT true
);

COMMENT ON TABLE group_bans IS 'Tracks users banned from group conversations by owner';

CREATE INDEX IF NOT EXISTS idx_group_bans_conv_user_active
  ON group_bans(conversation_id, user_id, is_active);

CREATE INDEX IF NOT EXISTS idx_group_bans_conversation_id
  ON group_bans(conversation_id);

-- ── 4. RLS policies for group_bans ───────────────────────────────────────────

ALTER TABLE group_bans ENABLE ROW LEVEL SECURITY;

-- Members of the group can read the ban list
CREATE POLICY "group_bans_select_members"
  ON group_bans FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM conversation_members cm
      WHERE cm.conversation_id = group_bans.conversation_id
        AND cm.user_id = auth.uid()
    )
  );

-- Only owner can insert bans
CREATE POLICY "group_bans_insert_owner"
  ON group_bans FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM conversation_members cm
      WHERE cm.conversation_id = group_bans.conversation_id
        AND cm.user_id = auth.uid()
        AND cm.role = 'owner'
    )
  );

-- Only owner can update (unban)
CREATE POLICY "group_bans_update_owner"
  ON group_bans FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM conversation_members cm
      WHERE cm.conversation_id = group_bans.conversation_id
        AND cm.user_id = auth.uid()
        AND cm.role = 'owner'
    )
  );

-- Only owner can hard-delete ban records
CREATE POLICY "group_bans_delete_owner"
  ON group_bans FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM conversation_members cm
      WHERE cm.conversation_id = group_bans.conversation_id
        AND cm.user_id = auth.uid()
        AND cm.role = 'owner'
    )
  );

-- ── 5. Realtime for group_bans ────────────────────────────────────────────────

ALTER PUBLICATION supabase_realtime ADD TABLE group_bans;
