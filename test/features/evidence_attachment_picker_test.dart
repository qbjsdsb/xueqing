import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:xueqing/features/teacher_workspace/presentation/'
    'evidence_attachment_picker.dart';

void main() {
  test(
    'explains Storage permission failures instead of calling them read errors',
    () {
      expect(
        describeEvidenceAttachmentError(
          StateError(
            'StorageException: permission denied for function current_teaching_membership_for_profile_v2; statusCode: 403',
          ),
          duringUpload: true,
        ),
        '当前账号没有附件上传权限，请确认仍负责该学生后重试。',
      );
    },
  );

  test('uses teacher language when the problem no longer accepts images', () {
    expect(
      describeEvidenceAttachmentError(
        StateError('attachment_target_not_writable: learning_case_closed'),
        duringUpload: true,
      ),
      '当前问题已结束跟进或你已不再负责该学生，无法上传图片。',
    );
  });

  test('keeps a picked image retryable when the network is unavailable', () {
    expect(
      describeEvidenceAttachmentError(
        StateError('SocketException: connection timed out'),
        duringUpload: true,
      ),
      '网络暂时不可用，图片仍保留在当前窗口，恢复网络后可重试。',
    );
  });

  test('keeps unsupported image guidance focused on the accepted formats', () {
    expect(
      describeEvidenceAttachmentError(
        const FormatException('Unsupported image content type.'),
      ),
      '目前只支持 JPG、PNG 或 WEBP 图片。',
    );
  });

  test(
    'lost-data recovery primes once and returns the recovered image once',
    () async {
      var calls = 0;
      final recovered = PickedEvidenceAttachment(
        attachmentId: '00000000-0000-4000-8000-000000000001',
        bytes: Uint8List.fromList(<int>[1, 2, 3]),
        fileName: '恢复图片.jpg',
        contentType: 'image/jpeg',
      );
      final recovery = EvidenceAttachmentLostDataRecovery(() async {
        calls++;
        return recovered;
      });

      recovery.prime();
      recovery.prime();

      expect(await recovery.take(), same(recovered));
      expect(await recovery.take(), isNull);
      expect(calls, 1);
    },
  );

  test('lost-data recovery can be consumed without explicit priming', () async {
    var calls = 0;
    final recovery = EvidenceAttachmentLostDataRecovery(() async {
      calls++;
      return null;
    });

    expect(await recovery.take(), isNull);
    expect(await recovery.take(), isNull);
    expect(calls, 1);
  });

  test(
    'lost-data recovery refreshes a stale startup null for a protected draft',
    () async {
      var calls = 0;
      final recovered = PickedEvidenceAttachment(
        attachmentId: '00000000-0000-4000-8000-000000000009',
        bytes: Uint8List.fromList(<int>[9, 8, 7]),
        fileName: '相机恢复.jpg',
        contentType: 'image/jpeg',
      );
      final recovery = EvidenceAttachmentLostDataRecovery(() async {
        calls++;
        return calls == 1 ? null : recovered;
      });

      recovery.prime();
      await Future<void>.delayed(Duration.zero);

      expect(await recovery.take(refreshIfEmpty: true), same(recovered));
      expect(calls, 2);
      expect(await recovery.take(refreshIfEmpty: true), isNull);
    },
  );

  test(
    'startup recovery errors are deferred until the result is consumed',
    () async {
      var calls = 0;
      final recovery = EvidenceAttachmentLostDataRecovery(() async {
        calls++;
        throw StateError('lost picker result is unreadable');
      });

      recovery.prime();
      await Future<void>.delayed(Duration.zero);

      await expectLater(recovery.take(), throwsA(isA<StateError>()));
      expect(await recovery.take(), isNull);
      expect(calls, 1);
    },
  );
}
