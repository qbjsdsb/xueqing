import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:xueqing/media/evidence_image_processing.dart';

void main() {
  test(
    'upload processing bounds dimensions and emits a readable JPEG',
    () async {
      final source = img.Image(width: 3000, height: 2000);
      final sourceBytes = Uint8List.fromList(img.encodePng(source));

      final processed = await processEvidenceImageForUpload(sourceBytes);
      final decoded = img.decodeJpg(processed.bytes);

      expect(decoded, isNotNull);
      expect(processed.width, 1920);
      expect(processed.height, 1280);
      expect(decoded!.width, 1920);
      expect(decoded.height, 1280);
      expect(processed.bytes[0], 0xff);
      expect(processed.bytes[1], 0xd8);
    },
  );

  test(
    'excel processing creates a smaller viewing copy without stretching',
    () async {
      final source = img.Image(width: 1200, height: 2400);
      final sourceBytes = Uint8List.fromList(
        img.encodeJpg(source, quality: 95),
      );

      final processed = await processEvidenceImageForExcel(sourceBytes);
      final decoded = img.decodeJpg(processed.bytes);

      expect(decoded, isNotNull);
      expect(processed.width, 480);
      expect(processed.height, 960);
      expect(decoded!.width, 480);
      expect(decoded.height, 960);
    },
  );

  test('normalizes exported upload names to jpg', () {
    expect(evidenceJpegFileName('作业照片.PNG'), '作业照片.jpg');
    expect(evidenceJpegFileName('camera'), 'camera.jpg');
    expect(evidenceJpegFileName('   '), '学情图片.jpg');
  });

  test('rejects unreadable image bytes', () async {
    await expectLater(
      processEvidenceImageForUpload(Uint8List.fromList(<int>[1, 2, 3, 4])),
      throwsA(isA<FormatException>()),
    );
  });
}
