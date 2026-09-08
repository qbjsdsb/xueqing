from pathlib import Path


def replace_once(text: str, label: str, old: str, new: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected exactly one match, found {count}')
    return text.replace(old, new, 1)


workspace_path = Path(
    'lib/features/teacher_workspace/presentation/teacher_workspace_page.dart'
)
workspace = workspace_path.read_text()

workspace = replace_once(
    workspace,
    'Today new Case expansion state',
    '''  bool _showAllPendingVerification = false;\n  bool _showAllFutureActions = false;''',
    '''  bool _showAllPendingVerification = false;\n  bool _showAllNewCases = false;\n  bool _showAllFutureActions = false;''',
)

workspace = replace_once(
    workspace,
    'Today collects new Cases without Actions',
    '''  Widget _buildToday(TeacherWorkspace workspace) {\n    final actions = <WorkspaceActionWithContext>[];\n    final pendingVerification = <WorkspaceCaseWithContext>[];\n    for (final student in workspace.students) {\n      for (final learningCase in student.cases) {\n        if (learningCase.status == LearningCaseStatus.pendingVerification) {''',
    '''  Widget _buildToday(TeacherWorkspace workspace) {\n    final actions = <WorkspaceActionWithContext>[];\n    final pendingVerification = <WorkspaceCaseWithContext>[];\n    final newCases = <WorkspaceCaseWithContext>[];\n    for (final student in workspace.students) {\n      for (final learningCase in student.cases) {\n        if (learningCase.status == LearningCaseStatus.newCase &&\n            learningCase.primaryAction == null) {\n          newCases.add(\n            WorkspaceCaseWithContext(\n              student: student,\n              learningCase: learningCase,\n            ),\n          );\n          continue;\n        }\n        if (learningCase.status == LearningCaseStatus.pendingVerification) {''',
)

workspace = replace_once(
    workspace,
    'Today immediate-work semantics include new Cases',
    '''    final hasImmediateWork =\n        hasScheduledWork ||\n        pendingVerification.isNotEmpty ||\n        undated.isNotEmpty;\n    final hasBlockBeforeFuture =\n        hasScheduledWork || !hasImmediateWork || pendingVerification.isNotEmpty;''',
    '''    final hasImmediateWork =\n        hasScheduledWork ||\n        pendingVerification.isNotEmpty ||\n        newCases.isNotEmpty ||\n        undated.isNotEmpty;\n    final hasBlockBeforeFuture =\n        hasScheduledWork ||\n        !hasImmediateWork ||\n        pendingVerification.isNotEmpty ||\n        newCases.isNotEmpty;''',
)

workspace = replace_once(
    workspace,
    'Today renders new Case section before future Actions',
    '''        if (future.isNotEmpty) ...[\n          if (hasBlockBeforeFuture) const SizedBox(height: AppSpacing.lg),''',
    '''        if (newCases.isNotEmpty) ...[\n          if (hasScheduledWork || pendingVerification.isNotEmpty)\n            const SizedBox(height: AppSpacing.lg),\n          _WorkspaceSection(\n            key: const Key('workspace-new-cases-section'),\n            title: '待整理',\n            count: '${newCases.length} 个问题',\n            showTopDivider: true,\n            action: newCases.length > _todayPreviewLimit\n                ? TextButton(\n                    key: const Key('workspace-new-cases-toggle'),\n                    onPressed: () => setState(\n                      () => _showAllNewCases = !_showAllNewCases,\n                    ),\n                    child: AnimatedSwitcher(\n                      duration: AppMotion.effectiveDuration(\n                        context,\n                        AppMotion.quick,\n                      ),\n                      child: Text(\n                        _showAllNewCases ? '收起' : '查看全部',\n                        key: ValueKey<bool>(_showAllNewCases),\n                      ),\n                    ),\n                  )\n                : null,\n            child: Column(\n              children: [\n                for (final item\n                    in (_showAllNewCases\n                        ? newCases\n                        : newCases.take(_todayPreviewLimit)))\n                  _WorkspaceCaseRow(\n                    student: item.student,\n                    learningCase: item.learningCase,\n                    onOpen: () => _openCase(item.student, item.learningCase),\n                  ),\n              ],\n            ),\n          ),\n        ],\n        if (future.isNotEmpty) ...[\n          if (hasBlockBeforeFuture) const SizedBox(height: AppSpacing.lg),''',
)

workspace_path.write_text(workspace)


test_path = Path('test/features/teacher_workspace_test.dart')
test_source = test_path.read_text()

test_source = replace_once(
    test_source,
    'fixture can omit Action',
    '''TeacherWorkspace _fixtureWorkspace({\n  LearningCaseStatus status = LearningCaseStatus.newCase,\n  String actionType = 'practice',\n  List<WorkspaceCaseType>? caseTypes,\n  bool canManageCaseTypes = false,\n  String? assessmentResult,\n  DateTime? businessDate,\n  DateTime? businessDueDate,\n}) {''',
    '''TeacherWorkspace _fixtureWorkspace({\n  LearningCaseStatus status = LearningCaseStatus.newCase,\n  String actionType = 'practice',\n  List<WorkspaceCaseType>? caseTypes,\n  bool canManageCaseTypes = false,\n  String? assessmentResult,\n  DateTime? businessDate,\n  DateTime? businessDueDate,\n  bool includeAction = true,\n}) {''',
)

test_source = replace_once(
    test_source,
    'fixture omits Action when requested',
    '''    actions: status == LearningCaseStatus.closed\n        ? const <WorkspaceAction>[]\n        : <WorkspaceAction>[action],''',
    '''    actions: status == LearningCaseStatus.closed || !includeAction\n        ? const <WorkspaceAction>[]\n        : <WorkspaceAction>[action],''',
)

test_source = replace_once(
    test_source,
    'Today keeps new no-Action Case visible regression',
    '''  testWidgets(\n    'quiet Today uses one useful empty state and hides empty sections',''',
    '''  testWidgets(\n    'new Quick Capture Case without an Action remains visible in Today',\n    (tester) async {\n      final repository = _FakeLearningRepository(\n        _fixtureWorkspace(\n          status: LearningCaseStatus.newCase,\n          includeAction: false,\n        ),\n      );\n      await _pumpWorkspace(tester, repository);\n\n      expect(find.text('今天暂时没有需要处理的事项'), findsNothing);\n      expect(\n        find.byKey(const Key('workspace-new-cases-section')),\n        findsOneWidget,\n      );\n      expect(find.text('待整理'), findsWidgets);\n      expect(find.text('分数步骤需要继续观察'), findsOneWidget);\n      expect(\n        find.byKey(const Key('workspace-undated-actions-section')),\n        findsNothing,\n      );\n    },\n  );\n\n  testWidgets(\n    'quiet Today uses one useful empty state and hides empty sections',''',
)

test_path.write_text(test_source)
