from pathlib import Path

workspace = Path('lib/features/design_v2/v2_workspace_preview.dart')
text = workspace.read_text(encoding='utf-8')

today_old = """                    if (data.students.isNotEmpty) ...[\n                      const SizedBox(height: 24),\n                      Divider(\n                        color: Theme.of(context).colorScheme.outlineVariant,\n                      ),\n                      const SizedBox(height: 14),\n                      KeyedSubtree(\n                        key: const Key('v2-today-recent-stacked'),\n"""
today_new = """                    if (data.students.isNotEmpty) ...[\n                      const SizedBox(height: AppSpacing.xl),\n                      KeyedSubtree(\n                        key: const Key('v2-today-recent-stacked'),\n"""
if today_old not in text:
    raise SystemExit('today stacked divider anchor not found')
text = text.replace(today_old, today_new, 1)

student_old = """                          children: [\n                            current,\n                            const SizedBox(height: 34),\n                            Divider(color: scheme.outlineVariant),\n                            const SizedBox(height: 20),\n                            growth,\n                          ],\n"""
student_new = """                          children: [\n                            current,\n                            const SizedBox(height: AppSpacing.xl),\n                            growth,\n                          ],\n"""
if student_old not in text:
    raise SystemExit('student stacked divider anchor not found')
text = text.replace(student_old, student_new, 1)
workspace.write_text(text, encoding='utf-8')

test = Path('test/features/v2_section_divider_density_test.dart')
test.write_text("""import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xueqing/features/design_v2/v2_theme.dart';
import 'package:xueqing/features/design_v2/v2_workspace_preview.dart';

void main() {
  Widget app() => MaterialApp(
    theme: V2Theme.light(),
    home: const V2WorkspacePreview(),
  );

  testWidgets(
    'stacked Today and student sections use whitespace instead of decorative dividers',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1024, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      final todayStack = find.byKey(const Key('v2-today-stacked-content'));
      expect(todayStack, findsOneWidget);
      expect(find.byKey(const Key('v2-today-recent-stacked')), findsOneWidget);
      final todayColumn = tester.widget<Column>(todayStack);
      expect(todayColumn.children.whereType<Divider>(), isEmpty);

      await tester.tap(find.byTooltip('我的学生'));
      await tester.pumpAndSettle();

      final studentStack = find.byKey(const Key('v2-student-stacked-sections'));
      expect(studentStack, findsOneWidget);
      expect(find.text('现在最重要'), findsOneWidget);
      expect(find.text('最近成长'), findsOneWidget);
      final studentColumn = tester.widget<Column>(studentStack);
      expect(studentColumn.children.whereType<Divider>(), isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
}
""", encoding='utf-8')
