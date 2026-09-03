import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xueqing/app/theme/app_theme.dart';
import 'package:xueqing/cloud/learning_repository.dart';
import 'package:xueqing/features/teacher_workspace/presentation/'
    'teacher_workspace_page.dart';

class _FakeLearningRepository implements LearningRepository {
  _FakeLearningRepository(this.workspace);

  TeacherWorkspace workspace;
  int loadCount = 0;
  int saveCount = 0;
  bool failFirstSave = false;
  final List<QuickCaptureCommand> commands = <QuickCaptureCommand>[];
  int confirmCount = 0;
  int interventionCount = 0;
  int assessmentCount = 0;
  final List<ConfirmCaseCommand> confirmCommands = <ConfirmCaseCommand>[];
  final List<RecordInterventionCommand> interventionCommands =
      <RecordInterventionCommand>[];
  final List<RecordAssessmentCommand> assessmentCommands =
      <RecordAssessmentCommand>[];

  @override
  Future<TeacherWorkspace> loadWorkspace() async {
    loadCount++;
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
}) {
  final action = WorkspaceAction(
    id: 'action-1',
    caseId: 'case-1',
    title: '补充一次课堂证据',
    actionType: actionType,
    status: WorkspaceActionStatus.pending,
    isPrimary: true,
    bucket: WorkspaceActionBucket.today,
    dueAt: DateTime(2026, 9, 3),
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
    assessments: const <WorkspaceAssessment>[],
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
        caseTypes: [
          ...WorkspaceCaseType.builtInTypes,
          customType,
        ],
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
        caseTypes: [
          ...WorkspaceCaseType.builtInTypes,
          customType,
        ],
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
    await tester.tap(find.widgetWithText(FilledButton, '保存问题'));
    await tester.pumpAndSettle();

    expect(repository.commands.single.organizationCaseTypeId, 'case-type-1');
    expect(
      repository.commands.single.caseType,
      LearningCaseType.examStrategy,
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
