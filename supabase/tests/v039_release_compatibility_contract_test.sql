begin;

select plan(6);

select has_function(
  'public',
  'xueqing_backend_compatibility',
  array[]::text[],
  'stable release compatibility RPC exists'
);

select is(
  public.xueqing_backend_compatibility() ->> 'schema_version',
  '20260911193000',
  'v0.3.9 preserves the stable structural schema floor'
);

select is(
  public.xueqing_backend_compatibility()
    -> 'capabilities' ->> 'explicit_teaching_handoff',
  'true',
  'v0.3.9 advertises explicit teaching handoff support'
);

select is(
  public.xueqing_backend_compatibility()
    -> 'capabilities' ->> 'set_student_subject_lead',
  'true',
  'v0.3.9 advertises missing Lead assignment support'
);

set local role anon;
select is(
  public.xueqing_backend_compatibility()
    -> 'capabilities' ->> 'explicit_teaching_handoff',
  'true',
  'publishable-key role can read explicit handoff compatibility'
);
select is(
  public.xueqing_backend_compatibility()
    -> 'capabilities' ->> 'set_student_subject_lead',
  'true',
  'publishable-key role can read missing Lead compatibility'
);
reset role;

select * from finish();
rollback;
