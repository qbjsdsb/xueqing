from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected exactly one match, found {count}")
    return text.replace(old, new, 1)


page_path = Path('lib/features/teacher_workspace/presentation/teacher_workspace_page.dart')
page = page_path.read_text()

old_filter = """        final query = _studentSearchController.text.trim();
        final students = workspace.students.where((student) {
          if (query.isEmpty) {
            return true;
          }
          final caseText = student.cases
              .map(
                (learningCase) =>
                    '${learningCase.title}${learningCase.description ?? ''}',
              )
              .join();
          return '${student.name}${student.subject}${student.context}$caseText'
              .contains(query);
        }).toList();
"""
new_filter = """        final query = _studentSearchController.text.trim();
        final studentGroups = _groupStudentsById(workspace.students).where((group) {
          if (query.isEmpty) {
            return true;
          }
          return group.any((student) {
            final caseText = student.cases
                .map(
                  (learningCase) =>
                      '${learningCase.title}${learningCase.description ?? ''}',
                )
                .join();
            return '${student.name}${student.subject}${student.context}$caseText'
                .contains(query);
          });
        }).toList();
"""
page = replace_once(page, old_filter, new_filter, 'student grouping filter')

old_list = """            if (students.isEmpty)
              const _WorkspaceStateNotice(
                title: '没有找到匹配的学生',
                message: '换一个姓名、学科或问题关键词试试。',
                icon: Icons.search_off_outlined,
              )
            else
              _WorkspaceSection(
                title: '学生列表',
                count:
                    '${students.map((student) => student.id).toSet().length} 人',
                child: Column(
                  children: [
                    for (final student in students)
                      _WorkspaceStudentRow(
                        student: student,
                        onOpen: () => _openStudent(student),
                      ),
                  ],
                ),
              ),
"""
new_list = """            if (studentGroups.isEmpty)
              const _WorkspaceStateNotice(
                title: '没有找到匹配的学生',
                message: '换一个姓名、学科或问题关键词试试。',
                icon: Icons.search_off_outlined,
              )
            else
              _WorkspaceSection(
                title: '学生列表',
                count: '${studentGroups.length} 人',
                child: Column(
                  children: [
                    for (final group in studentGroups)
                      if (group.length == 1)
                        _WorkspaceStudentRow(
                          student: group.single,
                          onOpen: () => _openStudent(group.single),
                        )
                      else
                        _WorkspaceMultiSubjectStudentRow(
                          students: group,
                          onOpen: _openStudent,
                        ),
                  ],
                ),
              ),
"""
page = replace_once(page, old_list, new_list, 'student grouped list')

helper_anchor = """List<WorkspaceStudent> _dedupeStudentsById(
  Iterable<WorkspaceStudent> students,
) {
"""
helper_insert = """List<List<WorkspaceStudent>> _groupStudentsById(
  Iterable<WorkspaceStudent> students,
) {
  final groups = <String, List<WorkspaceStudent>>{};
  for (final student in students) {
    groups.putIfAbsent(student.id, () => <WorkspaceStudent>[]).add(student);
  }
  return groups.values.toList(growable: false);
}

""" + helper_anchor
page = replace_once(page, helper_anchor, helper_insert, 'student grouping helper')

row_anchor = """class _WorkspaceCaseRow extends StatelessWidget {
"""
new_group_row = r"""class _WorkspaceMultiSubjectStudentRow extends StatelessWidget {
  const _WorkspaceMultiSubjectStudentRow({
    required this.students,
    required this.onOpen,
  });

  final List<WorkspaceStudent> students;
  final ValueChanged<WorkspaceStudent> onOpen;

  @override
  Widget build(BuildContext context) {
    final profiles = List<WorkspaceStudent>.of(students)
      ..sort((left, right) => left.subject.compareTo(right.subject));
    final student = profiles.first;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: AppSpacing.xxs),
            child: Icon(Icons.person_outline, size: 21),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student.name,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: AppSpacing.xxs),
                _WorkspaceMetadata(student.grade),
                const SizedBox(height: AppSpacing.xs),
                for (var index = 0; index < profiles.length; index++) ...[
                  if (index > 0) const Divider(height: 1),
                  _WorkspaceStudentSubjectLink(
                    student: profiles[index],
                    onOpen: () => onOpen(profiles[index]),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkspaceStudentSubjectLink extends StatelessWidget {
  const _WorkspaceStudentSubjectLink({
    required this.student,
    required this.onOpen,
  });

  final WorkspaceStudent student;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final activeCaseCount = student.cases
        .where(
          (learningCase) => learningCase.status != LearningCaseStatus.closed,
        )
        .length;
    final followUpLabel = activeCaseCount == 0
        ? '暂无需要跟进的问题'
        : '$activeCaseCount 个跟进中的问题';
    return Semantics(
      button: true,
      label: '打开 ${student.name} 的 ${student.subject} 学情',
      child: InkWell(
        key: ValueKey<String>(
          'workspace-student-subject-${student.profileId}',
        ),
        onTap: onOpen,
        borderRadius: BorderRadius.circular(AppRadii.small),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student.subject,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    if (student.context.trim().isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        student.context,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      followUpLabel,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Icon(
                Icons.chevron_right,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

""" + row_anchor
page = replace_once(page, row_anchor, new_group_row, 'multi subject student row')

copy_replacements = {
    "'提交前会保存安全恢复记录；两步可安全重试，退出应用后也会保留未完成进度。'": "'未完成的内容会自动保留；如果网络中断，重新打开后可以继续，不需要重复填写。'",
    "labelText: '证据来源 *'": "labelText: '记录来源 *'",
    "labelText: '复发证据标题 *'": "labelText: '简要标题 *'",
    "labelText: '可观察表现 *'": "labelText: '具体表现 *'",
    "'服务器会把观察时间和最新关闭边界比较；提交开始后输入会锁定，重试沿用原 operation ID。'": "'观察时间需要晚于上次结束跟进；开始保存后请等待完成，网络异常时可以直接重试。'",
    "'证据已保存，正在等待继续跟进；请重试完成第二步。'": "'这次观察已经保存，继续提交即可恢复跟进；如果刚才网络中断，直接重试即可。'",
    "? '证据已保存，但恢复记录暂时无法保存。请保持页面打开并重试。'": "? '这次观察已保存，但跟进状态暂时没有恢复。请保持页面打开并重试。'",
    ": '无法安全保存恢复记录，未提交到服务器。请重试。'": ": '这次内容还没有提交成功，请重试。'",
    "content: const Text('当前输入还没有保存。放弃后不会产生新的证据。'),": "content: const Text('当前输入还没有保存。放弃后不会新增这次观察记录。'),",
    "? '保存证据'": "? '保存并继续'",
    "return '观察时间必须晚于最近一次关闭时间；请调整实际观察时间后重试。';": "return '观察时间需要晚于最近一次结束跟进时间；请调整实际观察时间后重试。';",
}
for old, new in copy_replacements.items():
    page = replace_once(page, old, new, f'copy: {old[:32]}')

page_path.write_text(page)


test_path = Path('test/features/teacher_workspace_test.dart')
test = test_path.read_text()

old_fixture_signature = """WorkspaceStudent _studentFixture({
  required String id,
  required String name,
  DateTime? recentActivityAt,
  DateTime? actionDueAt,
  WorkspaceActionBucket actionBucket = WorkspaceActionBucket.overdue,
  String? actionTitle,
  List<WorkspaceCase>? cases,
}) {
"""
new_fixture_signature = """WorkspaceStudent _studentFixture({
  required String id,
  required String name,
  String? studentId,
  String? profileId,
  String subject = '数学',
  String context = '课堂学习',
  DateTime? recentActivityAt,
  DateTime? actionDueAt,
  WorkspaceActionBucket actionBucket = WorkspaceActionBucket.overdue,
  String? actionTitle,
  List<WorkspaceCase>? cases,
}) {
"""
test = replace_once(test, old_fixture_signature, new_fixture_signature, 'fixture options')
test = replace_once(
    test,
    """  return WorkspaceStudent(
    id: 'student-$id',
    profileId: 'profile-$id',
""",
    """  return WorkspaceStudent(
    id: studentId ?? 'student-$id',
    profileId: profileId ?? 'profile-$id',
""",
    'fixture identity',
)
test = replace_once(test, "    subject: '数学',\n    context: '课堂学习',\n", "    subject: subject,\n    context: context,\n", 'fixture subject context')

multi_test_anchor = """  testWidgets('clears student search in one tap and restores the list', (
"""
multi_test = r"""  testWidgets(
    'groups a multi-subject student once and keeps every subject reachable',
    (tester) async {
      final repository = _FakeLearningRepository(
        _workspaceWithStudents([
          _studentFixture(
            id: 'shared-math',
            name: '林同学',
            studentId: 'student-shared',
            profileId: 'profile-math',
            subject: '数学',
            context: '函数基础',
          ),
          _studentFixture(
            id: 'shared-chinese',
            name: '林同学',
            studentId: 'student-shared',
            profileId: 'profile-chinese',
            subject: '语文',
            context: '现代文阅读',
          ),
        ]),
      );
      await _pumpWorkspace(tester, repository);

      await tester.tap(find.byIcon(Icons.people_outline).first);
      await tester.pumpAndSettle();

      expect(find.text('1 人'), findsOneWidget);
      expect(find.text('林同学'), findsOneWidget);
      expect(
        find.byKey(
          const ValueKey<String>('workspace-student-subject-profile-math'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey<String>('workspace-student-subject-profile-chinese'),
        ),
        findsOneWidget,
      );
      expect(find.text('数学'), findsOneWidget);
      expect(find.text('语文'), findsOneWidget);

      final searchField = find.byKey(const Key('workspace-student-search'));
      await tester.enterText(searchField, '语文');
      await tester.pumpAndSettle();
      expect(find.text('林同学'), findsOneWidget);
      expect(find.text('数学'), findsOneWidget);
      expect(find.text('语文'), findsOneWidget);

      final chinese = find.byKey(
        const ValueKey<String>('workspace-student-subject-profile-chinese'),
      );
      await tester.ensureVisible(chinese);
      await tester.tap(chinese);
      await tester.pumpAndSettle();

      expect(find.text('林同学'), findsOneWidget);
      expect(find.textContaining('语文'), findsOneWidget);
      expect(find.textContaining('现代文阅读'), findsOneWidget);
    },
  );

""" + multi_test_anchor
test = replace_once(test, multi_test_anchor, multi_test, 'multi subject widget test')

# Reopen is one teacher action even though the backend preserves two safe steps.
test = test.replace("find.widgetWithText(FilledButton, '保存证据')", "find.widgetWithText(FilledButton, '保存并继续')")
test = test.replace("观察时间必须晚于最近一次关闭时间", "观察时间需要晚于最近一次结束跟进时间")

reopen_open_anchor = """    await tester.tap(reopenButton);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('reopen-evidence-title')),
"""
reopen_open_new = """    await tester.tap(reopenButton);
    await tester.pumpAndSettle();

    expect(find.text('记录来源 *'), findsOneWidget);
    expect(find.text('简要标题 *'), findsOneWidget);
    expect(find.text('具体表现 *'), findsOneWidget);
    expect(find.textContaining('operation ID'), findsNothing);
    expect(find.textContaining('服务器'), findsNothing);
    expect(find.textContaining('未完成的内容会自动保留'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('reopen-evidence-title')),
"""
test = replace_once(test, reopen_open_anchor, reopen_open_new, 'plain reopen copy test')

test_path.write_text(test)

contract_path = Path('test/features/workflow_clarity_contract_test.dart')
contract = contract_path.read_text()
contract = replace_once(
    contract,
    """    expect(source, contains('_dedupeStudentsById('));
""",
    """    expect(source, contains('_dedupeStudentsById('));
    expect(source, contains('_groupStudentsById('));
    expect(source, contains('_WorkspaceMultiSubjectStudentRow'));
    expect(source, contains("count: '\${studentGroups.length} 人'"));
""",
    'grouping contract',
)
contract = replace_once(
    contract,
    """    expect(source, contains("child: const Text('结束跟进')"));
""",
    """    expect(source, contains("child: const Text('结束跟进')"));
    expect(source, isNot(contains('operation ID')));
    expect(source, isNot(contains('未提交到服务器')));
    expect(source, contains("labelText: '记录来源 *'"));
    expect(source, contains("labelText: '简要标题 *'"));
    expect(source, contains("labelText: '具体表现 *'"));
    expect(source, contains("? '保存并继续'"));
""",
    'plain recovery contract',
)
contract_path.write_text(contract)
