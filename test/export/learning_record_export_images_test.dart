import 'dart:typed_data';

import 'package:excel_community/excel_community.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:xueqing/cloud/evidence_attachment_repository.dart';
import 'package:xueqing/export/learning_record_export.dart';

void main() {
  test('embeds private evidence bytes and downloads each path once', () async {
    final source = img.Image(width: 320, height: 180);
    final bytes = Uint8List.fromList(img.encodeJpg(source, quality: 90));
    final repository = _DownloadOnlyEvidenceAttachmentRepository(bytes);
    final rows = <LearningRecordExportRow>[
      LearningRecordExportRow(
        occurredAt: DateTime(2026, 9, 10, 18),
        studentName: '示例学生',
        subjectName: '语文',
        issueTitle: '阅读题漏看限制词',
        recordType: '学生表现',
        content: '虚构课堂观察。',
        status: '跟进中',
        attachmentNote: '1 个附件',
        attachmentPaths: const <String>['org/demo/shared.jpg'],
      ),
      LearningRecordExportRow(
        occurredAt: DateTime(2026, 9, 10, 18, 5),
        studentName: '示例学生',
        subjectName: '语文',
        issueTitle: '阅读题漏看限制词',
        recordType: '学生表现',
        content: '同一张图的第二条虚构投影。',
        status: '跟进中',
        attachmentNote: '1 个附件',
        attachmentPaths: const <String>['org/demo/shared.jpg'],
      ),
    ];

    final prepared = await LearningRecordExport.prepareRowsWithAttachmentImages(
      rows: rows,
      repository: repository,
    );

    expect(repository.downloadCount, 1);
    expect(prepared, hasLength(2));
    expect(prepared.first.attachmentImages, hasLength(1));
    expect(prepared.last.attachmentImages, hasLength(1));
    expect(
      identical(
        prepared.first.attachmentImages.single,
        prepared.last.attachmentImages.single,
      ),
      isTrue,
    );

    final workbookBytes = LearningRecordExport.buildWorkbook(rows: prepared);
    final zipIndex = String.fromCharCodes(workbookBytes);
    expect(zipIndex, contains('xl/media/image1.jpeg'));
    expect(zipIndex, contains('xl/drawings/drawing1.xml'));

    final workbook = Excel.decodeBytes(workbookBytes);
    final sheet = workbook.tables['全部记录'];
    expect(sheet, isNotNull);
    expect(sheet!.rows[1][9]?.value.toString(), '1 个附件');
    expect(sheet.rows[2][9]?.value.toString(), '1 个附件');
  });

  test('fails explicitly instead of silently dropping images', () async {
    final rows = <LearningRecordExportRow>[
      LearningRecordExportRow(
        occurredAt: DateTime(2026, 9, 10, 18),
        studentName: '示例学生',
        subjectName: '语文',
        issueTitle: '图片导出',
        recordType: '学生表现',
        content: '虚构记录。',
        status: '跟进中',
        attachmentNote: '1 个附件',
        attachmentPaths: const <String>['org/demo/missing.jpg'],
      ),
    ];

    await expectLater(
      LearningRecordExport.prepareRowsWithAttachmentImages(
        rows: rows,
        repository: null,
      ),
      throwsA(isA<LearningRecordExportImageException>()),
    );
    expect(
      learningRecordImageExportErrorMessage(
        LearningRecordExportImageException(StateError('missing')),
      ),
      '记录已读取，但其中一张图片暂时无法下载或处理，请检查网络后重试。',
    );
  });
}

class _DownloadOnlyEvidenceAttachmentRepository extends Fake
    implements EvidenceAttachmentRepository {
  _DownloadOnlyEvidenceAttachmentRepository(this.bytes);

  final Uint8List bytes;
  int downloadCount = 0;

  @override
  Future<Uint8List> downloadBytes(String storagePath) async {
    downloadCount += 1;
    return bytes;
  }
}
