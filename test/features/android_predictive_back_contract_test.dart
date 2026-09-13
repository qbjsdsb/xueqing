import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Android predictive Back stays enabled alongside guarded page swipe',
    () {
      final manifest = File('android/app/src/main/AndroidManifest.xml')
          .readAsStringSync();
      final workspace = File('lib/features/design_v2/v2_workspace_preview.dart')
          .readAsStringSync();

      expect(manifest, contains('android:enableOnBackInvokedCallback="true"'));
      expect(workspace, contains('PopScope<void>('));
      expect(workspace, contains('media.systemGestureInsets'));
      expect(
        workspace,
        contains('Theme.of(context).platform == TargetPlatform.android'),
      );
      expect(workspace, contains("Key('v2-compact-swipe-surface')"));
    },
  );
}
