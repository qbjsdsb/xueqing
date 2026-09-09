import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'student export stays teaching-gated, provenance-aware, and path-private',
    () {
      final sql = File(
        'supabase/migrations/20260909063000_student_subject_learning_record_export.sql',
      ).readAsStringSync();

      expect(
        sql,
        contains(
          'private.current_teaching_membership_for_profile_v2(p_profile_id)',
        ),
      );
      expect(
        sql,
        contains('learning_case.student_subject_profile_id = p_profile_id'),
      );
      expect(
        sql,
        contains(
          'creator_membership.id = learning_case.created_by_membership_id',
        ),
      );
      expect(
        sql,
        contains('creator_membership.id = evidence.created_by_membership_id'),
      );
      expect(
        sql,
        contains(
          'creator_membership.id = intervention.performed_by_membership_id',
        ),
      );
      expect(
        sql,
        contains(
          'creator_membership.id = assessment.assessed_by_membership_id',
        ),
      );
      expect(sql, contains('teacher_name text'));
      expect(sql, contains('next_step text'));
      expect(sql, contains("action.status = 'pending'"));
      expect(sql, contains('action.is_primary'));
      expect(
        sql,
        contains(
          "initial_event.metadata ->> 'evidence_id' = evidence.id::text",
        ),
      );
      expect(sql, isNot(contains('creator_membership.status')));
      expect(
        sql,
        contains(
          'grant execute on function public.list_student_subject_learning_records',
        ),
      );

      final returnedColumns = sql.substring(
        sql.indexOf('returns table ('),
        sql.indexOf('language plpgsql'),
      );
      expect(returnedColumns, isNot(contains('storage_path')));
      expect(returnedColumns, isNot(contains('storage_bucket')));
    },
  );
}
