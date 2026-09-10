import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xueqing/features/design_v2/v2_action_composers.dart';

void main() {
  testWidgets('reschedule failure keeps selected date and retries in place', (
    tester,
  ) async {
    var calls = 0;
    final seenDates = <DateTime?>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: V2RescheduleActionComposer(
            actionTitle: '再检查一次',
            businessDate: DateTime(2026, 9, 10),
            initialDueOn: DateTime(2026, 9, 12),
            onSave: (dueOn) async {
              calls++;
              seenDates.add(dueOn);
              if (calls == 1) throw Exception('network timeout');
            },
          ),
        ),
      ),
    );

    expect(find.text('9 月 12 日'), findsOneWidget);
    await tester.tap(find.byKey(const Key('v2-reschedule-action-save')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('v2-action-save-error')), findsOneWidget);
    expect(find.text('9 月 12 日'), findsOneWidget);
    expect(calls, 1);

    await tester.tap(find.byKey(const Key('v2-reschedule-action-save')));
    await tester.pumpAndSettle();

    expect(calls, 2);
    expect(seenDates, [DateTime(2026, 9, 12), DateTime(2026, 9, 12)]);
  });

  testWidgets('completion failure stays open for safe retry', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: V2CompleteActionComposer(
            actionTitle: '再检查一次',
            onSave: () async {
              calls++;
              if (calls == 1) throw Exception('network timeout');
            },
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('v2-complete-action-save')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('v2-action-save-error')), findsOneWidget);
    expect(calls, 1);

    await tester.tap(find.byKey(const Key('v2-complete-action-save')));
    await tester.pumpAndSettle();
    expect(calls, 2);
  });

  testWidgets('compact action sheet stays usable in a short viewport', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 300));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              key: const Key('open-complete-action'),
              onPressed: () => showV2CompleteActionComposer(
                context,
                actionTitle: '一条较长的后续检查事项，用于验证横屏和小高度窗口仍然可以完整操作',
                onSave: () async {},
              ),
              child: const Text('打开'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('open-complete-action')));
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsWidgets);
    await tester.ensureVisible(find.byKey(const Key('v2-complete-action-save')));
    expect(find.byKey(const Key('v2-complete-action-save')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop action dialog stays usable in a short window', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 360));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              key: const Key('open-reschedule-action'),
              onPressed: () => showV2RescheduleActionComposer(
                context,
                actionTitle: '一条较长的后续检查事项，用于验证桌面小窗口仍然可以完整操作',
                businessDate: DateTime(2026, 9, 10),
                initialDueOn: DateTime(2026, 9, 12),
                onSave: (_) async {},
              ),
              child: const Text('打开'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('open-reschedule-action')));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsWidgets);
    await tester.ensureVisible(find.byKey(const Key('v2-reschedule-action-save')));
    expect(find.byKey(const Key('v2-reschedule-action-save')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
