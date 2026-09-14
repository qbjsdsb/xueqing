from pathlib import Path

preview_path = Path('lib/features/design_v2/v2_workspace_preview.dart')
preview = preview_path.read_text(encoding='utf-8')

replacements = {
    "  void _openStudent(V2Student student) {\n    setState(() {":
        "  void _openStudent(V2Student student) {\n    FocusManager.instance.primaryFocus?.unfocus();\n    setState(() {",
    "  void _openCase(V2FocusItem item) {\n    final student = widget.data.studentForFocusItemOrNull(item);":
        "  void _openCase(V2FocusItem item) {\n    FocusManager.instance.primaryFocus?.unfocus();\n    final student = widget.data.studentForFocusItemOrNull(item);",
    "  void _openOrganization(V2OrganizationSection section) {\n    setState(() {":
        "  void _openOrganization(V2OrganizationSection section) {\n    FocusManager.instance.primaryFocus?.unfocus();\n    setState(() {",
    "      onNotification: (notification) {\n        notification.disallowIndicator();\n        return false;\n      },":
        "      onNotification: (notification) {\n        if (notification.depth == 0) {\n          notification.disallowIndicator();\n        }\n        return false;\n      },",
}
for old, new in replacements.items():
    count = preview.count(old)
    if count != 1:
        raise SystemExit(f'expected one match for {old!r}, found {count}')
    preview = preview.replace(old, new, 1)
preview_path.write_text(preview, encoding='utf-8')

# Add a behavioral regression: keeping the Student root mounted must not keep
# its EditableText focused after drilling into a foreground detail page.
test_path = Path('test/features/design_v2_workspace_test.dart')
test = test_path.read_text(encoding='utf-8')
anchor = "  testWidgets(\n    'Android compact root pages preserve student search across destination changes',"
if test.count(anchor) != 1:
    raise SystemExit('student-search continuity test anchor missing or duplicated')
new_test = r'''  testWidgets(
    'Android compact student drill-down releases retained search focus',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(androidApp());
      await tester.pumpAndSettle();
      await tester.tap(find.text('学生'));
      await tester.pumpAndSettle();

      final search = find.byKey(const Key('v2-student-search'));
      await tester.tap(search);
      await tester.enterText(search, '林同学');
      await tester.pump();
      final editable = tester.widget<EditableText>(
        find.descendant(of: search, matching: find.byType(EditableText)),
      );
      expect(editable.focusNode.hasFocus, isTrue);

      final studentResult = find.descendant(
        of: find.byType(ListView),
        matching: find.text('林同学'),
      );
      expect(studentResult, findsOneWidget);
      await tester.tap(studentResult);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('v2-student-detail-context-row')),
        findsOneWidget,
      );
      expect(editable.focusNode.hasFocus, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

'''
test = test.replace(anchor, new_test + anchor, 1)
test_path.write_text(test, encoding='utf-8')

contract_path = Path('test/features/android_predictive_back_contract_test.dart')
contract = contract_path.read_text(encoding='utf-8')
contract_anchor = "      expect(workspace, contains('const PageScrollPhysics()'));\n"
if contract.count(contract_anchor) != 1:
    raise SystemExit('predictive-back contract anchor missing or duplicated')
contract = contract.replace(
    contract_anchor,
    contract_anchor
    + "      expect(workspace, contains('if (notification.depth == 0)'));\n",
    1,
)
contract_path.write_text(contract, encoding='utf-8')
