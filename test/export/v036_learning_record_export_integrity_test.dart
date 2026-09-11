import 'package:excel_community/excel_community.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xueqing/cloud/student_learning_record_repository.dart';
import 'package:xueqing/export/learning_record_export.dart';

void main() {
  test('does not erase meaningful punctuation while deduplicating details', () {
    final rows = LearningRecordExport.rowsForStudentRecords(
      <StudentLearningRecord>[
        StudentLearningRecord(
          id: 'evidence-1',
          learningCaseId: 'case-1',
          occurredAt: DateTime.utc(2026, 9, 11, 10),
          studentName: '示例学生',
          subjectName: '数学',
          issueTitle: '第 3-1 题错误',
          recordKind: 'evidence',
          content: '第 31 题错误',
          teacherName: '王老师',
          attachmentCount: 0,
          currentStatus: 'confirmed',
        ),
      ],
    );

    expect(rows.single.content, '第 31 题错误');
  });

  test('shows the current next action only on the latest row of each case', () {
    final rows = LearningRecordExport.rowsForStudentRecords(
      <StudentLearningRecord>[
        StudentLearningRecord(
          id: 'created-1',
          learningCaseId: 'case-1',
          occurredAt: DateTime.utc(2026, 9, 10, 10),
          studentName: '示例学生',
          subjectName: '语文',
          issueTitle: '阅读题漏看限制词',
          recordKind: 'case_created',
          content: '两次漏看限制词。',
          teacherName: '王老师',
          nextStep: '下周再检查一次',
          attachmentCount: 0,
          currentStatus: 'confirmed',
        ),
        StudentLearningRecord(
          id: 'evidence-2',
          learningCaseId: 'case-1',
          occurredAt: DateTime.utc(2026, 9, 11, 10),
          studentName: '示例学生',
          subjectName: '语文',
          issueTitle: '阅读题漏看限制词',
          recordKind: 'evidence',
          content: '今天已经会主动圈限制词。',
          teacherName: '王老师',
          nextStep: '下周再检查一次',
          attachmentCount: 0,
          currentStatus: 'confirmed',
        ),
      ],
    );

    expect(rows.first.nextStep, isNull);
    expect(rows.last.nextStep, '下周再检查一次');
  });

  test('writes a typed Excel datetime and freezes the header row', () {
    final bytes = LearningRecordExport.buildWorkbook(
      rows: <LearningRecordExportRow>[
        LearningRecordExportRow(
          occurredAt: DateTime(2026, 9, 11, 18, 30),
          studentName: '示例学生',
          subjectName: '语文',
          issueTitle: '阅读题漏看限制词',
          recordType: '学生表现',
          content: '今天会主动圈限制词。',
          status: '跟进中',
        ),
      ],
    );

    final workbook = Excel.decodeBytes(bytes);
    final sheet = workbook.tables['全部记录'];
    expect(sheet, isNotNull);
    expect(sheet!.frozenRows, 1);
    expect(sheet.rows[0][7]?.value.toString(), '当前下一步 / 提醒');
    expect(sheet.rows[1][0]?.value, isA<DateTimeCellValue>());
  });
}
