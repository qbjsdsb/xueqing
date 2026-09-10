import 'dart:io';
import 'dart:typed_data';

import 'package:excel_community/excel_community.dart';
import 'package:file_saver/file_saver.dart';
import 'package:path_provider/path_provider.dart';

import '../cloud/learning_repository.dart';
import '../cloud/student_learning_record_repository.dart';
import '../cloud/teacher_learning_record_repository.dart';

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
      final status = _statusLabel(learningCase.status);
      final initialEvidence = _initialQuickCaptureEvidence(learningCase);
      final description = learningCase.description?.trim();
      final initialContent = <String>[
        if (description != null && description.isNotEmpty) description,
        if (initialEvidence != null) '具体表现：${initialEvidence.summary}',
      ].join('\n');

      rows.add(
        LearningRecordExportRow(
          occurredAt: learningCase.firstObservedAt,
          studentName: student.name,
          subjectName: student.subject,
          issueTitle: learningCase.title,
          recordType: '发现问题',
          content: initialContent.isEmpty ? learningCase.title : initialContent,
          nextStep: nextStep,
          status: status,
        ),
      );

      for (final evidence in learningCase.evidence) {
        if (evidence.id == initialEvidence?.id) {
          continue;
        }
        rows.add(
          LearningRecordExportRow(
            occurredAt: evidence.observedAt,
            studentName: student.name,
            subjectName: student.subject,
            issueTitle: learningCase.title,
            recordType: '学生表现',
            content: '${evidence.title}：${evidence.summary}',
            nextStep: nextStep,
            status: status,
          ),
        );
      }

      for (final intervention in learningCase.interventions) {
        final notes = intervention.notes?.trim();
        rows.add(
          LearningRecordExportRow(
            occurredAt: intervention.occurredAt,
            studentName: student.name,
            subjectName: student.subject,
            issueTitle: learningCase.title,
            recordType: '教学处理',
            content: notes == null || notes.isEmpty
                ? intervention.strategy
                : '${intervention.strategy}\n$notes',
            nextStep: nextStep,
            status: status,
          ),
        );
      }

      for (final assessment in learningCase.assessments) {
        final result = _assessmentResultLabel(assessment.result);
        final notes = assessment.notes?.trim();
        rows.add(
          LearningRecordExportRow(
            occurredAt: assessment.assessedAt,
            studentName: student.name,
            subjectName: student.subject,
            issueTitle: learningCase.title,
            recordType: '检查结果',
            content: notes == null || notes.isEmpty
                ? assessment.evidenceSummary
                : '${assessment.evidenceSummary}\n$notes',
            assessmentResult: result,
            nextStep: nextStep,
            status: status,
          ),
        );
      }
    }

    rows.sort((left, right) => left.occurredAt.compareTo(right.occurredAt));
    return List<LearningRecordExportRow>.unmodifiable(rows);
  }

  static List<LearningRecordExportRow> rowsForStudentRecords(
    List<StudentLearningRecord> records,
  ) {
    final rows = <LearningRecordExportRow>[
      for (final record in records)
        LearningRecordExportRow(
          occurredAt: record.occurredAt,
          studentName: record.studentName,
          subjectName: record.subjectName,
          issueTitle: record.issueTitle,
          recordType: _teacherRecordTypeLabel(record.recordKind),
          content: record.content,
          assessmentResult: record.assessmentResult == null
              ? null
              : _assessmentResultLabel(record.assessmentResult!),
          nextStep: record.nextStep,
          teacherName: record.teacherName,
          attachmentNote: record.attachmentCount <= 0
              ? null
              : '${record.attachmentCount} 个附件',
          status: _wireStatusLabel(record.currentStatus),
        ),
    ];
    rows.sort((left, right) => left.occurredAt.compareTo(right.occurredAt));
    return List<LearningRecordExportRow>.unmodifiable(rows);
  }

  static List<LearningRecordExportRow> rowsForTeacherRecords(
    List<TeacherLearningRecord> records, {
    required String teacherName,
  }) {
    final rows = <LearningRecordExportRow>[
      for (final record in records)
        LearningRecordExportRow(
          occurredAt: record.occurredAt,
          studentName: record.studentName,
          subjectName: record.subjectName,
          issueTitle: record.issueTitle,
          recordType: _teacherRecordTypeLabel(record.recordKind),
          content: record.content,
          assessmentResult: record.assessmentResult == null
              ? null
              : _assessmentResultLabel(record.assessmentResult!),
          teacherName: teacherName,
          attachmentNote: record.attachmentCount <= 0
              ? null
              : '${record.attachmentCount} 个附件',
          status: _wireStatusLabel(record.currentStatus),
        ),
    ];
    rows.sort((left, right) => left.occurredAt.compareTo(right.occurredAt));
    return List<LearningRecordExportRow>.unmodifiable(rows);
  }

  static WorkspaceEvidence? _initialQuickCaptureEvidence(
    WorkspaceCase learningCase,
  ) {
    for (final evidence in learningCase.evidence) {
      if (evidence.title == learningCase.title &&
          evidence.observedAt.isAtSameMomentAs(learningCase.firstObservedAt)) {
        return evidence;
      }
    }
    return null;
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
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: column, rowIndex: 0),
      );
      cell.cellStyle = headerStyle;
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

    const widths = <double>[20, 14, 12, 28, 16, 48, 14, 28, 14, 18, 14];
    for (var column = 0; column < widths.length; column++) {
      sheet.setColumnWidth(column, widths[column]);
    }

    for (var rowIndex = 1; rowIndex < sheet.maxRows; rowIndex++) {
      for (var column = 0; column < headers.length; column++) {
        final cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: column, rowIndex: rowIndex),
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
    final name = sanitizeFileName(fileNameWithoutExtension);
    if (Platform.isWindows) {
      final downloads = await getDownloadsDirectory();
      if (downloads == null) {
        throw const FileSystemException('无法读取 Windows 下载文件夹。');
      }
      var file = File('${downloads.path}${Platform.pathSeparator}$name.xlsx');
      var suffix = 2;
      while (await file.exists()) {
        file = File(
          '${downloads.path}${Platform.pathSeparator}$name-$suffix.xlsx',
        );
        suffix++;
      }
      await file.writeAsBytes(bytes, flush: true);
      return file.path;
    }
    return FileSaver.instance.saveAs(
      name: name,
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

  static String teacherFileName(String teacherName, {DateTime? exportedAt}) {
    final now = exportedAt ?? DateTime.now();
    return sanitizeFileName('${teacherName}_教学记录_${_formatDate(now)}');
  }

  static String studentBatchFileName({
    required int studentCount,
    required int profileCount,
    DateTime? exportedAt,
  }) {
    final now = exportedAt ?? DateTime.now();
    return sanitizeFileName(
      '学生学情记录_$studentCount人_$profileCount科_${_formatDate(now)}',
    );
  }

  static String sanitizeFileName(String value) {
    final normalized = value
        .trim()
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ');
    return normalized.isEmpty ? '学情记录' : normalized;
  }

  static String _statusLabel(LearningCaseStatus status) {
    return switch (status) {
      LearningCaseStatus.newCase => '新记录',
      LearningCaseStatus.confirmed => '跟进中',
      LearningCaseStatus.intervening => '跟进中',
      LearningCaseStatus.pendingVerification => '继续关注',
      LearningCaseStatus.stable => '暂时稳定',
      LearningCaseStatus.closed => '已结束',
    };
  }

  static String _wireStatusLabel(String status) {
    return switch (status) {
      'new' => '新记录',
      'confirmed' || 'intervening' => '跟进中',
      'pending_verification' => '继续关注',
      'stable' => '暂时稳定',
      'closed' => '已结束',
      _ => '状态未知',
    };
  }

  static String _teacherRecordTypeLabel(String kind) {
    return switch (kind) {
      'case_created' => '发现问题',
      'evidence' => '学生表现',
      'intervention' => '教学处理',
      'assessment' => '检查结果',
      _ => '其他记录',
    };
  }

  static String _assessmentResultLabel(String result) {
    return switch (result) {
      'passed' => '达到预期',
      'partial' => '部分改善',
      'not_passed' => '暂未达到预期',
      _ => '待判断',
    };
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
