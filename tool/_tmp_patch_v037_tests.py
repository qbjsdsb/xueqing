from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected exactly one match, found {count}')
    return text.replace(old, new, 1)


def test_segment(text: str, test_name: str) -> tuple[int, int, str]:
    name_at = text.find(test_name)
    if name_at < 0:
        raise SystemExit(f'test not found: {test_name}')
    start = text.rfind('testWidgets(', 0, name_at)
    if start < 0:
        raise SystemExit(f'testWidgets start not found: {test_name}')
    end = text.find('\n  testWidgets(', name_at)
    if end < 0:
        end = text.find('\n}', name_at)
    if end < 0:
        end = len(text)
    return start, end, text[start:end]


def mutate_test(text: str, test_name: str, mutator) -> str:
    start, end, segment = test_segment(text, test_name)
    updated = mutator(segment)
    if updated == segment:
        raise SystemExit(f'no change produced for test: {test_name}')
    return text[:start] + updated + text[end:]


def navigate_desktop_students(segment: str) -> str:
    marker = '    await tester.pumpAndSettle();\n'
    if marker not in segment:
        raise SystemExit('pump marker missing')
    return segment.replace(
        marker,
        marker
        + "    await tester.tap(find.byTooltip('学生'));\n"
        + '    await tester.pumpAndSettle();\n',
        1,
    )


# Existing workspace tests must explicitly navigate when they are testing the
# Students destination now that Today is the intentional teacher home.
path = Path('test/features/design_v2_workspace_test.dart')
text = path.read_text()
text = text.replace(
    "desktop starts with student master-detail workspace",
    "desktop starts with Today and can enter student master-detail workspace",
    1,
)
text = mutate_test(
    text,
    'desktop starts with Today and can enter student master-detail workspace',
    lambda segment: segment.replace(
        '    await tester.pumpAndSettle();\n\n'
        "    expect(find.text('学生'), findsWidgets);",
        '    await tester.pumpAndSettle();\n\n'
        "    expect(find.byKey(const Key('v2-today-quick-capture')), findsOneWidget);\n"
        "    await tester.tap(find.byTooltip('学生'));\n"
        '    await tester.pumpAndSettle();\n\n'
        "    expect(find.text('学生'), findsWidgets);",
        1,
    ),
)
for name in (
    'desktop switches student-specific cases and timeline',
    'student with no active Case cannot start progress capture',
    'student search filters real people without changing identity',
):
    text = mutate_test(text, name, navigate_desktop_students)


def compact_student_detail(segment: str) -> str:
    old = (
        "    expect(find.byType(NavigationBar), findsOneWidget);\n"
        "    expect(find.text('林同学'), findsOneWidget);"
    )
    new = (
        "    expect(find.byType(NavigationBar), findsOneWidget);\n"
        "    await tester.tap(find.text('学生'));\n"
        "    await tester.pumpAndSettle();\n"
        "    expect(find.text('林同学'), findsOneWidget);"
    )
    if old not in segment:
        raise SystemExit('compact student detail expectations not found')
    return segment.replace(old, new, 1)


text = mutate_test(
    text,
    'compact uses bottom navigation and opens student detail',
    compact_student_detail,
)


def system_back(segment: str) -> str:
    old = (
        "    var navigation = tester.widget<NavigationBar>(find.byType(NavigationBar));\n"
        "    expect(navigation.selectedIndex, 1);\n\n"
        "    await tester.binding.handlePopRoute();"
    )
    new = (
        "    var navigation = tester.widget<NavigationBar>(find.byType(NavigationBar));\n"
        "    expect(navigation.selectedIndex, 0);\n\n"
        "    await tester.tap(find.text('学生'));\n"
        "    await tester.pumpAndSettle();\n"
        "    navigation = tester.widget<NavigationBar>(find.byType(NavigationBar));\n"
        "    expect(navigation.selectedIndex, 1);\n\n"
        "    await tester.binding.handlePopRoute();"
    )
    if old not in segment:
        raise SystemExit('system back baseline not found')
    return segment.replace(old, new, 1)


text = mutate_test(
    text,
    'compact system back returns secondary destination to Today',
    system_back,
)
path.write_text(text)


# Focus-presentation tests all exercise Student detail, not the default shell.
path = Path('test/features/v2_student_focus_presentation_test.dart')
text = path.read_text()
needle = '      await tester.pumpAndSettle();\n'
# Two tests use six-space indentation inside a multiline callback and one uses four.
for name in (
    'student focus hides visually duplicated summary and concise next step',
    'student focus keeps a genuinely different summary',
    'student detail shows three priorities before expanding all',
):
    def _navigate(segment: str) -> str:
        marker = '    await tester.pumpAndSettle();\n'
        indent = '    '
        if marker not in segment:
            marker = '      await tester.pumpAndSettle();\n'
            indent = '      '
        if marker not in segment:
            raise SystemExit(f'focus pump marker missing: {name}')
        return segment.replace(
            marker,
            marker
            + f"{indent}await tester.tap(find.byTooltip('学生'));\n"
            + f'{indent}await tester.pumpAndSettle();\n',
            1,
        )
    text = mutate_test(text, name, _navigate)
path.write_text(text)


# Injected-data tests that assert Student detail also navigate there explicitly.
path = Path('test/features/design_v2_workspace_data_injection_test.dart')
text = path.read_text()
for name in (
    'workspace renders injected data instead of global fixture',
    'student without active Case keeps progress action disabled',
    'closed history is visible but stays read-only',
    'unknown historical author renders time without fake separator',
):
    text = mutate_test(text, name, navigate_desktop_students)


def closed_history(segment: str) -> str:
    old = (
        "    expect(find.text('历史问题'), findsOneWidget);\n"
        "    expect(find.text('曾经的问题'), findsOneWidget);\n"
        "    await tester.tap(find.text('曾经的问题'));"
    )
    new = (
        "    expect(find.text('历史问题'), findsNothing);\n"
        "    expect(find.byKey(const Key('v2-student-history-toggle')), findsOneWidget);\n"
        "    await tester.tap(find.byKey(const Key('v2-student-history-toggle')));\n"
        "    await tester.pumpAndSettle();\n"
        "    expect(find.text('历史问题'), findsOneWidget);\n"
        "    expect(find.text('曾经的问题'), findsOneWidget);\n"
        "    await tester.tap(find.text('曾经的问题'));"
    )
    if old not in segment:
        raise SystemExit('closed history expectations not found')
    return segment.replace(old, new, 1)


text = mutate_test(text, 'closed history is visible but stays read-only', closed_history)
path.write_text(text)


# Today is already active on compact, so do not tap an ambiguous Today label.
path = Path('test/features/v2_final_ergonomics_test.dart')
text = path.read_text()

def quick_capture(segment: str) -> str:
    old = (
        "    await tester.tap(find.text('今日'));\n"
        "    await tester.pumpAndSettle();\n"
    )
    if old not in segment:
        raise SystemExit('redundant Today tap not found')
    return segment.replace(old, '', 1)


text = mutate_test(
    text,
    'quick capture student picker searches name grade and subject',
    quick_capture,
)

def operation_guide(segment: str) -> str:
    old = "      expect(find.text('记录问题'), findsOneWidget);"
    new = "      expect(find.text('记录问题'), findsWidgets);"
    if old not in segment:
        raise SystemExit('operation-guide record problem expectation not found')
    return segment.replace(old, new, 1)


text = mutate_test(
    text,
    'operation guide stays reachable without optional account actions',
    operation_guide,
)
path.write_text(text)


# Loader mapping should inspect the Student destination explicitly.
path = Path('test/features/design_v2_workspace_loader_test.dart')
text = path.read_text()
text = mutate_test(text, 'maps an authorized workspace into the V2 UI', navigate_desktop_students)
path.write_text(text)
