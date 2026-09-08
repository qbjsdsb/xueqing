import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xueqing/app/theme/app_theme.dart';
import 'package:xueqing/cloud/case_reopen_draft_store.dart';
import 'package:xueqing/cloud/learning_repository.dart';
import 'package:xueqing/features/teacher_workspace/presentation/'
    'teacher_workspace_page.dart';

class _FakeLearningRepository implements LearningRepository {
  _FakeLearningRepository(this.workspace);

  TeacherWorkspace workspace;
  Object? loadError;
  int loadCount = 0;
  Completer<TeacherWorkspace>? nextLoad;
  int saveCount = 0;
  bool failFirstSave = false;
  bool failFirstClose = false;
  bool failFirstReschedule = false;
  bool failFirstComplete = false;
  bool failFirstEvidence = false;
  bool failFirstReopen = false;
  int addEvidenceCount = 0;
  int reopenCount = 0;
  final List<QuickCaptureCommand> commands = <QuickCaptureCommand>[];
  int confirmCount = 0;
  int interventionCount = 0;
  int assessmentCount = 0;
  int stabilizeCount = 0;
  int closeCount = 0;
  int rescheduleCount = 0;
  int completeCount = 0;
  final List<AddCaseEvidenceCommand> addEvidenceCommands =
      <AddCaseEvidenceCommand>[];
  final List<ReopenCaseCommand> reopenCommands = <ReopenCaseCommand>[];
  final List<CloseCaseCommand> closeCommands = <CloseCaseCommand>[];
  final List<ConfirmCaseCommand> confirmCommands = <ConfirmCaseCommand>[];
  final List<RecordInterventionCommand> interventionCommands =
      <RecordInterventionCommand>[];
  final List<RecordAssessmentCommand> assessmentCommands =
      <RecordAssessmentCommand>[];
  final List<RescheduleCaseActionCommand> rescheduleCommands =
      <RescheduleCaseActionCommand>[];
  final List<CompleteCaseActionCommand> completeCommands =
      <CompleteCaseActionCommand>[];

  @override
  Future<TeacherWorkspace> loadWorkspace() async {
    loadCount++;
    if (loadError != null) {
      throw loadError!;
    }
    final pendingLoad = nextLoad;
    nextLoad = null;
    if (pendingLoad != null) {
      return pendingLoad.future;
    }
    return workspace;
  }

  @override
  Future<QuickCaptureReceipt> quickCapture(QuickCaptureCommand command) async {
    saveCount++;
    commands.add(command);
    if (failFirstSave && saveCount == 1) {
      throw StateError('network unavailable');
    }
    return QuickCaptureReceipt(
      operationId: command.operationId,
      caseId: 'case-created',
      evidenceId: 'evidence-created',
      actionId: 'action-created',
      status: 'new',
      caseVersion: 1,
    );
  }

  @override
  Future<WorkspaceCaseType> createCaseType({
    required String organizationId,
    required String displayName,
    required LearningCaseType baseType,
  }) async {
    return WorkspaceCaseType(
      id: 'case-type-created',
      displayName: displayName,
      baseType: baseType,
      status: 'active',
      sortOrder: 0,
      version: 1,
    );
  }

  @override
  Future<WorkspaceCaseType> renameCaseType({
    required String caseTypeId,
    required String displayName,
    required int expectedVersion,
  }) async {
    return WorkspaceCaseType(
      id: caseTypeId,
      displayName: displayName,
      baseType: LearningCaseType.knowledge,
      status: 'active',
      sortOrder: 0,
      version: expectedVersion + 1,
    );
  }

  @override
  Future<WorkspaceCaseType> archiveCaseType({
    required String caseTypeId,
    required int expectedVersion,
  }) async {
    return WorkspaceCaseType(
      id: caseTypeId,
      displayName: '已归档类型',
      baseType: LearningCaseType.knowledge,
      status: 'archived',
      sortOrder: 0,
      version: expectedVersion + 1,
    );
  }

  @override
  Future<CaseCommandReceipt> confirmCase(ConfirmCaseCommand command) async {
    confirmCount++;
    confirmCommands.add(command);
    return _caseReceipt(
      command.operationId,
      command.caseId,
      'confirmed',
      command.expectedCaseVersion + 1,
    );
  }

  @override
  Future<CaseCommandReceipt> recordIntervention(
    RecordInterventionCommand command,
  ) async {
    interventionCount++;
    interventionCommands.add(command);
    return _caseReceipt(
      command.operationId,
      command.caseId,
      'intervening',
      command.expectedCaseVersion + 1,
    );
  }

  @override
  Future<CaseCommandReceipt> recordAssessment(
    RecordAssessmentCommand command,
  ) async {
    assessmentCount++;
    assessmentCommands.add(command);
    final status = command.result == CaseAssessmentResult.notPassed
        ? 'intervening'
        : 'pending_verification';
    return _caseReceipt(
      command.operationId,
      command.caseId,
      status,
      command.expectedCaseVersion + 1,
    );
  }

  @override
  Future<CaseCommandReceipt> stabilizeCase(StabilizeCaseCommand command) async {
    stabilizeCount++;
    return _caseReceipt(
      command.operationId,
      command.caseId,
      'stable',
      command.expectedCaseVersion + 1,
    );
  }

  @override
  Future<CaseCommandReceipt> closeCase(CloseCaseCommand command) async {
    closeCount++;
    closeCommands.add(command);
    if (failFirstClose && closeCount == 1) {
      throw StateError('network unavailable');
    }
    return CaseCommandReceipt(
      operationId: command.operationId,
      caseId: command.caseId,
      actionId: null,
      eventId: 'event-closed',
      status: 'closed',
      caseVersion: command.expectedCaseVersion + 1,
    );
  }

  @override
  Future<CaseCommandReceipt> addCaseEvidence(
    AddCaseEvidenceCommand command,
  ) async {
    addEvidenceCount++;
    addEvidenceCommands.add(command);
    if (failFirstEvidence && addEvidenceCount == 1) {
      throw StateError('case_recurrence_before_close');
    }
    return CaseCommandReceipt(
      operationId: command.operationId,
      caseId: command.caseId,
      actionId: null,
      eventId: 'event-evidence',
      status: 'closed',
      caseVersion: command.expectedCaseVersion,
      recordId: 'evidence-recurrence',
    );
  }

  @override
  Future<CaseCommandReceipt> reopenCase(ReopenCaseCommand command) async {
    reopenCount++;
    reopenCommands.add(command);
    if (failFirstReopen && reopenCount == 1) {
      throw StateError('network unavailable');
    }
    return CaseCommandReceipt(
      operationId: command.operationId,
      caseId: command.caseId,
      actionId: 'action-reopened',
      eventId: 'event-reopened',
      status: 'confirmed',
      caseVersion: command.expectedCaseVersion + 1,
    );
  }

  @override
  Future<CaseCommandReceipt> rescheduleCaseAction(
    RescheduleCaseActionCommand command,
  ) async {
    rescheduleCount++;
    rescheduleCommands.add(command);
    if (failFirstReschedule && rescheduleCount == 1) {
      throw StateError('network unavailable');
    }
    return _caseReceipt(
      command.operationId,
      command.caseId,
      'confirmed',
      command.expectedCaseVersion + 1,
    );
  }

  @override
  Future<CaseCommandReceipt> completeCaseAction(
    CompleteCaseActionCommand command,
  ) async {
    completeCount++;
    completeCommands.add(command);
    if (failFirstComplete && completeCount == 1) {
      throw StateError('network unavailable');
    }
    return _caseReceipt(
      command.operationId,
      command.caseId,
      'confirmed',
      command.expectedCaseVersion + 1,
    );
  }

  CaseCommandReceipt _caseReceipt(
    String operationId,
    String caseId,
    String status,
    int caseVersion,
  ) {
    return CaseCommandReceipt(
      operationId: operationId,
      caseId: caseId,
      actionId: 'action-follow-up',
      eventId: 'event-follow-up',
      status: status,
      caseVersion: caseVersion,
      recordId: 'record-follow-up',
    );
  }
}

TeacherWorkspace _fixtureWorkspace({
  LearningCaseStatus status = LearningCaseStatus.newCase,
  String actionType = 'practice',
  List<WorkspaceCaseType>? caseTypes,
  bool canManageCaseTypes = false,
  String? assessmentResult,
  DateTime? businessDate,
  DateTime? businessDueDate,
}) {
  final action = WorkspaceAction(
    id: 'action-1',
    caseId: 'case-1',
    title: '补充一次课堂证据',
    actionType: actionType,
    status: WorkspaceActionStatus.pending,
    isPrimary: true,
    bucket: WorkspaceActionBucket.today,
    version: 1,
    dueAt: DateTime(2026, 9, 3),
    businessDueDate: businessDueDate,
  );
  final learningCase = WorkspaceCase(
    id: 'case-1',
    profileId: 'profile-1',
    title: '分数步骤需要继续观察',
    type: LearningCaseType.knowledge,
    status: status,
    priority: 'high',
    description: '学生在新题中跳过通分步骤。',
    firstObservedAt: DateTime(2026, 9, 3),
    version: 1,
    evidence: const <WorkspaceEvidence>[],
    interventions: const <WorkspaceIntervention>[],
    assessments: assessmentResult == null
        ? const <WorkspaceAssessment>[]
        : [
            WorkspaceAssessment(
              id: 'assessment-1',
              result: assessmentResult,
              evidenceSummary: '学生已能独立完成。',
              notes: null,
              assessedAt: DateTime(2026, 9, 3),
            ),
          ],
    actions: status == LearningCaseStatus.closed
        ? const <WorkspaceAction>[]
        : <WorkspaceAction>[action],
    timeline: const <WorkspaceTimelineEvent>[],
  );
  return TeacherWorkspace(
    viewerName: '王老师',
    organizationName: '虚构机构',
    organizationTimeZone: 'Asia/Shanghai',
    hasTeachingAccess: true,
    organizationId: 'org-1',
    caseTypes: caseTypes ?? WorkspaceCaseType.builtInTypes,
    canManageCaseTypes: canManageCaseTypes,
    students: [
      WorkspaceStudent(
        id: 'student-1',
        profileId: 'profile-1',
        profileVersion: 1,
        name: '示例学生甲',
        grade: '初二',
        subject: '数学',
        context: '函数基础',
        positioning: '函数基础需要持续巩固',
        strengths: '愿意复盘错题',
        cadenceNote: '每周一次',
        cases: [learningCase],
        recentFacts: const <WorkspaceTimelineEvent>[],
      ),
    ],
    loadedAt: DateTime(2026, 9, 3),
    businessDate: businessDate,
  );
}

WorkspaceStudent _studentFixture({
  required String id,
  required String name,
  DateTime? recentActivityAt,
  DateTime? actionDueAt,
  WorkspaceActionBucket actionBucket = WorkspaceActionBucket.overdue,
  String? actionTitle,
  List<WorkspaceCase>? cases,
}) {
  final learningCase = actionDueAt == null
      ? null
      : WorkspaceCase(
          id: 'case-$id',
          profileId: 'profile-$id',
          title: '$name 的学习问题',
          type: LearningCaseType.knowledge,
          status: LearningCaseStatus.confirmed,
          priority: 'high',
          description: null,
          firstObservedAt: DateTime(2026, 9, 1),
          version: 1,
          evidence: const <WorkspaceEvidence>[],
          interventions: const <WorkspaceIntervention>[],
          assessments: const <WorkspaceAssessment>[],
          actions: [
            WorkspaceAction(
              id: 'action-$id',
              caseId: 'case-$id',
              title: actionTitle ?? '$name 的下一步',
              actionType: 'practice',
              status: WorkspaceActionStatus.pending,
              isPrimary: true,
              bucket: actionBucket,
              version: 1,
              dueAt: actionDueAt,
              businessDueDate: actionDueAt,
            ),
          ],
          timeline: const <WorkspaceTimelineEvent>[],
        );
  return WorkspaceStudent(
    id: 'student-$id',
    profileId: 'profile-$id',
    profileVersion: 1,
    name: name,
    grade: '初二',
    subject: '数学',
    context: '课堂学习',
    positioning: null,
    strengths: null,
    cadenceNote: null,
    cases: cases ?? (learningCase == null ? const [] : [learningCase]),
    recentFacts: recentActivityAt == null
        ? const []
        : [
            WorkspaceTimelineEvent(
              id: 'event-$id',
              occurredAt: recentActivityAt,
              typeLabel: '课堂证据',
              text: '$name 的课堂记录',
            ),
          ],
  );
}

WorkspaceCase _caseFixture({
  required String id,
  required String title,
  required LearningCaseStatus status,
  required WorkspaceActionBucket actionBucket,
  required DateTime? actionDueAt,
  String priority = 'normal',
  List<WorkspaceTimelineEvent> timeline = const <WorkspaceTimelineEvent>[],
}) {
  return WorkspaceCase(
    id: 'case-$id',
    profileId: 'profile-detail',
    title: title,
    type: LearningCaseType.knowledge,
    status: status,
    priority: priority,
    description: null,
    firstObservedAt: DateTime(2026, 8, 1),
    version: 1,
    evidence: const <WorkspaceEvidence>[],
    interventions: const <WorkspaceIntervention>[],
    assessments: const <WorkspaceAssessment>[],
    actions: [
      WorkspaceAction(
        id: 'action-$id',
        caseId: 'case-$id',
        title: '$title 的下一步',
        actionType: 'practice',
        status: WorkspaceActionStatus.pending,
        isPrimary: true,
        bucket: actionBucket,
        version: 1,
        dueAt: actionDueAt,
        businessDueDate: actionDueAt,
      ),
    ],
    timeline: timeline,
  );
}

TeacherWorkspace _workspaceWithStudents(List<WorkspaceStudent> students) {
  return TeacherWorkspace(
    viewerName: '王老师',
    organizationName: '虚构机构',
    organizationTimeZone: 'Asia/Shanghai',
    hasTeachingAccess: true,
    students: students,
    loadedAt: DateTime(2026, 9, 5),
    businessDate: DateTime(2026, 9, 5),
  );
}

Future<void> _pumpWorkspace(
  WidgetTester tester,
  _FakeLearningRepository repository, {
  CaseReopenDraftStore? draftStore,
  String? sessionUserId,
  VoidCallback? onSignOut,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: TeacherWorkspacePage(
        key: UniqueKey(),
        repository: repository,
        caseReopenDraftStore: draftStore,
        sessionUserId: sessionUserId,
        onSignOut: onSignOut,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('medium-width rail keeps labels and sign out reachable', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    var signOutCount = 0;
    final repository = _FakeLearningRepository(_fixtureWorkspace());
    await _pumpWorkspace(tester, repository, onSignOut: () => signOutCount++);

    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(rail.extended, isFalse);
    expect(rail.labelType, NavigationRailLabelType.all);
    expect(find.byKey(const Key('workspace-rail-sign-out')), findsOneWidget);
    expect(find.text('开发数据'), findsNothing);

    await tester.tap(find.byKey(const Key('workspace-rail-sign-out')));
    expect(signOutCount, 1);
  });

  testWidgets('loads the real workspace shape and keeps Case status separate', (
    tester,
  ) async {
    final repository = _FakeLearningRepository(_fixtureWorkspace());
    await _pumpWorkspace(tester, repository);

    expect(find.text('今日'), findsWidgets);
    expect(find.text('今天到期'), findsOneWidget);
    expect(find.text('补充一次课堂证据'), findsOneWidget);
    expect(repository.loadCount, 1);

    final studentRow = find.text('示例学生甲');
    await tester.ensureVisible(studentRow);
    await tester.tap(studentRow);
    await tester.pumpAndSettle();
    expect(find.text('现在最重要的事'), findsOneWidget);
    expect(find.text('函数基础需要持续巩固'), findsOneWidget);

    final caseButton = find.widgetWithText(OutlinedButton, '查看问题').first;
    await tester.ensureVisible(caseButton);
    await tester.tap(caseButton);
    await tester.pumpAndSettle();
    expect(find.text('分数步骤需要继续观察'), findsOneWidget);
    expect(find.text('待整理问题'), findsOneWidget);
    expect(find.text('待整理'), findsOneWidget);
    expect(find.text('尚未记录教学动作。'), findsOneWidget);
  });

  testWidgets(
    'Case detail keeps the next action first and bounds older history',
    (tester) async {
      final timeline = <WorkspaceTimelineEvent>[
        for (var index = 1; index <= 5; index++)
          WorkspaceTimelineEvent(
            id: 'timeline-$index',
            occurredAt: DateTime(2026, 9, 8 - index),
            typeLabel: '课堂记录',
            text: '历史记录 $index',
          ),
      ];
      final learningCase = _caseFixture(
        id: 'case-detail',
        title: '阅读题关键问题',
        status: LearningCaseStatus.confirmed,
        actionBucket: WorkspaceActionBucket.today,
        actionDueAt: DateTime(2026, 9, 5),
        timeline: timeline,
      );
      final repository = _FakeLearningRepository(
        _workspaceWithStudents([
          _studentFixture(
            id: 'case-detail',
            name: 'Case 详情示例',
            cases: [learningCase],
          ),
        ]),
      );
      await _pumpWorkspace(tester, repository);

      final studentRow = find.text('Case 详情示例').first;
      await tester.ensureVisible(studentRow);
      await tester.tap(studentRow);
      await tester.pumpAndSettle();
      final caseButton = find.widgetWithText(OutlinedButton, '查看问题').first;
      await tester.ensureVisible(caseButton);
      await tester.tap(caseButton);
      await tester.pumpAndSettle();

      expect(find.text('下一步'), findsOneWidget);
      expect(find.text('下一步：阅读题关键问题 的下一步'), findsNothing);
      expect(find.textContaining('阅读题关键问题 的下一步'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('下一步')).dy,
        lessThan(tester.getTopLeft(find.text('问题')).dy),
      );

      expect(find.text('5 条'), findsOneWidget);
      expect(find.text('历史记录 1'), findsOneWidget);
      expect(find.text('历史记录 2'), findsOneWidget);
      expect(find.text('历史记录 3'), findsOneWidget);
      expect(find.text('历史记录 4'), findsNothing);
      expect(find.text('历史记录 5'), findsNothing);

      final timelineToggle = find.byKey(
        const Key('workspace-case-timeline-toggle'),
      );
      await tester.ensureVisible(timelineToggle);
      await tester.tap(timelineToggle);
      await tester.pumpAndSettle();
      expect(find.text('历史记录 4'), findsOneWidget);
      expect(find.text('历史记录 5'), findsOneWidget);
      expect(find.text('收起历史'), findsOneWidget);

      final backButton = find.byTooltip('返回学生详情');
      await tester.ensureVisible(backButton);
      await tester.tap(backButton);
      await tester.pumpAndSettle();
      final reopenCaseButton = find
          .widgetWithText(OutlinedButton, '查看问题')
          .first;
      await tester.ensureVisible(reopenCaseButton);
      await tester.tap(reopenCaseButton);
      await tester.pumpAndSettle();
      expect(find.text('历史记录 4'), findsNothing);
      expect(find.text('展开历史'), findsOneWidget);
    },
  );

  testWidgets(
    'bounds lower-priority Today sections until explicitly expanded',
    (tester) async {
      final cases = <WorkspaceCase>[
        for (var index = 1; index <= 4; index++)
          _caseFixture(
            id: 'pending-$index',
            title: '待验证问题 $index',
            status: LearningCaseStatus.pendingVerification,
            actionBucket: WorkspaceActionBucket.today,
            actionDueAt: DateTime(2026, 9, 5),
          ),
        for (var index = 1; index <= 4; index++)
          _caseFixture(
            id: 'future-$index',
            title: '未来问题 $index',
            status: LearningCaseStatus.confirmed,
            actionBucket: WorkspaceActionBucket.future,
            actionDueAt: DateTime(2026, 9, 5 + index),
          ),
        for (var index = 1; index <= 4; index++)
          _caseFixture(
            id: 'undated-$index',
            title: '待安排问题 $index',
            status: LearningCaseStatus.confirmed,
            actionBucket: WorkspaceActionBucket.undated,
            actionDueAt: null,
          ),
      ];
      final repository = _FakeLearningRepository(
        _workspaceWithStudents([
          _studentFixture(id: 'preview', name: '预览学生', cases: cases),
        ]),
      );
      await _pumpWorkspace(tester, repository);

      expect(find.text('4 个问题'), findsOneWidget);
      expect(find.text('之后要处理'), findsOneWidget);
      expect(find.text('待验证问题 4'), findsNothing);
      expect(find.text('未来问题 4 的下一步'), findsNothing);
      expect(find.text('待安排问题 4 的下一步'), findsNothing);

      await tester.tap(
        find.byKey(const Key('workspace-pending-verification-toggle')),
      );
      await tester.pumpAndSettle();
      expect(find.text('待验证问题 4'), findsOneWidget);

      await tester.ensureVisible(
        find.byKey(const Key('workspace-future-actions-toggle')),
      );
      await tester.tap(
        find.byKey(const Key('workspace-future-actions-toggle')),
      );
      await tester.pumpAndSettle();
      expect(find.text('未来问题 4 的下一步'), findsOneWidget);

      await tester.ensureVisible(
        find.byKey(const Key('workspace-undated-actions-toggle')),
      );
      await tester.tap(
        find.byKey(const Key('workspace-undated-actions-toggle')),
      );
      await tester.pumpAndSettle();
      expect(find.text('待安排问题 4 的下一步'), findsOneWidget);

      await tester.tap(
        find.byKey(const Key('workspace-undated-actions-toggle')),
      );
      await tester.pumpAndSettle();
      expect(find.text('待安排问题 4 的下一步'), findsNothing);
    },
  );

  testWidgets(
    'student detail keeps priorities concise and removes duplicate problem lists',
    (tester) async {
      final cases = <WorkspaceCase>[
        _caseFixture(
          id: 'urgent-1',
          title: '今天重点一',
          status: LearningCaseStatus.confirmed,
          actionBucket: WorkspaceActionBucket.overdue,
          actionDueAt: DateTime(2026, 9, 4),
        ),
        _caseFixture(
          id: 'urgent-2',
          title: '今天重点二',
          status: LearningCaseStatus.confirmed,
          actionBucket: WorkspaceActionBucket.overdue,
          actionDueAt: DateTime(2026, 9, 4),
        ),
        _caseFixture(
          id: 'urgent-3',
          title: '今天重点三',
          status: LearningCaseStatus.confirmed,
          actionBucket: WorkspaceActionBucket.today,
          actionDueAt: DateTime(2026, 9, 5),
        ),
        for (var index = 1; index <= 3; index++)
          _caseFixture(
            id: 'pending-student-$index',
            title: '待验证问题 $index',
            status: LearningCaseStatus.pendingVerification,
            actionBucket: WorkspaceActionBucket.today,
            actionDueAt: DateTime(2026, 9, 5),
          ),
      ];
      final repository = _FakeLearningRepository(
        _workspaceWithStudents([
          _studentFixture(id: 'student-detail', name: '学生详情示例', cases: cases),
        ]),
      );
      await _pumpWorkspace(tester, repository);

      final studentRow = find.text('学生详情示例').first;
      await tester.ensureVisible(studentRow);
      await tester.tap(studentRow);
      await tester.pumpAndSettle();

      expect(find.text('现在最重要的事'), findsOneWidget);
      expect(find.text('当前 Learning Cases'), findsNothing);
      expect(find.text('学科上下文'), findsNothing);
      expect(find.text('另外待验证'), findsOneWidget);
      expect(find.text('待验证问题 3'), findsNothing);
      expect(
        find.byKey(const Key('student-detail-pending-toggle')),
        findsOneWidget,
      );

      await tester.ensureVisible(
        find.byKey(const Key('student-detail-pending-toggle')),
      );
      await tester.tap(find.byKey(const Key('student-detail-pending-toggle')));
      await tester.pumpAndSettle();

      expect(find.text('全部问题'), findsOneWidget);
      expect(find.text('另外待验证'), findsNothing);
      expect(find.text('待验证问题 3'), findsOneWidget);
      expect(find.text('今天重点一'), findsOneWidget);
      expect(find.widgetWithText(TextButton, '只看重点'), findsOneWidget);
    },
  );

  testWidgets('reschedules an action from Today', (tester) async {
    final repository = _FakeLearningRepository(_fixtureWorkspace());
    await _pumpWorkspace(tester, repository);

    final rescheduleButton = find.widgetWithText(TextButton, '改期');
    expect(rescheduleButton, findsOneWidget);
    await tester.tap(rescheduleButton);
    await tester.pumpAndSettle();

    expect(find.text('改期行动'), findsOneWidget);
    final saveButton = find.widgetWithText(TextButton, '保存');
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(repository.rescheduleCount, 1);
    expect(repository.rescheduleCommands.single.actionId, 'action-1');
    expect(repository.rescheduleCommands.single.caseId, 'case-1');
    expect(repository.rescheduleCommands.single.expectedCaseVersion, 1);
    expect(repository.rescheduleCommands.single.expectedActionVersion, 1);
    expect(repository.rescheduleCommands.single.dueOn, isNotNull);
    expect(find.textContaining('行动已安排在'), findsOneWidget);
  });

  testWidgets('completes an action and asks for the next action', (
    tester,
  ) async {
    final repository = _FakeLearningRepository(
      _fixtureWorkspace(status: LearningCaseStatus.confirmed),
    );
    await _pumpWorkspace(tester, repository);

    final completeButton = find.widgetWithText(FilledButton, '完成行动');
    expect(completeButton, findsOneWidget);
    await tester.tap(completeButton);
    await tester.pumpAndSettle();

    expect(
      find.text('完成“补充一次课堂证据”后安排下一步。这个问题不会因为勾选完成就失去后续跟进。'),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('complete-action-type-dropdown')),
      findsOneWidget,
    );
    final saveButton = find.widgetWithText(FilledButton, '完成并安排下一步');
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(repository.completeCount, 1);
    expect(repository.completeCommands.single.actionId, 'action-1');
    expect(repository.completeCommands.single.caseId, 'case-1');
    expect(repository.completeCommands.single.expectedCaseVersion, 1);
    expect(repository.completeCommands.single.expectedActionVersion, 1);
    expect(
      repository.completeCommands.single.nextActionType,
      CaseActionType.verify,
    );
    expect(repository.completeCommands.single.nextActionTitle, '安排下一次验证');
    expect(find.text('行动已完成，并已安排下一步。'), findsOneWidget);
  });

  testWidgets(
    'updates autogenerated next action title after repeated type changes',
    (tester) async {
      final repository = _FakeLearningRepository(
        _fixtureWorkspace(status: LearningCaseStatus.confirmed),
      );
      await _pumpWorkspace(tester, repository);

      await tester.tap(find.widgetWithText(FilledButton, '完成行动'));
      await tester.pumpAndSettle();

      final typeDropdown = find.byKey(
        const Key('complete-action-type-dropdown'),
      );
      await tester.tap(typeDropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.text('练习').last);
      await tester.pumpAndSettle();
      expect(find.text('安排一次针对性练习'), findsOneWidget);

      await tester.tap(typeDropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.text('复查').last);
      await tester.pumpAndSettle();
      expect(find.text('安排一次复查'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, '完成并安排下一步'));
      await tester.pumpAndSettle();

      expect(repository.completeCount, 1);
      expect(
        repository.completeCommands.single.nextActionType,
        CaseActionType.review,
      );
      expect(repository.completeCommands.single.nextActionTitle, '安排一次复查');
    },
  );

  testWidgets('keeps an ambiguous completion open until it is reconciled', (
    tester,
  ) async {
    final repository = _FakeLearningRepository(
      _fixtureWorkspace(status: LearningCaseStatus.confirmed),
    )..failFirstComplete = true;
    await _pumpWorkspace(tester, repository);

    await tester.tap(find.widgetWithText(FilledButton, '完成行动'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '完成并安排下一步'));
    await tester.pumpAndSettle();

    expect(find.textContaining('提交内容已锁定'), findsOneWidget);
    final cancelButton = find.widgetWithText(OutlinedButton, '取消');
    await tester.ensureVisible(cancelButton);
    await tester.tap(cancelButton);
    await tester.pumpAndSettle();

    expect(find.text('提交结果未确认'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, '继续查看'));
    await tester.pumpAndSettle();
    expect(find.text('提交结果未确认'), findsNothing);
    expect(
      find.byKey(const Key('complete-action-type-dropdown')),
      findsOneWidget,
    );

    final retryButton = find.widgetWithText(FilledButton, '重试原提交');
    await tester.ensureVisible(retryButton);
    await tester.tap(retryButton);
    await tester.pumpAndSettle();

    expect(repository.completeCount, 2);
  });

  testWidgets('reuses operation id after a completion response is lost', (
    tester,
  ) async {
    final repository = _FakeLearningRepository(
      _fixtureWorkspace(status: LearningCaseStatus.confirmed),
    )..failFirstComplete = true;
    await _pumpWorkspace(tester, repository);

    await tester.tap(find.widgetWithText(FilledButton, '完成行动'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '完成并安排下一步'));
    await tester.pumpAndSettle();

    expect(find.textContaining('网络暂时不可用'), findsOneWidget);
    expect(find.textContaining('本次提交内容已锁定'), findsOneWidget);
    expect(repository.completeCount, 1);
    final firstOperationId = repository.completeCommands.single.operationId;
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);

    final retryButton = find.widgetWithText(FilledButton, '重试原提交');
    await tester.ensureVisible(retryButton);
    await tester.tap(retryButton);
    await tester.pumpAndSettle();

    expect(repository.completeCount, 2);
    expect(repository.completeCommands[1].operationId, firstOperationId);
  });

  testWidgets('keeps the current workspace visible while refreshing', (
    tester,
  ) async {
    final repository = _FakeLearningRepository(_fixtureWorkspace());
    await _pumpWorkspace(tester, repository);

    final pendingLoad = Completer<TeacherWorkspace>();
    repository.nextLoad = pendingLoad;
    await tester.tap(find.widgetWithText(TextButton, '改期'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '保存'));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('今天到期'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);

    pendingLoad.complete(repository.workspace);
    await tester.pumpAndSettle();

    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(repository.loadCount, 2);
  });

  testWidgets('reuses operation id after a reschedule response is lost', (
    tester,
  ) async {
    final repository = _FakeLearningRepository(_fixtureWorkspace())
      ..failFirstReschedule = true;
    await _pumpWorkspace(tester, repository);

    final rescheduleButton = find.widgetWithText(TextButton, '改期');
    await tester.tap(rescheduleButton);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '保存'));
    await tester.pumpAndSettle();

    expect(find.textContaining('网络暂时不可用'), findsOneWidget);
    expect(repository.rescheduleCount, 1);
    final firstOperationId = repository.rescheduleCommands.single.operationId;

    await tester.tap(find.widgetWithText(TextButton, '改期'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '保存'));
    await tester.pumpAndSettle();

    expect(repository.rescheduleCount, 2);
    expect(repository.rescheduleCommands[1].operationId, firstOperationId);
  });

  testWidgets('uses the organization business date for Case due dates', (
    tester,
  ) async {
    final repository = _FakeLearningRepository(
      _fixtureWorkspace(businessDate: DateTime(2026, 9, 10)),
    );
    await _pumpWorkspace(tester, repository);

    final studentRow = find.text('示例学生甲').first;
    await tester.ensureVisible(studentRow);
    await tester.tap(studentRow);
    await tester.pumpAndSettle();
    final caseButton = find.widgetWithText(OutlinedButton, '查看问题').first;
    await tester.ensureVisible(caseButton);
    await tester.tap(caseButton);
    await tester.pumpAndSettle();

    final commandButton = find.widgetWithText(FilledButton, '整理并确认问题');
    await tester.ensureVisible(commandButton);
    await tester.tap(commandButton);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, '安排日期（可选）'));
    await tester.pumpAndSettle();

    final calendar = tester.widget<CalendarDatePicker>(
      find.byType(CalendarDatePicker),
    );
    expect(calendar.firstDate, DateTime(2026, 9, 10));
  });

  testWidgets('uses the organization business date for action display', (
    tester,
  ) async {
    final repository = _FakeLearningRepository(
      _fixtureWorkspace(
        businessDate: DateTime(2026, 9, 4),
        businessDueDate: DateTime(2026, 9, 4),
      ),
    );
    await _pumpWorkspace(tester, repository);

    expect(find.textContaining('9 月 4 日'), findsOneWidget);
    expect(find.textContaining('9 月 3 日'), findsNothing);
  });

  testWidgets('orders overdue student groups by their earliest action', (
    tester,
  ) async {
    final laterAction = _studentFixture(
      id: 'later',
      name: '陈同学',
      actionDueAt: DateTime(2026, 9, 4),
      actionTitle: '较晚逾期行动',
    );
    final earlierAction = _studentFixture(
      id: 'earlier',
      name: '周同学',
      actionDueAt: DateTime(2026, 9, 2),
      actionTitle: '更早逾期行动',
    );
    final repository = _FakeLearningRepository(
      _workspaceWithStudents([laterAction, earlierAction]),
    );

    await _pumpWorkspace(tester, repository);

    expect(
      tester.getTopLeft(find.text('更早逾期行动')).dy,
      lessThan(tester.getTopLeft(find.text('较晚逾期行动')).dy),
    );
  });

  testWidgets('shows students with newer activity first in Recent Students', (
    tester,
  ) async {
    final olderStudent = _studentFixture(
      id: 'older',
      name: '安同学',
      recentActivityAt: DateTime(2026, 9, 2),
    );
    final newerStudent = _studentFixture(
      id: 'newer',
      name: '周同学',
      recentActivityAt: DateTime(2026, 9, 4),
    );
    final studentWithoutActivity = _studentFixture(
      id: 'without-activity',
      name: '白同学',
    );
    final repository = _FakeLearningRepository(
      _workspaceWithStudents([
        studentWithoutActivity,
        olderStudent,
        newerStudent,
      ]),
    );

    await _pumpWorkspace(tester, repository);

    expect(
      tester.getTopLeft(find.text('周同学')).dy,
      lessThan(tester.getTopLeft(find.text('安同学')).dy),
    );
    expect(
      tester.getTopLeft(find.text('安同学')).dy,
      lessThan(tester.getTopLeft(find.text('白同学')).dy),
    );
  });

  testWidgets('keeps the three most actionable Cases in the student summary', (
    tester,
  ) async {
    final student = _studentFixture(
      id: 'detail',
      name: '许同学',
      cases: [
        _caseFixture(
          id: 'future',
          title: '未来再处理的问题',
          status: LearningCaseStatus.confirmed,
          actionBucket: WorkspaceActionBucket.future,
          actionDueAt: DateTime(2026, 9, 10),
          priority: 'high',
        ),
        _caseFixture(
          id: 'undated',
          title: '尚未安排的问题',
          status: LearningCaseStatus.intervening,
          actionBucket: WorkspaceActionBucket.undated,
          actionDueAt: null,
        ),
        _caseFixture(
          id: 'verification',
          title: '等待验证的问题',
          status: LearningCaseStatus.pendingVerification,
          actionBucket: WorkspaceActionBucket.future,
          actionDueAt: DateTime(2026, 9, 12),
        ),
        _caseFixture(
          id: 'today',
          title: '今天要处理的问题',
          status: LearningCaseStatus.confirmed,
          actionBucket: WorkspaceActionBucket.today,
          actionDueAt: DateTime(2026, 9, 5),
        ),
        _caseFixture(
          id: 'overdue',
          title: '已经逾期的问题',
          status: LearningCaseStatus.confirmed,
          actionBucket: WorkspaceActionBucket.overdue,
          actionDueAt: DateTime(2026, 9, 2),
          priority: 'low',
        ),
      ],
    );
    final repository = _FakeLearningRepository(
      _workspaceWithStudents([student]),
    );
    await _pumpWorkspace(tester, repository);

    final studentRow = find.text('许同学');
    await tester.ensureVisible(studentRow);
    await tester.tap(studentRow);
    await tester.pumpAndSettle();

    expect(find.text('已经逾期的问题'), findsOneWidget);
    expect(find.text('今天要处理的问题'), findsOneWidget);
    expect(find.text('等待验证的问题'), findsOneWidget);
    expect(find.text('尚未安排的问题'), findsNothing);
    expect(find.text('未来再处理的问题'), findsNothing);

    final allCasesButton = find.widgetWithText(TextButton, '查看全部 5 个');
    await tester.ensureVisible(allCasesButton);
    await tester.tap(allCasesButton);
    await tester.pumpAndSettle();

    expect(find.text('全部问题'), findsOneWidget);
    expect(find.text('已经逾期的问题'), findsOneWidget);
    expect(find.text('今天要处理的问题'), findsOneWidget);
    expect(find.text('等待验证的问题'), findsOneWidget);
    expect(find.text('尚未安排的问题'), findsOneWidget);
    expect(find.text('未来再处理的问题'), findsOneWidget);
  });

  testWidgets('explains schema drift and lets the user retry', (tester) async {
    final repository = _FakeLearningRepository(_fixtureWorkspace())
      ..loadError = StateError(
        '404 PGRST205 relation teacher_workspace_context does not exist',
      );
    await _pumpWorkspace(tester, repository);

    expect(find.text('暂时无法加载工作台'), findsOneWidget);
    expect(find.text('服务正在更新，暂时无法读取工作台。请稍后重试。'), findsOneWidget);

    repository.loadError = null;
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();

    expect(find.text('今日'), findsWidgets);
    expect(repository.loadCount, 2);
  });

  testWidgets(
    'keeps Quick Capture input and reuses operation id after failure',
    (tester) async {
      final repository = _FakeLearningRepository(_fixtureWorkspace())
        ..failFirstSave = true;
      await _pumpWorkspace(tester, repository);

      await tester.tap(find.text('记录问题').first);
      await tester.pumpAndSettle();
      expect(find.text('具体表现 *'), findsOneWidget);

      final studentPicker = find.byType(
        DropdownButtonFormField<WorkspaceStudent>,
      );
      await tester.ensureVisible(studentPicker);
      await tester.tap(studentPicker);
      await tester.pumpAndSettle();
      await tester.tap(find.text('示例学生甲 · 数学').last);
      await tester.pumpAndSettle();

      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(0), '新的课堂问题');
      await tester.enterText(textFields.at(1), '课堂练习中连续两次跳过通分。');
      final saveButton = find.byKey(const Key('workspace-quick-capture-save'));
      await tester.ensureVisible(saveButton);
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      expect(find.textContaining('网络暂时不可用'), findsOneWidget);
      expect(find.text('新的课堂问题'), findsOneWidget);
      expect(find.text('课堂练习中连续两次跳过通分。'), findsOneWidget);

      await tester.ensureVisible(saveButton);
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      expect(find.text('已记录为待整理问题。'), findsOneWidget);
      expect(repository.saveCount, 2);
      expect(
        repository.commands[0].operationId,
        repository.commands[1].operationId,
      );
      expect(repository.commands[1].profileId, 'profile-1');
    },
  );

  testWidgets('focuses the problem title after choosing a student', (
    tester,
  ) async {
    final repository = _FakeLearningRepository(_fixtureWorkspace());
    await _pumpWorkspace(tester, repository);

    await tester.tap(find.text('记录问题').first);
    await tester.pumpAndSettle();

    final studentPicker = find.byType(
      DropdownButtonFormField<WorkspaceStudent>,
    );
    await tester.ensureVisible(studentPicker);
    await tester.tap(studentPicker);
    await tester.pumpAndSettle();
    await tester.tap(find.text('示例学生甲 · 数学').last);
    await tester.pumpAndSettle();

    final titleField = find.byKey(const Key('quick-capture-title-field'));
    expect(titleField, findsOneWidget);
    expect(tester.widget<TextField>(titleField).focusNode?.hasFocus, isTrue);
  });

  testWidgets('keeps Quick Capture facts before classification', (
    tester,
  ) async {
    final repository = _FakeLearningRepository(_fixtureWorkspace());
    await _pumpWorkspace(tester, repository);

    await tester.tap(find.text('记录问题').first);
    await tester.pumpAndSettle();

    final titleField = find.byKey(const Key('quick-capture-title-field'));
    final evidenceField = find.byKey(const Key('quick-capture-evidence-field'));
    final typePicker = find.byKey(
      const Key('quick-capture-case-type-dropdown'),
    );

    expect(titleField, findsOneWidget);
    expect(evidenceField, findsOneWidget);
    expect(typePicker, findsOneWidget);
    expect(
      tester.getTopLeft(titleField).dy,
      lessThan(tester.getTopLeft(typePicker).dy),
    );
    expect(
      tester.getTopLeft(evidenceField).dy,
      lessThan(tester.getTopLeft(typePicker).dy),
    );
    expect(find.text('问题类型（可调整）'), findsOneWidget);
  });

  testWidgets('keeps configuration actions out of Today for managers', (
    tester,
  ) async {
    final repository = _FakeLearningRepository(
      _fixtureWorkspace(canManageCaseTypes: true),
    );
    await _pumpWorkspace(tester, repository);

    expect(find.text('今日'), findsWidgets);
    expect(find.widgetWithText(FilledButton, '记录问题'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, '问题类型'), findsNothing);
  });

  testWidgets('sends a selected custom type with its base classification', (
    tester,
  ) async {
    const customType = WorkspaceCaseType(
      id: 'case-type-1',
      displayName: '审题策略',
      baseType: LearningCaseType.examStrategy,
      status: 'active',
      sortOrder: 0,
      version: 1,
    );
    final repository = _FakeLearningRepository(
      _fixtureWorkspace(
        caseTypes: [...WorkspaceCaseType.builtInTypes, customType],
      ),
    );
    await _pumpWorkspace(tester, repository);

    await tester.tap(find.text('记录问题').first);
    await tester.pumpAndSettle();

    final studentPicker = find.byType(
      DropdownButtonFormField<WorkspaceStudent>,
    );
    await tester.tap(studentPicker);
    await tester.pumpAndSettle();
    await tester.tap(find.text('示例学生甲 · 数学').last);
    await tester.pumpAndSettle();

    final typePicker = find.byKey(
      const Key('quick-capture-case-type-dropdown'),
    );
    await tester.tap(typePicker);
    await tester.pumpAndSettle();
    await tester.tap(find.text('审题策略').last);
    await tester.pumpAndSettle();

    final textFields = find.byType(TextField);
    await tester.enterText(textFields.at(0), '新题审题策略不稳定');
    await tester.enterText(textFields.at(1), '面对综合题时没有先识别已知条件。');
    final saveButton = find.byKey(const Key('workspace-quick-capture-save'));
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(repository.commands.single.organizationCaseTypeId, 'case-type-1');
    expect(repository.commands.single.caseType, LearningCaseType.examStrategy);
  });

  testWidgets('uses bottom sheets for compact Quick Capture selectors', (
    tester,
  ) async {
    const customType = WorkspaceCaseType(
      id: 'case-type-1',
      displayName: '审题策略',
      baseType: LearningCaseType.examStrategy,
      status: 'active',
      sortOrder: 0,
      version: 1,
    );
    final repository = _FakeLearningRepository(
      _fixtureWorkspace(
        caseTypes: [...WorkspaceCaseType.builtInTypes, customType],
      ),
    );
    final originalPhysicalSize = tester.view.physicalSize;
    final originalDevicePixelRatio = tester.view.devicePixelRatio;
    addTearDown(() {
      tester.view.physicalSize = originalPhysicalSize;
      tester.view.devicePixelRatio = originalDevicePixelRatio;
    });
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(375, 812);

    await _pumpWorkspace(tester, repository);
    await tester.tap(find.text('记录问题').first);
    await tester.pumpAndSettle();

    expect(
      find.byType(DropdownButtonFormField<WorkspaceStudent>),
      findsNothing,
    );
    expect(find.byType(DropdownButtonFormField<String>), findsNothing);

    final studentPicker = find.byKey(const Key('quick-capture-student-picker'));
    await tester.tap(studentPicker);
    await tester.pumpAndSettle();
    expect(find.text('选择学生'), findsOneWidget);
    await tester.tap(
      find.byKey(const Key('quick-capture-student-option-student-1')),
    );
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: studentPicker, matching: find.text('示例学生甲 · 数学')),
      findsOneWidget,
    );

    final typePicker = find.byKey(
      const Key('quick-capture-case-type-dropdown'),
    );
    await tester.tap(typePicker);
    await tester.pumpAndSettle();
    expect(find.text('选择问题类型'), findsOneWidget);
    await tester.tap(
      find.byKey(const Key('quick-capture-case-type-option-case-type-1')),
    );
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: typePicker, matching: find.text('审题策略')),
      findsOneWidget,
    );
  });

  testWidgets('runs the confirmation command from a new Case', (tester) async {
    final repository = _FakeLearningRepository(_fixtureWorkspace());
    await _pumpWorkspace(tester, repository);

    final studentRow = find.text('示例学生甲').first;
    await tester.ensureVisible(studentRow);
    await tester.tap(studentRow);
    await tester.pumpAndSettle();
    final caseButton = find.widgetWithText(OutlinedButton, '查看问题').first;
    await tester.ensureVisible(caseButton);
    await tester.tap(caseButton);
    await tester.pumpAndSettle();

    final commandButton = find.widgetWithText(FilledButton, '整理并确认问题');
    await tester.ensureVisible(commandButton);
    await tester.tap(commandButton);
    await tester.pumpAndSettle();

    final saveButton = find.widgetWithText(FilledButton, '保存并进入下一步');
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(repository.confirmCount, 1);
    expect(repository.confirmCommands.single.caseId, 'case-1');
    expect(repository.confirmCommands.single.expectedCaseVersion, 1);
    expect(repository.confirmCommands.single.nextActionTitle, '安排一次针对性练习');
    expect(find.textContaining('Case 进入已确认'), findsOneWidget);
  });

  testWidgets('records an intervention from a confirmed Case', (tester) async {
    final repository = _FakeLearningRepository(
      _fixtureWorkspace(status: LearningCaseStatus.confirmed),
    );
    await _pumpWorkspace(tester, repository);

    final studentRow = find.text('示例学生甲').first;
    await tester.ensureVisible(studentRow);
    await tester.tap(studentRow);
    await tester.pumpAndSettle();
    final caseButton = find.widgetWithText(OutlinedButton, '查看问题').first;
    await tester.ensureVisible(caseButton);
    await tester.tap(caseButton);
    await tester.pumpAndSettle();
    final commandButton = find.widgetWithText(FilledButton, '记录教学动作');
    await tester.ensureVisible(commandButton);
    await tester.tap(commandButton);
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '用图示带学生重新完成通分步骤。');
    final saveButton = find.widgetWithText(FilledButton, '保存并进入下一步');
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(repository.interventionCount, 1);
    expect(repository.interventionCommands.single.strategy, '用图示带学生重新完成通分步骤。');
    expect(repository.interventionCommands.single.expectedCaseVersion, 1);
    expect(find.textContaining('Case 进入干预中'), findsOneWidget);
  });

  testWidgets('records verification from an intervening Case', (tester) async {
    final repository = _FakeLearningRepository(
      _fixtureWorkspace(
        status: LearningCaseStatus.intervening,
        actionType: 'verify',
      ),
    );
    await _pumpWorkspace(tester, repository);

    final studentRow = find.text('示例学生甲').first;
    await tester.ensureVisible(studentRow);
    await tester.tap(studentRow);
    await tester.pumpAndSettle();
    final caseButton = find.widgetWithText(OutlinedButton, '查看问题').first;
    await tester.ensureVisible(caseButton);
    await tester.tap(caseButton);
    await tester.pumpAndSettle();
    final commandButton = find.widgetWithText(FilledButton, '记录验证结果');
    await tester.ensureVisible(commandButton);
    await tester.tap(commandButton);
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '学生能独立完成，但仍有一次漏写通分步骤。');
    final saveButton = find.widgetWithText(FilledButton, '保存并进入下一步');
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(repository.assessmentCount, 1);
    expect(
      repository.assessmentCommands.single.result,
      CaseAssessmentResult.partial,
    );
    expect(find.textContaining('Case 进入待验证'), findsOneWidget);
  });

  testWidgets('records a verification result without auto-closing the Case', (
    tester,
  ) async {
    final repository = _FakeLearningRepository(
      _fixtureWorkspace(status: LearningCaseStatus.pendingVerification),
    );
    await _pumpWorkspace(tester, repository);

    final studentRow = find.text('示例学生甲').first;
    await tester.ensureVisible(studentRow);
    await tester.tap(studentRow);
    await tester.pumpAndSettle();
    final caseButton = find.widgetWithText(OutlinedButton, '查看问题').first;
    await tester.ensureVisible(caseButton);
    await tester.tap(caseButton);
    await tester.pumpAndSettle();
    final commandButton = find.widgetWithText(FilledButton, '记录验证结果');
    await tester.ensureVisible(commandButton);
    await tester.tap(commandButton);
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '学生能独立完成，但仍有一次漏写通分步骤。');
    final saveButton = find.widgetWithText(FilledButton, '保存并进入下一步');
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(repository.assessmentCount, 1);
    expect(
      repository.assessmentCommands.single.result,
      CaseAssessmentResult.partial,
    );
    expect(
      repository.assessmentCommands.single.evidenceSummary,
      '学生能独立完成，但仍有一次漏写通分步骤。',
    );
    expect(find.textContaining('Case 进入待验证'), findsOneWidget);
  });

  test('validates Case commands and parses command receipts', () {
    expect(
      () => ConfirmCaseCommand(
        operationId: '',
        caseId: 'case-1',
        expectedCaseVersion: 1,
        nextActionTitle: '下一步',
        nextActionDueAt: null,
      ).validate(),
      throwsArgumentError,
    );
    expect(
      () => RecordAssessmentCommand(
        operationId: 'op-1',
        caseId: 'case-1',
        expectedCaseVersion: 1,
        result: CaseAssessmentResult.partial,
        evidenceSummary: '',
        notes: null,
        assessedAt: null,
        nextActionTitle: '下一步',
        nextActionDueAt: null,
      ).validate(),
      throwsArgumentError,
    );

    expect(
      () => RescheduleCaseActionCommand(
        operationId: 'op-1',
        actionId: '',
        caseId: 'case-1',
        expectedCaseVersion: 1,
        expectedActionVersion: 1,
        dueOn: null,
      ).validate(),
      throwsArgumentError,
    );
    expect(
      () => RescheduleCaseActionCommand(
        operationId: 'op-1',
        actionId: 'action-1',
        caseId: 'case-1',
        expectedCaseVersion: 1,
        expectedActionVersion: 0,
        dueOn: null,
      ).validate(),
      throwsArgumentError,
    );

    final receipt = CaseCommandReceipt.fromJson(<String, dynamic>{
      'operation_id': 'op-1',
      'case_id': 'case-1',
      'assessment_id': 'assessment-1',
      'action_id': 'action-1',
      'event_id': 'event-1',
      'status': 'pending_verification',
      'case_version': 2,
    });
    expect(receipt.recordId, 'assessment-1');
    expect(receipt.caseVersion, 2);

    final closeReceipt = CaseCommandReceipt.fromJson(<String, dynamic>{
      'operation_id': 'op-close',
      'case_id': 'case-1',
      'event_id': 'event-close',
      'status': 'closed',
      'case_version': 3,
    });
    expect(closeReceipt.actionId, isNull);
  });

  test('validates Evidence and reopen command payloads', () {
    expect(
      () => AddCaseEvidenceCommand(
        operationId: 'op-1',
        caseId: 'case-1',
        expectedCaseVersion: 1,
        sourceType: 'unsupported',
        title: '标题',
        observedAt: DateTime(2026, 9, 3),
        summary: '表现',
      ).validate(),
      throwsArgumentError,
    );
    expect(
      () => ReopenCaseCommand(
        operationId: 'op-1',
        caseId: 'case-1',
        expectedCaseVersion: 1,
        recurrenceEvidenceIds: <String>['evidence-1', 'evidence-1'],
        expectedEvidenceVersions: <String, int>{'evidence-1': 1},
        nextActionType: CaseActionType.verify,
        nextActionTitle: '下一步',
        nextActionDueOn: null,
      ).validate(),
      throwsArgumentError,
    );
    expect(
      () => ReopenCaseCommand(
        operationId: 'op-1',
        caseId: 'case-1',
        expectedCaseVersion: 1,
        recurrenceEvidenceIds: <String>['evidence-1'],
        expectedEvidenceVersions: <String, int>{'evidence-1': 1},
        nextActionType: CaseActionType.review,
        nextActionTitle: '安排复查',
        nextActionDueOn: null,
      ).validate(),
      throwsArgumentError,
    );
  });

  testWidgets('stabilizes a Case after a passed verification', (tester) async {
    final repository = _FakeLearningRepository(
      _fixtureWorkspace(
        status: LearningCaseStatus.pendingVerification,
        assessmentResult: CaseAssessmentResult.passed.wireValue,
      ),
    );
    await _pumpWorkspace(tester, repository);

    final studentRow = find.text('示例学生甲').first;
    await tester.ensureVisible(studentRow);
    await tester.tap(studentRow);
    await tester.pumpAndSettle();
    final caseButton = find.widgetWithText(OutlinedButton, '查看问题').first;
    await tester.ensureVisible(caseButton);
    await tester.tap(caseButton);
    await tester.pumpAndSettle();

    final stabilizeButton = find.widgetWithText(FilledButton, '标记为稳定');
    await tester.ensureVisible(stabilizeButton);
    await tester.tap(stabilizeButton);
    await tester.pumpAndSettle();

    final saveButton = find.widgetWithText(FilledButton, '保存并进入下一步');
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(repository.stabilizeCount, 1);
    expect(find.textContaining('Case 进入稳定'), findsOneWidget);
  });

  testWidgets('closes a stable Case after confirmation', (tester) async {
    final repository = _FakeLearningRepository(
      _fixtureWorkspace(status: LearningCaseStatus.stable),
    );
    await _pumpWorkspace(tester, repository);

    final studentRow = find.text('示例学生甲').first;
    await tester.ensureVisible(studentRow);
    await tester.tap(studentRow);
    await tester.pumpAndSettle();
    final caseButton = find.widgetWithText(OutlinedButton, '查看问题').first;
    await tester.ensureVisible(caseButton);
    await tester.tap(caseButton);
    await tester.pumpAndSettle();

    final closeButton = find.widgetWithText(FilledButton, '结束跟进');
    await tester.ensureVisible(closeButton);
    await tester.tap(closeButton);
    await tester.pumpAndSettle();

    expect(find.text('关闭 Case？'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '关闭').last);
    await tester.pumpAndSettle();

    expect(repository.closeCount, 1);
    expect(find.textContaining('Case 进入已关闭'), findsOneWidget);
  });

  testWidgets('reuses operation id after closing response is lost', (
    tester,
  ) async {
    final repository = _FakeLearningRepository(
      _fixtureWorkspace(status: LearningCaseStatus.stable),
    )..failFirstClose = true;
    await _pumpWorkspace(tester, repository);

    final studentRow = find.text('示例学生甲').first;
    await tester.ensureVisible(studentRow);
    await tester.tap(studentRow);
    await tester.pumpAndSettle();
    final caseButton = find.widgetWithText(OutlinedButton, '查看问题').first;
    await tester.ensureVisible(caseButton);
    await tester.tap(caseButton);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, '结束跟进'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '关闭').last);
    await tester.pumpAndSettle();

    expect(find.textContaining('网络暂时不可用'), findsOneWidget);
    expect(repository.closeCount, 1);
    final firstOperationId = repository.closeCommands.single.operationId;

    await tester.tap(find.widgetWithText(FilledButton, '结束跟进'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '关闭').last);
    await tester.pumpAndSettle();

    expect(repository.closeCount, 2);
    expect(repository.closeCommands[1].operationId, firstOperationId);
  });

  testWidgets('records recurrence Evidence before reopening a closed Case', (
    tester,
  ) async {
    final repository = _FakeLearningRepository(
      _fixtureWorkspace(status: LearningCaseStatus.closed),
    );
    await _pumpWorkspace(tester, repository);

    expect(find.text('暂无需要跟进的问题'), findsOneWidget);
    final studentRow = find.text('示例学生甲').first;
    await tester.ensureVisible(studentRow);
    await tester.tap(studentRow);
    await tester.pumpAndSettle();
    final allCasesButton = find.widgetWithText(TextButton, '查看全部 1 个');
    await tester.ensureVisible(allCasesButton);
    await tester.tap(allCasesButton);
    await tester.pumpAndSettle();
    final caseButton = find.widgetWithText(OutlinedButton, '查看问题').first;
    await tester.ensureVisible(caseButton);
    await tester.tap(caseButton);
    await tester.pumpAndSettle();

    final reopenButton = find.widgetWithText(FilledButton, '记录复发并继续跟进');
    await tester.ensureVisible(reopenButton);
    await tester.tap(reopenButton);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('reopen-evidence-title')),
      '关闭后再次出现同类表现',
    );
    await tester.enterText(
      find.byKey(const Key('reopen-evidence-summary')),
      '学生再次跳过通分步骤，需要重新安排验证。',
    );
    await tester.enterText(
      find.byKey(const Key('reopen-next-action')),
      '复核复发原因并安排验证',
    );
    final saveEvidenceButton = find.widgetWithText(FilledButton, '保存证据');
    await tester.ensureVisible(saveEvidenceButton);
    await tester.tap(saveEvidenceButton);
    await tester.pumpAndSettle();

    expect(repository.addEvidenceCount, 1);
    expect(repository.reopenCount, 1);
    expect(repository.reopenCommands.single.recurrenceEvidenceIds, <String>[
      'evidence-recurrence',
    ]);
    expect(
      repository.reopenCommands.single.expectedEvidenceVersions,
      <String, int>{'evidence-recurrence': 1},
    );
    expect(find.textContaining('Case 进入已确认'), findsOneWidget);
  });

  testWidgets('restores an unfinished reopen after the page is recreated', (
    tester,
  ) async {
    final repository = _FakeLearningRepository(
      _fixtureWorkspace(status: LearningCaseStatus.closed),
    )..failFirstReopen = true;
    final store = InMemoryCaseReopenDraftStore();
    const scope = 'user:user-1|organization:org-1|case:case-1';

    await _pumpWorkspace(
      tester,
      repository,
      draftStore: store,
      sessionUserId: 'user-1',
    );
    final studentRow = find.text('示例学生甲').first;
    await tester.ensureVisible(studentRow);
    await tester.tap(studentRow);
    await tester.pumpAndSettle();
    final firstAllCasesButton = find.widgetWithText(TextButton, '查看全部 1 个');
    await tester.ensureVisible(firstAllCasesButton);
    await tester.tap(firstAllCasesButton);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, '查看问题').first);
    await tester.pumpAndSettle();
    final firstReopenButton = find.widgetWithText(FilledButton, '记录复发并继续跟进');
    await tester.ensureVisible(firstReopenButton);
    await tester.tap(firstReopenButton);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('reopen-evidence-title')),
      '关闭后再次出现同类表现',
    );
    await tester.enterText(
      find.byKey(const Key('reopen-evidence-summary')),
      '学生再次跳过通分步骤，需要重新安排验证。',
    );
    await tester.enterText(
      find.byKey(const Key('reopen-next-action')),
      '复核复发原因并安排验证',
    );
    final saveEvidenceButton = find.widgetWithText(FilledButton, '保存证据');
    await tester.ensureVisible(saveEvidenceButton);
    await tester.tap(saveEvidenceButton);
    await tester.pumpAndSettle();

    expect(repository.addEvidenceCount, 1);
    expect(repository.reopenCount, 1);
    final firstEvidenceOperationId =
        repository.addEvidenceCommands.single.operationId;
    final firstReopenOperationId = repository.reopenCommands.single.operationId;
    final draft = await store.load(scope);
    expect(draft?.evidenceId, 'evidence-recurrence');
    expect(draft?.evidenceOperationId, firstEvidenceOperationId);
    expect(draft?.reopenOperationId, firstReopenOperationId);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    await _pumpWorkspace(
      tester,
      repository,
      draftStore: store,
      sessionUserId: 'user-1',
    );
    final restoredStudentRow = find.text('示例学生甲').first;
    await tester.ensureVisible(restoredStudentRow);
    await tester.tap(restoredStudentRow);
    await tester.pumpAndSettle();
    final restoredAllCasesButton = find.widgetWithText(TextButton, '查看全部 1 个');
    await tester.ensureVisible(restoredAllCasesButton);
    await tester.tap(restoredAllCasesButton);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, '查看问题').first);
    await tester.pumpAndSettle();
    final restoredReopenButton = find.widgetWithText(FilledButton, '记录复发并继续跟进');
    await tester.ensureVisible(restoredReopenButton);
    await tester.tap(restoredReopenButton);
    await tester.pumpAndSettle();

    expect(find.widgetWithText(FilledButton, '继续跟进'), findsOneWidget);
    final reopenCaseButton = find.widgetWithText(FilledButton, '继续跟进');
    await tester.ensureVisible(reopenCaseButton);
    await tester.tap(reopenCaseButton);
    await tester.pumpAndSettle();

    expect(repository.addEvidenceCount, 1);
    expect(repository.reopenCount, 2);
    expect(repository.reopenCommands[1].operationId, firstReopenOperationId);
    expect(await store.load(scope), isNull);
    expect(find.textContaining('Case 进入已确认'), findsOneWidget);
  });

  testWidgets('unlocks a reopen form after a deterministic Evidence failure', (
    tester,
  ) async {
    final repository = _FakeLearningRepository(
      _fixtureWorkspace(status: LearningCaseStatus.closed),
    )..failFirstEvidence = true;
    await _pumpWorkspace(tester, repository);

    final studentRow = find.text('示例学生甲').first;
    await tester.ensureVisible(studentRow);
    await tester.tap(studentRow);
    await tester.pumpAndSettle();
    final allCasesButton = find.widgetWithText(TextButton, '查看全部 1 个');
    await tester.ensureVisible(allCasesButton);
    await tester.tap(allCasesButton);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, '查看问题').first);
    await tester.pumpAndSettle();
    final reopenButton = find.widgetWithText(FilledButton, '记录复发并继续跟进');
    await tester.ensureVisible(reopenButton);
    await tester.tap(reopenButton);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('reopen-evidence-title')),
      '关闭后再次出现同类表现',
    );
    await tester.enterText(
      find.byKey(const Key('reopen-evidence-summary')),
      '学生再次跳过通分步骤，需要重新安排验证。',
    );
    final saveEvidenceButton = find.widgetWithText(FilledButton, '保存证据');
    await tester.ensureVisible(saveEvidenceButton);
    await tester.tap(saveEvidenceButton);
    await tester.pumpAndSettle();

    expect(find.textContaining('观察时间必须晚于最近一次关闭时间'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('reopen-evidence-title')))
          .enabled,
      isTrue,
    );
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, '取消').last,
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('does not expose student data without teaching access', (
    tester,
  ) async {
    final workspace = _fixtureWorkspace();
    final repository = _FakeLearningRepository(
      TeacherWorkspace(
        viewerName: workspace.viewerName,
        organizationName: workspace.organizationName,
        organizationTimeZone: workspace.organizationTimeZone,
        hasTeachingAccess: false,
        students: const <WorkspaceStudent>[],
        loadedAt: workspace.loadedAt,
      ),
    );
    await _pumpWorkspace(tester, repository);

    expect(find.text('当前账号还没有可用的教学权限'), findsOneWidget);
    expect(find.text('示例学生甲'), findsNothing);
  });

  testWidgets(
    'renders management-only accounts without a navigation assertion',
    (tester) async {
      final workspace = _fixtureWorkspace();
      final repository = _FakeLearningRepository(
        TeacherWorkspace(
          viewerName: workspace.viewerName,
          organizationName: workspace.organizationName,
          organizationTimeZone: workspace.organizationTimeZone,
          hasTeachingAccess: false,
          organizationId: 'org-1',
          roles: const <String>['org_admin'],
          canManageOrganization: true,
          students: const <WorkspaceStudent>[],
          loadedAt: workspace.loadedAt,
        ),
      );

      await _pumpWorkspace(tester, repository);

      expect(find.text('管理功能暂时不可用'), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.byType(NavigationRail), findsNothing);
    },
  );
}
