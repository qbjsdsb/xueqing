-- Production-pilot subject catalog baseline.
--
-- Organization managers can only enable subjects that already exist in the
-- global catalog. The original fictional seed provides only Mathematics and
-- English, which makes a fresh real institution unable to add Chinese or the
-- other common K-12 subjects. Keep the shared catalog small and conventional;
-- organization-specific selection still happens through the guarded
-- create_organization_subject command.

insert into public.subjects (id, code, name, status)
values
  (gen_random_uuid(), 'chinese', '语文', 'active'),
  (gen_random_uuid(), 'physics', '物理', 'active'),
  (gen_random_uuid(), 'chemistry', '化学', 'active'),
  (gen_random_uuid(), 'biology', '生物', 'active'),
  (gen_random_uuid(), 'history', '历史', 'active'),
  (gen_random_uuid(), 'geography', '地理', 'active'),
  (gen_random_uuid(), 'civics', '道德与法治', 'active'),
  (gen_random_uuid(), 'science', '科学', 'active'),
  (gen_random_uuid(), 'information_technology', '信息科技', 'active')
on conflict (code) do update
set name = excluded.name,
    status = 'active';
