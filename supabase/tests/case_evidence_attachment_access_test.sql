begin;

select plan(17);

select is(
  (
    select count(*)::int
    from information_schema.tables
    where table_schema = 'public'
      and table_name = 'case_evidence_attachments'
  ),
  1,
  'Evidence attachment metadata table exists'
);

select is(
  (
    select count(*)::int
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'case_evidence_attachments'
      and column_name = 'storage_path'
      and data_type = 'text'
  ),
  1,
  'attachment metadata stores a private path rather than image bytes'
);

select is(
  (
    select public
    from storage.buckets
    where id = 'case-evidence-private'
  ),
  false,
  'Evidence bucket is private'
);

select is(
  (
    select file_size_limit::bigint
    from storage.buckets
    where id = 'case-evidence-private'
  ),
  10485760::bigint,
  'Evidence bucket enforces the 10 MB object limit'
);

select is(
  (
    select allowed_mime_types::text
    from storage.buckets
    where id = 'case-evidence-private'
  ),
  '{image/jpeg,image/png,image/webp}'::text,
  'Evidence bucket only accepts supported image types'
);

select is(
  has_table_privilege(
    'anon',
    'public.case_evidence_attachments',
    'select'
  ),
  false,
  'anonymous users cannot read attachment metadata'
);

select is(
  has_table_privilege(
    'authenticated',
    'public.case_evidence_attachments',
    'select'
  ),
  true,
  'authenticated users receive only policy-filtered attachment metadata'
);

select is(
  has_table_privilege(
    'authenticated',
    'public.case_evidence_attachments',
    'insert'
  ),
  false,
  'clients cannot bypass the metadata RPC with a direct insert'
);

select is(
  has_function_privilege(
    'anon',
    'public.create_case_evidence_attachment(uuid,uuid,uuid,uuid,text,text,text,bigint)',
    'execute'
  ),
  false,
  'anonymous users cannot register attachments'
);

select is(
  has_function_privilege(
    'authenticated',
    'public.create_case_evidence_attachment(uuid,uuid,uuid,uuid,text,text,text,bigint)',
    'execute'
  ),
  true,
  'authenticated users can use the controlled attachment RPC'
);

select is(
  (
    select count(*)::int
    from pg_policies
    where schemaname = 'public'
      and tablename = 'case_evidence_attachments'
      and policyname = 'teachers can read case evidence attachments'
  ),
  1,
  'attachment metadata has an explicit teacher read policy'
);

select is(
  (
    select count(*)::int
    from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname = 'teachers can upload case evidence attachments'
  ),
  1,
  'Storage upload is limited to assigned teachers and canonical Evidence paths'
);

select is(
  has_function_privilege(
    'authenticated',
    'private.can_write_case_evidence_attachment_v2(uuid)',
    'execute'
  ),
  true,
  'authenticated users can evaluate the granted Storage write wrapper'
);

select is(
  position(
    'can_write_case_evidence_attachment_v2' in
      coalesce(
        (
          select with_check
          from pg_policies
          where schemaname = 'storage'
            and tablename = 'objects'
            and policyname = 'teachers can upload case evidence attachments'
        ),
        ''
      )
  ) > 0,
  true,
  'Storage upload policy calls the granted write wrapper'
);

select is(
  position(
    'current_teaching_membership_for_profile_v2' in
      coalesce(
        (
          select with_check
          from pg_policies
          where schemaname = 'storage'
            and tablename = 'objects'
            and policyname = 'teachers can upload case evidence attachments'
        ),
        ''
      )
  ),
  0,
  'Storage upload policy does not call the ungranted internal helper'
);

select is(
  (
    select count(*)::int
    from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname = 'teachers can read case evidence attachment objects'
  ),
  1,
  'Storage reads require a signed-url-eligible teacher read boundary'
);

select is(
  (
    select count(*)::int
    from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname = 'teachers can clean unregistered case evidence objects'
  ),
  1,
  'cleanup can remove only unregistered failed-upload objects'
);

select * from finish();

rollback;
