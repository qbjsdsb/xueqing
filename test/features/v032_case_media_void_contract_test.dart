import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('V2 evidence thumbnails open a zoomable signed-url preview', () {
    final source = File('lib/features/design_v2/v2_workspace_preview.dart')
        .readAsStringSync();

    expect(
      source,
      contains(r"key: ValueKey<String>('v2-evidence-photo-$index')"),
    );
    expect(source, contains('onTap: () =>'));
    expect(
      source,
      contains('_showV2EvidencePhotoPreview(context, urls[index])'),
    );
    expect(source, contains('InteractiveViewer('));
    expect(
      source,
      contains("key: const Key('v2-evidence-photo-preview-image')"),
    );
    expect(source, contains('createSignedUrl(attachment.storagePath)'));
    expect(source, isNot(contains('getPublicUrl(')));
  });

  test(
    'teacher invalidation is audited and never physically deletes history',
    () {
      final controller = File(
        'lib/features/design_v2/v2_workflow_controller.dart',
      ).readAsStringSync();
      final preview = File('lib/features/design_v2/v2_workspace_preview.dart')
          .readAsStringSync();

      expect(controller, contains('repository.voidLearningCase('));
      expect(controller, contains('VoidLearningCaseCommand('));
      expect(controller, isNot(contains("note: '教师删除/作废误建或重复问题'")));
      expect(preview, contains("title: const Text('作废这条学情？')"));
      expect(preview, contains("key: const Key('v2-void-reason')"));
      expect(preview, contains("key: const Key('v2-confirm-void-case')"));
      expect(preview, contains("const Text('确认作废')"));
      expect(preview, contains("'作废错误学情'"));
    },
  );
}
