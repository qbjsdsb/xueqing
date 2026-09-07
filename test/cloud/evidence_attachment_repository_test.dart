import 'package:flutter_test/flutter_test.dart';
import 'package:xueqing/cloud/evidence_attachment_repository.dart';

void main() {
  test('parses private Evidence attachment metadata', () {
    final attachment = CaseEvidenceAttachment.fromJson({
      'id': 'attachment-1',
      'organization_id': 'organization-1',
      'learning_case_id': 'case-1',
      'case_evidence_id': 'evidence-1',
      'storage_bucket': caseEvidenceAttachmentBucket,
      'storage_path': 'org/organization-1/cases/case-1/evidence/evidence-1/attachment-1.jpg',
      'original_file_name': '课堂表现.jpg',
      'content_type': 'image/jpeg',
      'size_bytes': '2048',
      'created_at': '2026-09-06T01:00:00.000Z',
    });

    expect(attachment.id, 'attachment-1');
    expect(attachment.originalFileName, '课堂表现.jpg');
    expect(attachment.contentType, 'image/jpeg');
    expect(attachment.sizeBytes, 2048);
    expect(attachment.createdAt.isUtc, isFalse);
  });

  test('rejects incomplete attachment metadata', () {
    expect(
      () => CaseEvidenceAttachment.fromJson({
        'id': 'attachment-1',
        'organization_id': 'organization-1',
      }),
      throwsA(isA<FormatException>()),
    );
  });

  test('keeps the upload limit aligned with the Storage bucket contract', () {
    expect(maxCaseEvidenceAttachmentBytes, 10 * 1024 * 1024);
  });

  test('generates UUIDv4 attachment ids for retry-safe uploads', () {
    final attachmentId = createCaseEvidenceAttachmentId();

    expect(
      RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-4[0-9a-fA-F]{3}-'
        r'[89aAbB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
      ).hasMatch(attachmentId),
      isTrue,
    );
  });
}
