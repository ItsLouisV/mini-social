-- ============================================================
-- Migration: Fix Private Profile visibility to match major apps (Instagram/TikTok/Twitter)
--            - Thẻ thông tin cá nhân (Name, Avatar, Username, Bio) của tài khoản riêng tư luôn hiển thị công khai
--            - Nội dung riêng tư (bài viết, hình ảnh) được bảo mật nghiêm ngặt tại bảng posts
-- ============================================================

-- 1. Cho phép tất cả người dùng xem thông tin hồ sơ cơ bản (Avatar, Tên hiển thị, Username, Bio)
DROP POLICY IF EXISTS "Profiles viewable if public/friends" ON public.profiles;
DROP POLICY IF EXISTS "Profiles viewable if not blocked and public/friends" ON public.profiles;
DROP POLICY IF EXISTS "Profiles viewable by everyone" ON public.profiles;

CREATE POLICY "Public profiles viewable by everyone" ON public.profiles
  FOR SELECT USING (true);
