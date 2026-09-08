from pathlib import Path

product = Path('lib/features/teacher_workspace/presentation/teacher_workspace_page.dart')
text = product.read_text(encoding='utf-8')
start_marker = "  Widget _buildToday(TeacherWorkspace workspace) {\n"
end_marker = "  List<WorkspaceActionWithContext> _actionsInBucket(\n"
start = text.find(start_marker)
end = text.find(end_marker, start)
if start < 0 or end < 0:
    raise SystemExit('Could not locate _buildToday method boundaries')

replacement = """  Widget _buildToday(TeacherWorkspace workspace) {
    final actions = <WorkspaceActionWithContext>[];
    final pendingVerification = <WorkspaceCaseWithContext>[];
    for (final student in workspace.students) {
      for (final learningCase in student.cases) {
        if (learningCase.status == LearningCaseStatus.pendingVerification) {
          pendingVerification.add(
            WorkspaceCaseWithContext(
              student: student,
              learningCase: learningCase,
            ),
          );
          continue;
        }
        final action = learningCase.primaryAction;
        if (action == null ||
            learningCase.status == LearningCaseStatus.closed) {
          continue;
        }
        actions.add(
          WorkspaceActionWithContext(
            student: student,
            learningCase: learningCase,
            action: action,
          ),
        );
      }
    }

    final overdue = _actionsInBucket(actions, WorkspaceActionBucket.overdue);
    final today = _actionsInBucket(actions, WorkspaceActionBucket.today);
    final future = _actionsInBucket(actions, WorkspaceActionBucket.future);
    final undated = _actionsInBucket(actions, WorkspaceActionBucket.undated);
    final recentStudents = _studentsByRecentActivity(workspace.students);
    final hasScheduledWork = overdue.isNotEmpty || today.isNotEmpty;
    final hasImmediateWork =
        hasScheduledWork ||
        pendingVerification.isNotEmpty ||
        undated.isNotEmpty;
    final hasBlockBeforeFuture =
        hasScheduledWork || !hasImmediateWork || pendingVerification.isNotEmpty;
    final hasBlockBeforeUndated = hasBlockBeforeFuture || future.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _WorkspacePageHeader(
          title: '今日',
          subtitle: '先处理今天要做的事，再回看需要判断的学生。',
          actions: [
            FilledButton.icon(
              onPressed: () => _showQuickCapture(),
              icon: Icon(Icons.edit_note_outlined),
              label: const Text('记录问题'),
            ),
          ],
        ),
        if (!hasScheduledWork && !hasImmediateWork)
          _WorkspaceStateNotice(
            title: '今天暂时没有需要处理的事项',
            message: recentStudents.isEmpty
                ? '新的任课学生或需要跟进的问题会出现在这里。'
                : '可以回看最近学生，或在课堂中先记录一句问题。',
            icon: Icons.check_circle_outline,
          )
        else if (hasScheduledWork)
          _WorkspaceSection(
            key: const Key('workspace-today-work-section'),
            title: '今天的工作',
            count: '${overdue.length + today.length} 项',
            child: Column(
              children: [
                if (overdue.isNotEmpty) ...[
                  _WorkspaceSubheading(
                    label: '已逾期',
                    color: Theme.of(context).colorScheme.error,
                    icon: Icons.warning_amber_outlined,
                  ),
                  ..._buildActionRows(overdue, workspace),
                ],
                if (today.isNotEmpty) ...[
                  if (overdue.isNotEmpty) const Divider(height: AppSpacing.lg),
                  _WorkspaceSubheading(
                    label: '今天到期',
                    color: Theme.of(context).colorScheme.secondary,
                    icon: Icons.today_outlined,
                  ),
                  ..._buildActionRows(today, workspace),
                ],
              ],
            ),
          ),
        if (pendingVerification.isNotEmpty) ...[
          if (hasScheduledWork || !hasImmediateWork)
            const SizedBox(height: AppSpacing.lg),
          _WorkspaceSection(
            key: const Key('workspace-pending-verification-section'),
            title: '待验证',
            count: '${pendingVerification.length} 个问题',
            showTopDivider: true,
            action: pendingVerification.length > _todayPreviewLimit
                ? TextButton(
                    key: const Key('workspace-pending-verification-toggle'),
                    onPressed: () => setState(
                      () => _showAllPendingVerification =
                          !_showAllPendingVerification,
                    ),
                    child: AnimatedSwitcher(
                      duration: AppMotion.effectiveDuration(
                        context,
                        AppMotion.quick,
                      ),
                      child: Text(
                        _showAllPendingVerification ? '收起' : '查看全部',
                        key: ValueKey<bool>(_showAllPendingVerification),
                      ),
                    ),
                  )
                : null,
            child: Column(
              children: [
                for (final item
                    in (_showAllPendingVerification
                        ? pendingVerification
                        : pendingVerification.take(_todayPreviewLimit)))
                  _WorkspaceCaseRow(
                    student: item.student,
                    learningCase: item.learningCase,
                    onOpen: () => _openCase(item.student, item.learningCase),
                  ),
              ],
            ),
          ),
        ],
        if (future.isNotEmpty) ...[
          if (hasBlockBeforeFuture) const SizedBox(height: AppSpacing.lg),
          _WorkspaceSection(
            key: const Key('workspace-future-actions-section'),
            title: '之后要处理',
            count: '${future.length} 项',
            showTopDivider: true,
            action: future.length > _todayPreviewLimit
                ? TextButton(
                    key: const Key('workspace-future-actions-toggle'),
                    onPressed: () => setState(
                      () => _showAllFutureActions = !_showAllFutureActions,
                    ),
                    child: AnimatedSwitcher(
                      duration: AppMotion.effectiveDuration(
                        context,
                        AppMotion.quick,
                      ),
                      child: Text(
                        _showAllFutureActions ? '收起' : '查看全部',
                        key: ValueKey<bool>(_showAllFutureActions),
                      ),
                    ),
                  )
                : null,
            child: Column(
              children: _buildActionRows(
                _showAllFutureActions
                    ? future
                    : future.take(_todayPreviewLimit).toList(),
                workspace,
              ),
            ),
          ),
        ],
        if (undated.isNotEmpty) ...[
          if (hasBlockBeforeUndated) const SizedBox(height: AppSpacing.lg),
          _WorkspaceSection(
            key: const Key('workspace-undated-actions-section'),
            title: '待安排',
            count: '${undated.length} 项',
            showTopDivider: true,
            action: undated.length > _todayPreviewLimit
                ? TextButton(
                    key: const Key('workspace-undated-actions-toggle'),
                    onPressed: () => setState(
                      () => _showAllUndatedActions = !_showAllUndatedActions,
                    ),
                    child: AnimatedSwitcher(
                      duration: AppMotion.effectiveDuration(
                        context,
                        AppMotion.quick,
                      ),
                      child: Text(
                        _showAllUndatedActions ? '收起' : '查看全部',
                        key: ValueKey<bool>(_showAllUndatedActions),
                      ),
                    ),
                  )
                : null,
            child: Column(
              children: _buildActionRows(
                _showAllUndatedActions
                    ? undated
                    : undated.take(_todayPreviewLimit).toList(),
                workspace,
              ),
            ),
          ),
        ],
        if (recentStudents.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          _WorkspaceSection(
            title: '最近学生',
            showTopDivider: true,
            action: TextButton(
              onPressed: () => _selectDestination(1),
              child: const Text('查看全部'),
            ),
            child: Column(
              children: [
                for (final student in recentStudents.take(5))
                  _WorkspaceStudentRow(
                    student: student,
                    onOpen: () => _openStudent(student),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

"""
text = text[:start] + replacement + text[end:]
product.write_text(text, encoding='utf-8')

test_path = Path('test/features/teacher_workspace_test.dart')
tests = test_path.read_text(encoding='utf-8')
anchor = "  testWidgets(\n    'bounds lower-priority Today sections until explicitly expanded',\n"
if tests.count(anchor) != 1:
    raise SystemExit(f'Expected one Today preview test anchor, found {tests.count(anchor)}')

new_tests = """  testWidgets('pending verification is treated as real Today work', (tester) async {
    final repository = _FakeLearningRepository(
      _fixtureWorkspace(status: LearningCaseStatus.pendingVerification),
    );
    await _pumpWorkspace(tester, repository);

    expect(find.text('今天暂时没有需要处理的事项'), findsNothing);
    expect(find.text('今天没有已安排的行动'), findsNothing);
    expect(
      find.byKey(const Key('workspace-pending-verification-section')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('workspace-undated-actions-section')),
      findsNothing,
    );
    expect(find.text('分数步骤需要继续观察'), findsOneWidget);
  });

  testWidgets('quiet Today uses one useful empty state and hides empty sections', (
    tester,
  ) async {
    final repository = _FakeLearningRepository(
      _workspaceWithStudents([
        _studentFixture(id: 'quiet', name: '安静学生', cases: const []),
      ]),
    );
    await _pumpWorkspace(tester, repository);

    expect(find.text('今天暂时没有需要处理的事项'), findsOneWidget);
    expect(find.text('可以回看最近学生，或在课堂中先记录一句问题。'), findsOneWidget);
    expect(
      find.byKey(const Key('workspace-pending-verification-section')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('workspace-undated-actions-section')),
      findsNothing,
    );
    expect(find.text('最近学生'), findsOneWidget);
    expect(find.text('安静学生'), findsOneWidget);
  });

  testWidgets('empty assignment Today does not render a blank recent section', (
    tester,
  ) async {
    final repository = _FakeLearningRepository(_workspaceWithStudents(const []));
    await _pumpWorkspace(tester, repository);

    expect(find.text('今天暂时没有需要处理的事项'), findsOneWidget);
    expect(find.text('新的任课学生或需要跟进的问题会出现在这里。'), findsOneWidget);
    expect(find.text('最近学生'), findsNothing);
    expect(
      find.byKey(const Key('workspace-pending-verification-section')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('workspace-undated-actions-section')),
      findsNothing,
    );
  });

"""
tests = tests.replace(anchor, new_tests + anchor, 1)
test_path.write_text(tests, encoding='utf-8')
