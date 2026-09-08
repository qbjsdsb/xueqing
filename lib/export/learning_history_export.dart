import 'dart:typed_data';

import 'package:excel/excel.dart';

class LearningHistoryRecord {
  const LearningHistoryRecord({
    required this.occurredAt,
    required this.studentName,
    required this.subjectName,
    required this.caseTitle,
    required this.recordType,
    required this.content,
    required this.teacherName,
    required this.currentStatus,
    this.assessmentResult,
    this.nextStep,
    this.attachmentSummary,
    this.actorMembershipId,
  });

  final DateTime occurredAt;
  final String studentName;
  final String subjectName;
  final String caseTitle;
  final String recordType;
  final String content;
  final String? assessmentResult;
  final String? nextStep;
  final String teacherName;
  final String? attachmentSummary;
  final String currentStatus;
  final String? actorMembershipId;
}

class LearningHistoryExportData {
  const LearningHistoryExportData({
    required this.title,
    required this.suggestedFileName,
    required this.records,
  });

  final String title;
  final String suggestedFileName;
  final List<LearningHistoryRecord> records;
}

class LearningHistoryWorkbookBuilder {
  const LearningHistoryWorkbookBuilder();

  static const List<String> headers = <String>[
    '发生时间',
    '学员',
    '学科',
    '跟进问题',
    '记录类型',
    '具体内容',
    '检查结果',
    '下一步/提醒',
    '记录老师',
    '附件',
    '当前状态',
  ];

  Uint8List build(LearningHistoryExportData data) {
    final excel = Excel.createExcel();
    final sheet = excel['全部记录'];
    excel.setDefaultSheet('全部记录');
    if (excel.tables.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }

    final headerStyle = CellStyle(
      bold: true,
      verticalAlign: VerticalAlign.Center,
      textWrapping: TextWrapping.WrapText,
    );
    final bodyStyle = CellStyle(
      verticalAlign: VerticalAlign.Top,
      textWrapping: TextWrapping.WrapText,
    );

    sheet.appendRow(<CellValue?>[
      for (final header in headers) TextCellValue(header),
    ]);
    for (var column = 0; column < headers.length; column++) {
      sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: column, rowIndex: 0),
      ).cellStyle = headerStyle;
    }

    final records = data.records.toList(growable: false)
      ..sort((left, right) => left.occurredAt.compareTo(right.occurredAt));
    if (records.isEmpty) {
      sheet.appendRow(<CellValue?>[
        const TextCellValue('当前筛选范围内还没有可导出的记录。'),
      ]);
    } else {
      for (final record in records) {
        sheet.appendRow(<CellValue?>[
          TextCellValue(_formatDateTime(record.occurredAt)),
          TextCellValue(record.studentName),
          TextCellValue(record.subjectName),
          TextCellValue(record.caseTitle),
          TextCellValue(record.recordType),
          TextCellValue(record.content),
          TextCellValue(record.assessmentResult ?? ''),
          TextCellValue(record.nextStep ?? ''),
          TextCellValue(record.teacherName),
          TextCellValue(record.attachmentSummary ?? ''),
          TextCellValue(record.currentStatus),
        ]);
      }
    }

    for (var row = 1; row < sheet.maxRows; row++) {
      for (var column = 0; column < headers.length; column++) {
        sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: column, rowIndex: row),
        ).cellStyle = bodyStyle;
      }
    }

    const widths = <double>[
      19,
      12,
      12,
      24,
      16,
      46,
      14,
      30,
      14,
      28,
      14,
    ];
    for (var column = 0; column < widths.length; column++) {
      sheet.setColumnWidth(column, widths[column]);
    }
    sheet.setRowHeight(0, 24);

    final bytes = excel.save();
    if (bytes == null || bytes.isEmpty) {
      throw StateError('Excel 文件生成失败。');
    }
    return Uint8List.fromList(bytes);
  }
}

String sanitizeLearningHistoryFileName(String value) {
  final normalized = value
      .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
      .replaceAll(RegExp(r'\s+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
  return normalized.isEmpty ? '学情记录' : normalized;
}

String _formatDateTime(DateTime value) {
  final year = value.year.toString().padLeft(4, '0');
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$year-$month-$day $hour:$minute';
}
