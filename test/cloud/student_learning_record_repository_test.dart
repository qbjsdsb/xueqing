import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:xueqing/cloud/student_learning_record_repository.dart';

void main() {
  test('parses a provenance-aware student learning record row strictly', () {
    final record = StudentLearningRecord.fromJson(<String, dynamic>{
      'record_id': 'record-1',
      'occurred_at': '2026-09-09T10:30:00Z',
      'student_name': '示例学生',
      'subject_name': '语文',
      'issue_title': '阅读题漏看限制词',
      'record_kind': 'evidence',
      'content': '课堂观察：两次漏看限制词。',
      'assessment_result': null,
      'teacher_name': '王老师',
      'next_step': '下节课再检查一次',
      'attachment_count': 2,
      'current_status': 'confirmed',
    });

    expect(record.id, 'record-1');
    expect(record.teacherName, '王老师');
    expect(record.nextStep, '下节课再检查一次');
    expect(record.recordKind, 'evidence');
    expect(record.attachmentCount, 2);
    expect(record.occurredAt.toUtc(), DateTime.utc(2026, 9, 9, 10, 30));
  });

  test('rejects a row without its historical record person', () {
    expect(
      () => StudentLearningRecord.fromJson(<String, dynamic>{
        'record_id': 'record-1',
        'occurred_at': '2026-09-09T10:30:00Z',
        'student_name': '示例学生',
        'subject_name': '语文',
        'issue_title': '阅读题漏看限制词',
        'record_kind': 'evidence',
        'content': '课堂观察',
        'attachment_count': 0,
        'current_status': 'confirmed',
      }),
      throwsFormatException,
    );
  });

  test(
    'maps student export authorization and session errors to teacher copy',
    () {
      expect(
        studentLearningRecordExportErrorMessage(
          const PostgrestException(message: 'teaching_fact_gate'),
        ),
        '当前账号没有这个学生学科的记录导出权限。',
      );
      expect(
        studentLearningRecordExportErrorMessage(
          const AuthException('No active session.'),
        ),
        '登录状态已失效，请重新登录。',
      );
    },
  );
}
