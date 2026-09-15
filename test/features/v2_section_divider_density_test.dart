import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xueqing/features/design_v2/v2_theme.dart';
import 'package:xueqing/features/design_v2/v2_workspace_preview.dart';

void main() {
  Widget app() =>
      MaterialApp(theme: V2Theme.light(), home: const V2WorkspacePreview());

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
