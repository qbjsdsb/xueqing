import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xueqing/cloud/case_reopen_draft_store.dart';
import 'package:xueqing/cloud/learning_repository.dart';
import 'package:xueqing/features/design_v2/v2_workspace_page.dart';
import 'package:xueqing/features/teacher_workspace/workspace_runtime.dart';
import 'package:xueqing/update/update_installer.dart';
import 'package:xueqing/update/update_models.dart';
import 'package:xueqing/update/update_service.dart';

void main() {
  testWidgets('production V2 host loads the workspace without preview chrome', (
    tester,
  ) async {
    final runtime = AuthenticatedWorkspaceRuntime(
      learningRepository: _FakeLearningRepository(),
      updateService: UpdateService(
        currentVersion: '0.3.0+8',
        platform: UpdatePlatform.android,
        manifestLoader: (_) async => '{}',
      ),
      updateInstaller: _FakeUpdateInstaller(),
      caseReopenDraftStore: _FakeCaseReopenDraftStore(),
      appVersion: '0.3.0+8',
      sessionUserId: 'user-1',
    );

    await tester.pumpWidget(MaterialApp(home: V2WorkspacePage(runtime: runtime)));
    await tester.pumpAndSettle();

    expect(find.text('暂时还没有可查看的学生'), findsOneWidget);
    expect(find.text('V2 真实学情预览'), findsNothing);
    expect(find.byKey(const Key('v2-real-preview-back')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

class _FakeLearningRepository extends Fake implements LearningRepository {
  @override
  Future<TeacherWorkspace> loadWorkspace() async => TeacherWorkspace(
    viewerName: '乔老师',
    organizationName: '测试机构',
    organizationTimeZone: 'Asia/Shanghai',
    hasTeachingAccess: true,
    loadedAt: DateTime(2026, 9, 10, 9),
    businessDate: DateTime(2026, 9, 10),
    students: const <WorkspaceStudent>[],
  );
}

class _FakeUpdateInstaller extends Fake implements UpdateInstaller {}

class _FakeCaseReopenDraftStore extends Fake implements CaseReopenDraftStore {}
