import 'package:flutter_test/flutter_test.dart';
import 'package:xueqing/cloud/student_learning_record_repository.dart';
import 'package:xueqing/export/learning_record_export.dart';

void main() {
  test('maps student facts with their real record person and next reminder', () {
    final rows = LearningRecordExport.rowsForStudentRecords(<StudentLearningRecord>[
      StudentLearningRecord(
        id: 'assessment-1',
        occurredAt: DateTime.utc(2026, 9, 9, 11),
        studentName: '示例学生',
        subjectName: '语文',
        issueTitle: '阅读题漏看限制词',
        recordKind: 'assessment',
        content: '能够主动圈出限制词。',
        assessmentResult: 'partial',
        teacherName: '王老师',
        nextStep: '下节课再检查一次',
        attachmentCount: 0,
        currentStatus: 'pending_verification',
      ),
      StudentLearningRecord(
        id: 'evidence-1',
        occurredAt: DateTime.utc(2026, 9, 8, 10),
        studentName: '示例学生',
        subjectName: '语文',
        issueTitle: '阅读题漏看限制词',
        recordKind: 'evidence',
        content: '课堂观察：两次漏看限制词。',
        teacherName: '李老师',
        attachmentCount: 2,
        currentStatus: 'pending_verification',
      ),
    ]);

    expect(rows, hasLength(2));
    expect(rows.first.recordType, '学生表现');
    expect(rows.first.teacherName, '李老师');
    expect(rows.first.attachmentNote, '2 个附件');
    expect(rows.last.recordType, '检查结果');
    expect(rows.last.teacherName, '王老师');
    expect(rows.last.assessmentResult, '部分改善');
    expect(rows.last.nextStep, '下节课再检查一次');
    expect(rows.last.status, '继续关注');
  });
}
