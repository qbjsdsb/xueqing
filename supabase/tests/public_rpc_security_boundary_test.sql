begin;

select plan(4);

with expected(signature, authenticated_allowed) as (
  values
    ('public.accept_organization_invitation(text, text)'::regprocedure, true),
    ('public.add_case_evidence(uuid, uuid, integer, text, text, timestamp with time zone, text)'::regprocedure, true),
    ('public.approve_organization_invitation(uuid)'::regprocedure, true),
    ('public.archive_organization_case_type(uuid, integer)'::regprocedure, true),
    ('public.close_case(uuid, uuid, integer, timestamp with time zone)'::regprocedure, true),
    ('public.complete_member_onboarding()'::regprocedure, true),
    ('public.confirm_case(uuid, uuid, integer, text, timestamp with time zone)'::regprocedure, true),
    ('public.create_organization_case_type(uuid, text, text)'::regprocedure, true),
    ('public.create_organization_invitation(uuid, text, text)'::regprocedure, true),
    ('public.create_organization_student(uuid, uuid, text, text, text, text, text, uuid, uuid, date, text, text, text)'::regprocedure, true),
    ('public.create_organization_subject(uuid, uuid, uuid)'::regprocedure, true),
    ('public.get_my_membership_state()'::regprocedure, true),
    ('public.list_organization_invitations(uuid)'::regprocedure, true),
    ('public.list_organization_members(uuid)'::regprocedure, true),
    ('public.list_organization_setup_options(uuid)'::regprocedure, true),
    ('public.list_organization_student_teacher_assignments(uuid)'::regprocedure, true),
    ('public.list_organization_students(uuid)'::regprocedure, true),
    ('public.list_organization_subject_catalog(uuid)'::regprocedure, true),
    ('public.list_organization_teacher_subject_scopes(uuid)'::regprocedure, true),
    ('public.prepare_member_credential_reissue(uuid, uuid, uuid, uuid)'::regprocedure, false),
    ('public.provision_organization_member_from_auth(uuid, uuid, text, uuid, uuid, text)'::regprocedure, false),
    ('public.quick_capture_case(uuid, uuid, integer, text, text, text, timestamp with time zone, text, text, timestamp with time zone)'::regprocedure, true),
    ('public.quick_capture_case_with_type(uuid, uuid, integer, text, text, text, timestamp with time zone, text, text, timestamp with time zone, uuid)'::regprocedure, true),
    ('public.record_assessment(uuid, uuid, integer, text, text, text, timestamp with time zone, text, timestamp with time zone)'::regprocedure, true),
    ('public.record_intervention(uuid, uuid, integer, text, text, timestamp with time zone, text, timestamp with time zone)'::regprocedure, true),
    ('public.reissue_organization_invitation(uuid)'::regprocedure, true),
    ('public.rename_organization_case_type(uuid, text, integer)'::regprocedure, true),
    ('public.reschedule_case_action(uuid, uuid, uuid, integer, integer, date)'::regprocedure, true),
    ('public.revoke_member_auth_sessions(uuid)'::regprocedure, false),
    ('public.revoke_organization_invitation(uuid)'::regprocedure, true),
    ('public.stabilize_case(uuid, uuid, integer, timestamp with time zone, text, timestamp with time zone)'::regprocedure, true),
    ('public.transfer_organization_student_teacher_assignment(uuid, uuid, uuid, integer, uuid)'::regprocedure, true),
    ('public.update_organization_membership_status(uuid, uuid, uuid, integer, text)'::regprocedure, true),
    ('public.update_organization_student(uuid, uuid, uuid, integer, text, text, text)'::regprocedure, true),
    ('public.update_organization_teacher_subject_scope(uuid, uuid, uuid, uuid, uuid, integer, text)'::regprocedure, true)
),
found as (
  select
    e.authenticated_allowed,
    p.oid,
    p.prosecdef,
    has_function_privilege('anon', p.oid, 'execute') as anon_can_execute,
    has_function_privilege('authenticated', p.oid, 'execute') as authenticated_can_execute
  from expected as e
  join pg_catalog.pg_proc as p on p.oid = e.signature
)
select ok(
  (select count(*) from found) = 35
  and not exists (
    select 1
    from found
    where prosecdef
      or anon_can_execute
      or authenticated_can_execute <> authenticated_allowed
  ),
  'public RPCs are invoker-only and have explicit caller grants'
);

with expected(signature, authenticated_allowed) as (
  values
    ('private.accept_organization_invitation(text, text)'::regprocedure, true),
    ('private.add_case_evidence(uuid, uuid, integer, text, text, timestamp with time zone, text)'::regprocedure, true),
    ('private.approve_organization_invitation(uuid)'::regprocedure, true),
    ('private.archive_organization_case_type(uuid, integer)'::regprocedure, true),
    ('private.close_case(uuid, uuid, integer, timestamp with time zone)'::regprocedure, true),
    ('private.complete_member_onboarding()'::regprocedure, true),
    ('private.confirm_case(uuid, uuid, integer, text, timestamp with time zone)'::regprocedure, true),
    ('private.create_organization_case_type(uuid, text, text)'::regprocedure, true),
    ('private.create_organization_invitation(uuid, text, text)'::regprocedure, true),
    ('private.create_organization_student(uuid, uuid, text, text, text, text, text, uuid, uuid, date, text, text, text)'::regprocedure, true),
    ('private.create_organization_subject(uuid, uuid, uuid)'::regprocedure, true),
    ('private.get_my_membership_state()'::regprocedure, true),
    ('private.list_organization_invitations(uuid)'::regprocedure, true),
    ('private.list_organization_members(uuid)'::regprocedure, true),
    ('private.list_organization_setup_options(uuid)'::regprocedure, true),
    ('private.list_organization_student_teacher_assignments(uuid)'::regprocedure, true),
    ('private.list_organization_students(uuid)'::regprocedure, true),
    ('private.list_organization_subject_catalog(uuid)'::regprocedure, true),
    ('private.list_organization_teacher_subject_scopes(uuid)'::regprocedure, true),
    ('private.prepare_member_credential_reissue(uuid, uuid, uuid, uuid)'::regprocedure, false),
    ('private.provision_organization_member_from_auth(uuid, uuid, text, uuid, uuid, text)'::regprocedure, false),
    ('private.quick_capture_case(uuid, uuid, integer, text, text, text, timestamp with time zone, text, text, timestamp with time zone)'::regprocedure, true),
    ('private.quick_capture_case_with_type(uuid, uuid, integer, text, text, text, timestamp with time zone, text, text, timestamp with time zone, uuid)'::regprocedure, true),
    ('private.record_assessment(uuid, uuid, integer, text, text, text, timestamp with time zone, text, timestamp with time zone)'::regprocedure, true),
    ('private.record_intervention(uuid, uuid, integer, text, text, timestamp with time zone, text, timestamp with time zone)'::regprocedure, true),
    ('private.reissue_organization_invitation(uuid)'::regprocedure, true),
    ('private.rename_organization_case_type(uuid, text, integer)'::regprocedure, true),
    ('private.reschedule_case_action(uuid, uuid, uuid, integer, integer, date)'::regprocedure, true),
    ('private.revoke_member_auth_sessions(uuid)'::regprocedure, false),
    ('private.revoke_organization_invitation(uuid)'::regprocedure, true),
    ('private.stabilize_case(uuid, uuid, integer, timestamp with time zone, text, timestamp with time zone)'::regprocedure, true),
    ('private.transfer_organization_student_teacher_assignment(uuid, uuid, uuid, integer, uuid)'::regprocedure, true),
    ('private.update_organization_membership_status(uuid, uuid, uuid, integer, text)'::regprocedure, true),
    ('private.update_organization_student(uuid, uuid, uuid, integer, text, text, text)'::regprocedure, true),
    ('private.update_organization_teacher_subject_scope(uuid, uuid, uuid, uuid, uuid, integer, text)'::regprocedure, true)
),
found as (
  select
    e.authenticated_allowed,
    p.oid,
    p.prosecdef,
    has_function_privilege('service_role', p.oid, 'execute') as service_role_can_execute,
    has_function_privilege('authenticated', p.oid, 'execute') as authenticated_can_execute
  from expected as e
  join pg_catalog.pg_proc as p on p.oid = e.signature
)
select ok(
  (select count(*) from found) = 35
  and not exists (
    select 1
    from found
    where not prosecdef
      or not service_role_can_execute
      or authenticated_can_execute <> authenticated_allowed
  ),
  'private implementations retain definer execution and intended grants'
);

select ok(
  has_schema_privilege('authenticated', 'private', 'usage')
  and has_schema_privilege('service_role', 'private', 'usage'),
  'only authenticated and service roles can resolve private RPC implementations'
);

select ok(
  not exists (
    select 1
    from pg_catalog.pg_proc as p
    join pg_catalog.pg_namespace as n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.prosecdef
  ),
  'no SECURITY DEFINER function remains in public'
);

select * from finish();
rollback;
