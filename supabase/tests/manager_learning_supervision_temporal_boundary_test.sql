begin;

select plan(3);

-- The development seed intentionally gives Teacher A organization leadership
-- roles for management scenarios. Strip those roles inside this rollback-only
-- test so the assertions exercise the pure-teacher boundary rather than the
-- manager override.
delete from public.membership_roles
where membership_id = '61000000-0000-0000-0000-000000000001'
  and role in ('org_owner', 'org_admin');

-- Teacher A remains a valid teacher for the seeded math profile.
select is(
  (
    select private.legal_case_responsibility_membership_v2(
      '67000000-0000-0000-0000-000000000001',
      '61000000-0000-0000-0000-000000000001'
    )
  ),
  true,
  'currently effective assignment and scope make the pure teacher a legal Case owner'
);

-- An assignment may still carry status=active while its business-date window is
-- already over. The manager supervision helper must preserve the original date
-- gate instead of treating status alone as sufficient.
update public.student_teacher_assignments
set active_to = date '2026-01-02'
where id = '68000000-0000-0000-0000-000000000001';

select is(
  (
    select private.legal_case_responsibility_membership_v2(
      '67000000-0000-0000-0000-000000000001',
      '61000000-0000-0000-0000-000000000001'
    )
  ),
  false,
  'expired assignment is not a legal teacher Case responsibility even when status stays active'
);

update public.student_teacher_assignments
set active_to = null
where id = '68000000-0000-0000-0000-000000000001';

update public.membership_subject_scopes
set active_to = date '2026-01-02'
where id = '65000000-0000-0000-0000-000000000001';

select is(
  (
    select private.legal_case_responsibility_membership_v2(
      '67000000-0000-0000-0000-000000000001',
      '61000000-0000-0000-0000-000000000001'
    )
  ),
  false,
  'expired teaching scope is not a legal teacher Case responsibility even when status stays active'
);

select * from finish();
rollback;
