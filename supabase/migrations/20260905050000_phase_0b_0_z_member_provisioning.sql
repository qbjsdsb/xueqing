-- Phase 0B.0-Z: close the member provisioning and onboarding loop.
--
-- Auth Admin operations remain in the Edge Function. These database
-- functions only validate the actor/session and perform the business-side
-- transaction. Temporary passwords are never stored in this database.

alter table public.organization_memberships
  add column if not exists onboarding_started_at timestamptz;

alter table public.organization_memberships
  add column if not exists onboarding_completed_at timestamptz;

alter table public.organization_memberships
  add column if not exists onboarding_required boolean not null default false;

update public.organization_memberships
set onboarding_required = true,
    onboarding_started_at = coalesce(onboarding_started_at, created_at),
    onboarding_expires_at = coalesce(
      onboarding_expires_at,
      created_at + interval '7 days'
    )
where status = 'onboarding';

alter table public.organization_memberships
  drop constraint if exists organization_memberships_onboarding_contract_check;

alter table public.organization_memberships
  add constraint organization_memberships_onboarding_contract_check
  check (
    status <> 'onboarding'
    or (
      onboarding_required
      and onboarding_started_at is not null
      and onboarding_expires_at is not null
    )
  );

create or replace function private.guard_onboarding_membership_transition()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
begin
  -- The only public path that may clear onboarding_required and move a
  -- member to active is complete_member_onboarding. Authenticated clients
  -- cannot update this table directly, but this trigger also protects the
  -- existing status RPC and invitation acceptance RPC from bypassing the
  -- lifecycle.
  if old.onboarding_required
    and (
      new.status <> 'onboarding'
      or not new.onboarding_required
    )
    and (
      new.status <> 'active'
      or new.onboarding_required
      or new.onboarding_completed_at is null
    ) then
    raise exception using
      errcode = 'P0001',
      message = 'onboarding_completion_required';
  end if;

  return new;
end
$function$;

drop trigger if exists organization_memberships_onboarding_guard
  on public.organization_memberships;

create trigger organization_memberships_onboarding_guard
before update on public.organization_memberships
for each row
execute function private.guard_onboarding_membership_transition();

create or replace function public.get_my_membership_state()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $function$
declare
  v_auth_user_id uuid := (select auth.uid());
  v_app_user_id uuid;
  v_app_user_status text;
  v_display_name text;
  v_membership public.organization_memberships%rowtype;
  v_organization_name text;
begin
  if v_auth_user_id is null
    or not (select private.has_live_auth_session_v2()) then
    raise exception using
      errcode = 'P0001',
      message = 'invalid_live_session';
  end if;

  select app_user.id, app_user.status, app_user.display_name
  into v_app_user_id, v_app_user_status, v_display_name
  from public.app_users as app_user
  where app_user.auth_provider = 'supabase'
    and app_user.auth_subject_id = v_auth_user_id::text
  limit 1;

  if v_app_user_id is null then
    return jsonb_build_object(
      'status', 'none',
      'app_user_id', null,
      'display_name', null
    );
  end if;

  if v_app_user_status <> 'active' then
    return jsonb_build_object(
      'status', 'disabled',
      'app_user_id', v_app_user_id,
      'display_name', v_display_name
    );
  end if;

  select membership.*
  into v_membership
  from public.organization_memberships as membership
  join public.organizations as organization
    on organization.id = membership.organization_id
   and organization.status = 'active'
  where membership.app_user_id = v_app_user_id
  order by case membership.status
    when 'onboarding' then 1
    when 'active' then 2
    else 3
  end, membership.updated_at desc
  limit 1;

  if v_membership.id is not null then
    select organization.name
    into v_organization_name
    from public.organizations as organization
    where organization.id = v_membership.organization_id;
  end if;

  if v_membership.id is null then
    return jsonb_build_object(
      'status', 'none',
      'app_user_id', v_app_user_id,
      'display_name', v_display_name
    );
  end if;

  return jsonb_build_object(
    'status', v_membership.status,
    'app_user_id', v_app_user_id,
    'membership_id', v_membership.id,
    'organization_id', v_membership.organization_id,
    'organization_name', v_organization_name,
    'display_name', v_display_name,
    'onboarding_expires_at', v_membership.onboarding_expires_at
  );
end
$function$;

create or replace function public.reissue_organization_invitation(
  p_invitation_id uuid
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $function$
declare
  v_old_invitation public.organization_invitations%rowtype;
  v_new_invitation_id uuid := gen_random_uuid();
  v_current_app_user_id uuid;
  v_current_membership_id uuid;
  v_new_status text;
  v_invite_code text;
  v_expires_at timestamptz := now() + interval '7 days';
begin
  if p_invitation_id is null then
    raise exception using
      errcode = 'P0001',
      message = 'invalid_invitation_input';
  end if;

  select *
  into v_old_invitation
  from public.organization_invitations as invitation
  where invitation.id = p_invitation_id
  for update;

  if not found then
    raise exception using
      errcode = 'P0001',
      message = 'invitation_not_found';
  end if;

  v_current_app_user_id := (select private.current_app_user_id_v2());
  v_current_membership_id := (
    select private.current_membership_for_organization_v2(
      v_old_invitation.organization_id
    )
  );
  if v_current_app_user_id is null
    or v_current_membership_id is null
    or not (select private.can_manage_organization_v2(
      v_old_invitation.organization_id
    )) then
    raise exception using
      errcode = 'P0001',
      message = 'organization_manager_required';
  end if;

  if v_old_invitation.status in ('accepted', 'revoked') then
    raise exception using
      errcode = 'P0001',
      message = 'invitation_not_revocable';
  end if;

  if exists (
    select 1
    from auth.users as auth_user
    join public.app_users as app_user
      on app_user.auth_provider = 'supabase'
     and app_user.auth_subject_id = auth_user.id::text
    join public.organization_memberships as membership
      on membership.app_user_id = app_user.id
     and membership.organization_id = v_old_invitation.organization_id
     and membership.status in ('onboarding', 'active')
    where lower(auth_user.email) = v_old_invitation.email
  ) then
    raise exception using
      errcode = 'P0001',
      message = 'invitee_already_member';
  end if;

  if exists (
    select 1
    from auth.users as auth_user
    join public.app_users as app_user
      on app_user.auth_provider = 'supabase'
     and app_user.auth_subject_id = auth_user.id::text
    join public.organization_memberships as membership
      on membership.app_user_id = app_user.id
     and membership.organization_id = v_old_invitation.organization_id
     and membership.status = 'disabled'
    where lower(auth_user.email) = v_old_invitation.email
  ) then
    raise exception using
      errcode = 'P0001',
      message = 'app_user_disabled';
  end if;

  v_new_status := case
    when v_old_invitation.status = 'pending_owner_approval'
      or v_old_invitation.approved_by_membership_id is null
      and v_old_invitation.role = 'org_owner'
      then 'pending_owner_approval'
    else 'pending'
  end;

  v_invite_code := encode(extensions.gen_random_bytes(12), 'hex');

  update public.organization_invitations
  set status = 'revoked',
      revoked_at = now(),
      updated_at = now()
  where id = v_old_invitation.id;

  insert into public.organization_invitations (
    id,
    organization_id,
    email,
    role,
    status,
    invite_code_hash,
    invited_by_app_user_id,
    invited_by_membership_id,
    approved_by_membership_id,
    expires_at,
    approved_at
  )
  values (
    v_new_invitation_id,
    v_old_invitation.organization_id,
    v_old_invitation.email,
    v_old_invitation.role,
    v_new_status,
    encode(extensions.digest(v_invite_code, 'sha256'), 'hex'),
    v_old_invitation.invited_by_app_user_id,
    v_old_invitation.invited_by_membership_id,
    case when v_new_status = 'pending' then
      v_old_invitation.approved_by_membership_id
    else null end,
    v_expires_at,
    case when v_new_status = 'pending' then
      v_old_invitation.approved_at
    else null end
  );

  return jsonb_build_object(
    'id', v_new_invitation_id,
    'organization_id', v_old_invitation.organization_id,
    'email', v_old_invitation.email,
    'role', v_old_invitation.role,
    'status', v_new_status,
    'expires_at', v_expires_at,
    'created_at', now(),
    'invite_code', v_invite_code
  );
end
$function$;

create or replace function public.provision_organization_member_from_auth(
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
  v_actor_app_user_id uuid;
  v_actor_membership_id uuid;
  v_target_app_user_id uuid;
  v_target_app_user_status text;
  v_target_email text;
  v_membership_id uuid;
  v_resolved_display_name text;
  v_onboarding_started_at timestamptz := timezone('utc', clock_timestamp());
  v_onboarding_expires_at timestamptz;
  v_actor_is_owner boolean;
  v_organization_status text;
begin
  if p_actor_auth_user_id is null
    or p_actor_session_id is null
    or p_invitation_id is null
    or p_target_auth_user_id is null
    or nullif(btrim(coalesce(p_actor_issuer, '')), '') is null then
    raise exception using
      errcode = 'P0001',
      message = 'invalid_live_session';
  end if;

  if not exists (
    select 1
    from auth.sessions as auth_session
    where auth_session.id = p_actor_session_id
      and auth_session.user_id = p_actor_auth_user_id
  ) then
    raise exception using
      errcode = 'P0001',
      message = 'invalid_live_session';
  end if;

  select app_user.id
  into v_actor_app_user_id
  from public.app_users as app_user
  join public.identity_links as identity_link
    on identity_link.app_user_id = app_user.id
   and identity_link.provider_key = 'supabase'
   and identity_link.external_subject = p_actor_auth_user_id::text
   and identity_link.status = 'active'
  where app_user.auth_provider = 'supabase'
    and app_user.auth_subject_id = p_actor_auth_user_id::text
    and app_user.status = 'active'
  limit 1;

  if v_actor_app_user_id is null then
    raise exception using
      errcode = 'P0001',
      message = 'organization_manager_required';
  end if;

  select invitation.*
  into v_invitation
  from public.organization_invitations as invitation
  where invitation.id = p_invitation_id
  for update;

  if not found then
    raise exception using
      errcode = 'P0001',
      message = 'invitation_not_found';
  end if;

  select organization.status
  into v_organization_status
  from public.organizations as organization
  where organization.id = v_invitation.organization_id
  for update;

  if not found or v_organization_status <> 'active' then
    raise exception using
      errcode = 'P0001',
      message = 'organization_not_available';
  end if;

  select membership.id
  into v_actor_membership_id
  from public.organization_memberships as membership
  join public.membership_roles as membership_role
    on membership_role.membership_id = membership.id
   and membership_role.organization_id = membership.organization_id
   and membership_role.role in ('org_owner', 'org_admin')
  where membership.organization_id = v_invitation.organization_id
    and membership.app_user_id = v_actor_app_user_id
    and membership.status = 'active'
  order by membership.id
  limit 1;

  if v_actor_membership_id is null then
    raise exception using
      errcode = 'P0001',
      message = 'organization_manager_required';
  end if;

  v_actor_is_owner := exists (
    select 1
    from public.membership_roles as membership_role
    where membership_role.membership_id = v_actor_membership_id
      and membership_role.organization_id = v_invitation.organization_id
      and membership_role.role = 'org_owner'
  );

  if not v_actor_is_owner and v_invitation.role <> 'teacher' then
    raise exception using
      errcode = 'P0001',
      message = 'organization_owner_required';
  end if;

  if v_invitation.status <> 'pending' then
    if v_invitation.status = 'pending_owner_approval' then
      raise exception using
        errcode = 'P0001',
        message = 'invitation_not_approved';
    end if;
    raise exception using
      errcode = 'P0001',
      message = 'invitation_not_available';
  end if;

  if v_invitation.expires_at <= now() then
    update public.organization_invitations
    set status = 'expired',
        updated_at = now()
    where id = v_invitation.id;
    raise exception using
      errcode = 'P0001',
      message = 'invitation_expired';
  end if;

  select lower(btrim(coalesce(auth_user.email, '')))
  into v_target_email
  from auth.users as auth_user
  where auth_user.id = p_target_auth_user_id;

  if v_target_email is null or v_target_email = '' then
    raise exception using
      errcode = 'P0001',
      message = 'auth_user_not_found';
  end if;

  if v_target_email <> v_invitation.email then
    raise exception using
      errcode = 'P0001',
      message = 'invitation_email_mismatch';
  end if;

  select app_user.id, app_user.status
  into v_target_app_user_id, v_target_app_user_status
  from public.app_users as app_user
  where app_user.auth_provider = 'supabase'
    and app_user.auth_subject_id = p_target_auth_user_id::text
  limit 1;

  if v_target_app_user_status = 'disabled' then
    raise exception using
      errcode = 'P0001',
      message = 'app_user_disabled';
  end if;

  if v_target_app_user_id is not null then
    if exists (
      select 1
      from public.organization_memberships as membership
      where membership.app_user_id = v_target_app_user_id
        and membership.status in ('onboarding', 'active')
    ) then
      raise exception using
        errcode = 'P0001',
        message = 'user_already_member_elsewhere';
    end if;
  else
    v_resolved_display_name := nullif(
      btrim(coalesce(p_display_name, '')),
      ''
    );
    if v_resolved_display_name is null then
      v_resolved_display_name := split_part(v_target_email, '@', 1);
    end if;
    v_resolved_display_name := left(v_resolved_display_name, 120);

    insert into public.app_users (
      auth_provider,
      auth_subject_id,
      display_name,
      status
    )
    values (
      'supabase',
      p_target_auth_user_id::text,
      v_resolved_display_name,
      'active'
    )
    returning id into v_target_app_user_id;

    insert into public.identity_links (
      app_user_id,
      provider_key,
      issuer,
      external_subject,
      status
    )
    values (
      v_target_app_user_id,
      'supabase',
      left(btrim(p_actor_issuer), 500),
      p_target_auth_user_id::text,
      'active'
    );
  end if;

  if exists (
    select 1
    from public.organization_memberships as membership
    where membership.app_user_id = v_target_app_user_id
      and membership.status in ('onboarding', 'active')
  ) then
    raise exception using
      errcode = 'P0001',
      message = 'user_already_member_elsewhere';
  end if;

  v_onboarding_expires_at := least(
    v_invitation.expires_at,
    v_onboarding_started_at + interval '7 days'
  );

  insert into public.organization_memberships (
    organization_id,
    app_user_id,
    status,
    onboarding_expires_at,
    onboarding_started_at,
    onboarding_required
  )
  values (
    v_invitation.organization_id,
    v_target_app_user_id,
    'onboarding',
    v_onboarding_expires_at,
    v_onboarding_started_at,
    true
  )
  returning id into v_membership_id;

  insert into public.membership_roles (
    organization_id,
    membership_id,
    role
  )
  values (
    v_invitation.organization_id,
    v_membership_id,
    v_invitation.role
  );

  update public.organization_invitations
  set status = 'accepted',
      accepted_by_app_user_id = v_target_app_user_id,
      accepted_at = now(),
      updated_at = now()
  where id = v_invitation.id;

  return jsonb_build_object(
    'invitation_id', v_invitation.id,
    'organization_id', v_invitation.organization_id,
    'membership_id', v_membership_id,
    'app_user_id', v_target_app_user_id,
    'target_auth_user_id', p_target_auth_user_id,
    'role', v_invitation.role,
    'status', 'onboarding',
    'onboarding_expires_at', v_onboarding_expires_at
  );
end
$function$;

create or replace function public.prepare_member_credential_reissue(
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
  v_actor_app_user_id uuid;
  v_actor_membership_id uuid;
  v_target public.organization_memberships%rowtype;
  v_target_auth_user_id uuid;
  v_target_email text;
  v_started_at timestamptz := timezone('utc', clock_timestamp());
  v_expires_at timestamptz := v_started_at + interval '7 days';
  v_organization_status text;
begin
  if p_actor_auth_user_id is null
    or p_actor_session_id is null
    or p_organization_id is null
    or p_membership_id is null then
    raise exception using
      errcode = 'P0001',
      message = 'invalid_live_session';
  end if;

  if not exists (
    select 1
    from auth.sessions as auth_session
    where auth_session.id = p_actor_session_id
      and auth_session.user_id = p_actor_auth_user_id
  ) then
    raise exception using
      errcode = 'P0001',
      message = 'invalid_live_session';
  end if;

  select app_user.id
  into v_actor_app_user_id
  from public.app_users as app_user
  join public.identity_links as identity_link
    on identity_link.app_user_id = app_user.id
   and identity_link.provider_key = 'supabase'
   and identity_link.external_subject = p_actor_auth_user_id::text
   and identity_link.status = 'active'
  where app_user.auth_provider = 'supabase'
    and app_user.auth_subject_id = p_actor_auth_user_id::text
    and app_user.status = 'active'
  limit 1;

  if v_actor_app_user_id is null then
    raise exception using
      errcode = 'P0001',
      message = 'organization_manager_required';
  end if;

  select organization.status
  into v_organization_status
  from public.organizations as organization
  where organization.id = p_organization_id
  for update;

  if not found or v_organization_status <> 'active' then
    raise exception using
      errcode = 'P0001',
      message = 'organization_not_available';
  end if;

  select membership.id
  into v_actor_membership_id
  from public.organization_memberships as membership
  join public.membership_roles as membership_role
    on membership_role.membership_id = membership.id
   and membership_role.organization_id = membership.organization_id
   and membership_role.role in ('org_owner', 'org_admin')
  where membership.organization_id = p_organization_id
    and membership.app_user_id = v_actor_app_user_id
    and membership.status = 'active'
  order by membership.id
  limit 1;

  if v_actor_membership_id is null then
    raise exception using
      errcode = 'P0001',
      message = 'organization_manager_required';
  end if;

  select *
  into v_target
  from public.organization_memberships as membership
  where membership.id = p_membership_id
    and membership.organization_id = p_organization_id
  for update;

  if not found then
    raise exception using
      errcode = 'P0001',
      message = 'membership_not_found';
  end if;

  if v_target.app_user_id = v_actor_app_user_id then
    raise exception using
      errcode = 'P0001',
      message = 'current_membership_immutable';
  end if;

  if exists (
    select 1
    from public.membership_roles as target_role
    where target_role.membership_id = v_target.id
      and target_role.organization_id = p_organization_id
      and target_role.role = 'org_owner'
  )
  and not exists (
    select 1
    from public.membership_roles as actor_role
    where actor_role.membership_id = v_actor_membership_id
      and actor_role.organization_id = p_organization_id
      and actor_role.role = 'org_owner'
  ) then
    raise exception using
      errcode = 'P0001',
      message = 'organization_owner_required';
  end if;

  if v_target.status <> 'onboarding' then
    raise exception using
      errcode = 'P0001',
      message = 'member_not_onboarding';
  end if;

  select auth_user.id, lower(btrim(coalesce(auth_user.email, '')))
  into v_target_auth_user_id, v_target_email
  from public.app_users as app_user
  join auth.users as auth_user
    on auth_user.id::text = app_user.auth_subject_id
   and app_user.auth_provider = 'supabase'
  where app_user.id = v_target.app_user_id
    and app_user.auth_provider = 'supabase';

  if v_target_auth_user_id is null or v_target_email is null then
    raise exception using
      errcode = 'P0001',
      message = 'auth_user_not_found';
  end if;

  update public.organization_memberships
  set onboarding_started_at = v_started_at,
      onboarding_expires_at = v_expires_at,
      onboarding_required = true,
      onboarding_completed_at = null,
      version = version + 1,
      updated_at = v_started_at
  where id = v_target.id;

  return jsonb_build_object(
    'organization_id', p_organization_id,
    'membership_id', v_target.id,
    'app_user_id', v_target.app_user_id,
    'target_auth_user_id', v_target_auth_user_id,
    'email', v_target_email,
    'status', 'onboarding',
    'version', v_target.version + 1,
    'onboarding_expires_at', v_expires_at
  );
end
$function$;

create or replace function public.revoke_member_auth_sessions(
  p_target_auth_user_id uuid
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $function$
declare
  v_deleted_count integer := 0;
begin
  if p_target_auth_user_id is null then
    raise exception using
      errcode = 'P0001',
      message = 'auth_user_not_found';
  end if;

  delete from auth.sessions
  where user_id = p_target_auth_user_id;
  get diagnostics v_deleted_count = row_count;

  return jsonb_build_object('revoked_session_count', v_deleted_count);
end
$function$;

create or replace function public.complete_member_onboarding()
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $function$
declare
  v_app_user_id uuid;
  v_auth_user_id uuid := (select auth.uid());
  v_session_id uuid := nullif(
    (select auth.jwt() ->> 'session_id'),
    ''
  )::uuid;
  v_auth_updated_at timestamptz;
  v_session_created_at timestamptz;
  v_membership public.organization_memberships%rowtype;
  v_organization_name text;
  v_now timestamptz := timezone('utc', clock_timestamp());
begin
  v_app_user_id := (select private.current_app_user_id_v2());
  if v_auth_user_id is null
    or v_session_id is null
    or v_app_user_id is null then
    raise exception using
      errcode = 'P0001',
      message = 'invalid_live_session';
  end if;

  select auth_user.updated_at
  into v_auth_updated_at
  from auth.users as auth_user
  where auth_user.id = v_auth_user_id;

  select auth_session.created_at
  into v_session_created_at
  from auth.sessions as auth_session
  where auth_session.id = v_session_id
    and auth_session.user_id = v_auth_user_id;

  if v_auth_updated_at is null or v_session_created_at is null then
    raise exception using
      errcode = 'P0001',
      message = 'invalid_live_session';
  end if;

  select membership.*
  into v_membership
  from public.organization_memberships as membership
  join public.organizations as organization
    on organization.id = membership.organization_id
   and organization.status = 'active'
  where membership.app_user_id = v_app_user_id
    and membership.status = 'onboarding'
  order by membership.id
  limit 1
  for update of membership;

  if v_membership.id is not null then
    select organization.name
    into v_organization_name
    from public.organizations as organization
    where organization.id = v_membership.organization_id;
  end if;

  if v_membership.id is null then
    raise exception using
      errcode = 'P0001',
      message = 'onboarding_not_required';
  end if;

  if v_membership.onboarding_expires_at <= v_now then
    raise exception using
      errcode = 'P0001',
      message = 'onboarding_expired';
  end if;

  if v_membership.onboarding_started_at is null
    or v_auth_updated_at <= v_membership.onboarding_started_at
    or v_session_created_at <= v_membership.onboarding_started_at then
    raise exception using
      errcode = 'P0001',
      message = 'onboarding_relogin_required';
  end if;

  -- A completed onboarding invalidates every other session. The current
  -- session is deliberately kept long enough for the client to receive the
  -- successful result and then force a clean login screen.
  delete from auth.sessions
  where user_id = v_auth_user_id
    and id <> v_session_id;

  update public.organization_memberships
  set status = 'active',
      onboarding_required = false,
      onboarding_completed_at = v_now,
      onboarding_expires_at = null,
      version = version + 1,
      updated_at = v_now
  where id = v_membership.id;

  return jsonb_build_object(
    'organization_id', v_membership.organization_id,
    'organization_name', v_organization_name,
    'membership_id', v_membership.id,
    'app_user_id', v_app_user_id,
    'status', 'active',
    'version', v_membership.version + 1
  );
end
$function$;

-- Keep the legacy invite-code route available for already-existing Auth
-- users, but prevent it from silently activating a disabled/onboarding member.
create or replace function public.create_organization_invitation(
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
  normalized_email text;
  normalized_role text;
  current_app_user_id uuid;
  current_membership_id uuid;
  caller_is_owner boolean;
  invitation_status text;
  invitation_id uuid := gen_random_uuid();
  invite_code text;
  invitation_expires_at timestamptz := now() + interval '7 days';
begin
  normalized_email := lower(btrim(coalesce(p_email, '')));
  normalized_role := lower(btrim(coalesce(p_role, '')));

  if p_organization_id is null
    or char_length(normalized_email) < 3
    or char_length(normalized_email) > 320
    or position('@' in normalized_email) <= 1
    or normalized_role not in ('org_owner', 'org_admin', 'teacher') then
    raise exception using
      errcode = 'P0001',
      message = 'invalid_invitation_input';
  end if;

  current_app_user_id := (select private.current_app_user_id_v2());
  if current_app_user_id is null then
    raise exception using
      errcode = 'P0001',
      message = 'invalid_live_session';
  end if;

  current_membership_id := (
    select private.current_membership_for_organization_v2(
      p_organization_id
    )
  );
  if current_membership_id is null
    or not (select private.can_manage_organization_v2(p_organization_id)) then
    raise exception using
      errcode = 'P0001',
      message = 'organization_manager_required';
  end if;

  caller_is_owner := exists (
    select 1
    from public.membership_roles as membership_role
    where membership_role.membership_id = current_membership_id
      and membership_role.organization_id = p_organization_id
      and membership_role.role = 'org_owner'
  );

  if caller_is_owner then
    invitation_status := 'pending';
  elsif normalized_role not in ('org_owner', 'teacher') then
    raise exception using
      errcode = 'P0001',
      message = 'role_not_allowed';
  else
    invitation_status := case
      when normalized_role = 'org_owner' then 'pending_owner_approval'
      else 'pending'
    end;
  end if;

  if exists (
    select 1
    from auth.users as auth_user
    join public.app_users as app_user
      on app_user.auth_provider = 'supabase'
     and app_user.auth_subject_id = auth_user.id::text
    join public.organization_memberships as membership
      on membership.app_user_id = app_user.id
     and membership.organization_id = p_organization_id
     and membership.status in ('onboarding', 'active')
    where lower(auth_user.email) = normalized_email
  ) then
    raise exception using
      errcode = 'P0001',
      message = 'invitee_already_member';
  end if;

  if exists (
    select 1
    from auth.users as auth_user
    join public.app_users as app_user
      on app_user.auth_provider = 'supabase'
     and app_user.auth_subject_id = auth_user.id::text
    join public.organization_memberships as membership
      on membership.app_user_id = app_user.id
     and membership.organization_id = p_organization_id
     and membership.status = 'disabled'
    where lower(auth_user.email) = normalized_email
  ) then
    raise exception using
      errcode = 'P0001',
      message = 'app_user_disabled';
  end if;

  update public.organization_invitations as invitation
  set status = 'expired',
      updated_at = now()
  where invitation.organization_id = p_organization_id
    and lower(invitation.email) = normalized_email
    and invitation.role = normalized_role
    and invitation.status in ('pending', 'pending_owner_approval')
    and invitation.expires_at <= now();

  if exists (
    select 1
    from public.organization_invitations as invitation
    where invitation.organization_id = p_organization_id
      and lower(invitation.email) = normalized_email
      and invitation.role = normalized_role
      and invitation.status in ('pending', 'pending_owner_approval')
      and invitation.expires_at > now()
  ) then
    raise exception using
      errcode = 'P0001',
      message = 'invitation_already_exists';
  end if;

  invite_code := encode(extensions.gen_random_bytes(12), 'hex');

  insert into public.organization_invitations (
    id,
    organization_id,
    email,
    role,
    status,
    invite_code_hash,
    invited_by_app_user_id,
    invited_by_membership_id,
    expires_at
  )
  values (
    invitation_id,
    p_organization_id,
    normalized_email,
    normalized_role,
    invitation_status,
    encode(extensions.digest(invite_code, 'sha256'), 'hex'),
    current_app_user_id,
    current_membership_id,
    invitation_expires_at
  );

  return jsonb_build_object(
    'id', invitation_id,
    'organization_id', p_organization_id,
    'email', normalized_email,
    'role', normalized_role,
    'status', invitation_status,
    'expires_at', invitation_expires_at,
    'invite_code', invite_code
  );
end
$function$;

-- Re-declare acceptance so stale invitation codes cannot restore a disabled
-- membership or bypass a pending onboarding credential change.
create or replace function public.accept_organization_invitation(
  p_invite_code text,
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
  v_auth_user_id uuid := (select auth.uid());
  v_auth_email text := lower(
    btrim(coalesce((select auth.jwt() ->> 'email'), ''))
  );
  v_organization_status text;
  v_app_user_id uuid;
  v_app_user_status text;
  v_membership_id uuid;
  v_membership_status text;
  v_resolved_display_name text;
begin
  if v_auth_user_id is null
    or v_auth_email = ''
    or not (select private.has_live_auth_session_v2()) then
    raise exception using
      errcode = 'P0001',
      message = 'invalid_live_session';
  end if;

  if p_invite_code is null
    or char_length(btrim(p_invite_code)) < 16 then
    raise exception using
      errcode = 'P0001',
      message = 'invalid_invitation_input';
  end if;

  select *
  into v_invitation
  from public.organization_invitations as invitation
  where invitation.invite_code_hash =
    encode(extensions.digest(btrim(p_invite_code), 'sha256'), 'hex')
  for update;

  if not found then
    raise exception using
      errcode = 'P0001',
      message = 'invitation_not_found';
  end if;

  if v_invitation.status = 'pending_owner_approval' then
    raise exception using
      errcode = 'P0001',
      message = 'invitation_not_approved';
  end if;

  if v_invitation.status <> 'pending' then
    raise exception using
      errcode = 'P0001',
      message = 'invitation_not_available';
  end if;

  if v_invitation.expires_at <= now() then
    update public.organization_invitations
    set status = 'expired',
        updated_at = now()
    where id = v_invitation.id;
    raise exception using
      errcode = 'P0001',
      message = 'invitation_expired';
  end if;

  if v_auth_email <> v_invitation.email then
    raise exception using
      errcode = 'P0001',
      message = 'invitation_email_mismatch';
  end if;

  select organization.status
  into v_organization_status
  from public.organizations as organization
  where organization.id = v_invitation.organization_id
  for update;

  if not found or v_organization_status <> 'active' then
    raise exception using
      errcode = 'P0001',
      message = 'organization_not_available';
  end if;

  select app_user.id, app_user.status
  into v_app_user_id, v_app_user_status
  from public.app_users as app_user
  where app_user.auth_provider = 'supabase'
    and app_user.auth_subject_id = v_auth_user_id::text
  limit 1;

  if v_app_user_status = 'disabled' then
    raise exception using
      errcode = 'P0001',
      message = 'app_user_disabled';
  end if;

  if v_app_user_id is null then
    v_resolved_display_name := nullif(
      btrim(coalesce(p_display_name, '')),
      ''
    );
    if v_resolved_display_name is null then
      v_resolved_display_name := split_part(v_auth_email, '@', 1);
    end if;
    v_resolved_display_name := left(v_resolved_display_name, 120);

    insert into public.app_users (
      auth_provider,
      auth_subject_id,
      display_name,
      status
    )
    values (
      'supabase',
      v_auth_user_id::text,
      v_resolved_display_name,
      'active'
    )
    returning id into v_app_user_id;

    insert into public.identity_links (
      app_user_id,
      provider_key,
      issuer,
      external_subject,
      status
    )
    values (
      v_app_user_id,
      'supabase',
      coalesce(
        nullif((select auth.jwt() ->> 'iss'), ''),
        'supabase'
      ),
      v_auth_user_id::text,
      'active'
    );
  end if;

  select membership.id, membership.status
  into v_membership_id, v_membership_status
  from public.organization_memberships as membership
  where membership.organization_id = v_invitation.organization_id
    and membership.app_user_id = v_app_user_id
  for update;

  if v_membership_id is null then
    if exists (
      select 1
      from public.organization_memberships as existing_membership
      where existing_membership.app_user_id = v_app_user_id
        and existing_membership.status in ('onboarding', 'active')
    ) then
      raise exception using
        errcode = 'P0001',
        message = 'user_already_member_elsewhere';
    end if;

    insert into public.organization_memberships (
      organization_id,
      app_user_id,
      status
    )
    values (
      v_invitation.organization_id,
      v_app_user_id,
      'active'
    )
    returning id into v_membership_id;
  elsif v_membership_status = 'onboarding' then
    raise exception using
      errcode = 'P0001',
      message = 'onboarding_completion_required';
  elsif v_membership_status = 'disabled' then
    raise exception using
      errcode = 'P0001',
      message = 'app_user_disabled';
  end if;

  if exists (
    select 1
    from public.membership_roles as membership_role
    where membership_role.membership_id = v_membership_id
      and membership_role.organization_id = v_invitation.organization_id
      and membership_role.role = v_invitation.role
  ) then
    raise exception using
      errcode = 'P0001',
      message = 'invitation_already_member';
  end if;

  insert into public.membership_roles (
    organization_id,
    membership_id,
    role
  )
  values (
    v_invitation.organization_id,
    v_membership_id,
    v_invitation.role
  );

  update public.organization_invitations
  set status = 'accepted',
      accepted_by_app_user_id = v_app_user_id,
      accepted_at = now(),
      updated_at = now()
  where id = v_invitation.id;

  return jsonb_build_object(
    'invitation_id', v_invitation.id,
    'organization_id', v_invitation.organization_id,
    'membership_id', v_membership_id,
    'app_user_id', v_app_user_id,
    'role', v_invitation.role,
    'status', 'accepted'
  );
end
$function$;

revoke all on function public.get_my_membership_state()
  from public, anon;
grant execute on function public.get_my_membership_state()
  to authenticated;

revoke all on function public.reissue_organization_invitation(uuid)
  from public, anon;
grant execute on function public.reissue_organization_invitation(uuid)
  to authenticated;

revoke all on function public.provision_organization_member_from_auth(
  uuid, uuid, text, uuid, uuid, text
) from public, anon, authenticated;
grant execute on function public.provision_organization_member_from_auth(
  uuid, uuid, text, uuid, uuid, text
) to service_role;

revoke all on function public.prepare_member_credential_reissue(
  uuid, uuid, uuid, uuid
) from public, anon, authenticated;
grant execute on function public.prepare_member_credential_reissue(
  uuid, uuid, uuid, uuid
) to service_role;

revoke all on function public.revoke_member_auth_sessions(uuid)
  from public, anon, authenticated;
grant execute on function public.revoke_member_auth_sessions(uuid)
  to service_role;

revoke all on function public.complete_member_onboarding()
  from public, anon;
grant execute on function public.complete_member_onboarding()
  to authenticated;
