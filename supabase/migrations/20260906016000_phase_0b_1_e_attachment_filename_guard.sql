-- Phase 0B.1-E forward correction: validate the final Storage filename.
--
-- storage.foldername(name) returns only directory segments; it intentionally
-- excludes the final filename. The UUID and extension check therefore belongs
-- on storage.filename(name), while foldername(name) remains the source for
-- org/case/evidence directory segments.

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
  and storage.filename(name) ~
    E'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-4[0-9a-fA-F]{3}-[89aAbB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}\\.(jpg|png|webp)$'
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
