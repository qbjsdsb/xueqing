from pathlib import Path

nav_path = Path('test/features/v2_typed_organization_navigation_test.dart')
data_path = Path('test/features/design_v2_workspace_data_injection_test.dart')
nav = nav_path.read_text()
data = data_path.read_text()

old_nav = "expect(find.text('学生 · 林同学'), findsOneWidget);"
count = nav.count(old_nav)
if count != 2:
    raise SystemExit(f'expected 2 legacy medium detail breadcrumb assertions, found {count}')
nav = nav.replace(old_nav, "expect(find.text('林同学'), findsOneWidget);")

old_data = """  testWidgets('student without active Case keeps progress action disabled', (\n    tester,\n  ) async {\n    await tester.binding.setSurfaceSize(const Size(1440, 900));\n    addTearDown(() => tester.binding.setSurfaceSize(null));\n\n    await tester.pumpWidget(app(_studentWithoutCases));\n    await tester.pumpAndSettle();\n    await tester.tap(find.byTooltip('学生'));\n    await tester.pumpAndSettle();\n\n    expect(find.text('暂无进行中的问题'), findsOneWidget);\n    final progressButton = tester.widget<FilledButton>(\n      find.widgetWithText(FilledButton, '记进展'),\n    );\n    expect(progressButton.onPressed, isNull);\n  });\n"""
new_data = """  testWidgets(\n    'student without active Case exposes only record-problem primary action',\n    (tester) async {\n      await tester.binding.setSurfaceSize(const Size(1440, 900));\n      addTearDown(() => tester.binding.setSurfaceSize(null));\n\n      await tester.pumpWidget(app(_studentWithoutCases));\n      await tester.pumpAndSettle();\n      await tester.tap(find.byTooltip('学生'));\n      await tester.pumpAndSettle();\n\n      expect(find.text('暂无进行中的问题'), findsOneWidget);\n      expect(find.text('记进展'), findsNothing);\n      expect(find.widgetWithText(FilledButton, '记录问题'), findsOneWidget);\n    },\n  );\n"""
if data.count(old_data) != 1:
    raise SystemExit('legacy data-injection progress assertion not found exactly once')
data = data.replace(old_data, new_data, 1)

nav_path.write_text(nav)
data_path.write_text(data)
