begin;

select plan(4);

select is(
  (select name from public.subjects where code = 'chinese' and status = 'active'),
  '语文',
  'Chinese is available in the active global subject catalog'
);

select is(
  (select count(*)::integer from public.subjects where code in (
    'chinese',
    'physics',
    'chemistry',
    'biology',
    'history',
    'geography',
    'civics',
    'science',
    'information_technology'
  ) and status = 'active'),
  9,
  'all common K-12 catalog additions are active'
);

select is(
  (select count(*)::integer from public.subjects where code = 'chinese'),
  1,
  'standard subject codes stay unique'
);

select is(
  (select count(*)::integer from public.organization_subjects os
   join public.subjects s on s.id = os.subject_id
   where s.code = 'chinese'),
  0,
  'catalog expansion does not silently enable Chinese for every organization'
);

select * from finish();
rollback;
