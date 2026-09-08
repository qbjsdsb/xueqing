import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:file_saver/file_saver.dart';

import '../cloud/learning_repository.dart';

class LearningRecordExportRow {
  const LearningRecordExportRow({
    required this.occurredAt,
    required this.studentName,
    required this.subjectName,
    required this.issueTitle,
    required this.recordType,
    required this.content,
    required this.status,
    this.assessmentResult,
    this.nextStep,
    this.teacherName,
    this.attachmentNote,
  });

  final DateTime occurredAt;
  final String studentName;
  final String subjectName;
  final String issueTitle;
  final String recordType;
  final String content;
  final String? assessmentResult;
  final String? nextStep;
  final String? teacherName;
  final String? attachmentNote;
  final String status;
}

class LearningRecordExport {
  const LearningRecordExport._();

  static const List<String> headers = <String>[
    '发生时间',
    '学员',
    '学科',
    '跟进问题',
    '记录类型',
    '具体内容',
    '检查结果',
    '下一步 / 提醒',
    '记录老师',
    '附件',
    '当前状态',
  ];

  static List<LearningRecordExportRow> rowsForStudentSubject(
    WorkspaceStudent student,
  ) {
    final rows = <LearningRecordExportRow>[];
    for (final learningCase in student.cases) {
      final nextStep = learningCase.primaryAction?.title;
      for (final event in learningCase.timeline) {
        rows.add(
          LearningRecordExportRow(
            occurredAt: event.occurredAt,
            studentName: student.name,
            subjectName: student.subject,
            issueTitle: learningCase.title,
            recordType: event.typeLabel,
            content: event.text,
            nextStep: nextStep,
            status: learningCase.status.label,
          ),
        );
      }
    }
    rows.sort((left, right) => left.occurredAt.compareTo(right.occurredAt));
    return List<LearningRecordExportRow>.unmodifiable(rows);
  }

  static Uint8List buildWorkbook({
    required List<LearningRecordExportRow> rows,
    String sheetName = '全部记录',
  }) {
    final workbook = Excel.createExcel();
    final defaultSheet = workbook.getDefaultSheet();
    if (defaultSheet != null && defaultSheet != sheetName) {
      workbook.rename(defaultSheet, sheetName);
    }
    final sheet = workbook[sheetName];

    sheet.appendRow(
      headers.map<CellValue>((value) => TextCellValue(value)).toList(),
    );
    final headerStyle = CellStyle(
      bold: true,
      verticalAlign: VerticalAlign.Center,
      textWrapping: TextWrapping.WrapText,
    );
    for (var column = 0; column < headers.length; column++) {
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: column, rowIndex: 0))
          .cellStyle = headerStyle;
    }

    for (final row in rows) {
      sheet.appendRow(<CellValue?>[
        TextCellValue(_formatDateTime(row.occurredAt)),
        TextCellValue(row.studentName),
        TextCellValue(row.subjectName),
        TextCellValue(row.issueTitle),
        TextCellValue(row.recordType),
        TextCellValue(row.content),
        TextCellValue(row.assessmentResult ?? ''),
        TextCellValue(row.nextStep ?? ''),
        TextCellValue(row.teacherName ?? ''),
        TextCellValue(row.attachmentNote ?? ''),
        TextCellValue(row.status),
      ]);
    }

    const widths = <double>[
      20,
      14,
      12,
      28,
      16,
      48,
      14,
      28,
      14,
      18,
      14,
    ];
    for (var column = 0; column < widths.length; column++) {
      sheet.setColumnWidth(column, widths[column]);
    }

    for (var rowIndex = 1; rowIndex < sheet.maxRows; rowIndex++) {
      for (var column = 0; column < headers.length; column++) {
        final cell = sheet.cell(
          CellIndex.indexByColumnRow(
            columnIndex: column,
            rowIndex: rowIndex,
          ),
        );
        cell.cellStyle = (cell.cellStyle ?? CellStyle()).copyWith(
          verticalAlignVal: VerticalAlign.Top,
          textWrappingVal: TextWrapping.WrapText,
        );
      }
    }

    final bytes = workbook.encode();
    if (bytes == null || bytes.isEmpty) {
      throw StateError('学情记录表生成失败。');
    }
    return Uint8List.fromList(bytes);
  }

  static Future<String?> saveAsXlsx({
    required String fileNameWithoutExtension,
    required List<LearningRecordExportRow> rows,
  }) async {
    final bytes = buildWorkbook(rows: rows);
    return FileSaver.instance.saveAs(
      name: sanitizeFileName(fileNameWithoutExtension),
      bytes: bytes,
      fileExtension: 'xlsx',
      mimeType: MimeType.microsoftExcel,
    );
  }

  static String studentSubjectFileName(
    WorkspaceStudent student, {
    DateTime? exportedAt,
  }) {
    final now = exportedAt ?? DateTime.now();
    return sanitizeFileName(
      '${student.name}_${student.subject}_学情记录_${_formatDate(now)}',
    );
  }

  static String teacherFileName(
    String teacherName, {
    DateTime? exportedAt,
  }) {
    final now = exportedAt ?? DateTime.now();
    return sanitizeFileName('${teacherName}_教学记录_${_formatDate(now)}');
  }

  static String sanitizeFileName(String value) {
    final normalized = value
        .trim()
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ');
    return normalized.isEmpty ? '学情记录' : normalized;
  }

  static String _formatDateTime(DateTime value) {
    final local = value.toLocal();
    return '${_formatDate(local)} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  static String _formatDate(DateTime value) {
    return '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
  }
}
