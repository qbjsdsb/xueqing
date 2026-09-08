import 'package:flutter_test/flutter_test.dart';
import 'package:xueqing/cloud/teacher_learning_record_repository.dart';
import 'package:xueqing/export/learning_record_export.dart';

void main() {
  test('maps provenance-aware teacher facts to readable export rows', () {
    final records = <TeacherLearningRecord>[
      TeacherLearningRecord(
        id: 'case-1',
        occurredAt: DateTime.utc(2026, 9, 1, 10),
        studentName: '示例学生',
        subjectName: '语文',
        issueTitle: '概括题漏点',
        recordKind: 'case_created',
        content: '课堂发现概括不完整。\n学生表现：只答出一个方面。',
        attachmentCount: 1,
        currentStatus: 'pending_verification',
      ),
      TeacherLearningRecord(
        id: 'intervention-1',
        occurredAt: DateTime.utc(2026, 9, 2, 10),
        studentName: '示例学生',
        subjectName: '语文',
        issueTitle: '概括题漏点',
        recordKind: 'intervention',
        content: '带着学生重新圈关键词。',
        attachmentCount: 0,
        currentStatus: 'pending_verification',
      ),
      TeacherLearningRecord(
        id: 'assessment-1',
        occurredAt: DateTime.utc(2026, 9, 3, 10),
        studentName: '示例学生',
        subjectName: '语文',
        issueTitle: '概括题漏点',
        recordKind: 'assessment',
        content: '能答出两个方面。',
        assessmentResult: 'partial',
        attachmentCount: 0,
        currentStatus: 'closed',
      ),
    ];

    final rows = LearningRecordExport.rowsForTeacherRecords(
      records,
      teacherName: '王老师',
    );

    expect(rows, hasLength(3));
    expect(rows.map((row) => row.recordType), <String>[
      '发现问题',
      '教学处理',
      '检查结果',
    ]);
    expect(rows.first.teacherName, '王老师');
    expect(rows.first.attachmentNote, '1 个附件');
    expect(rows.first.status, '待验证');
    expect(rows.last.assessmentResult, '部分改善');
    expect(rows.last.status, '已结束');
    expect(rows.every((row) => row.nextStep == null), isTrue);
  });
}
