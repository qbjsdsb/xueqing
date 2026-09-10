import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

const int evidenceUploadMaxDimension = 1920;
const int evidenceUploadFallbackDimension = 1600;
const int evidenceUploadTargetBytes = 2500 * 1024;
const int evidenceExcelMaxDimension = 960;

class ProcessedEvidenceImage {
  const ProcessedEvidenceImage({
    required this.bytes,
    required this.width,
    required this.height,
  });

  final Uint8List bytes;
  final int width;
  final int height;
}

/// Normalizes a teacher photo before it reaches a draft or Supabase Storage.
///
/// Work happens in a background isolate so decoding a large camera image does
/// not stall Android navigation. Photos are orientation-corrected, resized
/// without stretching and encoded as JPEG. A second, gentler fallback keeps
/// unusually detailed/noisy photos from consuming excessive Storage while
/// preserving enough resolution for worksheet text.
Future<ProcessedEvidenceImage> processEvidenceImageForUpload(
  Uint8List sourceBytes,
) async {
  if (sourceBytes.isEmpty) {
    throw const FormatException('图片不能为空。');
  }
  final result = await compute(_processEvidenceImageForUpload, sourceBytes);
  return ProcessedEvidenceImage(
    bytes: result['bytes']! as Uint8List,
    width: result['width']! as int,
    height: result['height']! as int,
  );
}

/// Builds a smaller JPEG specifically for embedding in an exported workbook.
/// The original evidence object in Storage is never modified.
Future<ProcessedEvidenceImage> processEvidenceImageForExcel(
  Uint8List sourceBytes,
) async {
  if (sourceBytes.isEmpty) {
    throw const FormatException('图片不能为空。');
  }
  final result = await compute(_processEvidenceImageForExcel, sourceBytes);
  return ProcessedEvidenceImage(
    bytes: result['bytes']! as Uint8List,
    width: result['width']! as int,
    height: result['height']! as int,
  );
}

Map<String, Object> _processEvidenceImageForUpload(Uint8List sourceBytes) {
  var image = _decodeAndOrient(sourceBytes);
  image = _resizeLongestEdge(image, evidenceUploadMaxDimension);

  var encoded = img.encodeJpg(image, quality: 82);
  if (encoded.length > evidenceUploadTargetBytes) {
    encoded = img.encodeJpg(image, quality: 76);
  }
  if (encoded.length > evidenceUploadTargetBytes &&
      (image.width > evidenceUploadFallbackDimension ||
          image.height > evidenceUploadFallbackDimension)) {
    image = _resizeLongestEdge(image, evidenceUploadFallbackDimension);
    encoded = img.encodeJpg(image, quality: 76);
  }
  if (encoded.length > evidenceUploadTargetBytes) {
    encoded = img.encodeJpg(image, quality: 70);
  }

  return <String, Object>{
    'bytes': Uint8List.fromList(encoded),
    'width': image.width,
    'height': image.height,
  };
}

Map<String, Object> _processEvidenceImageForExcel(Uint8List sourceBytes) {
  var image = _decodeAndOrient(sourceBytes);
  image = _resizeLongestEdge(image, evidenceExcelMaxDimension);
  final encoded = img.encodeJpg(image, quality: 76);
  return <String, Object>{
    'bytes': Uint8List.fromList(encoded),
    'width': image.width,
    'height': image.height,
  };
}

img.Image _decodeAndOrient(Uint8List sourceBytes) {
  try {
    final decoded = img.decodeImage(sourceBytes);
    if (decoded == null || decoded.width <= 0 || decoded.height <= 0) {
      throw const FormatException('图片格式无法读取。');
    }
    return img.bakeOrientation(decoded);
  } on FormatException {
    rethrow;
  } catch (_) {
    // Some format probes in package:image throw RangeError/Error for severely
    // truncated files. Keep that implementation detail away from teachers and
    // expose one stable invalid-image contract to every picker/recovery path.
    throw const FormatException('图片格式无法读取。');
  }
}

img.Image _resizeLongestEdge(img.Image source, int maxDimension) {
  if (source.width <= maxDimension && source.height <= maxDimension) {
    return source;
  }
  if (source.width >= source.height) {
    return img.copyResize(
      source,
      width: maxDimension,
      interpolation: img.Interpolation.linear,
    );
  }
  return img.copyResize(
    source,
    height: maxDimension,
    interpolation: img.Interpolation.linear,
  );
}

String evidenceJpegFileName(String originalName) {
  final trimmed = originalName.trim();
  final safe = trimmed.isEmpty ? '学情图片' : trimmed;
  final dot = safe.lastIndexOf('.');
  final base = dot > 0 ? safe.substring(0, dot) : safe;
  return '$base.jpg';
}
