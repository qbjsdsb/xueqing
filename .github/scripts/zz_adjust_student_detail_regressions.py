from pathlib import Path

path = Path('test/features/teacher_workspace_test.dart')
tests = path.read_text()

old_priority = '''    expect(find.text('已经逾期的问题'), findsNWidgets(2));
    expect(find.text('今天要处理的问题'), findsNWidgets(2));
    expect(find.text('等待验证的问题'), findsNWidgets(3));
    expect(find.text('尚未安排的问题'), findsOneWidget);
    expect(find.text('未来再处理的问题'), findsOneWidget);
'''
new_priority = '''    expect(find.text('已经逾期的问题'), findsOneWidget);
    expect(find.text('今天要处理的问题'), findsOneWidget);
    expect(find.text('等待验证的问题'), findsOneWidget);
    expect(find.text('尚未安排的问题'), findsNothing);
    expect(find.text('未来再处理的问题'), findsNothing);

    final allCasesButton = find.widgetWithText(TextButton, '查看全部 5 个');
    await tester.ensureVisible(allCasesButton);
    await tester.tap(allCasesButton);
    await tester.pumpAndSettle();

    expect(find.text('全部问题'), findsOneWidget);
    expect(find.text('已经逾期的问题'), findsOneWidget);
    expect(find.text('今天要处理的问题'), findsOneWidget);
    expect(find.text('等待验证的问题'), findsOneWidget);
    expect(find.text('尚未安排的问题'), findsOneWidget);
    expect(find.text('未来再处理的问题'), findsOneWidget);
'''
if tests.count(old_priority) != 1:
    raise SystemExit('Student priority regression anchor drifted')
tests = tests.replace(old_priority, new_priority, 1)


def section_for(name: str) -> tuple[int, int, str]:
    marker = f"  testWidgets('{name}'"
    start = tests.find(marker)
    if start < 0:
        raise SystemExit(f'missing test section: {name}')
    end = tests.find('\n  testWidgets(', start + len(marker))
    if end < 0:
        end = tests.find('\n  test(', start + len(marker))
    if end < 0:
        end = len(tests)
    return start, end, tests[start:end]


def replace_in_section(name: str, old: str, new: str, count: int = 1) -> None:
    global tests
    start, end, section = section_for(name)
    if section.count(old) != count:
        raise SystemExit(
            f'{name}: expected {count} navigation anchor(s), found {section.count(old)}'
        )
    section = section.replace(old, new, count)
    tests = tests[:start] + section + tests[end:]


closed_open = '''    await tester.pumpAndSettle();
    final caseButton = find.widgetWithText(OutlinedButton, '查看 Case').first;
    await tester.ensureVisible(caseButton);
    await tester.tap(caseButton);
'''
closed_open_with_history = '''    await tester.pumpAndSettle();
    final allCasesButton = find.widgetWithText(TextButton, '查看全部 1 个');
    await tester.ensureVisible(allCasesButton);
    await tester.tap(allCasesButton);
    await tester.pumpAndSettle();
    final caseButton = find.widgetWithText(OutlinedButton, '查看 Case').first;
    await tester.ensureVisible(caseButton);
    await tester.tap(caseButton);
'''
replace_in_section(
    'records recurrence Evidence before reopening a closed Case',
    closed_open,
    closed_open_with_history,
)

direct_open = '''    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, '查看 Case').first);
'''
first_restore_open_with_history = '''    await tester.pumpAndSettle();
    final firstAllCasesButton = find.widgetWithText(TextButton, '查看全部 1 个');
    await tester.ensureVisible(firstAllCasesButton);
    await tester.tap(firstAllCasesButton);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, '查看 Case').first);
'''
replace_in_section(
    'restores an unfinished reopen after the page is recreated',
    direct_open,
    first_restore_open_with_history,
    count=2,
)

# The replacement above intentionally updates both page instances with the same
# safe path. Rename the second local variable so the Dart test keeps one scope.
start, end, restore_section = section_for(
    'restores an unfinished reopen after the page is recreated'
)
needle = "    final firstAllCasesButton = find.widgetWithText(TextButton, '查看全部 1 个');\n"
if restore_section.count(needle) != 2:
    raise SystemExit('restore Student history toggle count drifted')
first_index = restore_section.find(needle)
second_index = restore_section.find(needle, first_index + len(needle))
second_tail = restore_section[second_index:]
second_tail = second_tail.replace('firstAllCasesButton', 'restoredAllCasesButton', 3)
restore_section = restore_section[:second_index] + second_tail
tests = tests[:start] + restore_section + tests[end:]

unlock_open_with_history = '''    await tester.pumpAndSettle();
    final allCasesButton = find.widgetWithText(TextButton, '查看全部 1 个');
    await tester.ensureVisible(allCasesButton);
    await tester.tap(allCasesButton);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, '查看 Case').first);
'''
replace_in_section(
    'unlocks a reopen form after a deterministic Evidence failure',
    direct_open,
    unlock_open_with_history,
)

path.write_text(tests)
