import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('teacher export removes voided cases before public pagination', () {
    final sql = File(
      'supabase/migrations/20260911200000_teacher_learning_record_export_integrity.sql',
    ).readAsStringSync();

    expect(
      sql,
      contains('private.list_teacher_learning_records_with_attachments'),
    );
    expect(sql, contains('private.list_teacher_learning_records('));
    expect(sql, contains("mapped_record_state is distinct from 'active'"));
    expect(sql, contains('v_active_seen < p_offset'));
    expect(sql, contains('v_emitted >= p_limit'));
    expect(sql, contains('v_source_offset + v_source_batch_count'));
    expect(sql, contains('evidence.learning_case_id'));
    expect(sql, contains('intervention.learning_case_id'));
    expect(sql, contains('assessment.learning_case_id'));
    expect(sql, contains('mapped_attachment_paths'));

    final recordStateCheck = sql.indexOf(
      "mapped_record_state is distinct from 'active'",
    );
    final requestedOffsetCheck = sql.indexOf('v_active_seen < p_offset');
    expect(recordStateCheck, greaterThanOrEqualTo(0));
    expect(requestedOffsetCheck, greaterThan(recordStateCheck));
  });
}
