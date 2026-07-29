-- =====================================================
-- FIX: Enable RLS + Moderator SELECT policies
-- Chạy SQL này trên Supabase SQL Editor nếu dữ liệu
-- không hiển thị trong Admin Dashboard
-- =====================================================

-- 1. Enable RLS cho moderation_reports (nếu chưa có)
alter table moderation_reports enable row level security;

-- 2. Đảm bảo policy moderator đọc được reports
drop policy if exists "moderator view reports" on moderation_reports;
create policy "moderator view reports" on moderation_reports
  for select using (is_moderator());

-- 3. Đảm bảo policy moderator UPDATE reports (để resolve)
drop policy if exists "moderator update reports" on moderation_reports;
create policy "moderator update reports" on moderation_reports
  for update using (is_moderator());

-- 4. Enable RLS cho moderation_cases nếu chưa có
alter table moderation_cases enable row level security;

-- 5. Moderator đọc được cases
drop policy if exists "moderator view cases" on moderation_cases;
create policy "moderator view cases" on moderation_cases
  for select using (is_moderator());

-- 6. Moderator insert cases (cần cho resolveReport)
drop policy if exists "moderator insert cases" on moderation_cases;
create policy "moderator insert cases" on moderation_cases
  for insert with check (is_moderator());

-- 7. Enable RLS cho moderation_results nếu chưa có
alter table moderation_results enable row level security;

drop policy if exists "moderator view results" on moderation_results;
create policy "moderator view results" on moderation_results
  for select using (is_moderator());

drop policy if exists "moderator insert results" on moderation_results;
create policy "moderator insert results" on moderation_results
  for insert with check (is_moderator());

-- 8. Enable RLS cho moderation_actions nếu chưa có
alter table moderation_actions enable row level security;

drop policy if exists "moderator manage actions" on moderation_actions;
create policy "moderator manage actions" on moderation_actions
  for all using (is_moderator()) with check (is_moderator());

-- 9. Admin quản lý keywords (cần GRANT SELECT cho moderator đọc categories)
alter table moderation_keywords enable row level security;

drop policy if exists "admin manage keywords" on moderation_keywords;
create policy "admin manage keywords" on moderation_keywords
  for all using (is_admin()) with check (is_admin());

-- 10. Moderator đọc được categories & action_types (reference data)
alter table moderation_categories enable row level security;

drop policy if exists "everyone read categories" on moderation_categories;
create policy "everyone read categories" on moderation_categories
  for select using (true);

alter table moderation_action_types enable row level security;

drop policy if exists "everyone read action_types" on moderation_action_types;
create policy "everyone read action_types" on moderation_action_types
  for select using (true);

-- 11. Moderator đọc domains và phones
alter table moderation_domains enable row level security;

drop policy if exists "admin manage domains" on moderation_domains;
create policy "admin manage domains" on moderation_domains
  for all using (is_admin()) with check (is_admin());

alter table moderation_phones enable row level security;

drop policy if exists "admin manage phones" on moderation_phones;
create policy "admin manage phones" on moderation_phones
  for all using (is_admin()) with check (is_admin());

-- 12. Grant EXECUTE cho các RPCs nếu đã được tạo
grant execute on function get_moderation_dashboard_stats() to authenticated;
grant execute on function get_admin_report_queue(text, int, int) to authenticated;
grant execute on function admin_resolve_report(uuid, text, text) to authenticated;
grant execute on function get_admin_cases(text, int, int) to authenticated;
