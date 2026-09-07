from pathlib import Path

source_path = Path('lib/features/teacher_workspace/presentation/teacher_workspace_page.dart')
source = source_path.read_text()

old_build = '''  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '打开 ${student.name} 的学生详情',
'''
new_build = '''  @override
  Widget build(BuildContext context) {
    final activeCaseCount = student.cases
        .where(
          (learningCase) =>
              learningCase.status != LearningCaseStatus.closed,
        )
        .length;
    return Semantics(
      button: true,
      label: '打开 ${student.name} 的学生详情',
'''
if source.count(old_build) != 1:
    raise SystemExit('Student row build anchor drifted')
source = source.replace(old_build, new_build, 1)

old_copy = '''                    Text(
                      student.cases.isEmpty
                          ? '还没有 Learning Case'
                          : '${student.cases.length} 个当前 Learning Case',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
'''
new_copy = '''                    Text(
                      activeCaseCount == 0
                          ? '暂无需要跟进的问题'
                          : '$activeCaseCount 个跟进中的问题',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
'''
if source.count(old_copy) != 1:
    raise SystemExit('Student row copy anchor drifted')
source = source.replace(old_copy, new_copy, 1)
source_path.write_text(source)

test_path = Path('test/features/teacher_workspace_test.dart')
tests = test_path.read_text()
anchor = '''    await _pumpWorkspace(tester, repository);

    final studentRow = find.text('示例学生甲').first;
'''
replacement = '''    await _pumpWorkspace(tester, repository);

    expect(find.text('暂无需要跟进的问题'), findsOneWidget);
    final studentRow = find.text('示例学生甲').first;
'''
marker = "  testWidgets('records recurrence Evidence before reopening a closed Case'"
start = tests.find(marker)
if start < 0:
    raise SystemExit('Closed recurrence test not found')
end = tests.find('\n  testWidgets(', start + len(marker))
if end < 0:
    raise SystemExit('Closed recurrence test end not found')
section = tests[start:end]
if section.count(anchor) != 1:
    raise SystemExit('Closed recurrence Student row anchor drifted')
section = section.replace(anchor, replacement, 1)
tests = tests[:start] + section + tests[end:]
test_path.write_text(tests)
