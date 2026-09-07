-- Phase 0B.2: provide a practical standard subject catalog for real institutions.
--
-- The catalog is global reference data only. Institutions still explicitly
-- enable the subjects they actually teach, teachers still need an active
-- teaching scope, and student access remains assignment/RLS controlled.
--
-- Use stable ASCII codes so existing installations can keep their current
-- subject ids. on conflict do nothing deliberately avoids rewriting any
-- existing subject name or lifecycle decision.

insert into public.subjects (code, name, status)
values
  ('chinese', '语文', 'active'),
  ('math', '数学', 'active'),
  ('english', '英语', 'active'),
  ('physics', '物理', 'active'),
  ('chemistry', '化学', 'active'),
  ('biology', '生物', 'active'),
  ('history', '历史', 'active'),
  ('geography', '地理', 'active'),
  ('moral_and_rule_of_law', '道德与法治', 'active'),
  ('politics', '思想政治', 'active'),
  ('science', '科学', 'active'),
  ('information_technology', '信息科技', 'active'),
  ('physical_education', '体育与健康', 'active'),
  ('music', '音乐', 'active'),
  ('art', '美术', 'active')
on conflict (code) do nothing;
