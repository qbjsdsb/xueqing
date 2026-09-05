-- Phase 0B.0-U: collapse the pilot role contract to owner, admin, and teacher.
-- This is a fictional/development migration. It must be reviewed again
-- before any production deployment or real student data is introduced.

-- Academic administrators were exposed by early invitation code but were no
-- longer accepted by the organization manager authorization helper. Preserve
-- their intended management access by migrating them to organization admins.
delete from public.membership_roles as legacy_role
using public.membership_roles as admin_role
where legacy_role.role = 'academic_admin'
  and admin_role.membership_id = legacy_role.membership_id
  and admin_role.role = 'org_admin';

update public.membership_roles
set role = 'org_admin'
where role = 'academic_admin';

-- Subject lead and student advisor were design placeholders without complete
-- product workflows or authorization tests. Removing those capabilities is
-- safer than silently translating them into a more powerful role.
delete from public.membership_roles
where role in ('subject_lead', 'student_advisor');

-- Resolve a possible open academic-admin/admin invitation collision before
-- normalizing the historical invitation role through the partial unique index.
update public.organization_invitations as legacy_invitation
set status = 'revoked',
    revoked_at = coalesce(legacy_invitation.revoked_at, now()),
    updated_at = now()
where legacy_invitation.role = 'academic_admin'
  and legacy_invitation.status in ('pending', 'pending_owner_approval')
  and exists (
    select 1
    from public.organization_invitations as admin_invitation
    where admin_invitation.organization_id = legacy_invitation.organization_id
      and lower(admin_invitation.email) = lower(legacy_invitation.email)
      and admin_invitation.role = 'org_admin'
      and admin_invitation.status in ('pending', 'pending_owner_approval')
  );

update public.organization_invitations
set role = 'org_admin',
    updated_at = now()
where role = 'academic_admin';

alter table public.membership_roles
  drop constraint if exists membership_roles_role_check;

alter table public.membership_roles
  add constraint membership_roles_role_check
  check (role in ('org_owner', 'org_admin', 'teacher'));

comment on column public.membership_roles.role is
  'Pilot role hierarchy: org_owner > org_admin > teacher.';

alter table public.organization_invitations
  drop constraint if exists organization_invitations_role_check;

alter table public.organization_invitations
  add constraint organization_invitations_role_check
  check (role in ('org_owner', 'org_admin', 'teacher'));

create or replace function private.can_manage_organization_v2(
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
     and membership_role.role in ('org_owner', 'org_admin')
    join public.organizations as organization
      on organization.id = membership.organization_id
     and organization.status = 'active'
    where membership.organization_id = target_organization_id
      and membership.app_user_id =
        (select private.current_app_user_id_v2())
      and membership.status = 'active'
  )
$function$;

create or replace function private.can_manage_case_types_v2(
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
     and membership_role.role in ('org_owner', 'org_admin')
    join public.organizations as organization
      on organization.id = membership.organization_id
     and organization.status = 'active'
    where membership.organization_id = target_organization_id
      and membership.app_user_id =
        (select private.current_app_user_id_v2())
      and membership.status = 'active'
  )
$function$;

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
    -- An admin may nominate a responsible person, but cannot activate that
    -- elevated role without an existing responsible person's approval.
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
    'email', normalized_email,
    'role', normalized_role,
    'status', invitation_status,
    'expires_at', invitation_expires_at,
    'invite_code', invite_code
  );
end
$function$;
