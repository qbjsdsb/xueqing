import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('v0.3.6 keeps record validity independent from teaching lifecycle', () {
    final migration = File(
      'supabase/migrations/20260911183000_learning_case_record_organization.sql',
    ).readAsStringSync();

    expect(migration, contains("record_state text not null default 'active'"));
    expect(migration, contains("'case_voided'"));
    expect(migration, contains("'case_restored'"));
    expect(migration, contains('private.void_learning_case_v2'));
    expect(migration, contains('private.restore_learning_case_v2'));
    expect(migration, contains("closure_reason' = 'not_issue'"));
    expect(migration, contains("closure_note' = '教师删除/作废误建或重复问题'"));
    expect(migration, contains("record_state = 'active'"));
    expect(migration, isNot(contains('delete from public.case_evidence')));
    expect(migration, isNot(contains('delete from public.interventions')));
    expect(migration, isNot(contains('delete from public.assessments')));
  });

  test('selective export is Case-id based and local to one export', () {
    final picker = File('lib/export/learning_record_case_picker.dart')
        .readAsStringSync();
    final repository = File('lib/cloud/student_learning_record_repository.dart')
        .readAsStringSync();
    final loader = File('lib/features/design_v2/v2_workspace_loader.dart')
        .readAsStringSync();

    expect(picker, contains('选择要导出的学情'));
    expect(picker, contains('仅进行中'));
    expect(picker, contains('仅历史'));
    expect(picker, contains('不会结束、删除或修改任何学情'));
    expect(repository, contains('final String? learningCaseId;'));
    expect(
      repository,
      contains('list_student_subject_learning_records_v2_with_attachments'),
    );
    expect(loader, contains('selectedCaseIds.contains(record.learningCaseId)'));
    expect(loader, contains('showLearningRecordCasePicker('));
  });

  test('raw handshake failures are not exposed as the primary login message', () {
    final source = File(
      'lib/features/teacher_workspace/presentation/teacher_workspace_page.dart',
    ).readAsStringSync();
    expect(source, contains("rawDetail.contains('handshake')"));
    expect(source, contains('暂时无法连接服务器'));
    expect(source, contains('可以尝试切换网络'));
  });
}
