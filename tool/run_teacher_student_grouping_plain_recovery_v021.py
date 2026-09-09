from pathlib import Path
import runpy

script_path = Path('tool/apply_teacher_student_grouping_plain_recovery_v021.py')
source = script_path.read_text()

old = "test = replace_once(test, reopen_open_anchor, reopen_open_new, 'plain reopen copy test')"
new = """match_count = test.count(reopen_open_anchor)
if match_count != 2:
    raise SystemExit(
        f'plain reopen copy test: expected two reusable form-open anchors, found {match_count}'
    )
test = test.replace(reopen_open_anchor, reopen_open_new, 1)"""
if source.count(old) != 1:
    raise SystemExit('plain reopen patch runner: target statement changed')
source = source.replace(old, new, 1)

old_escape = "count: '\\${studentGroups.length} 人'"
new_escape = "count: '\\\\${studentGroups.length} 人'"
if source.count(old_escape) != 1:
    raise SystemExit('plain reopen patch runner: contract escape target changed')
source = source.replace(old_escape, new_escape, 1)

script_path.write_text(source)
runpy.run_path(str(script_path), run_name='__main__')

# The product list is now genuinely grouped by student id. The old contract
# asserted the pre-fix implementation detail, so make the regression guard
# assert that the old flat rendering path is gone instead.
contract_path = Path('test/features/workflow_clarity_contract_test.dart')
contract = contract_path.read_text()
old_contract = """    expect(
      source,
      contains(\"students.map((student) => student.id).toSet().length\"),
    );
"""
new_contract = """    expect(
      source,
      isNot(contains(\"students.map((student) => student.id).toSet().length\")),
    );
"""
if contract.count(old_contract) != 1:
    raise SystemExit('grouping contract: old flat-list expectation changed')
contract = contract.replace(old_contract, new_contract, 1)
contract_path.write_text(contract)

# After typing a subject into the search field, find.text() also sees the
# EditableText. Verify the subject row by its stable profile key instead of
# counting duplicate visible strings from the search control.
test_path = Path('test/features/teacher_workspace_test.dart')
test = test_path.read_text()
old_search_assertion = """      await tester.enterText(searchField, '语文');
      await tester.pumpAndSettle();
      expect(find.text('林同学'), findsOneWidget);
      expect(find.text('数学'), findsOneWidget);
      expect(find.text('语文'), findsOneWidget);

      final chinese = find.byKey(
"""
new_search_assertion = """      await tester.enterText(searchField, '语文');
      await tester.pumpAndSettle();
      expect(find.text('林同学'), findsOneWidget);
      expect(find.text('数学'), findsOneWidget);
      expect(
        find.byKey(
          const ValueKey<String>('workspace-student-subject-profile-chinese'),
        ),
        findsOneWidget,
      );

      final chinese = find.byKey(
"""
if test.count(old_search_assertion) != 1:
    raise SystemExit('grouping widget test: subject search assertion changed')
test = test.replace(old_search_assertion, new_search_assertion, 1)
test_path.write_text(test)

# Keep engineering wording out of the teacher-facing source text. These are
# implementation/recovery details, not concepts a teacher should have to learn.
page_path = Path('lib/features/teacher_workspace/presentation/teacher_workspace_page.dart')
page = page_path.read_text()
exact_replacements = {
    '// A committed reopen is safe to retry with the same operation ID.':
        '// A committed reopen is safe to retry with the same operation id.',
    "'无法安全保存恢复记录，未提交到服务器。请重试。'":
        "'这次内容还没有提交成功，请重试。'",
    "'证据已保存，但恢复记录暂时无法保存。请保持页面打开并重试。'":
        "'这次观察已保存，但跟进状态暂时没有恢复。请保持页面打开并重试。'",
}
for old_text, new_text in exact_replacements.items():
    if old_text in page:
        page = page.replace(old_text, new_text)
page_path.write_text(page)
