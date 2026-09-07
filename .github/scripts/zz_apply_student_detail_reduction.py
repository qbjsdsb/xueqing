from pathlib import Path

source_path = Path('lib/features/teacher_workspace/presentation/teacher_workspace_page.dart')
source = source_path.read_text()

old_fields = '''  static const int _todayPreviewLimit = 3;
  bool _showAllPendingVerification = false;
  bool _showAllFutureActions = false;
  bool _showAllUndatedActions = false;
'''
new_fields = '''  static const int _todayPreviewLimit = 3;
  static const int _studentPendingPreviewLimit = 2;
  bool _showAllPendingVerification = false;
  bool _showAllFutureActions = false;
  bool _showAllUndatedActions = false;
  bool _showAllStudentCases = false;
'''
if source.count(old_fields) != 1:
    raise SystemExit('Student state field anchor drifted')
source = source.replace(old_fields, new_fields, 1)

old_navigation = '''  void _selectDestination(int index) {
    setState(() {
      _selectedIndex = index;
      _selectedStudent = null;
      _selectedCase = null;
    });
  }

  void _openStudent(WorkspaceStudent student) {
    setState(() {
      _selectedStudent = student;
      _selectedCase = null;
    });
  }
'''
new_navigation = '''  void _selectDestination(int index) {
    setState(() {
      _selectedIndex = index;
      _selectedStudent = null;
      _selectedCase = null;
      _showAllStudentCases = false;
    });
  }

  void _openStudent(WorkspaceStudent student) {
    setState(() {
      _selectedStudent = student;
      _selectedCase = null;
      _showAllStudentCases = false;
    });
  }
'''
if source.count(old_navigation) != 1:
    raise SystemExit('Student navigation anchor drifted')
source = source.replace(old_navigation, new_navigation, 1)

old_back = '''    if (_selectedStudent != null) {
      setState(() => _selectedStudent = null);
    }
  }
'''
new_back = '''    if (_selectedStudent != null) {
      setState(() {
        _selectedStudent = null;
        _showAllStudentCases = false;
      });
    }
  }
'''
if source.count(old_back) != 1:
    raise SystemExit('Student back anchor drifted')
source = source.replace(old_back, new_back, 1)

old_subtitle = "              subtitle: '搜索学生，先理解当前重点，再进入需要处理的 Case。',\n"
new_subtitle = "              subtitle: '搜索学生，先理解当前重点，再进入需要处理的问题。',\n"
if source.count(old_subtitle) != 1:
    raise SystemExit('Student list copy anchor drifted')
source = source.replace(old_subtitle, new_subtitle, 1)

old_detail = '''  Widget _buildStudentDetail(
    WorkspaceStudent student,
    WindowSizeClass sizeClass,
  ) {
    final importantCases = _importantCasesForStudent(student);
    final pendingCases = student.cases
        .where(
          (learningCase) =>
              learningCase.status == LearningCaseStatus.pendingVerification,
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _WorkspacePageHeader(
          title: student.name,
          subtitle:
              '${student.grade} · ${student.subject} · ${student.context}',
          leading: IconButton(
            tooltip: '返回',
            onPressed: _goBack,
            icon: Icon(Icons.arrow_back),
          ),
          actions: [
            FilledButton.icon(
              onPressed: () => _showQuickCapture(student: student),
              icon: Icon(Icons.edit_note_outlined),
              label: const Text('记录问题'),
            ),
          ],
        ),
        _WorkspaceStateNotice(
          title: '学科上下文',
          message: student.positioning == null
              ? '当前显示 ${student.subject} 的最小学科上下文。'
              : student.positioning!,
          icon: Icons.menu_book_outlined,
        ),
        const SizedBox(height: AppSpacing.lg),
        if (importantCases.isEmpty)
          const _WorkspaceStateNotice(
            title: '还没有 Learning Case',
            message: '发现问题时，可以先记录一句，课后再整理。',
            icon: Icons.inbox_outlined,
          )
        else
          _WorkspaceSection(
            title: '现在最重要的事',
            count: '${importantCases.length} 项',
            child: Column(
              children: [
                for (final learningCase in importantCases)
                  _WorkspaceCaseRow(
                    student: student,
                    learningCase: learningCase,
                    onOpen: () => _openCase(student, learningCase),
                  ),
              ],
            ),
          ),
        const SizedBox(height: AppSpacing.lg),
        _WorkspaceSection(
          title: '当前 Learning Cases',
          count: '${student.cases.length} 个',
          showTopDivider: true,
          child: student.cases.isEmpty
              ? const _WorkspaceStateNotice(
                  title: '还没有当前 Case',
                  message: '问题出现时可以从这里开始记录。',
                  icon: Icons.inbox_outlined,
                )
              : Column(
                  children: [
                    for (final learningCase in student.cases)
                      _WorkspaceCaseRow(
                        student: student,
                        learningCase: learningCase,
                        onOpen: () => _openCase(student, learningCase),
                      ),
                  ],
                ),
        ),
        const SizedBox(height: AppSpacing.lg),
        _WorkspaceSection(
          title: '待验证',
          count: '${pendingCases.length} 个',
          showTopDivider: true,
          child: pendingCases.isEmpty
              ? const _WorkspaceStateNotice(
                  title: '目前没有待验证 Case',
                  message: '完成一次检查后，回到这里确认是否稳定。',
                  icon: Icons.fact_check_outlined,
                )
              : Column(
                  children: [
                    for (final learningCase in pendingCases)
                      _WorkspaceCaseRow(
                        student: student,
                        learningCase: learningCase,
                        onOpen: () => _openCase(student, learningCase),
                      ),
                  ],
                ),
        ),
        const SizedBox(height: AppSpacing.lg),
        _WorkspaceFacts(student: student, sizeClass: sizeClass),
      ],
    );
  }
'''
new_detail = '''  Widget _buildStudentDetail(
    WorkspaceStudent student,
    WindowSizeClass sizeClass,
  ) {
    final importantCases = _importantCasesForStudent(student);
    final allCases = student.cases.toList()
      ..sort(_compareCasesForStudentDetail);
    final visibleCases = _showAllStudentCases ? allCases : importantCases;
    final visibleCaseIds = visibleCases.map((item) => item.id).toSet();
    final additionalPendingCases = _showAllStudentCases
        ? const <WorkspaceCase>[]
        : allCases
              .where(
                (learningCase) =>
                    learningCase.status ==
                        LearningCaseStatus.pendingVerification &&
                    !visibleCaseIds.contains(learningCase.id),
              )
              .toList();
    final pendingPreview = additionalPendingCases
        .take(_studentPendingPreviewLimit)
        .toList();
    final hasAdditionalCases = allCases.length > importantCases.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _WorkspacePageHeader(
          title: student.name,
          subtitle:
              '${student.grade} · ${student.subject} · ${student.context}',
          leading: IconButton(
            tooltip: '返回',
            onPressed: _goBack,
            icon: Icon(Icons.arrow_back),
          ),
          actions: [
            FilledButton.icon(
              onPressed: () => _showQuickCapture(student: student),
              icon: Icon(Icons.edit_note_outlined),
              label: const Text('记录问题'),
            ),
          ],
        ),
        if (student.positioning?.trim().isNotEmpty == true) ...[
          Text(
            student.positioning!,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        _WorkspaceSection(
          key: const Key('student-detail-focus-section'),
          title: _showAllStudentCases ? '全部问题' : '现在最重要的事',
          count: '${visibleCases.length} 项',
          action: hasAdditionalCases
              ? TextButton(
                  key: const Key('student-detail-cases-toggle'),
                  onPressed: () => setState(
                    () => _showAllStudentCases = !_showAllStudentCases,
                  ),
                  child: Text(
                    _showAllStudentCases
                        ? '只看重点'
                        : '查看全部 ${allCases.length} 个',
                  ),
                )
              : null,
          child: visibleCases.isEmpty
              ? _WorkspaceStateNotice(
                  title: allCases.isEmpty ? '还没有记录的问题' : '当前没有需要跟进的问题',
                  message: allCases.isEmpty
                      ? '发现问题时，可以先记录一句，课后再整理。'
                      : '已有问题记录仍然保留，需要时可以查看全部。',
                  icon: Icons.inbox_outlined,
                )
              : Column(
                  children: [
                    for (final learningCase in visibleCases)
                      _WorkspaceCaseRow(
                        student: student,
                        learningCase: learningCase,
                        onOpen: () => _openCase(student, learningCase),
                      ),
                  ],
                ),
        ),
        if (additionalPendingCases.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          _WorkspaceSection(
            key: const Key('student-detail-pending-section'),
            title: '另外待验证',
            count: '${additionalPendingCases.length} 个',
            showTopDivider: true,
            action:
                additionalPendingCases.length > _studentPendingPreviewLimit
                ? TextButton(
                    key: const Key('student-detail-pending-toggle'),
                    onPressed: () => setState(() => _showAllStudentCases = true),
                    child: const Text('查看全部'),
                  )
                : null,
            child: Column(
              children: [
                for (final learningCase in pendingPreview)
                  _WorkspaceCaseRow(
                    student: student,
                    learningCase: learningCase,
                    onOpen: () => _openCase(student, learningCase),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        _WorkspaceFacts(student: student, sizeClass: sizeClass),
      ],
    );
  }
'''
if source.count(old_detail) != 1:
    raise SystemExit('Student detail anchor drifted')
source = source.replace(old_detail, new_detail, 1)
source_path.write_text(source)

test_path = Path('test/features/teacher_workspace_test.dart')
tests = test_path.read_text()
anchor = "  testWidgets('reschedules an action from Today', (tester) async {\n"
if tests.count(anchor) != 1:
    raise SystemExit('Student test insertion anchor drifted')
new_test = r'''  testWidgets(
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
          _studentFixture(
            id: 'student-detail',
            name: '学生详情示例',
            cases: cases,
          ),
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
      await tester.tap(
        find.byKey(const Key('student-detail-pending-toggle')),
      );
      await tester.pumpAndSettle();

      expect(find.text('全部问题'), findsOneWidget);
      expect(find.text('另外待验证'), findsNothing);
      expect(find.text('待验证问题 3'), findsOneWidget);
      expect(find.text('今天重点一'), findsOneWidget);
      expect(
        find.widgetWithText(TextButton, '只看重点'),
        findsOneWidget,
      );
    },
  );

'''
tests = tests.replace(anchor, new_test + anchor, 1)
test_path.write_text(tests)
