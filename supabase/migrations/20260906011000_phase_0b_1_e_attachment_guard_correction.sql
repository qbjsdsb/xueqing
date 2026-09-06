-- Correct the escaped-literal guards in the first attachment migration.
-- The original migration was already applied to the fictional development
-- project; keep this as a forward-only correction so the local migration
-- history and the remote schema remain reproducible.

alter table public.case_evidence_attachments
  drop constraint if exists case_evidence_attachments_original_file_name_check;

alter table public.case_evidence_attachments
  add constraint case_evidence_attachments_original_file_name_check
  check (
    char_length(btrim(original_file_name)) > 0
    and char_length(original_file_name) <= 255
    and position('/' in original_file_name) = 0
    and position(chr(92) in original_file_name) = 0
  );

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
