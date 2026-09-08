import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xueqing/update/update_dialog.dart';
import 'package:xueqing/update/update_models.dart';

void main() {
  testWidgets('does not claim a hard block when the UI still allows deferral', (
    tester,
  ) async {
    const result = UpdateCheckResult(
      state: UpdateCheckState.available,
      currentVersion: AppVersion(major: 1, minor: 0, patch: 0),
      manifest: UpdateManifest(
        schema: 1,
        channel: 'stable',
        version: AppVersion(major: 2, minor: 0, patch: 0),
        minimumSupportedVersion: AppVersion(major: 1, minor: 5, patch: 0),
        artifacts: <UpdatePlatform, UpdateArtifact>{},
      ),
      platform: UpdatePlatform.android,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: UpdateDialog(result: result)),
      ),
    );

    expect(find.text('建议立即更新'), findsOneWidget);
    expect(find.textContaining('最低支持版本'), findsOneWidget);
    expect(find.textContaining('建议现在更新'), findsOneWidget);
    expect(find.text('暂不更新'), findsOneWidget);
    expect(find.text('下载并安装'), findsOneWidget);
    expect(find.textContaining('必须更新'), findsNothing);
    expect(find.text('稍后处理'), findsNothing);
  });
}
