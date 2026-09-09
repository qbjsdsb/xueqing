import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xueqing/cloud/learning_repository.dart';
import 'package:xueqing/features/design_v2/v2_real_preview_page.dart';

void main() {
  testWidgets('real preview uses the read loader and exposes explicit sign out', (
    tester,
  ) async {
    var loadCount = 0;
    var signOutCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: V2RealPreviewPage(
          loadWorkspace: () async {
            loadCount++;
            return _emptyWorkspace();
          },
          onSignOut: () => signOutCount++,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(loadCount, 1);
    expect(find.text('真实数据只读预览'), findsOneWidget);
    expect(find.text('暂时还没有可查看的学生'), findsOneWidget);
    expect(find.byKey(const Key('v2-real-preview-sign-out')), findsOneWidget);

    await tester.tap(find.byKey(const Key('v2-real-preview-sign-out')));
    await tester.pump();

    expect(signOutCount, 1);
    expect(tester.takeException(), isNull);
  });
}

TeacherWorkspace _emptyWorkspace() {
  return TeacherWorkspace(
    viewerName: '乔老师',
    organizationName: '测试机构',
    organizationTimeZone: 'Asia/Shanghai',
    hasTeachingAccess: true,
    loadedAt: DateTime(2026, 9, 9, 21),
    businessDate: DateTime(2026, 9, 9),
    students: const <WorkspaceStudent>[],
  );
}
