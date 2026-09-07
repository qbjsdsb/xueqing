import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../cloud/evidence_attachment_repository.dart';
import '../../../app/theme/app_spacing.dart';

class PickedEvidenceAttachment {
  const PickedEvidenceAttachment({
    required this.attachmentId,
    required this.bytes,
    required this.fileName,
    required this.contentType,
  });

  final String attachmentId;
  final Uint8List bytes;
  final String fileName;
  final String contentType;
}

String describeEvidenceAttachmentError(
  Object error, {
  bool duringUpload = false,
}) {
  final detail = error.toString().toLowerCase();
  if (detail.contains('cancel') || detail.contains('cancelled')) {
    return '已取消选择图片。';
  }
  if (detail.contains('10 mb') ||
      detail.contains('too large') ||
      detail.contains('file_size_limit')) {
    return '图片不能超过 10 MB。';
  }
  if (detail.contains('invalid_live_session') ||
      detail.contains('session') ||
      detail.contains('jwt')) {
    return '登录状态已变化，请重新登录后再添加图片。';
  }
  if (detail.contains('permission denied') ||
      detail.contains('unauthorized') ||
      detail.contains('accessdenied') ||
      detail.contains('forbidden') ||
      detail.contains('statuscode: 403') ||
      detail.contains('status code: 403')) {
    return '当前账号没有附件上传权限，请确认仍负责该学生后重试。';
  }
  if (detail.contains('attachment_target_not_writable') ||
      detail.contains('case_evidence_not_writable') ||
      detail.contains('learning_case_closed') ||
      detail.contains('not assigned') ||
      detail.contains('assignment')) {
    return '当前 Case 已关闭或你已不再负责该学生，无法上传图片。';
  }
  if (detail.contains('network') ||
      detail.contains('socket') ||
      detail.contains('timeout') ||
      detail.contains('connection')) {
    return '网络暂时不可用，图片仍保留在当前窗口，恢复网络后可重试。';
  }
  if (detail.contains('unsupported') ||
      detail.contains('format') ||
      detail.contains('content type') ||
      detail.contains('mime') ||
      detail.contains('extension')) {
    return '目前只支持 JPG、PNG 或 WEBP 图片。';
  }
  if (duringUpload) {
    return '图片上传失败，请点击重试；文字记录已保留。';
  }
  return '图片读取失败，请换一张 JPG、PNG 或 WEBP 图片后重试。';
}

Future<PickedEvidenceAttachment?> pickEvidenceAttachment(
  BuildContext context,
) async {
  final source = await _chooseImageSource(context);
  if (source == null) {
    return null;
  }
  return _readPickedFile(
    await ImagePicker().pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 2048,
      maxHeight: 2048,
      requestFullMetadata: false,
    ),
  );
}

Future<PickedEvidenceAttachment?> recoverLostEvidenceAttachment() async {
  final response = await ImagePicker().retrieveLostData();
  if (response.isEmpty || response.files == null || response.files!.isEmpty) {
    return null;
  }
  return _readPickedFile(response.files!.first);
}

Future<ImageSource?> _chooseImageSource(BuildContext context) {
  final supportsCamera =
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;
  if (!supportsCamera) {
    return Future.value(ImageSource.gallery);
  }
  return showModalBottomSheet<ImageSource>(
    context: context,
    useSafeArea: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('拍照'),
            onTap: () => Navigator.of(context).pop(ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('从相册选择'),
            onTap: () => Navigator.of(context).pop(ImageSource.gallery),
          ),
          const SizedBox(height: AppSpacing.xs),
        ],
      ),
    ),
  );
}

Future<PickedEvidenceAttachment?> _readPickedFile(XFile? file) async {
  if (file == null) {
    return null;
  }
  final contentType = _contentTypeForName(file.name);
  if (contentType == null) {
    throw const FormatException('目前只支持 JPG、PNG 或 WEBP 图片。');
  }
  final bytes = await file.readAsBytes();
  if (bytes.isEmpty || bytes.length > maxCaseEvidenceAttachmentBytes) {
    throw const FormatException('图片不能为空，且大小不能超过 10 MB。');
  }
  return PickedEvidenceAttachment(
    attachmentId: createCaseEvidenceAttachmentId(),
    bytes: bytes,
    fileName: file.name,
    contentType: contentType,
  );
}

String? _contentTypeForName(String fileName) {
  final normalized = fileName.toLowerCase();
  if (normalized.endsWith('.jpg') || normalized.endsWith('.jpeg')) {
    return 'image/jpeg';
  }
  if (normalized.endsWith('.png')) {
    return 'image/png';
  }
  if (normalized.endsWith('.webp')) {
    return 'image/webp';
  }
  return null;
}
