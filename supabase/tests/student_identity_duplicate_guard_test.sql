begin;

select plan(14);

select is(
  (
    select index_record.indisunique
    from pg_catalog.pg_index as index_record
    where index_record.indexrelid =
      'public.students_organization_student_code_key'::regclass
  ),
  true,
  'student code index is unique'
);

select is(
  has_function_privilege(
    'authenticated',
    'private.guard_student_code_uniqueness_v2()',
    'execute'
  ),
  false,
  'authenticated cannot call the student code trigger directly'
);

select is(
  has_function_privilege(
    'authenticated',
    'private.guard_possible_duplicate_student_v2()',
    'execute'
  ),
  false,
  'authenticated cannot call the possible duplicate trigger directly'
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

select lives_ok(
  $$
    select set_config(
      'xueqing.coded_student',
      public.create_organization_student(
        '7a000000-0000-0000-0000-000000000001',
        '00000000-0000-0000-0000-000000000001',
        '编号学生甲',
        'DUP-001',
        '高一',
        '1班',
        '测试校区',
        '64000000-0000-0000-0000-000000000001',
        '61000000-0000-0000-0000-000000000001',
        null,
        null,
        null,
        null
      )::text,
      true
    )
  $$,
  'a manager can create a student with a new organization code'
);

select throws_ok(
  $$
    select public.create_organization_student(
      '7a000000-0000-0000-0000-000000000002',
      '00000000-0000-0000-0000-000000000001',
      '编号学生乙',
      ' dup-001 ',
      '高二',
      '2班',
      '测试校区',
      '64000000-0000-0000-0000-000000000001',
      '61000000-0000-0000-0000-000000000001',
      null,
      null,
      null,
      null
    )
  $$,
  'P0001',
  'student_code_already_exists',
  'student codes are unique within an organization after normalization'
);

select is(
  (
    select count(*)::int
    from public.students
    where organization_id = '00000000-0000-0000-0000-000000000001'
      and lower(btrim(student_code)) = 'dup-001'
  ),
  1,
  'a rejected duplicate code creates no second student'
);

select lives_ok(
  $$
    select public.create_organization_student(
      '7a000000-0000-0000-0000-000000000003',
      '00000000-0000-0000-0000-000000000001',
      '同名学生',
      null,
      '高一',
      '3班',
      '测试校区',
      '64000000-0000-0000-0000-000000000001',
      '61000000-0000-0000-0000-000000000001',
      null,
      null,
      null,
      null
    )
  $$,
  'an uncoded student can be created when the identity candidate is new'
);

select throws_ok(
  $$
    select public.create_organization_student(
      '7a000000-0000-0000-0000-000000000004',
      '00000000-0000-0000-0000-000000000001',
      ' 同名学生 ',
      null,
      '高一',
      '3班',
      '测试校区',
      '64000000-0000-0000-0000-000000000001',
      '61000000-0000-0000-0000-000000000001',
      null,
      null,
      null,
      null
    )
  $$,
  'P0001',
  'possible_duplicate_student',
  'an uncoded matching name and school context is rejected'
);

select lives_ok(
  $$
    select set_config(
      'xueqing.same_name_student',
      public.create_organization_student(
        '7a000000-0000-0000-0000-000000000005',
        '00000000-0000-0000-0000-000000000001',
        '同名学生',
        'TWIN-002',
        '高一',
        '3班',
        '测试校区',
        '64000000-0000-0000-0000-000000000001',
        '61000000-0000-0000-0000-000000000001',
        null,
        null,
        null,
        null
      )::text,
      true
    )
  $$,
  'a distinct code allows a real same-name student'
);

select is(
  (
    select count(*)::int
    from public.students
    where organization_id = '00000000-0000-0000-0000-000000000001'
      and name = '同名学生'
  ),
  2,
  'name remains a non-unique display attribute'
);

select throws_ok(
  $$
    select public.update_organization_student(
      '7a000000-0000-0000-0000-000000000006',
      '00000000-0000-0000-0000-000000000001',
      '30000000-0000-0000-0000-000000000001',
      1,
      '林雨桐',
      'DUP-001',
      'active'
    )
  $$,
  'P0001',
  'student_code_already_exists',
  'student lifecycle updates cannot reuse another student code'
);

reset role;

select is(
  (
    select count(*)::int
    from public.operation_receipts
    where operation_id in (
      '7a000000-0000-0000-0000-000000000002',
      '7a000000-0000-0000-0000-000000000004',
      '7a000000-0000-0000-0000-000000000006'
    )
  ),
  0,
  'rejected duplicate commands leave no claimed receipt'
);

select lives_ok(
  $$
    insert into public.students (
      id,
      organization_id,
      name,
      student_code,
      status
    )
    values (
      '7a000000-0000-0000-0000-000000000010',
      '00000000-0000-0000-0000-000000000002',
      '另一机构学生',
      'dup-001',
      'active'
    )
  $$,
  'the same student code remains valid in another organization'
);

select is(
  (
    select student_code
    from public.students
    where id = '7a000000-0000-0000-0000-000000000010'
  ),
  'dup-001',
  'the cross-organization code is stored without affecting the first org'
);

select * from finish();

rollback;
