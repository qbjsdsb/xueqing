-- P0 Gate A: Auth Identity Portability contract spike.
-- This test uses temporary tables only. It never changes the development schema
-- and never stores a provider credential or real user data.

begin;

select plan(18);

select is(
  (
    select data_type
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'app_users'
      and column_name = 'id'
  ),
  'uuid',
  'business identity has a provider-independent UUID'
);

select is(
  (
    select data_type
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'app_users'
      and column_name = 'auth_subject_id'
  ),
  'text',
  'external auth subject is stored as text'
);

select is(
  (
    select data_type
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'app_users'
      and column_name = 'auth_provider'
  ),
  'text',
  'auth provider key is stored as text'
);

select is(
  (
    select count(*)::int
    from pg_constraint
    where conrelid = 'public.app_users'::regclass
      and confrelid = 'auth.users'::regclass
      and contype = 'f'
  ),
  0,
  'business identity is not physically foreign-keyed to provider auth users'
);

create temporary table portability_profiles (
  id uuid primary key,
  display_name text not null
);

create temporary table portability_identity_links (
  id uuid primary key,
  business_profile_id uuid not null references portability_profiles(id),
  provider_key text not null check (char_length(btrim(provider_key)) > 0),
  issuer text not null check (char_length(btrim(issuer)) > 0),
  external_subject text not null check (char_length(btrim(external_subject)) > 0),
  status text not null check (status in ('active', 'retired')),
  unique (provider_key, issuer, external_subject)
);

create unique index portability_one_active_link_per_profile
  on portability_identity_links (business_profile_id)
  where status = 'active';

create temporary table portability_facts (
  id uuid primary key,
  business_profile_id uuid not null references portability_profiles(id),
  fact_text text not null
);

insert into portability_profiles (id, display_name)
values (
  '91000000-0000-0000-0000-000000000001',
  '虚构教师'
);

insert into portability_facts (id, business_profile_id, fact_text)
values (
  '92000000-0000-0000-0000-000000000001',
  '第一条虚构教学事实'
);

insert into portability_identity_links (
  id,
  business_profile_id,
  provider_key,
  issuer,
  external_subject,
  status
)
values (
  '93000000-0000-0000-0000-000000000001',
  '91000000-0000-0000-0000-000000000001',
  'supabase',
  'supabase-dev',
  '550e8400-e29b-41d4-a716-446655440000',
  'active'
);

select is(
  (
    select count(*)::int
    from portability_profiles
    where id = '91000000-0000-0000-0000-000000000001'
  ),
  1,
  'business profile keeps its stable UUID'
);

select is(
  (
    select count(*)::int
    from portability_facts
    where business_profile_id = '91000000-0000-0000-0000-000000000001'
  ),
  1,
  'child teaching facts reference the business UUID'
);

select is(
  (
    select pg_typeof(external_subject)::text
    from portability_identity_links
    where provider_key = 'supabase'
  ),
  'text',
  'a UUID-shaped Supabase subject remains a text subject'
);

select is(
  (
    select business_profile_id
    from portability_identity_links
    where provider_key = 'supabase'
      and issuer = 'supabase-dev'
      and external_subject = '550e8400-e29b-41d4-a716-446655440000'
      and status = 'active'
  ),
  '91000000-0000-0000-0000-000000000001'::uuid,
  'exact external identity lookup resolves the stable business UUID'
);

select is(
  (
    select count(*)::int
    from portability_facts
    where business_profile_id = '91000000-0000-0000-0000-000000000001'
  ),
  1,
  'facts remain attached before provider migration'
);

update portability_identity_links
set status = 'retired'
where provider_key = 'supabase'
  and issuer = 'supabase-dev'
  and external_subject = '550e8400-e29b-41d4-a716-446655440000';

insert into portability_identity_links (
  id,
  business_profile_id,
  provider_key,
  issuer,
  external_subject,
  status
)
values (
  '93000000-0000-0000-0000-000000000002',
  '91000000-0000-0000-0000-000000000001',
  'cloudbase',
  'cloudbase-dev',
  '1001',
  'active'
);

select is(
  (
    select count(*)::int
    from portability_identity_links
    where provider_key = 'cloudbase'
      and issuer = 'cloudbase-dev'
      and external_subject = '1001'
  ),
  1,
  'a non-UUID candidate-provider subject is accepted without casting'
);

select is(
  (
    select count(*)::int
    from portability_identity_links
    where business_profile_id = '91000000-0000-0000-0000-000000000001'
      and status = 'active'
  ),
  1,
  'provider switch leaves exactly one active identity link in V1'
);

select is(
  (
    select business_profile_id
    from portability_identity_links
    where provider_key = 'cloudbase'
      and issuer = 'cloudbase-dev'
      and external_subject = '1001'
      and status = 'active'
  ),
  '91000000-0000-0000-0000-000000000001'::uuid,
  'provider switch resolves to the same business UUID'
);

select is(
  (
    select count(*)::int
    from portability_facts
    where business_profile_id = '91000000-0000-0000-0000-000000000001'
  ),
  1,
  'provider switch does not rewrite child teaching facts'
);

select is(
  (
    select count(*)::int
    from portability_identity_links
    where provider_key = 'supabase'
      and issuer = 'supabase-dev'
      and status = 'active'
  ),
  0,
  'retired provider identity cannot remain an active login link'
);

create temporary table duplicate_probe (caught boolean not null default false);
insert into duplicate_probe values (false);

do $$
begin
  begin
    insert into portability_profiles (id, display_name)
    values (
      '91000000-0000-0000-0000-000000000002',
      '第二个虚构身份'
    );

    insert into portability_identity_links (
      id,
      business_profile_id,
      provider_key,
      issuer,
      external_subject,
      status
    )
    values (
      '93000000-0000-0000-0000-000000000003',
      '91000000-0000-0000-0000-000000000002',
      'cloudbase',
      'cloudbase-dev',
      '1001',
      'active'
    );
  exception
    when unique_violation then
      update duplicate_probe set caught = true;
  end;
end
$$;

select is(
  (select caught from duplicate_probe),
  true,
  'the same provider issuer and subject cannot bind to another business UUID'
);

insert into portability_profiles (id, display_name)
values (
  '91000000-0000-0000-0000-000000000003',
  '第三个虚构身份'
);

insert into portability_identity_links (
  id,
  business_profile_id,
  provider_key,
  issuer,
  external_subject,
  status
)
values (
  '93000000-0000-0000-0000-000000000004',
  '91000000-0000-0000-0000-000000000003',
  'cloudbase',
  'cloudbase-other-dev',
  '1001',
  'active'
);

select is(
  (
    select count(*)::int
    from portability_identity_links
    where provider_key = 'cloudbase'
      and external_subject = '1001'
  ),
  2,
  'identity subject uniqueness is correctly scoped by issuer'
);

select is(
  (
    select count(*)::int
    from pg_constraint
    where conrelid = to_regclass('pg_temp.portability_facts')
      and confrelid = to_regclass('pg_temp.portability_profiles')
      and contype = 'f'
  ),
  1,
  'child facts are foreign-keyed to the business profile, not the provider subject'
);

select * from finish();
rollback;
