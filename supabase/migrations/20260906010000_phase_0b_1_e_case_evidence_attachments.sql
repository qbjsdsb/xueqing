-- Phase 0B.1-E: private Evidence attachments.
--
-- This migration is intentionally limited to fictional development data. It
-- adds the storage/metadata boundary needed by the teacher workspace without
-- turning Evidence into a mutable photo library. The parent case_evidence row
-- remains append-only; an attachment can only be added to an existing,
-- finalized Evidence row by the teacher who currently has legal access to the
-- Case.

create table public.case_evidence_attachments (
  id uuid primary key,
  organization_id uuid not null
    references public.organizations(id) on delete restrict,
  learning_case_id uuid not null,
  case_evidence_id uuid not null,
  storage_bucket text not null default 'case-evidence-private'
    check (storage_bucket = 'case-evidence-private'),
  storage_path text not null,
  original_file_name text not null
    check (
      char_length(btrim(original_file_name)) > 0
      and char_length(original_file_name) <= 255
      and position('/' in original_file_name) = 0
      and position(chr(92) in original_file_name) = 0
    ),
  content_type text not null
    check (content_type in ('image/jpeg', 'image/png', 'image/webp')),
  size_bytes bigint not null
    check (size_bytes > 0 and size_bytes <= 10485760),
  created_by_app_user_id uuid not null
    references public.app_users(id) on delete restrict,
  created_by_membership_id uuid not null,
  created_at timestamptz not null default timezone('utc', now()),
  constraint case_evidence_attachments_case_fk
    foreign key (learning_case_id, organization_id)
    references public.learning_cases(id, organization_id)
    on delete restrict,
  constraint case_evidence_attachments_evidence_fk
    foreign key (case_evidence_id, organization_id)
    references public.case_evidence(id, organization_id)
    on delete restrict,
  constraint case_evidence_attachments_creator_membership_fk
    foreign key (created_by_membership_id, organization_id)
    references public.organization_memberships(id, organization_id)
    on delete restrict,
  constraint case_evidence_attachments_storage_path_key
    unique (storage_bucket, storage_path),
  constraint case_evidence_attachments_id_organization_key
    unique (id, organization_id)
);

create index case_evidence_attachments_evidence_created_idx
  on public.case_evidence_attachments (case_evidence_id, created_at, id);

comment on table public.case_evidence_attachments is
  'Private image metadata for immutable Case Evidence; object bytes live in private Storage.';
comment on column public.case_evidence_attachments.storage_path is
  'Opaque private path: org/{organization}/cases/{case}/evidence/{evidence}/{attachment}.{ext}.';

alter table public.case_evidence_attachments enable row level security;

revoke all on table public.case_evidence_attachments from anon, authenticated;
grant select on table public.case_evidence_attachments to authenticated;

create or replace function private.can_write_case_evidence_attachment_v2(
  target_evidence_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $function$
  select exists (
    select 1
    from public.case_evidence as evidence
    join public.learning_cases as learning_case
      on learning_case.id = evidence.learning_case_id
     and learning_case.organization_id = evidence.organization_id
    join public.student_subject_profiles as profile
      on profile.id = learning_case.student_subject_profile_id
     and profile.organization_id = learning_case.organization_id
    where evidence.id = target_evidence_id
      and evidence.status = 'finalized'
      and learning_case.status <> 'closed'
      and (select private.current_teaching_membership_for_profile_v2(profile.id))
        is not null
  )
$function$;

revoke all on function private.can_write_case_evidence_attachment_v2(uuid)
  from public, anon;
grant execute on function private.can_write_case_evidence_attachment_v2(uuid)
  to authenticated;

create policy "teachers can read case evidence attachments"
on public.case_evidence_attachments
for select
to authenticated
using (
  (select private.can_read_case_core_v2(case_evidence_attachments.learning_case_id))
);

insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
values (
  'case-evidence-private',
  'case-evidence-private',
  false,
  10485760,
  array['image/jpeg', 'image/png', 'image/webp']::text[]
)
on conflict (id) do update
set name = excluded.name,
    public = false,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

-- The path itself is not an authorization boundary. Every Storage policy
-- joins it back to the canonical Evidence/Case rows and checks the current
-- teacher assignment. The text comparisons avoid casting attacker-controlled
-- path segments before the row has been found.
drop policy if exists "teachers can upload case evidence attachments"
  on storage.objects;
create policy "teachers can upload case evidence attachments"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'case-evidence-private'
  and (storage.foldername(name))[1] = 'org'
  and (storage.foldername(name))[3] = 'cases'
  and (storage.foldername(name))[5] = 'evidence'
  and (storage.foldername(name))[7] ~
    E'^[0-9a-fA-F-]{36}\\.(jpg|png|webp)$'
  and exists (
    select 1
    from public.case_evidence as evidence
    join public.learning_cases as learning_case
      on learning_case.id = evidence.learning_case_id
     and learning_case.organization_id = evidence.organization_id
    join public.student_subject_profiles as profile
      on profile.id = learning_case.student_subject_profile_id
     and profile.organization_id = learning_case.organization_id
    where evidence.id::text = (storage.foldername(name))[6]
      and learning_case.id::text = (storage.foldername(name))[4]
      and evidence.organization_id::text = (storage.foldername(name))[2]
      and evidence.status = 'finalized'
      and learning_case.status <> 'closed'
      and (select private.current_teaching_membership_for_profile_v2(profile.id))
        is not null
  )
);

drop policy if exists "teachers can read case evidence attachment objects"
  on storage.objects;
create policy "teachers can read case evidence attachment objects"
on storage.objects
for select
to authenticated
using (
  bucket_id = 'case-evidence-private'
  and exists (
    select 1
    from public.case_evidence_attachments as attachment
    join public.case_evidence as evidence
      on evidence.id = attachment.case_evidence_id
     and evidence.organization_id = attachment.organization_id
    where attachment.storage_bucket = storage.objects.bucket_id
      and attachment.storage_path = storage.objects.name
      and (select private.can_read_case_core_v2(evidence.learning_case_id))
  )
);

-- Upload is intentionally two-phase: the client uploads first and then calls
-- the metadata RPC. If the RPC rejects the object, it may remove the object
-- only while no committed metadata row exists. Committed Evidence remains
-- append-only and cannot be deleted by the client.
drop policy if exists "teachers can clean unregistered case evidence objects"
  on storage.objects;
create policy "teachers can clean unregistered case evidence objects"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'case-evidence-private'
  and not exists (
    select 1
    from public.case_evidence_attachments as attachment
    where attachment.storage_bucket = storage.objects.bucket_id
      and attachment.storage_path = storage.objects.name
  )
  and exists (
    select 1
    from public.case_evidence as evidence
    join public.learning_cases as learning_case
      on learning_case.id = evidence.learning_case_id
     and learning_case.organization_id = evidence.organization_id
    join public.student_subject_profiles as profile
      on profile.id = learning_case.student_subject_profile_id
     and profile.organization_id = learning_case.organization_id
    where evidence.id::text = (storage.foldername(name))[6]
      and learning_case.id::text = (storage.foldername(name))[4]
      and evidence.organization_id::text = (storage.foldername(name))[2]
      and (select private.can_write_case_evidence_attachment_v2(evidence.id))
  )
);

create or replace function public.create_case_evidence_attachment(
  p_organization_id uuid,
  p_learning_case_id uuid,
  p_case_evidence_id uuid,
  p_attachment_id uuid,
  p_storage_path text,
  p_original_file_name text,
  p_content_type text,
  p_size_bytes bigint
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $function$
declare
  current_app_user_id uuid;
  current_membership_id uuid;
  profile_id uuid;
  evidence_status text;
  case_status text;
  existing_attachment public.case_evidence_attachments%rowtype;
  expected_extension text;
  object_exists boolean;
  object_mime text;
  object_size bigint;
begin
  current_app_user_id := (select private.current_app_user_id_v2());
  if current_app_user_id is null then
    raise exception using
      errcode = 'P0001',
      message = 'invalid_live_session';
  end if;

  if p_organization_id is null
    or p_learning_case_id is null
    or p_case_evidence_id is null
    or p_attachment_id is null
    or p_storage_path is null
    or p_original_file_name is null
    or p_content_type is null
    or p_size_bytes is null then
    raise exception using
      errcode = 'P0001',
      message = 'invalid_attachment_input';
  end if;

  if p_content_type not in ('image/jpeg', 'image/png', 'image/webp')
    or p_size_bytes <= 0
    or p_size_bytes > 10485760
    or char_length(btrim(p_original_file_name)) = 0
    or char_length(p_original_file_name) > 255
    or position('/' in p_original_file_name) > 0
    or position(chr(92) in p_original_file_name) > 0 then
    raise exception using
      errcode = 'P0001',
      message = 'invalid_attachment_input';
  end if;

  expected_extension := case p_content_type
    when 'image/jpeg' then 'jpg'
    when 'image/png' then 'png'
    when 'image/webp' then 'webp'
  end;

  if p_storage_path <> format(
    'org/%s/cases/%s/evidence/%s/%s.%s',
    p_organization_id,
    p_learning_case_id,
    p_case_evidence_id,
    p_attachment_id,
    expected_extension
  ) then
    raise exception using
      errcode = 'P0001',
      message = 'invalid_attachment_storage_path';
  end if;

  select
    evidence.status,
    learning_case.status,
    learning_case.student_subject_profile_id
  into
    evidence_status,
    case_status,
    profile_id
  from public.case_evidence as evidence
  join public.learning_cases as learning_case
    on learning_case.id = evidence.learning_case_id
   and learning_case.organization_id = evidence.organization_id
  where evidence.id = p_case_evidence_id
    and evidence.organization_id = p_organization_id
    and evidence.learning_case_id = p_learning_case_id;

  if not found then
    raise exception using
      errcode = 'P0001',
      message = 'attachment_target_not_found';
  end if;

  if evidence_status <> 'finalized' or case_status = 'closed' then
    raise exception using
      errcode = 'P0001',
      message = 'attachment_target_not_writable';
  end if;

  current_membership_id := (
    select private.current_teaching_membership_for_profile_v2(profile_id)
  );
  if current_membership_id is null then
    raise exception using
      errcode = 'P0001',
      message = 'attachment_target_not_writable';
  end if;

  select exists (
    select 1
    from storage.objects as object
    where object.bucket_id = 'case-evidence-private'
      and object.name = p_storage_path
  )
  into object_exists;
  if not object_exists then
    raise exception using
      errcode = 'P0001',
      message = 'attachment_object_not_found';
  end if;

  select
    lower(nullif(object.metadata ->> 'mimetype', '')),
    case
      when (object.metadata ->> 'size') ~ '^[0-9]+$'
        then (object.metadata ->> 'size')::bigint
      else null
    end
  into object_mime, object_size
  from storage.objects as object
  where object.bucket_id = 'case-evidence-private'
    and object.name = p_storage_path;

  if object_mime is not null and object_mime <> p_content_type then
    raise exception using
      errcode = 'P0001',
      message = 'attachment_content_type_mismatch';
  end if;
  if object_size is not null and object_size <> p_size_bytes then
    raise exception using
      errcode = 'P0001',
      message = 'attachment_size_mismatch';
  end if;

  select *
  into existing_attachment
  from public.case_evidence_attachments as attachment
  where attachment.id = p_attachment_id;

  if found then
    if existing_attachment.organization_id <> p_organization_id
      or existing_attachment.learning_case_id <> p_learning_case_id
      or existing_attachment.case_evidence_id <> p_case_evidence_id
      or existing_attachment.storage_path <> p_storage_path then
      raise exception using
        errcode = 'P0001',
        message = 'attachment_id_reuse_conflict';
    end if;
    return jsonb_build_object(
      'id', existing_attachment.id,
      'organization_id', existing_attachment.organization_id,
      'learning_case_id', existing_attachment.learning_case_id,
      'case_evidence_id', existing_attachment.case_evidence_id,
      'storage_bucket', existing_attachment.storage_bucket,
      'storage_path', existing_attachment.storage_path,
      'original_file_name', existing_attachment.original_file_name,
      'content_type', existing_attachment.content_type,
      'size_bytes', existing_attachment.size_bytes,
      'created_at', existing_attachment.created_at,
      'idempotent_replay', true
    );
  end if;

  insert into public.case_evidence_attachments (
    id,
    organization_id,
    learning_case_id,
    case_evidence_id,
    storage_bucket,
    storage_path,
    original_file_name,
    content_type,
    size_bytes,
    created_by_app_user_id,
    created_by_membership_id
  )
  values (
    p_attachment_id,
    p_organization_id,
    p_learning_case_id,
    p_case_evidence_id,
    'case-evidence-private',
    p_storage_path,
    btrim(p_original_file_name),
    p_content_type,
    p_size_bytes,
    current_app_user_id,
    current_membership_id
  )
  returning * into existing_attachment;

  return jsonb_build_object(
    'id', existing_attachment.id,
    'organization_id', existing_attachment.organization_id,
    'learning_case_id', existing_attachment.learning_case_id,
    'case_evidence_id', existing_attachment.case_evidence_id,
    'storage_bucket', existing_attachment.storage_bucket,
    'storage_path', existing_attachment.storage_path,
    'original_file_name', existing_attachment.original_file_name,
    'content_type', existing_attachment.content_type,
    'size_bytes', existing_attachment.size_bytes,
    'created_at', existing_attachment.created_at,
    'idempotent_replay', false
  );
end
$function$;

revoke all on function public.create_case_evidence_attachment(
  uuid, uuid, uuid, uuid, text, text, text, bigint
) from public, anon;
grant execute on function public.create_case_evidence_attachment(
  uuid, uuid, uuid, uuid, text, text, text, bigint
) to authenticated;
