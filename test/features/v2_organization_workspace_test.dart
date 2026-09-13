import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xueqing/cloud/case_reopen_draft_store.dart';
import 'package:xueqing/cloud/learning_repository.dart';
import 'package:xueqing/cloud/organization_management_repository.dart';
import 'package:xueqing/cloud/responsibility_read_repository.dart';
import 'package:xueqing/features/design_v2/v2_organization_workspace_page.dart';
import 'package:xueqing/features/design_v2/v2_read_model_adapter.dart';
import 'package:xueqing/features/design_v2/v2_theme.dart';
import 'package:xueqing/features/design_v2/v2_workspace_loader.dart';
import 'package:xueqing/features/teacher_workspace/workspace_runtime.dart';
import 'package:xueqing/update/update_installer.dart';
import 'package:xueqing/update/update_service.dart';

void main() {
  testWidgets(
    'Organization learning is a responsibility-aware supervision workspace',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1100, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final workspace = _workspace();
      await tester.pumpWidget(
        MaterialApp(
          theme: V2Theme.light(),
          home: V2OrganizationWorkspacePage(
            workspace: workspace,
            workspaceData: V2ReadModelAdapter.fromWorkspace(workspace)
                .workspaceData,
            responsibility: _context(personalProfileIds: const []),
            runtime: _runtime(includeManagement: false),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('机构'), findsOneWidget);
      expect(
        find.byKey(const Key('v2-organization-page-header')),
        findsOneWidget,
      );
      expect(find.byType(AppBar), findsNothing);
      expect(find.text('机构学情'), findsNothing);
      expect(find.text('学情监督'), findsOneWidget);
      expect(find.text('管理'), findsOneWidget);
      expect(find.text('2 名学生 · 2 个问题正在跟进'), findsOneWidget);
      expect(find.text('需要关注：1 个学科未明确主责'), findsOneWidget);
      expect(find.textContaining('机构操作不会自动改变教师主责'), findsNothing);
      expect(find.byKey(const Key('v2-today-quick-capture')), findsNothing);
      expect(
        find.byKey(const Key('v2-organization-supervision-split')),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.expand_more), findsNothing);
      expect(find.textContaining('语文 · 张老师'), findsNothing);
      expect(find.text('1 个跟进中'), findsOneWidget);
      expect(find.text('1 门学科未明确主责'), findsOneWidget);
      expect(find.textContaining('个跟进中 ·'), findsNothing);
      expect(find.widgetWithText(TextButton, '记录问题'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('v2-organization-student-list')),
          matching: find.byType(Divider),
        ),
        findsNothing,
      );

      await tester.tap(
        find.byKey(const Key('v2-organization-student-select-student-a')),
      );
      await tester.pumpAndSettle();
      expect(find.text('跟进中'), findsWidgets);
      expect(
        find.byKey(const ValueKey<String>('v2-organization-priority-case-a')),
        findsOneWidget,
      );
      expect(find.text('优先处理'), findsOneWidget);
      expect(find.text('负责：张老师'), findsOneWidget);
      expect(find.text('下一步：下一次继续检查'), findsOneWidget);
      expect(find.text('其他当前问题'), findsNothing);
      expect(find.text('最近记录：李老师 · 机构协作'), findsOneWidget);

      await tester.tap(
        find.byKey(const Key('v2-organization-student-select-student-b')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('v2-organization-priority-case-b')),
        findsOneWidget,
      );
      expect(find.text('负责：王老师'), findsOneWidget);
      // Profile B still has no current Lead. Existing Case B nevertheless keeps
      // its persisted Case owner instead of inheriting the Profile Lead state.
      expect(find.text('教学主责：未设置主责'), findsOneWidget);
      expect(find.textContaining('语文 · 未设置主责'), findsOneWidget);
      expect(find.text('最近记录：王老师 · 机构协作'), findsNothing);

      await tester.enterText(
        find.byKey(const Key('v2-organization-learning-search')),
        '张老师',
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('v2-organization-student-select-student-a')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('v2-organization-student-select-student-b')),
        findsNothing,
      );

      await tester.enterText(
        find.byKey(const Key('v2-organization-learning-search')),
        '王老师',
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('v2-organization-student-select-student-a')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('v2-organization-student-select-student-b')),
        findsOneWidget,
      );
    },
  );

  testWidgets('medium Organization learning keeps stacked supervision rows', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final workspace = _workspace();
    await tester.pumpWidget(
      MaterialApp(
        theme: V2Theme.light(),
        home: V2OrganizationWorkspacePage(
          workspace: workspace,
          workspaceData: V2ReadModelAdapter.fromWorkspace(workspace)
              .workspaceData,
          responsibility: _context(personalProfileIds: const []),
          runtime: _runtime(includeManagement: false),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('v2-organization-supervision-split')),
      findsNothing,
    );
    expect(find.byType(ExpansionTile), findsWidgets);
    expect(find.text('1 个跟进中'), findsOneWidget);
    expect(find.text('1 门学科未明确主责'), findsOneWidget);
    expect(find.textContaining('语文 · 张老师'), findsNothing);
    expect(find.widgetWithText(TextButton, '记录问题'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('organization attention filters are factual and actionable', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1100, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final workspace = _workspace();
    await tester.pumpWidget(
      MaterialApp(
        theme: V2Theme.light(),
        home: V2OrganizationWorkspacePage(
          workspace: workspace,
          workspaceData: V2ReadModelAdapter.fromWorkspace(workspace)
              .workspaceData,
          responsibility: _context(personalProfileIds: const []),
          runtime: _runtime(includeManagement: false),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('v2-organization-student-select-student-a')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('v2-organization-student-select-student-b')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('v2-organization-filter-more')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('v2-organization-filter-unassigned')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('v2-organization-student-select-student-a')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('v2-organization-student-select-student-b')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('v2-organization-filter-attention')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('v2-organization-student-select-student-a')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('v2-organization-student-select-student-b')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('v2-organization-filter-more')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('v2-organization-filter-overdue')));
    await tester.pumpAndSettle();
    expect(find.text('当前没有符合这个关注条件的学生。'), findsOneWidget);
  });

  testWidgets(
    'Personal rail yields refresh ownership to Organization scope on desktop and medium',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1100, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final managementRepository = _FakeOrganizationManagementRepository();
      await tester.pumpWidget(
        MaterialApp(
          theme: V2Theme.light(),
          home: V2WorkspaceLoader(
            loadWorkspace: () async => _workspace(),
            responsibilityReadRepository: _FakeResponsibilityRepository(
              _context(personalProfileIds: const ['profile-a']),
            ),
            runtime: _runtime(
              includeManagement: true,
              managementRepository: managementRepository,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('v2-workspace-refresh')), findsOneWidget);
      await tester.tap(find.byTooltip('学情监督'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('v2-organization-refresh')), findsOneWidget);
      expect(find.byKey(const Key('v2-workspace-refresh')), findsNothing);

      await tester.binding.setSurfaceSize(const Size(800, 800));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('v2-medium-shell')), findsOneWidget);
      expect(find.byKey(const Key('v2-organization-refresh')), findsOneWidget);
      expect(find.byKey(const Key('v2-workspace-refresh')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Organization scope refresh reloads activated Management without losing its area',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1100, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final workspace = _workspace();
      final managementRepository = _FakeOrganizationManagementRepository();
      var outerRefreshCount = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: V2Theme.light(),
          home: V2OrganizationWorkspacePage(
            workspace: workspace,
            workspaceData: V2ReadModelAdapter.fromWorkspace(workspace)
                .workspaceData,
            responsibility: _context(personalProfileIds: const []),
            runtime: _runtime(
              includeManagement: true,
              managementRepository: managementRepository,
            ),
            onRefresh: () async => outerRefreshCount++,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(managementRepository.listStudentsCount, 0);
      await tester.tap(find.text('管理').last);
      await tester.pumpAndSettle();
      expect(managementRepository.listStudentsCount, 1);

      await tester.tap(find.byKey(const Key('management-area-people')));
      await tester.pumpAndSettle();
      expect(find.text('机构成员'), findsOneWidget);

      final previousLoadCount = managementRepository.listStudentsCount;
      await tester.tap(find.byKey(const Key('v2-organization-refresh')));
      await tester.pumpAndSettle();

      expect(outerRefreshCount, 1);
      expect(
        managementRepository.listStudentsCount,
        greaterThan(previousLoadCount),
      );
      expect(find.text('机构成员'), findsOneWidget);
      expect(find.byKey(const Key('management-area-people')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Organization scope refresh shows pending feedback and blocks duplicate taps',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1100, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final completer = Completer<void>();
      var refreshCount = 0;
      final workspace = _workspace();
      await tester.pumpWidget(
        MaterialApp(
          theme: V2Theme.light(),
          home: V2OrganizationWorkspacePage(
            workspace: workspace,
            workspaceData: V2ReadModelAdapter.fromWorkspace(workspace)
                .workspaceData,
            responsibility: _context(personalProfileIds: const []),
            runtime: _runtime(includeManagement: false),
            onRefresh: () {
              refreshCount++;
              return completer.future;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final refreshFinder = find.byKey(const Key('v2-organization-refresh'));
      expect(refreshFinder, findsOneWidget);
      await tester.tap(refreshFinder);
      await tester.pump();

      expect(refreshCount, 1);
      expect(
        find.byKey(const Key('v2-organization-refresh-progress')),
        findsOneWidget,
      );
      expect(tester.widget<IconButton>(refreshFinder).onPressed, isNull);

      completer.complete();
      await tester.pumpAndSettle();

      expect(refreshCount, 1);
      expect(
        find.byKey(const Key('v2-organization-refresh-progress')),
        findsNothing,
      );
      expect(tester.widget<IconButton>(refreshFinder).onPressed, isNotNull);
      expect(tester.takeException(), isNull);
    },
  );

  test('soft refresh callers join one coalesced refresh cycle', () {
    final loader = File('lib/features/design_v2/v2_workspace_loader.dart')
        .readAsStringSync();

    expect(loader, contains('Future<void>? _softRefreshInFlight;'));
    expect(loader, contains('return running;'));
    expect(loader, contains('Future<void> _runSoftRefreshLoop() async'));
    expect(loader, contains('finalAttemptFailed = false;'));
    expect(loader, isNot(contains('bool _softRefreshRunning = false;')));
  });

  testWidgets('manager without Personal Assignment enters Organization root', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: V2Theme.light(),
        home: V2WorkspaceLoader(
          loadWorkspace: () async => _workspace(),
          responsibilityReadRepository: _FakeResponsibilityRepository(
            _context(personalProfileIds: const []),
          ),
          runtime: _runtime(includeManagement: true),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('暂时没有任课学情'), findsNothing);
    expect(find.text('机构'), findsOneWidget);
    expect(find.text('机构学生一'), findsOneWidget);
    expect(find.text('机构学生二'), findsOneWidget);
    expect(
      find.byKey(const Key('v2-organization-section-switch')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('v2-organization-refresh')), findsOneWidget);
  });
}

AuthenticatedWorkspaceRuntime _runtime({
  required bool includeManagement,
  OrganizationManagementRepository? managementRepository,
}) {
  return AuthenticatedWorkspaceRuntime(
    learningRepository: _FakeLearningRepository(),
    organizationManagementRepository: includeManagement
        ? managementRepository ?? _FakeOrganizationManagementRepository()
        : null,
    updateService: UpdateService(currentVersion: '0.3.8'),
    updateInstaller: _FakeUpdateInstaller(),
    caseReopenDraftStore: _FakeCaseReopenDraftStore(),
    appVersion: '0.3.8',
    sessionUserId: 'user-manager',
  );
}

class _FakeResponsibilityRepository implements ResponsibilityReadRepository {
  _FakeResponsibilityRepository(this.context);

  final WorkspaceResponsibilityContext context;

  @override
  Future<WorkspaceResponsibilityContext> loadContext({
    required String organizationId,
  }) async {
    expect(organizationId, 'org-1');
    return context;
  }
}

class _FakeLearningRepository implements LearningRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

class _FakeOrganizationManagementRepository
    implements OrganizationManagementRepository {
  int listStudentsCount = 0;

  @override
  Future<List<OrganizationMember>> listMembers({
    required String organizationId,
  }) async => const [];

  @override
  Future<List<OrganizationInvitation>> listInvitations({
    required String organizationId,
  }) async => const [];

  @override
  Future<List<OrganizationStudentRecord>> listStudents({
    required String organizationId,
  }) async {
    listStudentsCount++;
    return const [];
  }

  @override
  Future<OrganizationSetupOptions> listSetupOptions({
    required String organizationId,
  }) async => const OrganizationSetupOptions(
    subjects: [OrganizationSetupSubject(id: 'subject-1', displayName: '语文')],
    teachers: [
      OrganizationSetupTeacher(
        membershipId: 'membership-manager',
        displayName: '李老师',
        email: 'manager@example.com',
        organizationSubjectIds: ['subject-1'],
      ),
    ],
  );

  @override
  Future<List<OrganizationSubjectCatalogItem>> listSubjectCatalog({
    required String organizationId,
  }) async => const [];

  @override
  Future<List<OrganizationTeacherSubjectScope>> listTeacherSubjectScopes({
    required String organizationId,
  }) async => const [];

  @override
  Future<List<OrganizationStudentTeacherAssignment>>
  listStudentTeacherAssignments({required String organizationId}) async =>
      const [];

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
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

WorkspaceResponsibilityContext _context({
  required List<String> personalProfileIds,
}) {
  return WorkspaceResponsibilityContext(
    organizationId: 'org-1',
    currentMembershipId: 'membership-manager',
    personalAssignments: [
      for (final profileId in personalProfileIds)
        WorkspacePersonalAssignment(
          assignmentId: 'assignment-$profileId',
          profileId: profileId,
          membershipId: 'membership-manager',
          assignmentRole: 'collaborator',
          businessDate: DateTime(2026, 9, 12),
        ),
    ],
    caseOwnerMembershipIds: const {
      'case-a': 'membership-lead',
      'case-b': 'membership-other',
    },
    actionAssignedMembershipIds: const {
      'action-a': 'membership-lead',
      'action-b': 'membership-other',
    },
    eventActorMembershipIds: const {
      'event-manager-a': 'membership-manager',
      'event-owner-b': 'membership-other',
    },
    memberDisplayNames: const {
      'membership-manager': '李老师',
      'membership-lead': '张老师',
      'membership-other': '王老师',
    },
    profileLeadMembershipIds: const {
      'profile-a': 'membership-lead',
      'profile-b': null,
    },
  );
}

TeacherWorkspace _workspace() {
  return TeacherWorkspace(
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
      _profile(
        studentId: 'student-a',
        profileId: 'profile-a',
        name: '机构学生一',
        caseId: 'case-a',
        actionId: 'action-a',
        title: '阅读概括遗漏要点',
        timeline: [
          WorkspaceTimelineEvent(
            id: 'evidence:evidence-a',
            responsibilityEventId: 'event-manager-a',
            occurredAt: DateTime(2026, 9, 12, 11),
            typeLabel: '学生表现',
            text: '负责人补充了一次课堂观察。',
          ),
        ],
      ),
      _profile(
        studentId: 'student-b',
        profileId: 'profile-b',
        name: '机构学生二',
        caseId: 'case-b',
        actionId: 'action-b',
        title: '作文立意不稳定',
        timeline: [
          WorkspaceTimelineEvent(
            id: 'event-owner-b',
            responsibilityEventId: 'event-owner-b',
            occurredAt: DateTime(2026, 9, 12, 10),
            typeLabel: '记录',
            text: '王老师继续跟进。',
          ),
        ],
      ),
    ],
  );
}

WorkspaceStudent _profile({
  required String studentId,
  required String profileId,
  required String name,
  required String caseId,
  required String actionId,
  required String title,
  List<WorkspaceTimelineEvent> timeline = const <WorkspaceTimelineEvent>[],
}) {
  return WorkspaceStudent(
    id: studentId,
    profileId: profileId,
    profileVersion: 1,
    name: name,
    grade: '初三',
    subject: '语文',
    context: '',
    positioning: null,
    strengths: null,
    cadenceNote: null,
    recentFacts: const [],
    cases: [
      WorkspaceCase(
        id: caseId,
        profileId: profileId,
        title: title,
        type: LearningCaseType.knowledge,
        status: LearningCaseStatus.intervening,
        priority: 'normal',
        description: title,
        firstObservedAt: DateTime(2026, 9, 10),
        version: 1,
        evidence: const [],
        interventions: const [],
        assessments: const [],
        actions: [
          WorkspaceAction(
            id: actionId,
            caseId: caseId,
            title: '下一次继续检查',
            actionType: 'verify',
            status: WorkspaceActionStatus.pending,
            isPrimary: true,
            bucket: WorkspaceActionBucket.today,
            version: 1,
            dueAt: DateTime(2026, 9, 12, 18),
            businessDueDate: DateTime(2026, 9, 12),
          ),
        ],
        timeline: timeline,
      ),
    ],
  );
}
