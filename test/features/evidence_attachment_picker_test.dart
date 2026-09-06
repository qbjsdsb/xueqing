import 'package:flutter_test/flutter_test.dart';
import 'package:xueqing/features/teacher_workspace/presentation/'
    'evidence_attachment_picker.dart';

void main() {
  test('explains Storage permission failures instead of calling them read errors', () {
    expect(
      describeEvidenceAttachmentError(
        StateError(
          'StorageException: permission denied for function current_teaching_membership_for_profile_v2; statusCode: 403',
        ),
        duringUpload: true,
      ),
      '当前账号没有附件上传权限，请确认仍负责该学生后重试。',
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
}
