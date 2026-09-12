import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xueqing/cloud/case_reopen_draft_store.dart';
import 'package:xueqing/cloud/composer_draft_store.dart';
import 'package:xueqing/cloud/learning_repository.dart';
import 'package:xueqing/cloud/progressive_case_repository.dart';
import 'package:xueqing/cloud/responsibility_read_repository.dart';
import 'package:xueqing/cloud/responsibility_scoped_learning_repository.dart';
import 'package:xueqing/features/design_v2/v2_organization_workspace_page.dart';
import 'package:xueqing/features/design_v2/v2_read_model_adapter.dart';
import 'package:xueqing/features/design_v2/v2_theme.dart';
import 'package:xueqing/features/teacher_workspace/workspace_runtime.dart';
import 'package:xueqing/update/update_installer.dart';
import 'package:xueqing/update/update_models.dart';
import 'package:xueqing/update/update_service.dart';

void main() {
  testWidgets(
    'Organization Quick Capture records against the selected Profile Lead and isolates its draft',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final learning = _FakeOrganizationLearningRepository();
      final drafts = _RecordingComposerDraftStore();
      await tester.pumpWidget(
        _app(
          learning: learning,
          responsibility: _responsibility(leadMembershipId: 'membership-lead'),
          drafts: drafts,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('主责：语文 张老师'), findsOneWidget);
      await tester.tap(
        find.byKey(const Key('v2-organization-quick-capture-student-1')),
      );
      await tester.pumpAndSettle();

      expect(find.text('记录新问题'), findsOneWidget);
      expect(drafts.lastLoadedScope, isNotNull);
      expect(drafts.lastLoadedScope, endsWith(':organization'));
      expect(
        drafts.lastLoadedScope,
        isNot(equals('quick-capture:user-manager:org-1')),
      );

      await tester.enterText(
        find.byKey(const Key('v2-quick-capture-body')),
        '阅读概括遗漏结果要点。',
      );
      await tester.pump();
      final save = find.widgetWithText(FilledButton, '记录问题');
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();

      expect(learning.organizationCalls, 1);
      expect(learning.legacyCalls, 0);
      expect(learning.lastExpectedResponsibility, 'membership-lead');
      expect(learning.lastCommand?.profileId, 'profile-cn');
      expect(learning.lastCommand?.evidenceSummary, '阅读概括遗漏结果要点。');
      expect(find.text('记录新问题'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Organization Quick Capture fails closed when the Profile has no Lead',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final learning = _FakeOrganizationLearningRepository();
      await tester.pumpWidget(
        _app(
          learning: learning,
          responsibility: _responsibility(leadMembershipId: null),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('未设置主责'), findsOneWidget);
      await tester.tap(
        find.byKey(const Key('v2-organization-quick-capture-student-1')),
      );
      await tester.pump();

      expect(find.text('记录新问题'), findsNothing);
      expect(find.textContaining('先设置主责老师后再建立正式学情'), findsOneWidget);
      expect(learning.organizationCalls, 0);
      expect(learning.legacyCalls, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'stale Lead conflict preserves the draft and asks the supervisor to refresh',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final learning = _FakeOrganizationLearningRepository(
        saveError: StateError('responsibility_conflict'),
      );
      await tester.pumpWidget(
        _app(
          learning: learning,
          responsibility: _responsibility(leadMembershipId: 'membership-lead'),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('v2-organization-quick-capture-student-1')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('v2-quick-capture-body')),
        '这段文字在主责变化后不能丢。',
      );
      final save = find.widgetWithText(FilledButton, '记录问题');
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();

      expect(learning.organizationCalls, 1);
      expect(find.text('记录新问题'), findsOneWidget);
      expect(find.text('这段文字在主责变化后不能丢。'), findsOneWidget);
      expect(find.textContaining('主责老师刚刚发生变化'), findsOneWidget);
      expect(find.textContaining('刷新学情后再记录'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

Widget _app({
  required _FakeOrganizationLearningRepository learning,
  required WorkspaceResponsibilityContext responsibility,
  ComposerDraftStore? drafts,
}) {
  final workspace = _workspace();
  return MaterialApp(
    theme: V2Theme.light(),
    home: V2OrganizationWorkspacePage(
      workspace: workspace,
      workspaceData: V2ReadModelAdapter.fromWorkspace(workspace).workspaceData,
      responsibility: responsibility,
      runtime: AuthenticatedWorkspaceRuntime(
        learningRepository: learning,
        progressiveCaseRepository: _FakeProgressiveCaseRepository(),
        updateService: UpdateService(currentVersion: '0.3.8'),
        updateInstaller: _FakeUpdateInstaller(),
        caseReopenDraftStore: _FakeCaseReopenDraftStore(),
        composerDraftStore: drafts,
        appVersion: '0.3.8',
        sessionUserId: 'user-manager',
      ),
    ),
  );
}

TeacherWorkspace _workspace() => TeacherWorkspace(
  viewerName: '李老师',
  organizationName: '测试机构',
  organizationTimeZone: 'Asia/Shanghai',
  organizationId: 'org-1',
  hasTeachingAccess: true,
  canManageOrganization: true,
  roles: const ['org_admin'],
  loadedAt: DateTime(2026, 9, 12, 12),
  businessDate: DateTime(2026, 9, 12),
  students: [
    WorkspaceStudent(
      id: 'student-1',
      profileId: 'profile-cn',
      profileVersion: 3,
      name: '机构学生',
      grade: '初三',
      subject: '语文',
      context: '',
      positioning: null,
      strengths: null,
      cadenceNote: null,
      cases: const [],
      recentFacts: const [],
    ),
  ],
);

WorkspaceResponsibilityContext _responsibility({
  required String? leadMembershipId,
}) => WorkspaceResponsibilityContext(
  organizationId: 'org-1',
  currentMembershipId: 'membership-manager',
  personalAssignments: const [],
  caseOwnerMembershipIds: const {},
  actionAssignedMembershipIds: const {},
  eventActorMembershipIds: const {},
  memberDisplayNames: const {
    'membership-manager': '李老师',
    'membership-lead': '张老师',
  },
  profileLeadMembershipIds: {'profile-cn': leadMembershipId},
);

class _FakeOrganizationLearningRepository
    implements LearningRepository, OrganizationQuickCaptureRepository {
  _FakeOrganizationLearningRepository({this.saveError});

  final Object? saveError;
  int organizationCalls = 0;
  int legacyCalls = 0;
  QuickCaptureCommand? lastCommand;
  String? lastExpectedResponsibility;

  @override
  Future<QuickCaptureReceipt> quickCaptureForOrganization(
    QuickCaptureCommand command, {
    required String expectedResponsibilityMembershipId,
  }) async {
    organizationCalls += 1;
    lastCommand = command;
    lastExpectedResponsibility = expectedResponsibilityMembershipId;
    final error = saveError;
    if (error != null) throw error;
    return QuickCaptureReceipt(
      operationId: command.operationId,
      caseId: 'case-created',
      evidenceId: 'evidence-created',
      status: 'new',
      caseVersion: 1,
    );
  }

  @override
  Future<QuickCaptureReceipt> quickCapture(QuickCaptureCommand command) async {
    legacyCalls += 1;
    throw StateError('legacy Quick Capture must not be used in Organization');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

class _FakeProgressiveCaseRepository implements ProgressiveCaseRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

class _RecordingComposerDraftStore implements ComposerDraftStore {
  String? lastLoadedScope;

  @override
  Future<ComposerDraftSnapshot?> load(String scopeKey) async {
    lastLoadedScope = scopeKey;
    return null;
  }

  @override
  Future<void> save(String scopeKey, ComposerDraftSnapshot snapshot) async {}

  @override
  Future<void> clear(String scopeKey) async {}
}

class _FakeUpdateInstaller implements UpdateInstaller {
  @override
  Future<UpdateInstallResult> install(UpdateDownloadedArtifact update) async =>
      const UpdateInstallResult(shouldExit: false);
}

class _FakeCaseReopenDraftStore implements CaseReopenDraftStore {
  @override
  Future<void> clear(String scopeKey) async {}

  @override
  Future<CaseReopenDraft?> load(String scopeKey) async => null;

  @override
  Future<void> save(String scopeKey, CaseReopenDraft draft) async {}
}
