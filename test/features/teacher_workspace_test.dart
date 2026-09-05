import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xueqing/app/theme/app_theme.dart';
import 'package:xueqing/cloud/learning_repository.dart';
import 'package:xueqing/features/teacher_workspace/presentation/'
    'teacher_workspace_page.dart';

class _FakeLearningRepository implements LearningRepository {
  _FakeLearningRepository(this.workspace);

  TeacherWorkspace workspace;
  Object? loadError;
  int loadCount = 0;
  int saveCount = 0;
  bool failFirstSave = false;
  final List<QuickCaptureCommand> commands = <QuickCaptureCommand>[];
  int confirmCount = 0;
  int interventionCount = 0;
  int assessmentCount = 0;
  int stabilizeCount = 0;
  int closeCount = 0;
  int rescheduleCount = 0;
  final List<ConfirmCaseCommand> confirmCommands = <ConfirmCaseCommand>[];
  final List<RecordInterventionCommand> interventionCommands =
      <RecordInterventionCommand>[];
  final List<RecordAssessmentCommand> assessmentCommands =
      <RecordAssessmentCommand>[];
  final List<RescheduleCaseActionCommand> rescheduleCommands =
      <RescheduleCaseActionCommand>[];

  @override
  Future<TeacherWorkspace> loadWorkspace() async {
    loadCount++;
    if (loadError != null) {
      throw loadError!;
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
  Future<CaseCommandReceipt> rescheduleCaseAction(
    RescheduleCaseActionCommand command,
  ) async {
    rescheduleCount++;
    rescheduleCommands.add(command);
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
    actions: <WorkspaceAction>[action],
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
    timeline: const <WorkspaceTimelineEvent>[],
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
  _FakeLearningRepository repository,
) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: TeacherWorkspacePage(repository: repository),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
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

    final caseButton = find.widgetWithText(OutlinedButton, '查看 Case').first;
    await tester.ensureVisible(caseButton);
    await tester.tap(caseButton);
    await tester.pumpAndSettle();
    expect(find.text('分数步骤需要继续观察'), findsOneWidget);
    expect(find.text('待整理 Case'), findsOneWidget);
    expect(find.text('待整理'), findsOneWidget);
    expect(find.text('尚未记录教学动作。'), findsOneWidget);
  });

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

    expect(find.text('已经逾期的问题'), findsNWidgets(2));
    expect(find.text('今天要处理的问题'), findsNWidgets(2));
    expect(find.text('等待验证的问题'), findsNWidgets(3));
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
    expect(find.text('开发环境服务还没有完成同步，请稍后重试。'), findsOneWidget);

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
      expect(find.text('现场表现 / Evidence *'), findsOneWidget);

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
      final saveButton = find.widgetWithText(FilledButton, '保存问题');
      await tester.ensureVisible(saveButton);
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      expect(find.textContaining('网络暂时不可用'), findsOneWidget);
      expect(find.text('新的课堂问题'), findsOneWidget);
      expect(find.text('课堂练习中连续两次跳过通分。'), findsOneWidget);

      await tester.ensureVisible(saveButton);
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      expect(find.text('已保存为待整理 Case，并保留下一步行动。'), findsOneWidget);
      expect(repository.saveCount, 2);
      expect(
        repository.commands[0].operationId,
        repository.commands[1].operationId,
      );
      expect(repository.commands[1].profileId, 'profile-1');
    },
  );

  testWidgets('shows custom type settings to an organization manager', (
    tester,
  ) async {
    final customType = WorkspaceCaseType(
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
        canManageCaseTypes: true,
      ),
    );
    await _pumpWorkspace(tester, repository);

    await tester.tap(find.widgetWithText(OutlinedButton, '问题类型'));
    await tester.pumpAndSettle();

    expect(find.text('可用于新记录'), findsOneWidget);
    expect(find.text('审题策略'), findsOneWidget);
    expect(find.textContaining('系统类型始终保留。自定义类型只负责分类'), findsOneWidget);
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
    final saveButton = find.widgetWithText(FilledButton, '保存问题');
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
    final caseButton = find.widgetWithText(OutlinedButton, '查看 Case').first;
    await tester.ensureVisible(caseButton);
    await tester.tap(caseButton);
    await tester.pumpAndSettle();

    final commandButton = find.widgetWithText(FilledButton, '确认 Case');
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
    final caseButton = find.widgetWithText(OutlinedButton, '查看 Case').first;
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
    final caseButton = find.widgetWithText(OutlinedButton, '查看 Case').first;
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
    final caseButton = find.widgetWithText(OutlinedButton, '查看 Case').first;
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
    final caseButton = find.widgetWithText(OutlinedButton, '查看 Case').first;
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
    final caseButton = find.widgetWithText(OutlinedButton, '查看 Case').first;
    await tester.ensureVisible(caseButton);
    await tester.tap(caseButton);
    await tester.pumpAndSettle();

    final closeButton = find.widgetWithText(FilledButton, '关闭 Case');
    await tester.ensureVisible(closeButton);
    await tester.tap(closeButton);
    await tester.pumpAndSettle();

    expect(find.text('关闭 Case？'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '关闭').last);
    await tester.pumpAndSettle();

    expect(repository.closeCount, 1);
    expect(find.textContaining('Case 进入已关闭'), findsOneWidget);
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

    expect(find.text('当前账号没有可用的教师教学范围'), findsOneWidget);
    expect(find.text('示例学生甲'), findsNothing);
  });
}
