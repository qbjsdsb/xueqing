import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:xueqing/cloud/teacher_learning_record_repository.dart';

void main() {
  test('parses a teacher learning record row strictly', () {
    final record = TeacherLearningRecord.fromJson(<String, dynamic>{
      'record_id': 'record-1',
      'occurred_at': '2026-09-08T10:30:00Z',
      'student_name': '示例学生',
      'subject_name': '语文',
      'issue_title': '阅读题漏看限制词',
      'record_kind': 'evidence',
      'content': '课堂观察：两次漏看限制词。',
      'assessment_result': null,
      'attachment_count': 2,
      'attachment_paths': <String>['org/demo/a.jpg'],
      'current_status': 'confirmed',
    });

    expect(record.id, 'record-1');
    expect(record.recordKind, 'evidence');
    expect(record.attachmentCount, 2);
    expect(record.attachmentPaths, <String>['org/demo/a.jpg']);
    expect(record.occurredAt.toUtc(), DateTime.utc(2026, 9, 8, 10, 30));
  });

  test('rejects malformed export rows instead of returning partial facts', () {
    expect(
      () => TeacherLearningRecord.fromJson(<String, dynamic>{
        'record_id': 'record-1',
        'occurred_at': 'not-a-date',
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

  test('maps export authorization and session errors to teacher copy', () {
    expect(
      teacherLearningRecordExportErrorMessage(
        const PostgrestException(message: 'organization_manager_required'),
      ),
      '当前账号没有本机构的老师记录导出权限。',
    );
    expect(
      teacherLearningRecordExportErrorMessage(
        const AuthException('No active session.'),
      ),
      '登录状态已失效，请重新登录。',
    );
  });
}
