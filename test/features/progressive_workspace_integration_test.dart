import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xueqing/app/theme/app_theme.dart';
import 'package:xueqing/cloud/learning_repository.dart';
import 'package:xueqing/cloud/progressive_case_repository.dart';
import 'package:xueqing/features/teacher_workspace/presentation/teacher_workspace_page.dart';

void main() {
  testWidgets('Today uses progressive handling instead of forced next action', (
    tester,
  ) async {
    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();

    expect(find.text('处理'), findsOneWidget);
    expect(find.text('完成行动'), findsNothing);
    expect(find.text('今天的工作'), findsOneWidget);
  });

  testWidgets('Case detail exposes progress and close, not legacy state steps', (
    tester,
  ) async {
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
  });
}

Widget _host() {
  return MaterialApp(
    theme: AppTheme.light(),
    home: TeacherWorkspacePage(
      repository: _WorkspaceRepository(_workspace()),
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

  @override
  Future<TeacherWorkspace> loadWorkspace() async => workspace;

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
  Future<ProgressiveCaseReceipt> endFollowUp(
    EndCaseFollowUpCommand command,
  ) {
    throw UnimplementedError();
  }
}
