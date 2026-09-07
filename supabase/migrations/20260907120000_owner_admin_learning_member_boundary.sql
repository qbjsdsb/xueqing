-- Production-pilot role contract:
--   * org_owner: full organization access, including member account management.
--   * org_admin: full organization learning/operations access, but no member-account writes.
--   * teacher: learning access remains assignment + teaching-scope bound.
--
-- Keep member account management separate from ordinary organization management so
-- administrators can run the institution without being able to invite, disable,
-- reissue credentials for, or otherwise take over another member account.

create or replace function private.can_manage_member_accounts_v2(
  target_organization_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $function$
  select exists (
    select 1
    from public.organization_memberships as membership
    join public.membership_roles as membership_role
      on membership_role.membership_id = membership.id
     and membership_role.organization_id = membership.organization_id
     and membership_role.role = 'org_owner'
    join public.organizations as organization
      on organization.id = membership.organization_id
     and organization.status = 'active'
    where membership.organization_id = target_organization_id
      and membership.app_user_id =
        (select private.current_app_user_id_v2())
      and membership.status = 'active'
  )
$function$;

create or replace function private.actor_can_manage_member_accounts_v2(
  target_auth_user_id uuid,
  target_session_id uuid,
  target_organization_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $function$
  select exists (
    select 1
    from auth.sessions as auth_session
    join public.app_users as app_user
      on app_user.auth_provider = 'supabase'
     and app_user.auth_subject_id = target_auth_user_id::text
     and app_user.status = 'active'
    join public.identity_links as identity_link
      on identity_link.app_user_id = app_user.id
     and identity_link.provider_key = 'supabase'
     and identity_link.external_subject = target_auth_user_id::text
     and identity_link.status = 'active'
    join public.organization_memberships as membership
      on membership.app_user_id = app_user.id
     and membership.organization_id = target_organization_id
     and membership.status = 'active'
    join public.membership_roles as membership_role
      on membership_role.membership_id = membership.id
     and membership_role.organization_id = membership.organization_id
     and membership_role.role = 'org_owner'
    join public.organizations as organization
      on organization.id = membership.organization_id
     and organization.status = 'active'
    where auth_session.id = target_session_id
      and auth_session.user_id = target_auth_user_id
  )
$function$;

revoke all on function private.can_manage_member_accounts_v2(uuid) from public;
revoke all on function private.actor_can_manage_member_accounts_v2(uuid, uuid, uuid)
  from public;

-- Owner/admin learning entitlement. The returned membership remains the actor's
-- own active organization membership; teacher access still requires the legal
-- assignment + subject-scope gate when the actor is not an owner/admin.
create or replace function private.current_teaching_membership_for_profile_v2(
  target_profile_id uuid
)
returns uuid
language plpgsql
stable
security definer
set search_path = ''
as $function$
declare
  v_organization_id uuid;
  v_organization_subject_id uuid;
  v_business_date date;
  v_membership_id uuid;
begin
  select
    profile.organization_id,
    profile.organization_subject_id,
    (now() at time zone organization.time_zone)::date
  into
    v_organization_id,
    v_organization_subject_id,
    v_business_date
  from public.student_subject_profiles as profile
  join public.students as student
    on student.id = profile.student_id
   and student.organization_id = profile.organization_id
   and student.status = 'active'
  join public.organizations as organization
    on organization.id = profile.organization_id
   and organization.status = 'active'
  join public.organization_subjects as organization_subject
    on organization_subject.id = profile.organization_subject_id
   and organization_subject.organization_id = profile.organization_id
   and organization_subject.status = 'active'
  where profile.id = target_profile_id
    and profile.status = 'active'
  limit 1;

  if v_organization_id is null then
    return null;
  end if;

  select membership.id
  into v_membership_id
  from public.organization_memberships as membership
  join public.membership_roles as membership_role
    on membership_role.membership_id = membership.id
   and membership_role.organization_id = membership.organization_id
   and membership_role.role in ('org_owner', 'org_admin')
  where membership.organization_id = v_organization_id
    and membership.app_user_id =
      (select private.current_app_user_id_v2())
    and membership.status = 'active'
  order by
    case membership_role.role when 'org_owner' then 0 else 1 end,
    membership.id
  limit 1;

  if v_membership_id is not null then
    return v_membership_id;
  end if;

  select assignment.membership_id
  into v_membership_id
  from public.student_teacher_assignments as assignment
  join public.organization_memberships as membership
    on membership.id = assignment.membership_id
   and membership.organization_id = assignment.organization_id
   and membership.status = 'active'
   and membership.app_user_id =
     (select private.current_app_user_id_v2())
  join public.membership_roles as membership_role
    on membership_role.membership_id = membership.id
   and membership_role.organization_id = membership.organization_id
   and membership_role.role = 'teacher'
  join public.membership_subject_scopes as scope
    on scope.membership_id = membership.id
   and scope.organization_id = membership.organization_id
   and scope.organization_subject_id = v_organization_subject_id
   and scope.scope_kind = 'teaching'
   and scope.status = 'active'
   and v_business_date >= scope.active_from
   and (scope.active_to is null or v_business_date <= scope.active_to)
  where assignment.organization_id = v_organization_id
    and assignment.student_subject_profile_id = target_profile_id
    and assignment.status = 'active'
    and v_business_date >= assignment.active_from
    and (
      assignment.active_to is null
      or v_business_date <= assignment.active_to
    )
  order by
    case assignment.assignment_role when 'lead' then 0 else 1 end,
    assignment.id
  limit 1;

  return v_membership_id;
end
$function$;

create or replace function private.can_read_profile_v2(
  target_profile_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $function$
  select (
    select private.current_teaching_membership_for_profile_v2(target_profile_id)
  ) is not null
$function$;

revoke all on function private.current_teaching_membership_for_profile_v2(uuid)
  from public;
revoke all on function private.can_read_profile_v2(uuid) from public;

-- Harden every direct member-account mutation behind the owner-only helper.
-- Rename the already-tested implementations and preserve them as internal
-- implementation details; the new functions keep the public signatures stable.
alter function private.create_organization_invitation(uuid, text, text)
  rename to create_organization_invitation_manager_legacy;
alter function private.approve_organization_invitation(uuid)
  rename to approve_organization_invitation_manager_legacy;
alter function private.revoke_organization_invitation(uuid)
  rename to revoke_organization_invitation_manager_legacy;
alter function private.reissue_organization_invitation(uuid)
  rename to reissue_organization_invitation_manager_legacy;
alter function private.update_organization_membership_status(
  uuid, uuid, uuid, integer, text
) rename to update_organization_membership_status_manager_legacy;
alter function private.prepare_member_credential_reissue(uuid, uuid, uuid, uuid)
  rename to prepare_member_credential_reissue_manager_legacy;
alter function private.provision_organization_member_from_auth(
  uuid, uuid, text, uuid, uuid, text
) rename to provision_organization_member_from_auth_manager_legacy;

revoke all on function private.create_organization_invitation_manager_legacy(
  uuid, text, text
) from public, anon, authenticated, service_role;
revoke all on function private.approve_organization_invitation_manager_legacy(uuid)
  from public, anon, authenticated, service_role;
revoke all on function private.revoke_organization_invitation_manager_legacy(uuid)
  from public, anon, authenticated, service_role;
revoke all on function private.reissue_organization_invitation_manager_legacy(uuid)
  from public, anon, authenticated, service_role;
revoke all on function private.update_organization_membership_status_manager_legacy(
  uuid, uuid, uuid, integer, text
) from public, anon, authenticated, service_role;
revoke all on function private.prepare_member_credential_reissue_manager_legacy(
  uuid, uuid, uuid, uuid
) from public, anon, authenticated, service_role;
revoke all on function private.provision_organization_member_from_auth_manager_legacy(
  uuid, uuid, text, uuid, uuid, text
) from public, anon, authenticated, service_role;

create or replace function private.create_organization_invitation(
  p_organization_id uuid,
  p_email text,
  p_role text
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $function$
begin
  if not (select private.can_manage_member_accounts_v2(p_organization_id)) then
    raise exception using errcode = 'P0001', message = 'organization_owner_required';
  end if;
  return private.create_organization_invitation_manager_legacy(
    p_organization_id, p_email, p_role
  );
end
$function$;

create or replace function private.approve_organization_invitation(
  p_invitation_id uuid
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $function$
declare
  v_organization_id uuid;
begin
  select invitation.organization_id
  into v_organization_id
  from public.organization_invitations as invitation
  where invitation.id = p_invitation_id;
  if v_organization_id is null then
    raise exception using errcode = 'P0001', message = 'invitation_not_found';
  end if;
  if not (select private.can_manage_member_accounts_v2(v_organization_id)) then
    raise exception using errcode = 'P0001', message = 'organization_owner_required';
  end if;
  return private.approve_organization_invitation_manager_legacy(p_invitation_id);
end
$function$;

create or replace function private.revoke_organization_invitation(
  p_invitation_id uuid
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $function$
declare
  v_organization_id uuid;
begin
  select invitation.organization_id
  into v_organization_id
  from public.organization_invitations as invitation
  where invitation.id = p_invitation_id;
  if v_organization_id is null then
    raise exception using errcode = 'P0001', message = 'invitation_not_found';
  end if;
  if not (select private.can_manage_member_accounts_v2(v_organization_id)) then
    raise exception using errcode = 'P0001', message = 'organization_owner_required';
  end if;
  return private.revoke_organization_invitation_manager_legacy(p_invitation_id);
end
$function$;

create or replace function private.reissue_organization_invitation(
  p_invitation_id uuid
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $function$
declare
  v_organization_id uuid;
begin
  select invitation.organization_id
  into v_organization_id
  from public.organization_invitations as invitation
  where invitation.id = p_invitation_id;
  if v_organization_id is null then
    raise exception using errcode = 'P0001', message = 'invitation_not_found';
  end if;
  if not (select private.can_manage_member_accounts_v2(v_organization_id)) then
    raise exception using errcode = 'P0001', message = 'organization_owner_required';
  end if;
  return private.reissue_organization_invitation_manager_legacy(p_invitation_id);
end
$function$;

create or replace function private.update_organization_membership_status(
  p_operation_id uuid,
  p_organization_id uuid,
  p_membership_id uuid,
  p_expected_membership_version integer,
  p_status text
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $function$
begin
  if not (select private.can_manage_member_accounts_v2(p_organization_id)) then
    raise exception using errcode = 'P0001', message = 'organization_owner_required';
  end if;
  return private.update_organization_membership_status_manager_legacy(
    p_operation_id,
    p_organization_id,
    p_membership_id,
    p_expected_membership_version,
    p_status
  );
end
$function$;

create or replace function private.prepare_member_credential_reissue(
  p_actor_auth_user_id uuid,
  p_actor_session_id uuid,
  p_organization_id uuid,
  p_membership_id uuid
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $function$
begin
  if not (select private.actor_can_manage_member_accounts_v2(
    p_actor_auth_user_id,
    p_actor_session_id,
    p_organization_id
  )) then
    raise exception using errcode = 'P0001', message = 'organization_owner_required';
  end if;
  return private.prepare_member_credential_reissue_manager_legacy(
    p_actor_auth_user_id,
    p_actor_session_id,
    p_organization_id,
    p_membership_id
  );
end
$function$;

create or replace function private.provision_organization_member_from_auth(
  p_actor_auth_user_id uuid,
  p_actor_session_id uuid,
  p_actor_issuer text,
  p_invitation_id uuid,
  p_target_auth_user_id uuid,
  p_display_name text default null
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $function$
declare
  v_organization_id uuid;
begin
  select invitation.organization_id
  into v_organization_id
  from public.organization_invitations as invitation
  where invitation.id = p_invitation_id;
  if v_organization_id is null then
    raise exception using errcode = 'P0001', message = 'invitation_not_found';
  end if;
  if not (select private.actor_can_manage_member_accounts_v2(
    p_actor_auth_user_id,
    p_actor_session_id,
    v_organization_id
  )) then
    raise exception using errcode = 'P0001', message = 'organization_owner_required';
  end if;
  return private.provision_organization_member_from_auth_manager_legacy(
    p_actor_auth_user_id,
    p_actor_session_id,
    p_actor_issuer,
    p_invitation_id,
    p_target_auth_user_id,
    p_display_name
  );
end
$function$;

-- Restore the intended execution surface after replacing the private functions.
revoke all on function private.create_organization_invitation(uuid, text, text)
  from public, anon, authenticated, service_role;
grant execute on function private.create_organization_invitation(uuid, text, text)
  to authenticated, service_role;
revoke all on function private.approve_organization_invitation(uuid)
  from public, anon, authenticated, service_role;
grant execute on function private.approve_organization_invitation(uuid)
  to authenticated, service_role;
revoke all on function private.revoke_organization_invitation(uuid)
  from public, anon, authenticated, service_role;
grant execute on function private.revoke_organization_invitation(uuid)
  to authenticated, service_role;
revoke all on function private.reissue_organization_invitation(uuid)
  from public, anon, authenticated, service_role;
grant execute on function private.reissue_organization_invitation(uuid)
  to authenticated, service_role;
revoke all on function private.update_organization_membership_status(
  uuid, uuid, uuid, integer, text
) from public, anon, authenticated, service_role;
grant execute on function private.update_organization_membership_status(
  uuid, uuid, uuid, integer, text
) to authenticated, service_role;
revoke all on function private.prepare_member_credential_reissue(
  uuid, uuid, uuid, uuid
) from public, anon, authenticated, service_role;
grant execute on function private.prepare_member_credential_reissue(
  uuid, uuid, uuid, uuid
) to service_role;
revoke all on function private.provision_organization_member_from_auth(
  uuid, uuid, text, uuid, uuid, text
) from public, anon, authenticated, service_role;
grant execute on function private.provision_organization_member_from_auth(
  uuid, uuid, text, uuid, uuid, text
) to service_role;

comment on function private.can_manage_member_accounts_v2(uuid) is
  'Owner-only member-account mutation gate; admins retain non-member organization operations.';
comment on function private.current_teaching_membership_for_profile_v2(uuid) is
  'Learning entitlement membership: owner/admin organization-wide, teachers by assignment and teaching scope.';
