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

  insert into public.identity_links (
    id,
    app_user_id,
    provider_key,
    issuer,
    external_subject,
    status
  )
  values
    (
      '60000000-0000-0000-0000-000000000001',
      '10000000-0000-0000-0000-000000000001',
      'supabase',
      'http://127.0.0.1:54321/auth/v1',
      auth_a::text,
      'active'
    ),
    (
      '60000000-0000-0000-0000-000000000002',
      '10000000-0000-0000-0000-000000000002',
      'supabase',
      'http://127.0.0.1:54321/auth/v1',
      auth_b::text,
      'active'
    ),
    (
      '60000000-0000-0000-0000-000000000003',
      '10000000-0000-0000-0000-000000000003',
      'supabase',
      'http://127.0.0.1:54321/auth/v1',
      auth_no_membership::text,
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

  insert into public.organization_memberships (
    id,
    organization_id,
    app_user_id,
    status
  )
  values
    (
      '61000000-0000-0000-0000-000000000001',
      '00000000-0000-0000-0000-000000000001',
      '10000000-0000-0000-0000-000000000001',
      'active'
    ),
    (
      '61000000-0000-0000-0000-000000000002',
      '00000000-0000-0000-0000-000000000002',
      '10000000-0000-0000-0000-000000000002',
      'active'
    );

  insert into public.membership_roles (
    id,
    organization_id,
    membership_id,
    role
  )
  values
    (
      '62000000-0000-0000-0000-000000000001',
      '00000000-0000-0000-0000-000000000001',
      '61000000-0000-0000-0000-000000000001',
      'teacher'
    ),
    (
      '62000000-0000-0000-0000-000000000002',
      '00000000-0000-0000-0000-000000000002',
      '61000000-0000-0000-0000-000000000002',
      'teacher'
    );

  insert into public.subjects (id, code, name, status)
  values
    (
      '63000000-0000-0000-0000-000000000001',
      'math',
      '数学',
      'active'
    ),
    (
      '63000000-0000-0000-0000-000000000002',
      'english',
      '英语',
      'active'
    );

  insert into public.organization_subjects (
    id,
    organization_id,
    subject_id,
    display_name,
    status
  )
  values
    (
      '64000000-0000-0000-0000-000000000001',
      '00000000-0000-0000-0000-000000000001',
      '63000000-0000-0000-0000-000000000001',
      '数学',
      'active'
    ),
    (
      '64000000-0000-0000-0000-000000000002',
      '00000000-0000-0000-0000-000000000002',
      '63000000-0000-0000-0000-000000000002',
      '英语',
      'active'
    );

  insert into public.membership_subject_scopes (
    id,
    organization_id,
    membership_id,
    organization_subject_id,
    scope_kind,
    status,
    active_from
  )
  values
    (
      '65000000-0000-0000-0000-000000000001',
      '00000000-0000-0000-0000-000000000001',
      '61000000-0000-0000-0000-000000000001',
      '64000000-0000-0000-0000-000000000001',
      'teaching',
      'active',
      '2026-01-01'
    ),
    (
      '65000000-0000-0000-0000-000000000002',
      '00000000-0000-0000-0000-000000000002',
      '61000000-0000-0000-0000-000000000002',
      '64000000-0000-0000-0000-000000000002',
      'teaching',
      'active',
      '2026-01-01'
    );

  insert into public.student_enrollments (
    id,
    organization_id,
    student_id,
    grade,
    class_name,
    campus,
    starts_on
  )
  values
    (
      '66000000-0000-0000-0000-000000000001',
      '00000000-0000-0000-0000-000000000001',
      '30000000-0000-0000-0000-000000000001',
      '初二',
      'A班',
      '厦门校区',
      '2026-01-01'
    ),
    (
      '66000000-0000-0000-0000-000000000002',
      '00000000-0000-0000-0000-000000000002',
      '30000000-0000-0000-0000-000000000002',
      '初二',
      'B班',
      '深圳校区',
      '2026-01-01'
    );

  insert into public.student_subject_profiles (
    id,
    organization_id,
    student_id,
    organization_subject_id,
    status,
    positioning,
    strengths,
    cadence_note
  )
  values
    (
      '67000000-0000-0000-0000-000000000001',
      '00000000-0000-0000-0000-000000000001',
      '30000000-0000-0000-0000-000000000001',
      '64000000-0000-0000-0000-000000000001',
      'active',
      '函数基础需要持续巩固',
      '愿意复盘错题',
      '每周一次'
    ),
    (
      '67000000-0000-0000-0000-000000000002',
      '00000000-0000-0000-0000-000000000002',
      '30000000-0000-0000-0000-000000000002',
      '64000000-0000-0000-0000-000000000002',
      'active',
      '阅读理解需要稳定训练',
      '口头表达积极',
      '每周一次'
    );

  insert into public.student_teacher_assignments (
    id,
    organization_id,
    student_subject_profile_id,
    membership_id,
    assignment_role,
    status,
    active_from
  )
  values
    (
      '68000000-0000-0000-0000-000000000001',
      '00000000-0000-0000-0000-000000000001',
      '67000000-0000-0000-0000-000000000001',
      '61000000-0000-0000-0000-000000000001',
      'lead',
      'active',
      '2026-01-01'
    ),
    (
      '68000000-0000-0000-0000-000000000002',
      '00000000-0000-0000-0000-000000000002',
      '67000000-0000-0000-0000-000000000002',
      '61000000-0000-0000-0000-000000000002',
      'lead',
      'active',
      '2026-01-01'
    );

  -- Teacher A is the fictional development manager for organization-scoped
  -- Case type configuration. This seed data is never for production.
  insert into public.membership_roles (
    id,
    organization_id,
    membership_id,
    role
  )
  values (
    '62000000-0000-0000-0000-000000000010',
    '00000000-0000-0000-0000-000000000001',
    '61000000-0000-0000-0000-000000000001',
    'org_admin'
  );

  -- Teacher A is also the fictional responsible person for Organization A.
  -- This role exists only so local tests and the development UI can exercise
  -- the owner path without creating a real account.
  insert into public.membership_roles (
    id,
    organization_id,
    membership_id,
    role
  )
  values (
    '62000000-0000-0000-0000-000000000011',
    '00000000-0000-0000-0000-000000000001',
    '61000000-0000-0000-0000-000000000001',
    'org_owner'
  );

end;
$seed$;
