begin;

select plan(14);

select is(
  (
    select count(*)::int
    from public.membership_roles
    where role not in ('org_owner', 'org_admin', 'teacher')
  ),
  0,
  'migration leaves only the three supported membership roles'
);

select throws_ok(
  $$
    update public.membership_roles
    set role = 'academic_admin'
    where id = '62000000-0000-0000-0000-000000000001'
  $$,
  '23514',
  null,
  'academic admin can no longer be assigned'
);

select throws_ok(
  $$
    update public.membership_roles
    set role = 'subject_lead'
    where id = '62000000-0000-0000-0000-000000000001'
  $$,
  '23514',
  null,
  'subject lead can no longer be assigned'
);

select throws_ok(
  $$
    update public.membership_roles
    set role = 'student_advisor'
    where id = '62000000-0000-0000-0000-000000000001'
  $$,
  '23514',
  null,
  'student advisor can no longer be assigned'
);

select ok(
  position(
    'academic_admin' in pg_get_functiondef(
      'public.create_organization_invitation(uuid,text,text)'::regprocedure
    )
  ) = 0,
  'invitation creation exposes no academic admin path'
);

select ok(
  position(
    'academic_admin' in pg_get_functiondef(
      'private.can_manage_organization_v2(uuid)'::regprocedure
    )
  ) = 0,
  'organization management uses the same three-role contract'
);

select ok(
  position(
    'academic_admin' in pg_get_functiondef(
      'private.can_manage_case_types_v2(uuid)'::regprocedure
    )
  ) = 0,
  'Case type management uses the same three-role contract'
);

set local role authenticated;

select set_config(
  'request.jwt.claim.sub',
  '20000000-0000-0000-0000-000000000001',
  true
);

select set_config(
  'request.jwt.claims',
  json_build_object(
    'role', 'authenticated',
    'sub', '20000000-0000-0000-0000-000000000001',
    'iss', 'http://127.0.0.1:54321/auth/v1',
    'session_id', '50000000-0000-0000-0000-000000000001'
  )::text,
  true
);

select throws_ok(
  $$
    select public.create_organization_invitation(
      '00000000-0000-0000-0000-000000000001',
      'legacy-academic@xueqing.test',
      'academic_admin'
    )
  $$,
  'P0001',
  'invalid_invitation_input',
  'academic admin invitations are rejected'
);

select throws_ok(
  $$
    select public.create_organization_invitation(
      '00000000-0000-0000-0000-000000000001',
      'legacy-lead@xueqing.test',
      'subject_lead'
    )
  $$,
  'P0001',
  'invalid_invitation_input',
  'subject lead invitations are rejected'
);

select throws_ok(
  $$
    select public.create_organization_invitation(
      '00000000-0000-0000-0000-000000000001',
      'legacy-advisor@xueqing.test',
      'student_advisor'
    )
  $$,
  'P0001',
  'invalid_invitation_input',
  'student advisor invitations are rejected'
);

select lives_ok(
  $$
    select set_config(
      'xueqing.three_role_admin_invite',
      public.create_organization_invitation(
        '00000000-0000-0000-0000-000000000001',
        'three-role-admin@xueqing.test',
        'org_admin'
      )::text,
      true
    )
  $$,
  'an owner can still invite an administrator'
);

select is(
  current_setting('xueqing.three_role_admin_invite')::jsonb ->> 'role',
  'org_admin',
  'administrator invitations keep the supported role'
);

select lives_ok(
  $$
    select set_config(
      'xueqing.three_role_teacher_invite',
      public.create_organization_invitation(
        '00000000-0000-0000-0000-000000000001',
        'three-role-teacher@xueqing.test',
        'teacher'
      )::text,
      true
    )
  $$,
  'an owner can still invite a teacher'
);

select is(
  current_setting('xueqing.three_role_teacher_invite')::jsonb ->> 'role',
  'teacher',
  'teacher invitations keep the supported role'
);

select * from finish();

rollback;
