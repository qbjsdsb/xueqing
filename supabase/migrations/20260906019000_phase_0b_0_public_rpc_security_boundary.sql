-- Phase 0B.0 security boundary: keep privileged implementations out of
-- the exposed API schema while preserving the existing RPC contracts.
--
-- The existing functions already enforce the domain and authorization rules.
-- This migration moves those implementations to private, then recreates only
-- thin SECURITY INVOKER wrappers in public. No business behavior is changed.

create schema if not exists private;
revoke all on schema private from public;
grant usage on schema private to authenticated, service_role;

alter function public.accept_organization_invitation(text, text) set schema private;
alter function public.add_case_evidence(uuid, uuid, integer, text, text, timestamp with time zone, text) set schema private;
alter function public.approve_organization_invitation(uuid) set schema private;
alter function public.archive_organization_case_type(uuid, integer) set schema private;
alter function public.close_case(uuid, uuid, integer, timestamp with time zone) set schema private;
alter function public.complete_member_onboarding() set schema private;
alter function public.confirm_case(uuid, uuid, integer, text, timestamp with time zone) set schema private;
alter function public.create_organization_case_type(uuid, text, text) set schema private;
alter function public.create_organization_invitation(uuid, text, text) set schema private;
alter function public.create_organization_student(uuid, uuid, text, text, text, text, text, uuid, uuid, date, text, text, text) set schema private;
alter function public.create_organization_subject(uuid, uuid, uuid) set schema private;
alter function public.get_my_membership_state() set schema private;
alter function public.list_organization_invitations(uuid) set schema private;
alter function public.list_organization_members(uuid) set schema private;
alter function public.list_organization_setup_options(uuid) set schema private;
alter function public.list_organization_student_teacher_assignments(uuid) set schema private;
alter function public.list_organization_students(uuid) set schema private;
alter function public.list_organization_subject_catalog(uuid) set schema private;
alter function public.list_organization_teacher_subject_scopes(uuid) set schema private;
alter function public.prepare_member_credential_reissue(uuid, uuid, uuid, uuid) set schema private;
alter function public.provision_organization_member_from_auth(uuid, uuid, text, uuid, uuid, text) set schema private;
alter function public.quick_capture_case(uuid, uuid, integer, text, text, text, timestamp with time zone, text, text, timestamp with time zone) set schema private;
alter function public.quick_capture_case_with_type(uuid, uuid, integer, text, text, text, timestamp with time zone, text, text, timestamp with time zone, uuid) set schema private;
alter function public.record_assessment(uuid, uuid, integer, text, text, text, timestamp with time zone, text, timestamp with time zone) set schema private;
alter function public.record_intervention(uuid, uuid, integer, text, text, timestamp with time zone, text, timestamp with time zone) set schema private;
alter function public.reissue_organization_invitation(uuid) set schema private;
alter function public.rename_organization_case_type(uuid, text, integer) set schema private;
alter function public.reschedule_case_action(uuid, uuid, uuid, integer, integer, date) set schema private;
alter function public.revoke_member_auth_sessions(uuid) set schema private;
alter function public.revoke_organization_invitation(uuid) set schema private;
alter function public.stabilize_case(uuid, uuid, integer, timestamp with time zone, text, timestamp with time zone) set schema private;
alter function public.transfer_organization_student_teacher_assignment(uuid, uuid, uuid, integer, uuid) set schema private;
alter function public.update_organization_membership_status(uuid, uuid, uuid, integer, text) set schema private;
alter function public.update_organization_student(uuid, uuid, uuid, integer, text, text, text) set schema private;
alter function public.update_organization_teacher_subject_scope(uuid, uuid, uuid, uuid, uuid, integer, text) set schema private;

revoke all on function private.accept_organization_invitation(text, text) from public, anon, authenticated, service_role;
grant execute on function private.accept_organization_invitation(text, text) to service_role, authenticated;
revoke all on function private.add_case_evidence(uuid, uuid, integer, text, text, timestamp with time zone, text) from public, anon, authenticated, service_role;
grant execute on function private.add_case_evidence(uuid, uuid, integer, text, text, timestamp with time zone, text) to service_role, authenticated;
revoke all on function private.approve_organization_invitation(uuid) from public, anon, authenticated, service_role;
grant execute on function private.approve_organization_invitation(uuid) to service_role, authenticated;
revoke all on function private.archive_organization_case_type(uuid, integer) from public, anon, authenticated, service_role;
grant execute on function private.archive_organization_case_type(uuid, integer) to service_role, authenticated;
revoke all on function private.close_case(uuid, uuid, integer, timestamp with time zone) from public, anon, authenticated, service_role;
grant execute on function private.close_case(uuid, uuid, integer, timestamp with time zone) to service_role, authenticated;
revoke all on function private.complete_member_onboarding() from public, anon, authenticated, service_role;
grant execute on function private.complete_member_onboarding() to service_role, authenticated;
revoke all on function private.confirm_case(uuid, uuid, integer, text, timestamp with time zone) from public, anon, authenticated, service_role;
grant execute on function private.confirm_case(uuid, uuid, integer, text, timestamp with time zone) to service_role, authenticated;
revoke all on function private.create_organization_case_type(uuid, text, text) from public, anon, authenticated, service_role;
grant execute on function private.create_organization_case_type(uuid, text, text) to service_role, authenticated;
revoke all on function private.create_organization_invitation(uuid, text, text) from public, anon, authenticated, service_role;
grant execute on function private.create_organization_invitation(uuid, text, text) to service_role, authenticated;
revoke all on function private.create_organization_student(uuid, uuid, text, text, text, text, text, uuid, uuid, date, text, text, text) from public, anon, authenticated, service_role;
grant execute on function private.create_organization_student(uuid, uuid, text, text, text, text, text, uuid, uuid, date, text, text, text) to service_role, authenticated;
revoke all on function private.create_organization_subject(uuid, uuid, uuid) from public, anon, authenticated, service_role;
grant execute on function private.create_organization_subject(uuid, uuid, uuid) to service_role, authenticated;
revoke all on function private.get_my_membership_state() from public, anon, authenticated, service_role;
grant execute on function private.get_my_membership_state() to service_role, authenticated;
revoke all on function private.list_organization_invitations(uuid) from public, anon, authenticated, service_role;
grant execute on function private.list_organization_invitations(uuid) to service_role, authenticated;
revoke all on function private.list_organization_members(uuid) from public, anon, authenticated, service_role;
grant execute on function private.list_organization_members(uuid) to service_role, authenticated;
revoke all on function private.list_organization_setup_options(uuid) from public, anon, authenticated, service_role;
grant execute on function private.list_organization_setup_options(uuid) to service_role, authenticated;
revoke all on function private.list_organization_student_teacher_assignments(uuid) from public, anon, authenticated, service_role;
grant execute on function private.list_organization_student_teacher_assignments(uuid) to service_role, authenticated;
revoke all on function private.list_organization_students(uuid) from public, anon, authenticated, service_role;
grant execute on function private.list_organization_students(uuid) to service_role, authenticated;
revoke all on function private.list_organization_subject_catalog(uuid) from public, anon, authenticated, service_role;
grant execute on function private.list_organization_subject_catalog(uuid) to service_role, authenticated;
revoke all on function private.list_organization_teacher_subject_scopes(uuid) from public, anon, authenticated, service_role;
grant execute on function private.list_organization_teacher_subject_scopes(uuid) to service_role, authenticated;
revoke all on function private.prepare_member_credential_reissue(uuid, uuid, uuid, uuid) from public, anon, authenticated, service_role;
grant execute on function private.prepare_member_credential_reissue(uuid, uuid, uuid, uuid) to service_role;
revoke all on function private.provision_organization_member_from_auth(uuid, uuid, text, uuid, uuid, text) from public, anon, authenticated, service_role;
grant execute on function private.provision_organization_member_from_auth(uuid, uuid, text, uuid, uuid, text) to service_role;
revoke all on function private.quick_capture_case(uuid, uuid, integer, text, text, text, timestamp with time zone, text, text, timestamp with time zone) from public, anon, authenticated, service_role;
grant execute on function private.quick_capture_case(uuid, uuid, integer, text, text, text, timestamp with time zone, text, text, timestamp with time zone) to service_role, authenticated;
revoke all on function private.quick_capture_case_with_type(uuid, uuid, integer, text, text, text, timestamp with time zone, text, text, timestamp with time zone, uuid) from public, anon, authenticated, service_role;
grant execute on function private.quick_capture_case_with_type(uuid, uuid, integer, text, text, text, timestamp with time zone, text, text, timestamp with time zone, uuid) to service_role, authenticated;
revoke all on function private.record_assessment(uuid, uuid, integer, text, text, text, timestamp with time zone, text, timestamp with time zone) from public, anon, authenticated, service_role;
grant execute on function private.record_assessment(uuid, uuid, integer, text, text, text, timestamp with time zone, text, timestamp with time zone) to service_role, authenticated;
revoke all on function private.record_intervention(uuid, uuid, integer, text, text, timestamp with time zone, text, timestamp with time zone) from public, anon, authenticated, service_role;
grant execute on function private.record_intervention(uuid, uuid, integer, text, text, timestamp with time zone, text, timestamp with time zone) to service_role, authenticated;
revoke all on function private.reissue_organization_invitation(uuid) from public, anon, authenticated, service_role;
grant execute on function private.reissue_organization_invitation(uuid) to service_role, authenticated;
revoke all on function private.rename_organization_case_type(uuid, text, integer) from public, anon, authenticated, service_role;
grant execute on function private.rename_organization_case_type(uuid, text, integer) to service_role, authenticated;
revoke all on function private.reschedule_case_action(uuid, uuid, uuid, integer, integer, date) from public, anon, authenticated, service_role;
grant execute on function private.reschedule_case_action(uuid, uuid, uuid, integer, integer, date) to service_role, authenticated;
revoke all on function private.revoke_member_auth_sessions(uuid) from public, anon, authenticated, service_role;
grant execute on function private.revoke_member_auth_sessions(uuid) to service_role;
revoke all on function private.revoke_organization_invitation(uuid) from public, anon, authenticated, service_role;
grant execute on function private.revoke_organization_invitation(uuid) to service_role, authenticated;
revoke all on function private.stabilize_case(uuid, uuid, integer, timestamp with time zone, text, timestamp with time zone) from public, anon, authenticated, service_role;
grant execute on function private.stabilize_case(uuid, uuid, integer, timestamp with time zone, text, timestamp with time zone) to service_role, authenticated;
revoke all on function private.transfer_organization_student_teacher_assignment(uuid, uuid, uuid, integer, uuid) from public, anon, authenticated, service_role;
grant execute on function private.transfer_organization_student_teacher_assignment(uuid, uuid, uuid, integer, uuid) to service_role, authenticated;
revoke all on function private.update_organization_membership_status(uuid, uuid, uuid, integer, text) from public, anon, authenticated, service_role;
grant execute on function private.update_organization_membership_status(uuid, uuid, uuid, integer, text) to service_role, authenticated;
revoke all on function private.update_organization_student(uuid, uuid, uuid, integer, text, text, text) from public, anon, authenticated, service_role;
grant execute on function private.update_organization_student(uuid, uuid, uuid, integer, text, text, text) to service_role, authenticated;
revoke all on function private.update_organization_teacher_subject_scope(uuid, uuid, uuid, uuid, uuid, integer, text) from public, anon, authenticated, service_role;
grant execute on function private.update_organization_teacher_subject_scope(uuid, uuid, uuid, uuid, uuid, integer, text) to service_role, authenticated;

create or replace function public.accept_organization_invitation(p_invite_code text, p_display_name text default null)
returns jsonb
language sql
volatile
security invoker
set search_path = ''
as $function$
  select private.accept_organization_invitation(p_invite_code, p_display_name)
$function$;

revoke all on function public.accept_organization_invitation(text, text) from public, anon, authenticated, service_role;
grant execute on function public.accept_organization_invitation(text, text) to service_role, authenticated;

create or replace function public.add_case_evidence(p_operation_id uuid, p_case_id uuid, p_expected_case_version integer, p_source_type text, p_title text, p_observed_at timestamptz, p_summary text)
returns jsonb
language sql
volatile
security invoker
set search_path = ''
as $function$
  select private.add_case_evidence(p_operation_id, p_case_id, p_expected_case_version, p_source_type, p_title, p_observed_at, p_summary)
$function$;

revoke all on function public.add_case_evidence(uuid, uuid, integer, text, text, timestamp with time zone, text) from public, anon, authenticated, service_role;
grant execute on function public.add_case_evidence(uuid, uuid, integer, text, text, timestamp with time zone, text) to service_role, authenticated;

create or replace function public.approve_organization_invitation(p_invitation_id uuid)
returns jsonb
language sql
volatile
security invoker
set search_path = ''
as $function$
  select private.approve_organization_invitation(p_invitation_id)
$function$;

revoke all on function public.approve_organization_invitation(uuid) from public, anon, authenticated, service_role;
grant execute on function public.approve_organization_invitation(uuid) to service_role, authenticated;

create or replace function public.archive_organization_case_type(p_case_type_id uuid, p_expected_version integer)
returns jsonb
language sql
volatile
security invoker
set search_path = ''
as $function$
  select private.archive_organization_case_type(p_case_type_id, p_expected_version)
$function$;

revoke all on function public.archive_organization_case_type(uuid, integer) from public, anon, authenticated, service_role;
grant execute on function public.archive_organization_case_type(uuid, integer) to service_role, authenticated;

create or replace function public.close_case(p_operation_id uuid, p_case_id uuid, p_expected_case_version integer, p_closed_at timestamptz)
returns jsonb
language sql
volatile
security invoker
set search_path = ''
as $function$
  select private.close_case(p_operation_id, p_case_id, p_expected_case_version, p_closed_at)
$function$;

revoke all on function public.close_case(uuid, uuid, integer, timestamp with time zone) from public, anon, authenticated, service_role;
grant execute on function public.close_case(uuid, uuid, integer, timestamp with time zone) to service_role, authenticated;

create or replace function public.complete_member_onboarding()
returns jsonb
language sql
volatile
security invoker
set search_path = ''
as $function$
  select private.complete_member_onboarding()
$function$;

revoke all on function public.complete_member_onboarding() from public, anon, authenticated, service_role;
grant execute on function public.complete_member_onboarding() to service_role, authenticated;

create or replace function public.confirm_case(p_operation_id uuid, p_case_id uuid, p_expected_case_version integer, p_next_action_title text, p_next_action_due_at timestamptz)
returns jsonb
language sql
volatile
security invoker
set search_path = ''
as $function$
  select private.confirm_case(p_operation_id, p_case_id, p_expected_case_version, p_next_action_title, p_next_action_due_at)
$function$;

revoke all on function public.confirm_case(uuid, uuid, integer, text, timestamp with time zone) from public, anon, authenticated, service_role;
grant execute on function public.confirm_case(uuid, uuid, integer, text, timestamp with time zone) to service_role, authenticated;

create or replace function public.create_organization_case_type(p_organization_id uuid, p_display_name text, p_base_case_type text)
returns jsonb
language sql
volatile
security invoker
set search_path = ''
as $function$
  select private.create_organization_case_type(p_organization_id, p_display_name, p_base_case_type)
$function$;

revoke all on function public.create_organization_case_type(uuid, text, text) from public, anon, authenticated, service_role;
grant execute on function public.create_organization_case_type(uuid, text, text) to service_role, authenticated;

create or replace function public.create_organization_invitation(p_organization_id uuid, p_email text, p_role text)
returns jsonb
language sql
volatile
security invoker
set search_path = ''
as $function$
  select private.create_organization_invitation(p_organization_id, p_email, p_role)
$function$;

revoke all on function public.create_organization_invitation(uuid, text, text) from public, anon, authenticated, service_role;
grant execute on function public.create_organization_invitation(uuid, text, text) to service_role, authenticated;

create or replace function public.create_organization_student(p_operation_id uuid, p_organization_id uuid, p_name text, p_student_code text, p_grade text, p_class_name text, p_campus text, p_organization_subject_id uuid, p_teacher_membership_id uuid, p_starts_on date, p_positioning text, p_strengths text, p_cadence_note text)
returns jsonb
language sql
volatile
security invoker
set search_path = ''
as $function$
  select private.create_organization_student(p_operation_id, p_organization_id, p_name, p_student_code, p_grade, p_class_name, p_campus, p_organization_subject_id, p_teacher_membership_id, p_starts_on, p_positioning, p_strengths, p_cadence_note)
$function$;

revoke all on function public.create_organization_student(uuid, uuid, text, text, text, text, text, uuid, uuid, date, text, text, text) from public, anon, authenticated, service_role;
grant execute on function public.create_organization_student(uuid, uuid, text, text, text, text, text, uuid, uuid, date, text, text, text) to service_role, authenticated;

create or replace function public.create_organization_subject(p_operation_id uuid, p_organization_id uuid, p_subject_id uuid)
returns jsonb
language sql
volatile
security invoker
set search_path = ''
as $function$
  select private.create_organization_subject(p_operation_id, p_organization_id, p_subject_id)
$function$;

revoke all on function public.create_organization_subject(uuid, uuid, uuid) from public, anon, authenticated, service_role;
grant execute on function public.create_organization_subject(uuid, uuid, uuid) to service_role, authenticated;

create or replace function public.get_my_membership_state()
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $function$
  select private.get_my_membership_state()
$function$;

revoke all on function public.get_my_membership_state() from public, anon, authenticated, service_role;
grant execute on function public.get_my_membership_state() to service_role, authenticated;

create or replace function public.list_organization_invitations(p_organization_id uuid)
returns setof jsonb
language sql
volatile
security invoker
set search_path = ''
as $function$
  select item
  from private.list_organization_invitations(p_organization_id) as item(item)
$function$;

revoke all on function public.list_organization_invitations(uuid) from public, anon, authenticated, service_role;
grant execute on function public.list_organization_invitations(uuid) to service_role, authenticated;

create or replace function public.list_organization_members(p_organization_id uuid)
returns setof jsonb
language sql
stable
security invoker
set search_path = ''
as $function$
  select item
  from private.list_organization_members(p_organization_id) as item(item)
$function$;

revoke all on function public.list_organization_members(uuid) from public, anon, authenticated, service_role;
grant execute on function public.list_organization_members(uuid) to service_role, authenticated;

create or replace function public.list_organization_setup_options(p_organization_id uuid)
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $function$
  select private.list_organization_setup_options(p_organization_id)
$function$;

revoke all on function public.list_organization_setup_options(uuid) from public, anon, authenticated, service_role;
grant execute on function public.list_organization_setup_options(uuid) to service_role, authenticated;

create or replace function public.list_organization_student_teacher_assignments(p_organization_id uuid)
returns setof jsonb
language sql
stable
security invoker
set search_path = ''
as $function$
  select item
  from private.list_organization_student_teacher_assignments(p_organization_id) as item(item)
$function$;

revoke all on function public.list_organization_student_teacher_assignments(uuid) from public, anon, authenticated, service_role;
grant execute on function public.list_organization_student_teacher_assignments(uuid) to service_role, authenticated;

create or replace function public.list_organization_students(p_organization_id uuid)
returns setof jsonb
language sql
stable
security invoker
set search_path = ''
as $function$
  select item
  from private.list_organization_students(p_organization_id) as item(item)
$function$;

revoke all on function public.list_organization_students(uuid) from public, anon, authenticated, service_role;
grant execute on function public.list_organization_students(uuid) to service_role, authenticated;

create or replace function public.list_organization_subject_catalog(p_organization_id uuid)
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $function$
  select private.list_organization_subject_catalog(p_organization_id)
$function$;

revoke all on function public.list_organization_subject_catalog(uuid) from public, anon, authenticated, service_role;
grant execute on function public.list_organization_subject_catalog(uuid) to service_role, authenticated;

create or replace function public.list_organization_teacher_subject_scopes(p_organization_id uuid)
returns setof jsonb
language sql
stable
security invoker
set search_path = ''
as $function$
  select item
  from private.list_organization_teacher_subject_scopes(p_organization_id) as item(item)
$function$;

revoke all on function public.list_organization_teacher_subject_scopes(uuid) from public, anon, authenticated, service_role;
grant execute on function public.list_organization_teacher_subject_scopes(uuid) to service_role, authenticated;

create or replace function public.prepare_member_credential_reissue(p_actor_auth_user_id uuid, p_actor_session_id uuid, p_organization_id uuid, p_membership_id uuid)
returns jsonb
language sql
volatile
security invoker
set search_path = ''
as $function$
  select private.prepare_member_credential_reissue(p_actor_auth_user_id, p_actor_session_id, p_organization_id, p_membership_id)
$function$;

revoke all on function public.prepare_member_credential_reissue(uuid, uuid, uuid, uuid) from public, anon, authenticated, service_role;
grant execute on function public.prepare_member_credential_reissue(uuid, uuid, uuid, uuid) to service_role;

create or replace function public.provision_organization_member_from_auth(p_actor_auth_user_id uuid, p_actor_session_id uuid, p_actor_issuer text, p_invitation_id uuid, p_target_auth_user_id uuid, p_display_name text default null)
returns jsonb
language sql
volatile
security invoker
set search_path = ''
as $function$
  select private.provision_organization_member_from_auth(p_actor_auth_user_id, p_actor_session_id, p_actor_issuer, p_invitation_id, p_target_auth_user_id, p_display_name)
$function$;

revoke all on function public.provision_organization_member_from_auth(uuid, uuid, text, uuid, uuid, text) from public, anon, authenticated, service_role;
grant execute on function public.provision_organization_member_from_auth(uuid, uuid, text, uuid, uuid, text) to service_role;

create or replace function public.quick_capture_case(p_operation_id uuid, p_profile_id uuid, p_expected_profile_version integer, p_case_type text, p_title text, p_description text, p_observed_at timestamptz, p_evidence_summary text, p_next_action_title text, p_next_action_due_at timestamptz)
returns jsonb
language sql
volatile
security invoker
set search_path = ''
as $function$
  select private.quick_capture_case(p_operation_id, p_profile_id, p_expected_profile_version, p_case_type, p_title, p_description, p_observed_at, p_evidence_summary, p_next_action_title, p_next_action_due_at)
$function$;

revoke all on function public.quick_capture_case(uuid, uuid, integer, text, text, text, timestamp with time zone, text, text, timestamp with time zone) from public, anon, authenticated, service_role;
grant execute on function public.quick_capture_case(uuid, uuid, integer, text, text, text, timestamp with time zone, text, text, timestamp with time zone) to service_role, authenticated;

create or replace function public.quick_capture_case_with_type(p_operation_id uuid, p_profile_id uuid, p_expected_profile_version integer, p_case_type text, p_title text, p_description text, p_observed_at timestamptz, p_evidence_summary text, p_next_action_title text, p_next_action_due_at timestamptz, p_organization_case_type_id uuid)
returns jsonb
language sql
volatile
security invoker
set search_path = ''
as $function$
  select private.quick_capture_case_with_type(p_operation_id, p_profile_id, p_expected_profile_version, p_case_type, p_title, p_description, p_observed_at, p_evidence_summary, p_next_action_title, p_next_action_due_at, p_organization_case_type_id)
$function$;

revoke all on function public.quick_capture_case_with_type(uuid, uuid, integer, text, text, text, timestamp with time zone, text, text, timestamp with time zone, uuid) from public, anon, authenticated, service_role;
grant execute on function public.quick_capture_case_with_type(uuid, uuid, integer, text, text, text, timestamp with time zone, text, text, timestamp with time zone, uuid) to service_role, authenticated;

create or replace function public.record_assessment(p_operation_id uuid, p_case_id uuid, p_expected_case_version integer, p_result text, p_evidence_summary text, p_notes text, p_assessed_at timestamptz, p_next_action_title text, p_next_action_due_at timestamptz)
returns jsonb
language sql
volatile
security invoker
set search_path = ''
as $function$
  select private.record_assessment(p_operation_id, p_case_id, p_expected_case_version, p_result, p_evidence_summary, p_notes, p_assessed_at, p_next_action_title, p_next_action_due_at)
$function$;

revoke all on function public.record_assessment(uuid, uuid, integer, text, text, text, timestamp with time zone, text, timestamp with time zone) from public, anon, authenticated, service_role;
grant execute on function public.record_assessment(uuid, uuid, integer, text, text, text, timestamp with time zone, text, timestamp with time zone) to service_role, authenticated;

create or replace function public.record_intervention(p_operation_id uuid, p_case_id uuid, p_expected_case_version integer, p_strategy text, p_notes text, p_occurred_at timestamptz, p_next_action_title text, p_next_action_due_at timestamptz)
returns jsonb
language sql
volatile
security invoker
set search_path = ''
as $function$
  select private.record_intervention(p_operation_id, p_case_id, p_expected_case_version, p_strategy, p_notes, p_occurred_at, p_next_action_title, p_next_action_due_at)
$function$;

revoke all on function public.record_intervention(uuid, uuid, integer, text, text, timestamp with time zone, text, timestamp with time zone) from public, anon, authenticated, service_role;
grant execute on function public.record_intervention(uuid, uuid, integer, text, text, timestamp with time zone, text, timestamp with time zone) to service_role, authenticated;

create or replace function public.reissue_organization_invitation(p_invitation_id uuid)
returns jsonb
language sql
volatile
security invoker
set search_path = ''
as $function$
  select private.reissue_organization_invitation(p_invitation_id)
$function$;

revoke all on function public.reissue_organization_invitation(uuid) from public, anon, authenticated, service_role;
grant execute on function public.reissue_organization_invitation(uuid) to service_role, authenticated;

create or replace function public.rename_organization_case_type(p_case_type_id uuid, p_display_name text, p_expected_version integer)
returns jsonb
language sql
volatile
security invoker
set search_path = ''
as $function$
  select private.rename_organization_case_type(p_case_type_id, p_display_name, p_expected_version)
$function$;

revoke all on function public.rename_organization_case_type(uuid, text, integer) from public, anon, authenticated, service_role;
grant execute on function public.rename_organization_case_type(uuid, text, integer) to service_role, authenticated;

create or replace function public.reschedule_case_action(p_operation_id uuid, p_action_id uuid, p_case_id uuid, p_expected_case_version integer, p_expected_action_version integer, p_due_on date)
returns jsonb
language sql
volatile
security invoker
set search_path = ''
as $function$
  select private.reschedule_case_action(p_operation_id, p_action_id, p_case_id, p_expected_case_version, p_expected_action_version, p_due_on)
$function$;

revoke all on function public.reschedule_case_action(uuid, uuid, uuid, integer, integer, date) from public, anon, authenticated, service_role;
grant execute on function public.reschedule_case_action(uuid, uuid, uuid, integer, integer, date) to service_role, authenticated;

create or replace function public.revoke_member_auth_sessions(p_target_auth_user_id uuid)
returns jsonb
language sql
volatile
security invoker
set search_path = ''
as $function$
  select private.revoke_member_auth_sessions(p_target_auth_user_id)
$function$;

revoke all on function public.revoke_member_auth_sessions(uuid) from public, anon, authenticated, service_role;
grant execute on function public.revoke_member_auth_sessions(uuid) to service_role;

create or replace function public.revoke_organization_invitation(p_invitation_id uuid)
returns jsonb
language sql
volatile
security invoker
set search_path = ''
as $function$
  select private.revoke_organization_invitation(p_invitation_id)
$function$;

revoke all on function public.revoke_organization_invitation(uuid) from public, anon, authenticated, service_role;
grant execute on function public.revoke_organization_invitation(uuid) to service_role, authenticated;

create or replace function public.stabilize_case(p_operation_id uuid, p_case_id uuid, p_expected_case_version integer, p_stabilized_at timestamptz, p_next_action_title text, p_next_action_due_at timestamptz)
returns jsonb
language sql
volatile
security invoker
set search_path = ''
as $function$
  select private.stabilize_case(p_operation_id, p_case_id, p_expected_case_version, p_stabilized_at, p_next_action_title, p_next_action_due_at)
$function$;

revoke all on function public.stabilize_case(uuid, uuid, integer, timestamp with time zone, text, timestamp with time zone) from public, anon, authenticated, service_role;
grant execute on function public.stabilize_case(uuid, uuid, integer, timestamp with time zone, text, timestamp with time zone) to service_role, authenticated;

create or replace function public.transfer_organization_student_teacher_assignment(p_operation_id uuid, p_organization_id uuid, p_assignment_id uuid, p_expected_assignment_version integer, p_replacement_membership_id uuid)
returns jsonb
language sql
volatile
security invoker
set search_path = ''
as $function$
  select private.transfer_organization_student_teacher_assignment(p_operation_id, p_organization_id, p_assignment_id, p_expected_assignment_version, p_replacement_membership_id)
$function$;

revoke all on function public.transfer_organization_student_teacher_assignment(uuid, uuid, uuid, integer, uuid) from public, anon, authenticated, service_role;
grant execute on function public.transfer_organization_student_teacher_assignment(uuid, uuid, uuid, integer, uuid) to service_role, authenticated;

create or replace function public.update_organization_membership_status(p_operation_id uuid, p_organization_id uuid, p_membership_id uuid, p_expected_membership_version integer, p_status text)
returns jsonb
language sql
volatile
security invoker
set search_path = ''
as $function$
  select private.update_organization_membership_status(p_operation_id, p_organization_id, p_membership_id, p_expected_membership_version, p_status)
$function$;

revoke all on function public.update_organization_membership_status(uuid, uuid, uuid, integer, text) from public, anon, authenticated, service_role;
grant execute on function public.update_organization_membership_status(uuid, uuid, uuid, integer, text) to service_role, authenticated;

create or replace function public.update_organization_student(p_operation_id uuid, p_organization_id uuid, p_student_id uuid, p_expected_student_version integer, p_name text, p_student_code text, p_status text)
returns jsonb
language sql
volatile
security invoker
set search_path = ''
as $function$
  select private.update_organization_student(p_operation_id, p_organization_id, p_student_id, p_expected_student_version, p_name, p_student_code, p_status)
$function$;

revoke all on function public.update_organization_student(uuid, uuid, uuid, integer, text, text, text) from public, anon, authenticated, service_role;
grant execute on function public.update_organization_student(uuid, uuid, uuid, integer, text, text, text) to service_role, authenticated;

create or replace function public.update_organization_teacher_subject_scope(p_operation_id uuid, p_organization_id uuid, p_membership_id uuid, p_organization_subject_id uuid, p_scope_id uuid, p_expected_scope_version integer, p_status text)
returns jsonb
language sql
volatile
security invoker
set search_path = ''
as $function$
  select private.update_organization_teacher_subject_scope(p_operation_id, p_organization_id, p_membership_id, p_organization_subject_id, p_scope_id, p_expected_scope_version, p_status)
$function$;

revoke all on function public.update_organization_teacher_subject_scope(uuid, uuid, uuid, uuid, uuid, integer, text) from public, anon, authenticated, service_role;
grant execute on function public.update_organization_teacher_subject_scope(uuid, uuid, uuid, uuid, uuid, integer, text) to service_role, authenticated;

