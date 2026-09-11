import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:excel_community/excel_community.dart';
import 'package:file_saver/file_saver.dart';
import 'package:path_provider/path_provider.dart';

import '../cloud/evidence_attachment_repository.dart';
import '../cloud/learning_repository.dart';
import '../cloud/student_learning_record_repository.dart';
import '../cloud/teacher_learning_record_repository.dart';
import '../media/evidence_image_processing.dart';

class LearningRecordExportImage {
  const LearningRecordExportImage({
    required this.bytes,
    required this.width,
    required this.height,
  });

  final Uint8List bytes;
  final int width;
  final int height;
}

class LearningRecordExportImageException implements Exception {
  LearningRecordExportImageException(this.cause);

  final Object cause;

  @override
  String toString() => '学情记录中的图片无法下载或处理。';
}

String? learningRecordImageExportErrorMessage(Object error) =>
    error is LearningRecordExportImageException
    ? '记录已读取，但其中一张图片暂时无法下载或处理，请检查网络后重试。'
    : null;

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
    this.attachmentPaths = const <String>[],
    this.attachmentImages = const <LearningRecordExportImage>[],
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
  final List<String> attachmentPaths;
  final List<LearningRecordExportImage> attachmentImages;
  final String status;

  LearningRecordExportRow copyWithAttachmentImages(
    List<LearningRecordExportImage> images,
  ) => LearningRecordExportRow(
    occurredAt: occurredAt,
    studentName: studentName,
    subjectName: subjectName,
    issueTitle: issueTitle,
    recordType: recordType,
    content: content,
    status: status,
    assessmentResult: assessmentResult,
    nextStep: nextStep,
    teacherName: teacherName,
    attachmentNote: attachmentNote,
    attachmentPaths: attachmentPaths,
    attachmentImages: List<LearningRecordExportImage>.unmodifiable(images),
  );

  LearningRecordExportRow copyWithNextStep(String? value) =>
      LearningRecordExportRow(
        occurredAt: occurredAt,
        studentName: studentName,
        subjectName: subjectName,
        issueTitle: issueTitle,
        recordType: recordType,
        content: content,
        status: status,
        assessmentResult: assessmentResult,
        nextStep: value,
        teacherName: teacherName,
        attachmentNote: attachmentNote,
        attachmentPaths: attachmentPaths,
        attachmentImages: attachmentImages,
      );
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
    '当前下一步 / 提醒',
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
      final caseRows = <LearningRecordExportRow>[];

      caseRows.add(
        LearningRecordExportRow(
          occurredAt: learningCase.firstObservedAt,
          studentName: student.name,
          subjectName: student.subject,
          issueTitle: learningCase.title,
          recordType: '发现问题',
          content: _dedupeIssueContent(learningCase.title, initialContent),
          status: status,
        ),
      );

      for (final evidence in learningCase.evidence) {
        if (evidence.id == initialEvidence?.id) {
          continue;
        }
        caseRows.add(
          LearningRecordExportRow(
            occurredAt: evidence.observedAt,
            studentName: student.name,
            subjectName: student.subject,
            issueTitle: learningCase.title,
            recordType: '学生表现',
            content: _dedupeIssueContent(
              learningCase.title,
              '${evidence.title}：${evidence.summary}',
            ),
            status: status,
          ),
        );
      }

      for (final intervention in learningCase.interventions) {
        final notes = intervention.notes?.trim();
        caseRows.add(
          LearningRecordExportRow(
            occurredAt: intervention.occurredAt,
            studentName: student.name,
            subjectName: student.subject,
            issueTitle: learningCase.title,
            recordType: '教学处理',
            content: notes == null || notes.isEmpty
                ? intervention.strategy
                : '${intervention.strategy}\n$notes',
            status: status,
          ),
        );
      }

      for (final assessment in learningCase.assessments) {
        final result = _assessmentResultLabel(assessment.result);
        final notes = assessment.notes?.trim();
        caseRows.add(
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
            status: status,
          ),
        );
      }

      caseRows.sort(
        (left, right) => left.occurredAt.compareTo(right.occurredAt),
      );
      if (nextStep != null && caseRows.isNotEmpty) {
        final latestIndex = caseRows.length - 1;
        caseRows[latestIndex] = caseRows[latestIndex].copyWithNextStep(
          nextStep,
        );
      }
      rows.addAll(caseRows);
    }

    rows.sort((left, right) => left.occurredAt.compareTo(right.occurredAt));
    return List<LearningRecordExportRow>.unmodifiable(rows);
  }

  static List<LearningRecordExportRow> rowsForStudentRecords(
    List<StudentLearningRecord> records,
  ) {
    final latestRecordByCase = <String, StudentLearningRecord>{};
    for (final record in records) {
      final caseId = record.learningCaseId?.trim();
      if (caseId == null || caseId.isEmpty) continue;
      final current = latestRecordByCase[caseId];
      if (current == null ||
          record.occurredAt.isAfter(current.occurredAt) ||
          (record.occurredAt.isAtSameMomentAs(current.occurredAt) &&
              record.id.compareTo(current.id) > 0)) {
        latestRecordByCase[caseId] = record;
      }
    }

    final rows = <LearningRecordExportRow>[
      for (final record in records)
        LearningRecordExportRow(
          occurredAt: record.occurredAt,
          studentName: record.studentName,
          subjectName: record.subjectName,
          issueTitle: record.issueTitle,
          recordType: _teacherRecordTypeLabel(record.recordKind),
          content: _dedupeIssueContent(record.issueTitle, record.content),
          assessmentResult: record.assessmentResult == null
              ? null
              : _assessmentResultLabel(record.assessmentResult!),
          nextStep:
              record.learningCaseId == null ||
                  record.learningCaseId!.trim().isEmpty ||
                  latestRecordByCase[record.learningCaseId!.trim()]?.id ==
                      record.id
              ? record.nextStep
              : null,
          teacherName: record.teacherName,
          attachmentNote: record.attachmentCount <= 0
              ? null
              : '${record.attachmentCount} 个附件',
          attachmentPaths: record.attachmentPaths,
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
          content: _dedupeIssueContent(record.issueTitle, record.content),
          assessmentResult: record.assessmentResult == null
              ? null
              : _assessmentResultLabel(record.assessmentResult!),
          teacherName: teacherName,
          attachmentNote: record.attachmentCount <= 0
              ? null
              : '${record.attachmentCount} 个附件',
          attachmentPaths: record.attachmentPaths,
          status: _wireStatusLabel(record.currentStatus),
        ),
    ];
    rows.sort((left, right) => left.occurredAt.compareTo(right.occurredAt));
    return List<LearningRecordExportRow>.unmodifiable(rows);
  }

  static Future<List<LearningRecordExportRow>> prepareRowsWithAttachmentImages({
    required List<LearningRecordExportRow> rows,
    required EvidenceAttachmentRepository? repository,
  }) async {
    final uniquePaths = <String>{for (final row in rows) ...row.attachmentPaths}
        .toList(growable: false);
    if (uniquePaths.isEmpty) {
      return List<LearningRecordExportRow>.unmodifiable(rows);
    }
    if (repository == null) {
      throw LearningRecordExportImageException(
        StateError('Attachment repository is unavailable.'),
      );
    }

    final cache = <String, LearningRecordExportImage>{};
    const batchSize = 2;
    for (var start = 0; start < uniquePaths.length; start += batchSize) {
      final end = math.min(start + batchSize, uniquePaths.length);
      final batch = uniquePaths.sublist(start, end);
      final images = await Future.wait([
        for (final path in batch) _loadExportImage(repository, path),
      ]);
      for (var index = 0; index < batch.length; index++) {
        cache[batch[index]] = images[index];
      }
    }

    return List<LearningRecordExportRow>.unmodifiable([
      for (final row in rows)
        if (row.attachmentPaths.isEmpty)
          row
        else
          row.copyWithAttachmentImages([
            for (final path in row.attachmentPaths) cache[path]!,
          ]),
    ]);
  }

  static Future<LearningRecordExportImage> _loadExportImage(
    EvidenceAttachmentRepository repository,
    String path,
  ) async {
    try {
      final sourceBytes = await repository.downloadBytes(path);
      final processed = await processEvidenceImageForExcel(sourceBytes);
      return LearningRecordExportImage(
        bytes: processed.bytes,
        width: processed.width,
        height: processed.height,
      );
    } catch (error) {
      throw LearningRecordExportImageException(error);
    }
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
    sheet.frozenRows = 1;

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

    for (var index = 0; index < rows.length; index++) {
      final row = rows[index];
      final sheetRow = index + 1;
      sheet.appendRow(<CellValue?>[
        DateTimeCellValue.fromDateTime(row.occurredAt.toLocal()),
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
      _addAttachmentImages(sheet, sheetRow, row.attachmentImages);
    }

    const widths = <double>[20, 14, 12, 28, 16, 48, 14, 28, 14, 38, 14];
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

  static void _addAttachmentImages(
    Sheet sheet,
    int rowIndex,
    List<LearningRecordExportImage> images,
  ) {
    if (images.isEmpty) return;
    const attachmentColumn = 9;
    const topOffset = 22;

    if (images.length == 1) {
      final size = _fitImage(images.single, maxWidth: 220, maxHeight: 150);
      sheet.addImage(
        ExcelImage(
          imageBytes: images.single.bytes,
          imageType: ExcelImageType.jpeg,
          anchor: ImageAnchor.fromPixels(
            column: attachmentColumn,
            row: rowIndex,
            widthPixels: size.width,
            heightPixels: size.height,
            colOffsetPixels: 6,
            rowOffsetPixels: topOffset,
          ),
        ),
      );
      final rowHeight = ((topOffset + size.height + 8) * 0.75)
          .clamp(18.0, 409.0)
          .toDouble();
      sheet.setRowHeight(rowIndex, rowHeight);
      return;
    }

    // Excel has a practical row-height limit. Keep every image visible by
    // fitting all thumbnails into a bounded grid rather than silently dropping
    // overflow attachments.
    final columns = images.length <= 4 ? 2 : 3;
    const cellWidth = 220;
    const gutter = 4;
    final rowsNeeded = (images.length + columns - 1) ~/ columns;
    final maxGridHeight = 500 - topOffset - 8;
    final tileWidth = math.max(
      24,
      ((cellWidth - (columns - 1) * gutter) / columns).floor(),
    );
    final tileHeight = math.max(
      18,
      ((maxGridHeight - (rowsNeeded - 1) * gutter) / rowsNeeded).floor(),
    );
    var maxBottom = topOffset;

    for (var index = 0; index < images.length; index++) {
      final image = images[index];
      final size = _fitImage(image, maxWidth: tileWidth, maxHeight: tileHeight);
      final gridColumn = index % columns;
      final gridRow = index ~/ columns;
      final x = 6 + gridColumn * (tileWidth + gutter);
      final y = topOffset + gridRow * (tileHeight + gutter);
      sheet.addImage(
        ExcelImage(
          imageBytes: image.bytes,
          imageType: ExcelImageType.jpeg,
          anchor: ImageAnchor.fromPixels(
            column: attachmentColumn,
            row: rowIndex,
            widthPixels: size.width,
            heightPixels: size.height,
            colOffsetPixels: x,
            rowOffsetPixels: y,
          ),
        ),
      );
      maxBottom = math.max(maxBottom, y + size.height);
    }

    final rowHeight = ((maxBottom + 8) * 0.75).clamp(18.0, 409.0).toDouble();
    sheet.setRowHeight(rowIndex, rowHeight);
  }

  static ({int width, int height}) _fitImage(
    LearningRecordExportImage image, {
    required int maxWidth,
    required int maxHeight,
  }) {
    if (image.width <= 0 || image.height <= 0) {
      return (width: 1, height: 1);
    }
    final scale = math.min(
      1.0,
      math.min(maxWidth / image.width, maxHeight / image.height),
    );
    return (
      width: math.max(1, (image.width * scale).round()),
      height: math.max(1, (image.height * scale).round()),
    );
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

  static String _dedupeIssueContent(String issueTitle, String content) {
    final issue = issueTitle.trim();
    final text = content.trim();
    if (text.isEmpty || issue.isEmpty) return text;
    if (_semanticTextKey(text) == _semanticTextKey(issue)) return '';

    final lines = text.split('\n');
    if (lines.isNotEmpty &&
        _semanticTextKey(lines.first) == _semanticTextKey(issue)) {
      return lines.skip(1).join('\n').trim();
    }

    for (final separator in const ['：', ':']) {
      final prefix = '$issue$separator';
      if (!text.startsWith(prefix)) continue;
      final remainder = text.substring(prefix.length).trim();
      if (remainder.isEmpty ||
          _semanticTextKey(remainder) == _semanticTextKey(issue)) {
        return '';
      }
      return remainder;
    }

    for (final label in const ['具体表现：', '具体表现:']) {
      if (!text.startsWith(label)) continue;
      final remainder = text.substring(label.length).trim();
      if (_semanticTextKey(remainder) == _semanticTextKey(issue)) {
        return '';
      }
    }
    return text;
  }

  static String _semanticTextKey(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll('：', ':')
      .replaceAll(RegExp(r'\s+'), '');

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

  static String _formatDate(DateTime value) {
    return '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
  }
}
