import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xueqing/app/theme/app_theme.dart';
import 'package:xueqing/cloud/learning_repository.dart';
import 'package:xueqing/cloud/progressive_case_repository.dart';
import 'package:xueqing/features/teacher_workspace/presentation/progressive_case_forms.dart';

void main() {
  testWidgets(
    'progress starts with one main input and no manufactured next decision',
    (tester) async {
      final repository = _FakeProgressiveCaseRepository();
      await tester.pumpWidget(
        _host(CaseProgressForm(repository: repository, learningCase: _case())),
      );

      expect(find.text('记录进展'), findsOneWidget);
      expect(find.byKey(const Key('progress-summary')), findsOneWidget);
      expect(
        find.byKey(const Key('progress-record-options-toggle')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('progress-next-options-toggle')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('progress-kind-observation')), findsNothing);
      expect(find.byKey(const Key('progress-next-continue')), findsNothing);
      expect(find.byKey(const Key('progress-reminder-title')), findsNothing);

      await tester.enterText(
        find.byKey(const Key('progress-summary')),
        '今天能主动说出审题限制词',
      );
      await _tapVisible(tester, find.byKey(const Key('progress-save')));
      await tester.pumpAndSettle();

      final command = repository.progressCommands.single;
      expect(command.progressKind, CaseProgressKind.observation);
      expect(command.summary, '今天能主动说出审题限制词');
      expect(command.nextStep, CaseProgressNextStep.continueTracking);
      expect(command.nextActionTitle, isNull);
      expect(command.nextActionDueOn, isNull);
      expect(command.completeCurrentAction, isFalse);
    },
  );

  testWidgets('record type choices appear only when teacher asks for them', (
    tester,
  ) async {
    final repository = _FakeProgressiveCaseRepository();
    await tester.pumpWidget(
      _host(CaseProgressForm(repository: repository, learningCase: _case())),
    );

    expect(find.byKey(const Key('progress-kind-intervention')), findsNothing);
    await tester.tap(find.byKey(const Key('progress-record-options-toggle')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('progress-kind-observation')), findsOneWidget);
    expect(find.byKey(const Key('progress-kind-intervention')), findsOneWidget);
    expect(find.byKey(const Key('progress-kind-assessment')), findsOneWidget);
  });

  testWidgets('reminder fields appear only after teacher asks for a reminder', (
    tester,
  ) async {
    final repository = _FakeProgressiveCaseRepository();
    await tester.pumpWidget(
      _host(CaseProgressForm(repository: repository, learningCase: _case())),
    );

    expect(find.byKey(const Key('progress-next-remind')), findsNothing);
    await tester.tap(find.byKey(const Key('progress-next-options-toggle')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('progress-next-remind')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('progress-reminder-title')), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('progress-summary')),
      '今天完成同类题时已经能主动圈关键词',
    );
    await tester.enterText(
      find.byKey(const Key('progress-reminder-title')),
      '下周抽查一次同类阅读题',
    );
    await _tapVisible(tester, find.byKey(const Key('progress-save')));
    await tester.pumpAndSettle();

    final command = repository.progressCommands.single;
    expect(command.nextStep, CaseProgressNextStep.remind);
    expect(command.nextActionTitle, '下周抽查一次同类阅读题');
  });

  testWidgets('assessment result can be saved without manufacturing notes', (
    tester,
  ) async {
    final repository = _FakeProgressiveCaseRepository();
    await tester.pumpWidget(
      _host(CaseProgressForm(repository: repository, learningCase: _case())),
    );

    await tester.tap(find.byKey(const Key('progress-record-options-toggle')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('progress-kind-assessment')));
    await tester.pumpAndSettle();

    final resultPicker = find.byKey(const Key('progress-assessment-result'));
    expect(resultPicker, findsOneWidget);
    await tester.tap(resultPicker);
    await tester.pumpAndSettle();
    await tester.tap(find.text('通过').last);
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<TextField>(find.byKey(const Key('progress-summary')))
          .controller
          ?.text,
      isEmpty,
    );
    await _tapVisible(tester, find.byKey(const Key('progress-save')));
    await tester.pumpAndSettle();

    final command = repository.progressCommands.single;
    expect(command.progressKind, CaseProgressKind.assessment);
    expect(command.assessmentResult, CaseAssessmentResult.passed);
    expect(command.summary, '检查结果：通过');
    expect(command.nextStep, CaseProgressNextStep.continueTracking);
  });

  testWidgets(
    'Today-style progress can complete the current action without a next action',
    (tester) async {
      final repository = _FakeProgressiveCaseRepository();
      final action = _action();
      await tester.pumpWidget(
        _host(
          CaseProgressForm(
            repository: repository,
            learningCase: _case(action: action),
            currentAction: action,
            completeCurrentActionInitially: true,
          ),
        ),
      );

      expect(
        tester
            .widget<SwitchListTile>(
              find.byKey(const Key('progress-complete-current-action')),
            )
            .value,
        isTrue,
      );
      await tester.enterText(
        find.byKey(const Key('progress-summary')),
        '今天已经完成针对性练习',
      );
      await _tapVisible(tester, find.byKey(const Key('progress-save')));
      await tester.pumpAndSettle();

      final command = repository.progressCommands.single;
      expect(command.completeCurrentAction, isTrue);
      expect(command.currentActionId, action.id);
      expect(command.expectedActionVersion, action.version);
      expect(command.nextStep, CaseProgressNextStep.continueTracking);
      expect(command.nextActionTitle, isNull);
    },
  );

  testWidgets(
    'progress can end follow-up only after teacher opens follow-up options',
    (tester) async {
      final repository = _FakeProgressiveCaseRepository();
      await tester.pumpWidget(
        _host(CaseProgressForm(repository: repository, learningCase: _case())),
      );

      await tester.enterText(
        find.byKey(const Key('progress-summary')),
        '连续两周都没有再出现漏看限制词',
      );
      expect(find.byKey(const Key('progress-next-close')), findsNothing);
      await tester.tap(find.byKey(const Key('progress-next-options-toggle')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('progress-next-close')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('progress-close-reason')), findsOneWidget);
      await _tapVisible(tester, find.byKey(const Key('progress-save')));
      await tester.pumpAndSettle();

      final command = repository.progressCommands.single;
      expect(command.nextStep, CaseProgressNextStep.close);
      expect(command.closeReason, CaseClosureReason.other);
      expect(command.nextActionTitle, isNull);
    },
  );

  testWidgets('a new case can end follow-up directly', (tester) async {
    final repository = _FakeProgressiveCaseRepository();
    await tester.pumpWidget(
      _host(
        EndCaseFollowUpForm(
          repository: repository,
          learningCase: _case(status: LearningCaseStatus.newCase),
        ),
      ),
    );

    expect(find.text('结束跟进'), findsWidgets);
    expect(find.text('结束当前跟进'), findsOneWidget);
    await tester.tap(find.byKey(const Key('end-follow-up-save')));
    await tester.pumpAndSettle();

    final command = repository.endCommands.single;
    expect(command.expectedCaseVersion, 3);
    expect(command.reason, CaseClosureReason.other);
  });
  testWidgets('teacher can explicitly mark a follow-up as resolved', (
    tester,
  ) async {
    final repository = _FakeProgressiveCaseRepository();
    await tester.pumpWidget(
      _host(
        EndCaseFollowUpForm(
          repository: repository,
          learningCase: _case(status: LearningCaseStatus.newCase),
        ),
      ),
    );

    final reasonField = find.byKey(const Key('end-follow-up-reason'));
    await _tapVisible(tester, reasonField);
    await tester.pumpAndSettle();
    await tester.tap(find.text('问题已解决').last);
    await tester.pumpAndSettle();
    await _tapVisible(tester, find.byKey(const Key('end-follow-up-save')));
    await tester.pumpAndSettle();

    expect(repository.endCommands.single.reason, CaseClosureReason.resolved);
  });
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
}

Widget _host(Widget child) {
  return MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(body: Center(child: child)),
  );
}

WorkspaceCase _case({
  LearningCaseStatus status = LearningCaseStatus.confirmed,
  WorkspaceAction? action,
}) {
  return WorkspaceCase(
    id: 'case-1',
    profileId: 'profile-1',
    title: '阅读题漏看限制词',
    type: LearningCaseType.knowledge,
    status: status,
    priority: 'normal',
    description: '做题时容易跳过题干中的限制词',
    firstObservedAt: DateTime(2026, 9, 8),
    version: 3,
    evidence: const <WorkspaceEvidence>[],
    interventions: const <WorkspaceIntervention>[],
    assessments: const <WorkspaceAssessment>[],
    actions: action == null
        ? const <WorkspaceAction>[]
        : <WorkspaceAction>[action],
    timeline: const <WorkspaceTimelineEvent>[],
  );
}

WorkspaceAction _action() {
  return const WorkspaceAction(
    id: 'action-1',
    caseId: 'case-1',
    title: '做一组限制词专项练习',
    actionType: 'practice',
    status: WorkspaceActionStatus.pending,
    isPrimary: true,
    bucket: WorkspaceActionBucket.today,
    version: 2,
  );
}

class _FakeProgressiveCaseRepository implements ProgressiveCaseRepository {
  final List<RecordCaseProgressCommand> progressCommands =
      <RecordCaseProgressCommand>[];
  final List<EndCaseFollowUpCommand> endCommands = <EndCaseFollowUpCommand>[];

  @override
  Future<ProgressiveCaseReceipt> recordProgress(
    RecordCaseProgressCommand command,
  ) async {
    command.validate();
    progressCommands.add(command);
    return ProgressiveCaseReceipt(
      operationId: command.operationId,
      caseId: command.caseId,
      status: command.nextStep == CaseProgressNextStep.close
          ? 'closed'
          : 'confirmed',
      caseVersion: command.expectedCaseVersion + 1,
      nextStep: command.nextStep.wireValue,
      recordId: 'record-1',
    );
  }

  @override
  Future<ProgressiveCaseReceipt> endFollowUp(
    EndCaseFollowUpCommand command,
  ) async {
    command.validate();
    endCommands.add(command);
    return ProgressiveCaseReceipt(
      operationId: command.operationId,
      caseId: command.caseId,
      status: 'closed',
      caseVersion: command.expectedCaseVersion + 1,
      eventId: 'event-1',
    );
  }
}
