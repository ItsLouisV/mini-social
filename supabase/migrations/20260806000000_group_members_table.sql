-- ── 1. Bổ sung các cột tính năng Nhóm vào bảng public.conversations ──────
ALTER TABLE public.conversations
    ADD COLUMN IF NOT EXISTS is_group BOOLEAN DEFAULT false,
    ADD COLUMN IF NOT EXISTS group_name TEXT,
    ADD COLUMN IF NOT EXISTS group_avatar_url TEXT,
    ADD COLUMN IF NOT EXISTS group_admin_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS member_ids TEXT[] DEFAULT '{}';

-- Cập nhật các ràng buộc constraint trên conversations để hỗ trợ nhiều nhóm chat
ALTER TABLE public.conversations DROP CONSTRAINT IF EXISTS conversations_check;
ALTER TABLE public.conversations ADD CONSTRAINT conversations_check CHECK (is_group = true OR participant_1 < participant_2);

ALTER TABLE public.conversations DROP CONSTRAINT IF EXISTS conversations_participant_1_participant_2_key;
CREATE UNIQUE INDEX IF NOT EXISTS conversations_unique_1on1_idx 
    ON public.conversations (participant_1, participant_2) 
    WHERE (is_group IS NOT TRUE);

-- ── 2. Bảng public.group_members (Quản lý thành viên & phân quyền nhóm chat) ──────
CREATE TABLE IF NOT EXISTS public.group_members (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id UUID NOT NULL REFERENCES public.conversations(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    role TEXT NOT NULL DEFAULT 'member' CHECK (role IN ('admin', 'co_admin', 'member')),
    joined_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT unique_conversation_user UNIQUE (conversation_id, user_id)
);

-- Index giúp tăng tốc độ truy vấn danh sách thành viên trong nhóm
CREATE INDEX IF NOT EXISTS idx_group_members_conv_id ON public.group_members(conversation_id);
CREATE INDEX IF NOT EXISTS idx_group_members_user_id ON public.group_members(user_id);

-- Bật Row Level Security (RLS)
ALTER TABLE public.group_members ENABLE ROW LEVEL SECURITY;

-- Dynamic RLS Policies cho group_members
DROP POLICY IF EXISTS "Cho phép xem danh sách thành viên trong nhóm" ON public.group_members;
CREATE POLICY "Cho phép xem danh sách thành viên trong nhóm"
    ON public.group_members FOR SELECT
    USING (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS "Cho phép chèn thành viên vào nhóm" ON public.group_members;
CREATE POLICY "Cho phép chèn thành viên vào nhóm"
    ON public.group_members FOR INSERT
    WITH CHECK (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS "Cho phép cập nhật vai trò thành viên" ON public.group_members;
CREATE POLICY "Cho phép cập nhật vai trò thành viên"
    ON public.group_members FOR UPDATE
    USING (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS "Cho phép xóa thành viên hoặc tự rời nhóm" ON public.group_members;
CREATE POLICY "Cho phép xóa thành viên hoặc tự rời nhóm"
    ON public.group_members FOR DELETE
    USING (auth.uid() IS NOT NULL);

-- ── 3. Cấp quyền RLS INSERT cho bảng public.notifications ──────
DROP POLICY IF EXISTS "Users send notifications" ON public.notifications;
CREATE POLICY "Users send notifications" ON public.notifications FOR INSERT WITH CHECK (auth.uid() = sender_id);
