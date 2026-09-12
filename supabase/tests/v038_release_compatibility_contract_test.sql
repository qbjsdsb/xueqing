begin;

select plan(4);

select has_function(
  'public',
  'xueqing_backend_compatibility',
  array[]::text[],
  'stable release compatibility RPC exists'
);

select is(
  public.xueqing_backend_compatibility()
    -> 'capabilities' ->> 'responsibility_read_model',
  'true',
  'v0.3.8 responsibility read model includes Organization Profile Lead data'
);

select is(
  public.xueqing_backend_compatibility()
    -> 'capabilities' ->> 'organization_profile_responsibility',
  'true',
  'v0.3.8 explicitly advertises Organization Profile responsibility support'
);

set local role anon;
select is(
  public.xueqing_backend_compatibility()
    -> 'capabilities' ->> 'organization_profile_responsibility',
  'true',
  'publishable-key role can read v0.3.8 compatibility without private-schema access'
);
reset role;

select * from finish();
rollback;