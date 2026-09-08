import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xueqing/export/learning_history_export.dart';

void main() {
  test('builds one readable sheet with stable columns and chronological rows', () {
    final data = LearningHistoryExportData(
      title: '示例学生 · 语文 · 学情记录',
      suggestedFileName: '示例学生_语文_学情记录',
      records: <LearningHistoryRecord>[
        LearningHistoryRecord(
          occurredAt: DateTime(2026, 9, 10, 18, 20),
          studentName: '示例学生',
          subjectName: '语文',
          caseTitle: '概括题漏点',
          recordType: '教学处理',
          content: '重新练习圈关键词和分层概括。',
          teacherName: '王老师',
          currentStatus: '跟进中',
        ),
        LearningHistoryRecord(
          occurredAt: DateTime(2026, 9, 8, 19, 40),
          studentName: '示例学生',
          subjectName: '语文',
          caseTitle: '概括题漏点',
          recordType: '发现问题',
          content: '经常只答一个方面。',
          teacherName: '王老师',
          currentStatus: '跟进中',
        ),
      ],
    );

    final bytes = const LearningHistoryWorkbookBuilder().build(data);
    expect(bytes.length, greaterThan(100));
    expect(bytes[0], 0x50);
    expect(bytes[1], 0x4b);

    final decoded = Excel.decodeBytes(bytes);
    expect(decoded.tables.keys, contains('全部记录'));
    final sheet = decoded.tables['全部记录']!;
    expect(sheet.maxColumns, LearningHistoryWorkbookBuilder.headers.length);
    expect(
      (sheet.cell(CellIndex.indexByString('A1')).value as TextCellValue).value,
      '发生时间',
    );
    expect(
      (sheet.cell(CellIndex.indexByString('E2')).value as TextCellValue).value,
      '发现问题',
    );
    expect(
      (sheet.cell(CellIndex.indexByString('E3')).value as TextCellValue).value,
      '教学处理',
    );
  });

  test('sanitizes file names for Android and Windows save dialogs', () {
    expect(
      sanitizeLearningHistoryFileName('张三 / 语文:*?  学情记录'),
      '张三_语文_学情记录',
    );
  });
}
