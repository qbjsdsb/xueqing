-- Fictional development-only seed data for Phase 0B.0-A.
-- Never run this seed against production.

do $seed$
declare
  auth_a uuid := '20000000-0000-0000-0000-000000000001';
  auth_b uuid := '20000000-0000-0000-0000-000000000002';
  auth_no_membership uuid := '20000000-0000-0000-0000-000000000003';
begin
  insert into auth.users (
    id,
    instance_id,
    aud,
    role,
    email,
    encrypted_password,
    email_confirmed_at,
    created_at,
    updated_at,
    raw_app_meta_data,
    raw_user_meta_data,
    confirmation_token,
    email_change,
    email_change_token_new,
    recovery_token
  )
  values
    (
      auth_a,
      '00000000-0000-0000-0000-000000000000',
      'authenticated',
      'authenticated',
      'teacher.a@xueqing.test',
      crypt('XueqingDev-Only-123!', gen_salt('bf')),
      now(),
      now(),
      now(),
      '{"provider":"email","providers":["email"]}'::jsonb,
      '{}'::jsonb,
      '',
      '',
      '',
      ''
    ),
    (
      auth_b,
      '00000000-0000-0000-0000-000000000000',
      'authenticated',
      'authenticated',
      'teacher.b@xueqing.test',
      crypt('XueqingDev-Only-123!', gen_salt('bf')),
      now(),
      now(),
      now(),
      '{"provider":"email","providers":["email"]}'::jsonb,
      '{}'::jsonb,
      '',
      '',
      '',
      ''
    ),
    (
      auth_no_membership,
      '00000000-0000-0000-0000-000000000000',
      'authenticated',
      'authenticated',
      'no.membership@xueqing.test',
      crypt('XueqingDev-Only-123!', gen_salt('bf')),
      now(),
      now(),
      now(),
      '{"provider":"email","providers":["email"]}'::jsonb,
      '{}'::jsonb,
      '',
      '',
      '',
      ''
    );

  insert into auth.identities (
    id,
    user_id,
    identity_data,
    provider,
    provider_id,
    created_at,
    updated_at
  )
  select
    gen_random_uuid(),
    users.id,
    jsonb_build_object(
      'sub', users.id::text,
      'email', users.email
    ),
    'email',
    users.id::text,
    now(),
    now()
  from auth.users as users;

  insert into public.organizations (id, name)
  values
    ('00000000-0000-0000-0000-000000000001', '厦门启航教育'),
    ('00000000-0000-0000-0000-000000000002', '深圳星河教育');

  insert into public.app_users (
    id,
    auth_provider,
    auth_subject_id,
    display_name,
    status
  )
  values
    (
      '10000000-0000-0000-0000-000000000001',
      'supabase',
      auth_a::text,
      '王老师',
      'active'
    ),
    (
      '10000000-0000-0000-0000-000000000002',
      'supabase',
      auth_b::text,
      '李老师',
      'active'
    ),
    (
      '10000000-0000-0000-0000-000000000003',
      'supabase',
      auth_no_membership::text,
      '无机构测试用户',
      'active'
    );

  insert into public.memberships (id, organization_id, user_id, role, status)
  values
    (
      '11000000-0000-0000-0000-000000000001',
      '00000000-0000-0000-0000-000000000001',
      '10000000-0000-0000-0000-000000000001',
      'teacher',
      'active'
    ),
    (
      '11000000-0000-0000-0000-000000000002',
      '00000000-0000-0000-0000-000000000002',
      '10000000-0000-0000-0000-000000000002',
      'teacher',
      'active'
    );

  insert into public.students (id, organization_id, name, status)
  values
    (
      '30000000-0000-0000-0000-000000000001',
      '00000000-0000-0000-0000-000000000001',
      '林雨桐',
      'active'
    ),
    (
      '30000000-0000-0000-0000-000000000002',
      '00000000-0000-0000-0000-000000000002',
      '陈宇航',
      'active'
    );

  insert into public.teacher_assignments (
    id,
    teacher_id,
    student_id,
    subject,
    status
  )
  values
    (
      '40000000-0000-0000-0000-000000000001',
      '10000000-0000-0000-0000-000000000001',
      '30000000-0000-0000-0000-000000000001',
      '数学',
      'active'
    ),
    (
      '40000000-0000-0000-0000-000000000002',
      '10000000-0000-0000-0000-000000000002',
      '30000000-0000-0000-0000-000000000002',
      '英语',
      'active'
    );

  insert into auth.sessions (id, user_id, created_at, updated_at)
  values
    (
      '50000000-0000-0000-0000-000000000001',
      auth_a,
      now(),
      now()
    ),
    (
      '50000000-0000-0000-0000-000000000002',
      auth_b,
      now(),
      now()
    ),
    (
      '50000000-0000-0000-0000-000000000003',
      auth_no_membership,
      now(),
      now()
    );
end;
$seed$;
