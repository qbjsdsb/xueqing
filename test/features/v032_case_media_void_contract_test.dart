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
    'teacher delete remains an audited closure rather than physical delete',
    () {
      final controller = File(
        'lib/features/design_v2/v2_workflow_controller.dart',
      ).readAsStringSync();
      final preview = File('lib/features/design_v2/v2_workspace_preview.dart')
          .readAsStringSync();

      expect(controller, contains('progressiveCaseRepository.endFollowUp('));
      expect(controller, contains('reason: CaseClosureReason.notIssue'));
      expect(controller, isNot(contains('deleteLearningCase')));
      expect(preview, contains("title: const Text('删除这个问题？')"));
      expect(preview, contains("key: const Key('v2-confirm-void-case')"));
      expect(preview, contains("child: saving"));
      expect(preview, contains(": const Text('删除问题')"));
    },
  );
}
