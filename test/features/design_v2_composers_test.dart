import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xueqing/features/design_v2/v2_composers.dart';
import 'package:xueqing/features/design_v2/v2_theme.dart';

void main() {
  Widget app(Widget child) => MaterialApp(
    theme: V2Theme.light(),
    home: Scaffold(body: Center(child: child)),
  );

  testWidgets('Quick Capture requires subject when student has multiple subjects', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      app(
        Builder(
          builder: (context) => FilledButton(
            onPressed: () => showV2QuickCapture(
              context,
              studentName: '林同学',
              subjects: const ['语文', '数学'],
              attachmentPicker: (_) async => null,
            ),
            child: const Text('打开'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();

    expect(find.text('记录新问题'), findsOneWidget);
    expect(find.text('选择学科'), findsOneWidget);
    expect(find.text('语文'), findsOneWidget);
    expect(find.text('数学'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('v2-quick-capture-body')),
      '概括题遗漏结果。',
    );
    await tester.pump();

    var save = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '记录问题'),
    );
    expect(save.onPressed, isNull);

    await tester.tap(find.text('数学'));
    await tester.pump();

    save = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '记录问题'),
    );
    expect(save.onPressed, isNotNull);
  });

  testWidgets('Progress Composer progressively reveals assessment and reminder', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      app(
        Builder(
          builder: (context) => FilledButton(
            onPressed: () => showV2ProgressComposer(
              context,
              studentName: '林同学',
              subject: '语文',
              caseTitle: '阅读概括不完整',
              attachmentPicker: (_) async => null,
            ),
            child: const Text('打开'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();

    expect(find.text('记录进展'), findsOneWidget);
    expect(find.text('通过'), findsNothing);
    expect(find.byKey(const Key('v2-reminder-title')), findsNothing);

    await tester.tap(find.text('检查结果'));
    await tester.pumpAndSettle();

    expect(find.text('通过'), findsOneWidget);
    expect(find.text('部分通过'), findsOneWidget);
    expect(find.text('未通过'), findsOneWidget);

    await tester.tap(find.text('提醒我再检查'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('v2-reminder-title')), findsOneWidget);
    expect(find.byKey(const Key('v2-reminder-date')), findsOneWidget);
  });
}
