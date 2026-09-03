-- Phase 0B.0-H: organization leadership and zero-cost invitation workflow.
-- This is a fictional/development migration. It must be reviewed again
-- before any production deployment or real student data is introduced.
--
-- Role hierarchy:
--   org_owner       负责人
--   org_admin       管理员
--   academic_admin  教务管理员
--   teacher         老师
--
-- An administrator may request a new org_owner, but an existing org_owner
-- must approve that invitation before the invitee can accept it.

alter table public.membership_roles
  drop constraint if exists membership_roles_role_check;

alter table public.membership_roles
  add constraint membership_roles_role_check
  check (role in (
    'org_owner',
    'org_admin',
    'academic_admin',
    'subject_lead',
    'teacher',
    'student_advisor'
  ));

comment on column public.membership_roles.role is
  'Role hierarchy includes org_owner > org_admin/academic_admin > teacher.';

create table public.organization_invitations (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null
    references public.organizations(id) on delete restrict,
  email text not null
    check (
      email = lower(btrim(email))
      and char_length(email) between 3 and 320
      and position('@' in email) > 1
    ),
  role text not null
    check (role in (
      'org_owner',
      'org_admin',
      'academic_admin',
      'teacher'
    )),
  status text not null default 'pending'
    check (status in (
      'pending',
      'pending_owner_approval',
      'accepted',
      'revoked',
      'expired'
    )),
  invite_code_hash text not null
    check (char_length(invite_code_hash) = 64),
  invited_by_app_user_id uuid not null
    references public.app_users(id) on delete restrict,
  invited_by_membership_id uuid not null,
  approved_by_membership_id uuid,
  accepted_by_app_user_id uuid
    references public.app_users(id) on delete restrict,
  expires_at timestamptz not null,
  approved_at timestamptz,
  accepted_at timestamptz,
  revoked_at timestamptz,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint organization_invitations_code_key
    unique (invite_code_hash),
  constraint organization_invitations_inviter_membership_fk
    foreign key (invited_by_membership_id, organization_id)
    references public.organization_memberships(id, organization_id)
    on delete restrict,
  constraint organization_invitations_approver_membership_fk
    foreign key (approved_by_membership_id, organization_id)
    references public.organization_memberships(id, organization_id)
    on delete restrict
);

create index organization_invitations_org_status_created_idx
  on public.organization_invitations (
    organization_id,
    status,
    created_at desc
  );

create index organization_invitations_org_email_idx
  on public.organization_invitations (
    organization_id,
    lower(email),
    role
  );

create unique index organization_invitations_open_email_role_key
  on public.organization_invitations (
    organization_id,
    lower(email),
    role
  )
  where status in ('pending', 'pending_owner_approval');

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
     and membership_role.role in (
       'org_owner',
       'org_admin',
       'academic_admin'
     )
    join public.organizations as organization
      on organization.id = membership.organization_id
     and organization.status = 'active'
    where membership.organization_id = target_organization_id
      and membership.app_user_id =
        (select private.current_app_user_id_v2())
      and membership.status = 'active'
  )
$function$;

create or replace function private.current_membership_for_organization_v2(
  target_organization_id uuid
)
returns uuid
language sql
stable
security definer
set search_path = ''
as $function$
  select membership.id
  from public.organization_memberships as membership
  where membership.organization_id = target_organization_id
    and membership.app_user_id =
      (select private.current_app_user_id_v2())
    and membership.status = 'active'
  order by membership.id
  limit 1
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
     and membership_role.role in (
       'org_owner',
       'org_admin',
       'academic_admin'
     )
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
    or normalized_role not in (
      'org_owner',
      'org_admin',
      'academic_admin',
      'teacher'
    ) then
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
    if normalized_role not in (
      'org_owner',
      'org_admin',
      'academic_admin',
      'teacher'
    ) then
      raise exception using
        errcode = 'P0001',
        message = 'role_not_allowed';
    end if;
    invitation_status := 'pending';
  elsif normalized_role not in ('org_owner', 'teacher') then
    raise exception using
      errcode = 'P0001',
      message = 'role_not_allowed';
  else
    -- An admin may nominate a responsible person, but cannot activate
    -- that elevated role without an existing responsible person's approval.
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

  invite_code := encode(gen_random_bytes(12), 'hex');

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
    encode(digest(invite_code, 'sha256'), 'hex'),
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

create or replace function public.list_organization_members(
  p_organization_id uuid
)
returns setof jsonb
language plpgsql
stable
security definer
set search_path = ''
as $function$
begin
  if p_organization_id is null
    or not (select private.can_manage_organization_v2(p_organization_id)) then
    raise exception using
      errcode = 'P0001',
      message = 'organization_manager_required';
  end if;

  return query
  select jsonb_build_object(
    'app_user_id', app_user.id,
    'membership_id', membership.id,
    'email', coalesce(auth_user.email, ''),
    'display_name', app_user.display_name,
    'status', membership.status,
    'roles', coalesce(
      (
        select jsonb_agg(
          membership_role.role
          order by membership_role.role
        )
        from public.membership_roles as membership_role
        where membership_role.membership_id = membership.id
          and membership_role.organization_id = membership.organization_id
      ),
      '[]'::jsonb
    )
  )
  from public.organization_memberships as membership
  join public.app_users as app_user
    on app_user.id = membership.app_user_id
  left join auth.users as auth_user
    on auth_user.id::text = app_user.auth_subject_id
   and app_user.auth_provider = 'supabase'
  where membership.organization_id = p_organization_id
  order by app_user.display_name, auth_user.email;
end
$function$;

create or replace function public.list_organization_invitations(
  p_organization_id uuid
)
returns setof jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $function$
begin
  if p_organization_id is null
    or not (select private.can_manage_organization_v2(p_organization_id)) then
    raise exception using
      errcode = 'P0001',
      message = 'organization_manager_required';
  end if;

  update public.organization_invitations
  set status = 'expired',
      updated_at = now()
  where organization_id = p_organization_id
    and status in ('pending', 'pending_owner_approval')
    and expires_at <= now();

  return query
  select jsonb_build_object(
    'id', invitation.id,
    'email', invitation.email,
    'role', invitation.role,
    'status', invitation.status,
    'expires_at', invitation.expires_at,
    'created_at', invitation.created_at,
    'invited_by_name', inviter.display_name
  )
  from public.organization_invitations as invitation
  join public.app_users as inviter
    on inviter.id = invitation.invited_by_app_user_id
  where invitation.organization_id = p_organization_id
    and invitation.status not in ('accepted', 'revoked')
  order by invitation.created_at desc;
end
$function$;

create or replace function public.approve_organization_invitation(
  p_invitation_id uuid
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $function$
declare
  invitation public.organization_invitations%rowtype;
  current_membership_id uuid;
begin
  if p_invitation_id is null then
    raise exception using
      errcode = 'P0001',
      message = 'invalid_invitation_input';
  end if;

  select *
  into invitation
  from public.organization_invitations
  where id = p_invitation_id
  for update;

  if not found then
    raise exception using
      errcode = 'P0001',
      message = 'invitation_not_found';
  end if;

  current_membership_id := (
    select private.current_membership_for_organization_v2(
      invitation.organization_id
    )
  );
  if current_membership_id is null
    or not exists (
      select 1
      from public.membership_roles as membership_role
      where membership_role.membership_id = current_membership_id
        and membership_role.organization_id = invitation.organization_id
        and membership_role.role = 'org_owner'
    ) then
    raise exception using
      errcode = 'P0001',
      message = 'organization_owner_required';
  end if;

  if invitation.status <> 'pending_owner_approval' then
    raise exception using
      errcode = 'P0001',
      message = 'invitation_not_awaiting_approval';
  end if;

  if invitation.expires_at <= now() then
    update public.organization_invitations
    set status = 'expired',
        updated_at = now()
    where id = invitation.id;
    raise exception using
      errcode = 'P0001',
      message = 'invitation_expired';
  end if;

  update public.organization_invitations
  set status = 'pending',
      approved_by_membership_id = current_membership_id,
      approved_at = now(),
      updated_at = now()
  where id = invitation.id;

  return jsonb_build_object(
    'id', invitation.id,
    'email', invitation.email,
    'role', invitation.role,
    'status', 'pending',
    'expires_at', invitation.expires_at
  );
end
$function$;

create or replace function public.revoke_organization_invitation(
  p_invitation_id uuid
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $function$
declare
  invitation public.organization_invitations%rowtype;
begin
  if p_invitation_id is null then
    raise exception using
      errcode = 'P0001',
      message = 'invalid_invitation_input';
  end if;

  select *
  into invitation
  from public.organization_invitations
  where id = p_invitation_id
  for update;

  if not found
    or not (select private.can_manage_organization_v2(invitation.organization_id)) then
    raise exception using
      errcode = 'P0001',
      message = 'organization_manager_required';
  end if;

  if invitation.status in ('accepted', 'revoked') then
    raise exception using
      errcode = 'P0001',
      message = 'invitation_not_revocable';
  end if;

  update public.organization_invitations
  set status = 'revoked',
      revoked_at = now(),
      updated_at = now()
  where id = invitation.id;

  return jsonb_build_object(
    'id', invitation.id,
    'email', invitation.email,
    'role', invitation.role,
    'status', 'revoked',
    'expires_at', invitation.expires_at
  );
end
$function$;

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
  invitation public.organization_invitations%rowtype;
  auth_user_id uuid := (select auth.uid());
  auth_email text := lower(
    btrim(coalesce((select auth.jwt() ->> 'email'), ''))
  );
  app_user_id uuid;
  app_user_status text;
  membership_id uuid;
  membership_status text;
  resolved_display_name text;
begin
  if auth_user_id is null
    or auth_email = '' then
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
  into invitation
  from public.organization_invitations
  where invite_code_hash =
    encode(digest(btrim(p_invite_code), 'sha256'), 'hex')
  for update;

  if not found then
    raise exception using
      errcode = 'P0001',
      message = 'invitation_not_found';
  end if;

  if invitation.status = 'pending_owner_approval' then
    raise exception using
      errcode = 'P0001',
      message = 'invitation_not_approved';
  end if;

  if invitation.status <> 'pending' then
    raise exception using
      errcode = 'P0001',
      message = 'invitation_not_available';
  end if;

  if invitation.expires_at <= now() then
    update public.organization_invitations
    set status = 'expired',
        updated_at = now()
    where id = invitation.id;
    raise exception using
      errcode = 'P0001',
      message = 'invitation_expired';
  end if;

  if auth_email <> invitation.email then
    raise exception using
      errcode = 'P0001',
      message = 'invitation_email_mismatch';
  end if;

  select app_user.id, app_user.status
  into app_user_id, app_user_status
  from public.app_users as app_user
  where app_user.auth_provider = 'supabase'
    and app_user.auth_subject_id = auth_user_id::text
  limit 1;

  if app_user_id is null then
    resolved_display_name := nullif(
      btrim(coalesce(p_display_name, '')),
      ''
    );
    if resolved_display_name is null then
      resolved_display_name := split_part(auth_email, '@', 1);
    end if;
    resolved_display_name := left(resolved_display_name, 120);

    insert into public.app_users (
      auth_provider,
      auth_subject_id,
      display_name,
      status
    )
    values (
      'supabase',
      auth_user_id::text,
      resolved_display_name,
      'active'
    )
    returning id into app_user_id;

    insert into public.identity_links (
      app_user_id,
      provider_key,
      issuer,
      external_subject,
      status
    )
    values (
      app_user_id,
      'supabase',
      coalesce(
        nullif((select auth.jwt() ->> 'iss'), ''),
        'supabase'
      ),
      auth_user_id::text,
      'active'
    );
  elsif app_user_status <> 'active' then
    raise exception using
      errcode = 'P0001',
      message = 'app_user_disabled';
  end if;

  select membership.id, membership.status
  into membership_id, membership_status
  from public.organization_memberships as membership
  where membership.organization_id = invitation.organization_id
    and membership.app_user_id = app_user_id
  for update;

  if membership_id is null then
    if exists (
      select 1
      from public.organization_memberships as membership
      where membership.app_user_id = app_user_id
        and membership.status in ('onboarding', 'active')
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
      invitation.organization_id,
      app_user_id,
      'active'
    )
    returning id into membership_id;
  elsif membership_status = 'disabled' then
    update public.organization_memberships
    set status = 'active',
        updated_at = now()
    where id = membership_id;
  end if;

  if exists (
    select 1
    from public.membership_roles as membership_role
    where membership_role.membership_id = membership_id
      and membership_role.organization_id = invitation.organization_id
      and membership_role.role = invitation.role
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
    invitation.organization_id,
    membership_id,
    invitation.role
  );

  update public.organization_invitations
  set status = 'accepted',
      accepted_by_app_user_id = app_user_id,
      accepted_at = now(),
      updated_at = now()
  where id = invitation.id;

  return jsonb_build_object(
    'invitation_id', invitation.id,
    'organization_id', invitation.organization_id,
    'membership_id', membership_id,
    'app_user_id', app_user_id,
    'role', invitation.role,
    'status', 'accepted'
  );
end
$function$;

revoke all on function private.can_manage_organization_v2(uuid) from public;
revoke all on function private.current_membership_for_organization_v2(uuid) from public;
revoke all on function private.can_manage_case_types_v2(uuid) from public;

revoke all on function public.create_organization_invitation(uuid, text, text)
  from public;
revoke all on function public.list_organization_members(uuid)
  from public;
revoke all on function public.list_organization_invitations(uuid)
  from public;
revoke all on function public.approve_organization_invitation(uuid)
  from public;
revoke all on function public.revoke_organization_invitation(uuid)
  from public;
revoke all on function public.accept_organization_invitation(text, text)
  from public;

grant execute on function public.create_organization_invitation(uuid, text, text)
  to authenticated;
grant execute on function public.list_organization_members(uuid)
  to authenticated;
grant execute on function public.list_organization_invitations(uuid)
  to authenticated;
grant execute on function public.approve_organization_invitation(uuid)
  to authenticated;
grant execute on function public.revoke_organization_invitation(uuid)
  to authenticated;
grant execute on function public.accept_organization_invitation(text, text)
  to authenticated;

alter table public.organization_invitations enable row level security;
revoke all on table public.organization_invitations from anon, authenticated;
