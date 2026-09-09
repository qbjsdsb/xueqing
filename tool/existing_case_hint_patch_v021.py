from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected 1 match, found {count}")
    return text.replace(old, new, 1)


page_path = Path("lib/features/teacher_workspace/presentation/teacher_workspace_page.dart")
text = page_path.read_text(encoding="utf-8")

anchor = """  WorkspaceCaseType get _selectedCaseType {
    for (final caseType in _caseTypeOptions) {
      if (caseType.key == _selectedCaseTypeKey) {
        return caseType;
      }
    }
    return WorkspaceCaseType.builtInTypes.last;
  }
"""
replacement = anchor + """
  List<WorkspaceCase> get _currentCasesForSelectedStudent {
    final student = _selectedStudent;
    if (student == null) {
      return const <WorkspaceCase>[];
    }
    final cases = student.cases
        .where((learningCase) => learningCase.status != LearningCaseStatus.closed)
        .toList()
      ..sort(
        (left, right) => right.firstObservedAt.compareTo(left.firstObservedAt),
      );
    return List<WorkspaceCase>.unmodifiable(cases);
  }
"""
text = replace_once(text, anchor, replacement, "current case getter")

text = replace_once(
    text,
    """  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return PopScope<void>(""",
    """  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final currentCases = _currentCasesForSelectedStudent;
    return PopScope<void>(""",
    "quick capture build state",
)

student_anchor = """                  if (widget.initialStudent != null)
                    _WorkspaceContextLine(
                      label: '学生',
                      value: [
                        widget.initialStudent!.name,
                        widget.initialStudent!.subject,
                      ].join(' · '),
                    )
                  else
                    _buildStudentField(context),
                  const SizedBox(height: AppSpacing.md),
                  TextField("""
student_replacement = """                  if (widget.initialStudent != null)
                    _WorkspaceContextLine(
                      label: '学生',
                      value: [
                        widget.initialStudent!.name,
                        widget.initialStudent!.subject,
                      ].join(' · '),
                    )
                  else
                    _buildStudentField(context),
                  if (currentCases.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Container(
                      key: const Key('quick-capture-existing-cases-hint'),
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest
                            .withValues(alpha: 0.46),
                        borderRadius: BorderRadius.circular(AppRadii.compact),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.history_outlined,
                            size: 19,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '这个学生已有正在跟进的问题',
                                  style: Theme.of(context).textTheme.labelLarge,
                                ),
                                const SizedBox(height: AppSpacing.xxs),
                                Text(
                                  [
                                    ...currentCases
                                        .take(3)
                                        .map((learningCase) => learningCase.title),
                                    if (currentCases.length > 3)
                                      '另外 ${currentCases.length - 3} 个',
                                  ].join(' · '),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                const SizedBox(height: AppSpacing.xxs),
                                Text(
                                  '如果今天看到的是这些问题的新变化，请用“记进展”；确实是新的问题，可以继续记录。',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  TextField("""
text = replace_once(text, student_anchor, student_replacement, "existing case hint UI")
page_path.write_text(text, encoding="utf-8")


test_path = Path("test/features/teacher_workspace_test.dart")
test = test_path.read_text(encoding="utf-8")
insert_after = """  testWidgets('focuses the problem title after choosing a student', (
    tester,
  ) async {
    final repository = _FakeLearningRepository(_fixtureWorkspace());
    await _pumpWorkspace(tester, repository);

    await tester.tap(find.text('记录新问题').first);
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
"""
new_tests = insert_after + """

  testWidgets('new problem flow quietly shows current problems after student selection', (
    tester,
  ) async {
    final repository = _FakeLearningRepository(_fixtureWorkspace());
    await _pumpWorkspace(tester, repository);

    await tester.tap(find.text('记录新问题').first);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('quick-capture-existing-cases-hint')),
      findsNothing,
    );

    final studentPicker = find.byType(
      DropdownButtonFormField<WorkspaceStudent>,
    );
    await tester.ensureVisible(studentPicker);
    await tester.tap(studentPicker);
    await tester.pumpAndSettle();
    await tester.tap(find.text('示例学生甲 · 数学').last);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('quick-capture-existing-cases-hint')),
      findsOneWidget,
    );
    expect(find.text('这个学生已有正在跟进的问题'), findsOneWidget);
    expect(find.textContaining('分数步骤需要继续观察'), findsOneWidget);
    expect(find.textContaining('请用“记进展”'), findsOneWidget);
    expect(find.byKey(const Key('workspace-quick-capture-save')), findsOneWidget);
  });

  testWidgets('new problem flow does not warn about already closed problems', (
    tester,
  ) async {
    final repository = _FakeLearningRepository(
      _fixtureWorkspace(status: LearningCaseStatus.closed),
    );
    await _pumpWorkspace(tester, repository);

    await tester.tap(find.text('记录新问题').first);
    await tester.pumpAndSettle();
    final studentPicker = find.byType(
      DropdownButtonFormField<WorkspaceStudent>,
    );
    await tester.ensureVisible(studentPicker);
    await tester.tap(studentPicker);
    await tester.pumpAndSettle();
    await tester.tap(find.text('示例学生甲 · 数学').last);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('quick-capture-existing-cases-hint')),
      findsNothing,
    );
  });
"""
test = replace_once(test, insert_after, new_tests, "Quick Capture duplicate guidance tests")
test_path.write_text(test, encoding="utf-8")


spec_path = Path("docs/design/SCREEN_SPECS.md")
spec = spec_path.read_text(encoding="utf-8")
old = "看起来已有相近记录……（可忽略）"
new = "如果该学生已有未结束问题，安静展示最多 3 个当前问题，并提示：若是已有问题的新变化请用“记进展”；确实是新问题仍可继续记录。"
if old not in spec:
    raise SystemExit("screen spec duplicate guidance anchor missing")
spec = spec.replace(old, new, 1)
spec_path.write_text(spec, encoding="utf-8")
