from pathlib import Path

# The generic student lifecycle test now owns identity correction, authorization,
# idempotency, and optimistic concurrency. Temporary pause / archive semantics
# are covered by student_teaching_pause_resume_test.sql.
path = Path('supabase/tests/organization_student_lifecycle_test.sql')
text = path.read_text()
text = text.replace('select plan(37);', 'select plan(28);', 1)
start_marker = "select lives_ok(\n  $$\n    select set_config(\n      'xueqing.student_update',"
end_marker = "select * from finish();\n\nrollback;"
start = text.index(start_marker)
end = text.index(end_marker, start)
replacement = r'''select lives_ok(
  $$
    select set_config(
      'xueqing.student_update',
      public.update_organization_student(
        '74000000-0000-0000-0000-000000000003',
        '00000000-0000-0000-0000-000000000001',
        '30000000-0000-0000-0000-000000000001',
        1,
        '林雨桐（档案更新）',
        'S-UPDATED',
        'active'
      )::text,
      true
    )
  $$,
  'a manager can correct student identity without changing teaching lifecycle'
);

select is(
  current_setting('xueqing.student_update')::jsonb ->> 'student_name',
  '林雨桐（档案更新）',
  'student update returns the normalized name'
);

select is(
  current_setting('xueqing.student_update')::jsonb ->> 'status',
  'active',
  'ordinary identity correction preserves active teaching status'
);

select is(
  (current_setting('xueqing.student_update')::jsonb ->> 'version')::int,
  2,
  'student identity update increments the optimistic version'
);

reset role;

select is(
  (
    select student.name || '|' || student.student_code || '|' ||
      student.status || '|' || student.version::text
    from public.students as student
    where student.id =
      '30000000-0000-0000-0000-000000000001'
  ),
  '林雨桐（档案更新）|S-UPDATED|active|2',
  'student root stores identity correction without lifecycle drift'
);

select is(
  (
    select archived_at is null
    from public.students
    where id = '30000000-0000-0000-0000-000000000001'
  ),
  true,
  'ordinary identity correction does not create archive metadata'
);

set local role authenticated;

select is(
  (
    select item ->> 'status'
    from public.list_organization_students(
      '00000000-0000-0000-0000-000000000001'
    ) as item
  ),
  'active',
  'manager roster reflects unchanged teaching lifecycle after identity correction'
);

select lives_ok(
  $$
    select public.update_organization_student(
      '74000000-0000-0000-0000-000000000003',
      '00000000-0000-0000-0000-000000000001',
      '30000000-0000-0000-0000-000000000001',
      1,
      'different retry name',
      'DIFFERENT',
      'inactive'
    )
  $$,
  'repeating the identity operation returns its committed result'
);

reset role;

select is(
  (
    select count(*)::int
    from public.operation_receipts
    where operation_id =
      '74000000-0000-0000-0000-000000000003'
      and command_type = 'update_organization_student'
      and target_type = 'student'
      and result ->> 'student_name' = '林雨桐（档案更新）'
      and result ->> 'status' = 'active'
      and committed_at is not null
  ),
  1,
  'identity retry keeps one committed operation receipt'
);

set local role authenticated;

select throws_ok(
  $$
    select public.update_organization_student(
      '74000000-0000-0000-0000-000000000005',
      '00000000-0000-0000-0000-000000000001',
      '30000000-0000-0000-0000-000000000001',
      1,
      '过期版本',
      null,
      'active'
    )
  $$,
  'P0001',
  null,
  'stale student version is rejected'
);

'''
path.write_text(text[:start] + replacement + text[end:])

# This test is only about the read boundary. Build an archived fixture that is
# consistent with the new lifecycle instead of directly jumping active->archived.
path = Path('supabase/tests/student_active_read_boundary_test.sql')
text = path.read_text()
old = """reset role;\nupdate public.students\nset status = 'archived',\n    archived_at = timezone('utc', now())\nwhere id = '30000000-0000-0000-0000-000000000001';\n"""
new = """reset role;\nupdate public.student_teacher_assignments\nset status = 'ended',\n    active_to = active_from,\n    ended_at = timezone('utc', now())\nwhere student_subject_profile_id =\n  '67000000-0000-0000-0000-000000000001'\n  and status = 'active';\n\nupdate public.student_subject_profiles\nset status = 'inactive',\n    version = version + 1,\n    updated_at = timezone('utc', now())\nwhere id = '67000000-0000-0000-0000-000000000001';\n\nupdate public.students\nset status = 'inactive',\n    version = version + 1,\n    updated_at = timezone('utc', now())\nwhere id = '30000000-0000-0000-0000-000000000001';\n\nupdate public.students\nset status = 'archived',\n    version = version + 1,\n    updated_at = timezone('utc', now()),\n    archived_at = timezone('utc', now())\nwhere id = '30000000-0000-0000-0000-000000000001';\n"""
assert text.count(old) == 1, text.count(old)
path.write_text(text.replace(old, new, 1))
