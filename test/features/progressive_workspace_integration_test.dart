import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xueqing/app/theme/app_theme.dart';
import 'package:xueqing/cloud/learning_repository.dart';
import 'package:xueqing/cloud/progressive_case_repository.dart';
import 'package:xueqing/features/teacher_workspace/presentation/teacher_workspace_page.dart';

void main() {
  testWidgets('Today can complete a reminder without inventing progress', (
    tester,
  ) async {
    final repository = _WorkspaceRepository(_workspace());
    await tester.pumpWidget(_host(repository: repository));
    await tester.pumpAndSettle();

    expect(find.text('完成'), findsOneWidget);
    expect(find.text('处理'), findsNothing);
    expect(find.text('今天的工作'), findsOneWidget);

    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();

    expect(find.text('完成待办'), findsWidgets);
    expect(find.textContaining('不会自动写入学生表现'), findsOneWidget);
    await tester.tap(find.byKey(const Key('workspace-complete-action-save')));
    await tester.pumpAndSettle();

    final command = repository.completeCommands.single;
    expect(command.actionId, 'action-1');
    expect(command.caseId, 'case-1');
    expect(command.nextActionType, isNull);
    expect(command.nextActionTitle, isNull);
    expect(command.nextActionDueOn, isNull);
  });

  test(
    'complete command accepts no successor and rejects a partial successor',
    () {
      final withoutFollowUp = CompleteCaseActionCommand(
        operationId: 'operation-1',
        actionId: 'action-1',
        caseId: 'case-1',
        expectedCaseVersion: 3,
        expectedActionVersion: 2,
      );
      expect(withoutFollowUp.validate, returnsNormally);

      final invalidPartialFollowUp = CompleteCaseActionCommand(
        operationId: 'operation-2',
        actionId: 'action-1',
        caseId: 'case-1',
        expectedCaseVersion: 3,
        expectedActionVersion: 2,
        nextActionType: CaseActionType.practice,
      );
      expect(invalidPartialFollowUp.validate, throwsArgumentError);
    },
  );

  testWidgets(
    'Case detail exposes progress and close, not legacy state steps',
    (tester) async {
      await tester.pumpWidget(_host());
      await tester.pumpAndSettle();

      await tester.tap(find.text('查看问题').first);
      await tester.pumpAndSettle();

      expect(find.text('继续理解这个问题'), findsOneWidget);
      expect(find.text('记录进展'), findsOneWidget);
      expect(find.text('结束跟进'), findsOneWidget);
      expect(find.text('当前提醒'), findsOneWidget);
      expect(find.text('记录教学动作'), findsNothing);
      expect(find.text('整理并确认问题'), findsNothing);
      expect(find.text('记录验证结果'), findsNothing);
    },
  );
}

Widget _host({_WorkspaceRepository? repository}) {
  return MaterialApp(
    theme: AppTheme.light(),
    home: TeacherWorkspacePage(
      repository: repository ?? _WorkspaceRepository(_workspace()),
      progressiveCaseRepository: _NoopProgressiveRepository(),
    ),
  );
}

TeacherWorkspace _workspace() {
  final action = WorkspaceAction(
    id: 'action-1',
    caseId: 'case-1',
    title: '做一组限制词专项练习',
    actionType: 'practice',
    status: WorkspaceActionStatus.pending,
    isPrimary: true,
    bucket: WorkspaceActionBucket.today,
    version: 2,
    businessDueDate: DateTime(2026, 9, 8),
  );
  final learningCase = WorkspaceCase(
    id: 'case-1',
    profileId: 'profile-1',
    title: '阅读题漏看限制词',
    type: LearningCaseType.knowledge,
    status: LearningCaseStatus.confirmed,
    priority: 'normal',
    description: '做题时容易跳过题干中的限制词',
    firstObservedAt: DateTime(2026, 9, 1),
    version: 3,
    evidence: const <WorkspaceEvidence>[],
    interventions: const <WorkspaceIntervention>[],
    assessments: const <WorkspaceAssessment>[],
    actions: <WorkspaceAction>[action],
    timeline: const <WorkspaceTimelineEvent>[],
  );
  final student = WorkspaceStudent(
    id: 'student-1',
    profileId: 'profile-1',
    profileVersion: 1,
    name: '林同学',
    grade: '初三',
    subject: '语文',
    context: '周末班',
    positioning: '基础稳定，阅读审题需要持续提醒',
    strengths: null,
    cadenceNote: null,
    cases: <WorkspaceCase>[learningCase],
    recentFacts: const <WorkspaceTimelineEvent>[],
  );
  return TeacherWorkspace(
    viewerName: '乔老师',
    organizationName: '青云阁',
    organizationTimeZone: 'Asia/Shanghai',
    hasTeachingAccess: true,
    students: <WorkspaceStudent>[student],
    loadedAt: DateTime(2026, 9, 8),
    businessDate: DateTime(2026, 9, 8),
    organizationId: 'org-1',
    roles: const <String>['teacher'],
  );
}

class _WorkspaceRepository implements LearningRepository {
  _WorkspaceRepository(this.workspace);

  final TeacherWorkspace workspace;
  final List<CompleteCaseActionCommand> completeCommands =
      <CompleteCaseActionCommand>[];

  @override
  Future<TeacherWorkspace> loadWorkspace() async => workspace;

  @override
  Future<CaseCommandReceipt> completeCaseAction(
    CompleteCaseActionCommand command,
  ) async {
    command.validate();
    completeCommands.add(command);
    return CaseCommandReceipt(
      operationId: command.operationId,
      caseId: command.caseId,
      eventId: 'event-1',
      status: 'confirmed',
      caseVersion: command.expectedCaseVersion + 1,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NoopProgressiveRepository implements ProgressiveCaseRepository {
  @override
  Future<ProgressiveCaseReceipt> recordProgress(
    RecordCaseProgressCommand command,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<ProgressiveCaseReceipt> endFollowUp(EndCaseFollowUpCommand command) {
    throw UnimplementedError();
  }
}
