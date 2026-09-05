-- Phase 0B.0-V: reject unambiguous duplicate student identities.
-- A name is never a unique key. A distinct student with the same name and
-- school context remains valid when the manager supplies a distinct code.
-- This is a fictional/development migration and does not merge existing data.

do $block$
begin
  if exists (
    select
      student.organization_id,
      lower(btrim(student.student_code))
    from public.students as student
    where nullif(btrim(student.student_code), '') is not null
    group by
      student.organization_id,
      lower(btrim(student.student_code))
    having count(*) > 1
  ) then
    raise exception using
      errcode = 'P0001',
      message = 'duplicate_student_codes_require_resolution';
  end if;
end
$block$;

create unique index students_organization_student_code_key
  on public.students (
    organization_id,
    lower(btrim(student_code))
  )
  where nullif(btrim(student_code), '') is not null;

create or replace function private.guard_student_code_uniqueness_v2()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
declare
  normalized_student_code text;
begin
  normalized_student_code := nullif(btrim(new.student_code), '');
  new.student_code := normalized_student_code;

  if normalized_student_code is not null
    and exists (
      select 1
      from public.students as existing_student
      where existing_student.organization_id = new.organization_id
        and existing_student.id <> new.id
        and lower(btrim(existing_student.student_code)) =
          lower(normalized_student_code)
    ) then
    raise exception using
      errcode = 'P0001',
      message = 'student_code_already_exists';
  end if;

  return new;
end
$function$;

create or replace function private.guard_possible_duplicate_student_v2()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
begin
  if exists (
    select 1
    from public.students as incoming_student
    where incoming_student.id = new.student_id
      and incoming_student.organization_id = new.organization_id
      and incoming_student.student_code is null
      and incoming_student.status <> 'merged'
      and exists (
        select 1
        from public.students as existing_student
        join public.student_enrollments as existing_enrollment
          on existing_enrollment.student_id = existing_student.id
         and existing_enrollment.organization_id =
           existing_student.organization_id
        where existing_student.organization_id = new.organization_id
          and existing_student.id <> incoming_student.id
          and existing_student.status <> 'merged'
          and lower(btrim(existing_student.name)) =
            lower(btrim(incoming_student.name))
          and lower(btrim(existing_enrollment.grade)) is not distinct from
            lower(btrim(new.grade))
          and lower(btrim(existing_enrollment.class_name)) is not distinct from
            lower(btrim(new.class_name))
          and lower(btrim(existing_enrollment.campus)) is not distinct from
            lower(btrim(new.campus))
      )
  ) then
    raise exception using
      errcode = 'P0001',
      message = 'possible_duplicate_student';
  end if;

  return new;
end
$function$;

drop trigger if exists guard_student_code_uniqueness_v2
  on public.students;
create trigger guard_student_code_uniqueness_v2
before insert or update of organization_id, student_code
on public.students
for each row
execute function private.guard_student_code_uniqueness_v2();

drop trigger if exists guard_possible_duplicate_student_v2
  on public.student_enrollments;
create trigger guard_possible_duplicate_student_v2
before insert or update of organization_id, student_id, grade, class_name, campus
on public.student_enrollments
for each row
execute function private.guard_possible_duplicate_student_v2();

revoke all on function private.guard_student_code_uniqueness_v2()
  from public, anon, authenticated;
revoke all on function private.guard_possible_duplicate_student_v2()
  from public, anon, authenticated;

comment on index public.students_organization_student_code_key is
  'A non-empty student code identifies at most one student per organization.';
comment on function private.guard_possible_duplicate_student_v2() is
  'Rejects an uncoded student matching an existing name and school context.';
