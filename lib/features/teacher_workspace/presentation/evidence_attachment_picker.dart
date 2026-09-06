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
