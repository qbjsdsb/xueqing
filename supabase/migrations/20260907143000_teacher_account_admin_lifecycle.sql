-- Production-pilot member lifecycle refinement.
--
-- org_owner keeps full member-account control.
-- org_admin may manage teacher accounts and nominate an owner, but cannot
-- directly manage org_owner/org_admin memberships or credentials.
-- Cross-organization active/onboarding membership is rejected before a new
-- invitation is created so the UI does not lead operators into a dead end.

create or replace function private.actor_can_manage_organization_v2(
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
     and membership_role.role in ('org_owner', 'org_admin')
    join public.organizations as organization
      on organization.id = membership.organization_id
     and organization.status = 'active'
    where auth_session.id = target_session_id
      and auth_session.user_id = target_auth_user_id
  )
$function$;

revoke all on function private.actor_can_manage_organization_v2(uuid, uuid, uuid)
  from public, anon, authenticated, service_role;

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
declare
  v_email text := lower(btrim(coalesce(p_email, '')));
begin
  if not (select private.can_manage_organization_v2(p_organization_id)) then
    raise exception using errcode = 'P0001', message = 'organization_manager_required';
  end if;

  if exists (
    select 1
    from auth.users as auth_user
    join public.app_users as app_user
      on app_user.auth_provider = 'supabase'
     and app_user.auth_subject_id = auth_user.id::text
    join public.organization_memberships as membership
      on membership.app_user_id = app_user.id
     and membership.status in ('onboarding', 'active')
    where lower(auth_user.email) = v_email
      and membership.organization_id <> p_organization_id
  ) then
    raise exception using errcode = 'P0001', message = 'user_already_member_elsewhere';
  end if;

  return private.create_organization_invitation_manager_legacy(
    p_organization_id,
    p_email,
    p_role
  );
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
  v_invitation public.organization_invitations%rowtype;
  v_current_membership_id uuid;
  v_caller_is_owner boolean;
begin
  select invitation.*
  into v_invitation
  from public.organization_invitations as invitation
  where invitation.id = p_invitation_id;

  if not found then
    raise exception using errcode = 'P0001', message = 'invitation_not_found';
  end if;

  if not (select private.can_manage_organization_v2(v_invitation.organization_id)) then
    raise exception using errcode = 'P0001', message = 'organization_manager_required';
  end if;

  v_current_membership_id := (
    select private.current_membership_for_organization_v2(
      v_invitation.organization_id
    )
  );
  v_caller_is_owner := exists (
    select 1
    from public.membership_roles as membership_role
    where membership_role.organization_id = v_invitation.organization_id
      and membership_role.membership_id = v_current_membership_id
      and membership_role.role = 'org_owner'
  );

  if not v_caller_is_owner
    and (
      v_invitation.role = 'org_admin'
      or (
        v_invitation.role = 'org_owner'
        and v_invitation.status <> 'pending_owner_approval'
      )
    ) then
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
  v_invitation public.organization_invitations%rowtype;
  v_current_membership_id uuid;
  v_caller_is_owner boolean;
begin
  select invitation.*
  into v_invitation
  from public.organization_invitations as invitation
  where invitation.id = p_invitation_id;

  if not found then
    raise exception using errcode = 'P0001', message = 'invitation_not_found';
  end if;

  if not (select private.can_manage_organization_v2(v_invitation.organization_id)) then
    raise exception using errcode = 'P0001', message = 'organization_manager_required';
  end if;

  v_current_membership_id := (
    select private.current_membership_for_organization_v2(
      v_invitation.organization_id
    )
  );
  v_caller_is_owner := exists (
    select 1
    from public.membership_roles as membership_role
    where membership_role.organization_id = v_invitation.organization_id
      and membership_role.membership_id = v_current_membership_id
      and membership_role.role = 'org_owner'
  );

  if not v_caller_is_owner
    and (
      v_invitation.role = 'org_admin'
      or (
        v_invitation.role = 'org_owner'
        and v_invitation.status <> 'pending_owner_approval'
      )
    ) then
    raise exception using errcode = 'P0001', message = 'organization_owner_required';
  end if;

  if exists (
    select 1
    from auth.users as auth_user
    join public.app_users as app_user
      on app_user.auth_provider = 'supabase'
     and app_user.auth_subject_id = auth_user.id::text
    join public.organization_memberships as membership
      on membership.app_user_id = app_user.id
     and membership.status in ('onboarding', 'active')
    where lower(auth_user.email) = lower(v_invitation.email)
      and membership.organization_id <> v_invitation.organization_id
  ) then
    raise exception using errcode = 'P0001', message = 'user_already_member_elsewhere';
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
declare
  v_current_membership_id uuid;
  v_caller_is_owner boolean;
  v_target_is_manager boolean;
begin
  if not (select private.can_manage_organization_v2(p_organization_id)) then
    raise exception using errcode = 'P0001', message = 'organization_manager_required';
  end if;

  v_current_membership_id := (
    select private.current_membership_for_organization_v2(p_organization_id)
  );
  v_caller_is_owner := exists (
    select 1
    from public.membership_roles as membership_role
    where membership_role.organization_id = p_organization_id
      and membership_role.membership_id = v_current_membership_id
      and membership_role.role = 'org_owner'
  );
  v_target_is_manager := exists (
    select 1
    from public.membership_roles as membership_role
    where membership_role.organization_id = p_organization_id
      and membership_role.membership_id = p_membership_id
      and membership_role.role in ('org_owner', 'org_admin')
  );

  if not v_caller_is_owner and v_target_is_manager then
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
declare
  v_actor_is_owner boolean;
  v_target_is_manager boolean;
begin
  if not (select private.actor_can_manage_organization_v2(
    p_actor_auth_user_id,
    p_actor_session_id,
    p_organization_id
  )) then
    raise exception using errcode = 'P0001', message = 'organization_manager_required';
  end if;

  v_actor_is_owner := (
    select private.actor_can_manage_member_accounts_v2(
      p_actor_auth_user_id,
      p_actor_session_id,
      p_organization_id
    )
  );
  v_target_is_manager := exists (
    select 1
    from public.membership_roles as membership_role
    where membership_role.organization_id = p_organization_id
      and membership_role.membership_id = p_membership_id
      and membership_role.role in ('org_owner', 'org_admin')
  );

  if not v_actor_is_owner and v_target_is_manager then
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
  v_invitation public.organization_invitations%rowtype;
  v_actor_is_owner boolean;
begin
  select invitation.*
  into v_invitation
  from public.organization_invitations as invitation
  where invitation.id = p_invitation_id;

  if not found then
    raise exception using errcode = 'P0001', message = 'invitation_not_found';
  end if;

  if not (select private.actor_can_manage_organization_v2(
    p_actor_auth_user_id,
    p_actor_session_id,
    v_invitation.organization_id
  )) then
    raise exception using errcode = 'P0001', message = 'organization_manager_required';
  end if;

  v_actor_is_owner := (
    select private.actor_can_manage_member_accounts_v2(
      p_actor_auth_user_id,
      p_actor_session_id,
      v_invitation.organization_id
    )
  );

  if not v_actor_is_owner and v_invitation.role <> 'teacher' then
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

comment on function private.actor_can_manage_organization_v2(uuid, uuid, uuid) is
  'Trusted-service manager gate: active owner/admin with the supplied live Auth session.';
comment on function private.create_organization_invitation(uuid, text, text) is
  'Owner/admin invite entrypoint with cross-organization membership preflight; legacy role rules remain authoritative.';
comment on function private.update_organization_membership_status(uuid, uuid, uuid, integer, text) is
  'Owner may manage any other member; admin may manage teacher-only memberships.';