import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xueqing/app/theme/app_theme.dart';
import 'package:xueqing/features/design_prototype/design_fixture.dart';
import 'package:xueqing/features/design_prototype/presentation/'
    'design_prototype_page.dart';

void main() {
  testWidgets('shows the Today work queue and opens quick capture', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light(), home: const DesignPrototypePage()),
    );
    await tester.pumpAndSettle();

    expect(find.text('今日'), findsWidgets);
    expect(find.text('已逾期'), findsOneWidget);
    expect(find.text('待验证'), findsWidgets);
    expect(find.text('待安排'), findsWidgets);

    await tester.tap(find.widgetWithText(OutlinedButton, '记录问题'));
    await tester.pumpAndSettle();

    expect(find.text('问题标题 *'), findsOneWidget);
    await tester.tap(find.byType(DropdownButtonFormField<PrototypeStudent>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('示例学生甲 · 数学').last);
    await tester.enterText(find.byType(TextField).first, '记录一个新的课堂问题');
    await tester.tap(find.widgetWithText(FilledButton, '记录问题'));
    await tester.pump(const Duration(milliseconds: 260));
    await tester.pumpAndSettle();

    expect(find.text('已记录为待整理问题'), findsOneWidget);
  });
}
