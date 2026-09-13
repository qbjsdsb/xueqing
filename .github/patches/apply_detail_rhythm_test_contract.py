from pathlib import Path

path = Path('test/features/design_v2_workspace_test.dart')
text = path.read_text()
old = """    expect(find.text('暂无进行中的问题'), findsOneWidget);\n    expect(find.text('王老师负责语文'), findsOneWidget);\n    final progressButton = tester.widget<FilledButton>(\n      find.widgetWithText(FilledButton, '记进展'),\n    );\n    expect(progressButton.onPressed, isNull);\n"""
new = """    expect(find.text('暂无进行中的问题'), findsOneWidget);\n    expect(find.text('王老师负责语文'), findsOneWidget);\n    expect(find.text('记进展'), findsNothing);\n    expect(find.widgetWithText(FilledButton, '记录问题'), findsOneWidget);\n"""
count = text.count(old)
if count != 1:
    raise SystemExit(f'expected one legacy no-active-case assertion, found {count}')
path.write_text(text.replace(old, new, 1))
