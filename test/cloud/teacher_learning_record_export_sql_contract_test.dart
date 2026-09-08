import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'teacher export stays manager-only, provenance-aware, and path-private',
    () {
      final sql = File(
        'supabase/migrations/20260908230000_teacher_learning_record_export.sql',
      ).readAsStringSync();

      expect(sql, contains('private.manager_membership_can_supervise_v2'));
      expect(
        sql,
        contains('learning_case.created_by_membership_id = p_membership_id'),
      );
      expect(
        sql,
        contains('evidence.created_by_membership_id = p_membership_id'),
      );
      expect(
        sql,
        contains('intervention.performed_by_membership_id = p_membership_id'),
      );
      expect(
        sql,
        contains('assessment.assessed_by_membership_id = p_membership_id'),
      );
      expect(
        sql,
        contains(
          "initial_event.metadata ->> 'evidence_id' = evidence.id::text",
        ),
      );
      expect(
        sql,
        contains(
          'grant execute on function public.list_teacher_learning_records',
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
