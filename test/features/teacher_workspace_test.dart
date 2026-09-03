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
}

TeacherWorkspace _fixtureWorkspace() {
  final action = WorkspaceAction(
    id: 'action-1',
    caseId: 'case-1',
    title: '补充一次课堂证据',
    actionType: 'practice',
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
    status: LearningCaseStatus.newCase,
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

    final studentRow = find.bySemanticsLabel('打开 示例学生甲 的学生详情');
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
