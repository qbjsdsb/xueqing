begin;

select plan(5);

select ok(
  position(
    'order by app_user.display_name, auth_user.email, membership.id;'
    in regexp_replace(
      lower(
        pg_get_functiondef(
          'public.list_organization_members(uuid)'::regprocedure
        )
      ),
      '\s+',
      ' ',
      'g'
    )
  ) > 0,
  'member paging order has a unique membership id tie-breaker'
);

select ok(
  position(
    'order by invitation.created_at desc, invitation.id desc;'
    in regexp_replace(
      lower(
        pg_get_functiondef(
          'public.list_organization_invitations(uuid)'::regprocedure
        )
      ),
      '\s+',
      ' ',
      'g'
    )
  ) > 0,
  'invitation paging order has a unique invitation id tie-breaker'
);

select ok(
  position(
    'order by student.name, student.id;'
    in regexp_replace(
      lower(
        pg_get_functiondef(
          'public.list_organization_students(uuid)'::regprocedure
        )
      ),
      '\s+',
      ' ',
      'g'
    )
  ) > 0,
  'student paging order has a unique student id tie-breaker'
);

select ok(
  position(
    'scope.active_from, scope.id;'
    in regexp_replace(
      lower(
        pg_get_functiondef(
          'public.list_organization_teacher_subject_scopes(uuid)'::regprocedure
        )
      ),
      '\s+',
      ' ',
      'g'
    )
  ) > 0,
  'teacher scope paging order has a unique scope id tie-breaker'
);

select ok(
  position(
    'assignment.active_from, assignment.id;'
    in regexp_replace(
      lower(
        pg_get_functiondef(
          'public.list_organization_student_teacher_assignments(uuid)'::regprocedure
        )
      ),
      '\s+',
      ' ',
      'g'
    )
  ) > 0,
  'teacher assignment paging order has a unique assignment id tie-breaker'
);

select * from finish();

rollback;
