import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Android predictive Back stays enabled alongside native root paging',
    () {
      final manifest = File('android/app/src/main/AndroidManifest.xml')
          .readAsStringSync();
      final workspace = File('lib/features/design_v2/v2_workspace_preview.dart')
          .readAsStringSync();

      expect(manifest, contains('android:enableOnBackInvokedCallback="true"'));
      expect(workspace, contains('PopScope<void>('));
      expect(workspace, contains('PageView('));
      expect(workspace, contains('const PageScrollPhysics()'));
      expect(
        workspace,
        contains('Theme.of(context).platform == TargetPlatform.android'),
      );
      expect(workspace, contains("Key('v2-compact-swipe-surface')"));

      // Android owns system-edge Back recognition. The app must not bring back
      // the old custom edge-inset drag gate just to protect paging.
      expect(workspace, isNot(contains('media.systemGestureInsets')));
      expect(workspace, isNot(contains('_minimumFlingVelocity')));
      expect(workspace, isNot(contains('_handleHorizontalDragDown')));
    },
  );
}
