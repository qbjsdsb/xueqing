from pathlib import Path

manifest_path = Path('android/app/src/main/AndroidManifest.xml')
manifest = manifest_path.read_text()
anchor = '        android:allowBackup="false">'
replacement = (
    '        android:allowBackup="false"\n'
    '        android:enableOnBackInvokedCallback="true">'
)
if anchor not in manifest:
    raise SystemExit('predictive back manifest anchor not found')
manifest = manifest.replace(anchor, replacement, 1)
manifest_path.write_text(manifest)

contract_path = Path('test/features/android_predictive_back_contract_test.dart')
contract_path.write_text(
    """import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android predictive Back stays enabled alongside guarded page swipe', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    final workspace = File(
      'lib/features/design_v2/v2_workspace_preview.dart',
    ).readAsStringSync();

    expect(
      manifest,
      contains('android:enableOnBackInvokedCallback=\"true\"'),
    );
    expect(workspace, contains('PopScope<void>('));
    expect(workspace, contains('media.systemGestureInsets'));
    expect(workspace, contains('Theme.of(context).platform == TargetPlatform.android'));
    expect(workspace, contains("Key('v2-compact-swipe-surface')"));
  });
}
"""
)
