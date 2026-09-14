import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xueqing/features/design_v2/v2_theme.dart';
import 'package:xueqing/features/design_v2/v2_workspace_preview.dart';

void main() {
  Widget app({double textScale = 1, bool dark = false}) => MaterialApp(
    theme: dark ? V2Theme.dark() : V2Theme.light(),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: const V2WorkspacePreview(),
  );

  Future<void> openCase(
    WidgetTester tester,
    Size size, {
    double textScale = 1,
    bool dark = false,
  }) async {
    await tester.binding.setSurfaceSize(size);
    await tester.pumpWidget(app(textScale: textScale, dark: dark));
    await tester.pumpAndSettle();
    final caseTitle = find.text('函数应用题思路不清').first;
    await tester.ensureVisible(caseTitle);
    await tester.tap(caseTitle);
    await tester.pumpAndSettle();
  }

  testWidgets('case detail stays stacked below expanded desktop breakpoint', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await openCase(tester, const Size(1024, 720));

    expect(find.byKey(const Key('v2-case-stacked-sections')), findsOneWidget);
    expect(find.byKey(const Key('v2-case-desktop-columns')), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('v2-case-next-step-case-lin-function')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('case detail separates timeline from action on wide desktop', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await openCase(tester, const Size(1440, 800));

    final timeline = find.byKey(const Key('v2-case-timeline-column'));
    final action = find.byKey(const Key('v2-case-action-column'));
    expect(find.byKey(const Key('v2-case-desktop-columns')), findsOneWidget);
    expect(timeline, findsOneWidget);
    expect(action, findsOneWidget);
    expect(
      tester.getTopLeft(timeline).dx,
      lessThan(tester.getTopLeft(action).dx),
    );
    expect(
      find.byKey(const ValueKey<String>('v2-case-next-step-case-lin-function')),
      findsOneWidget,
    );
    expect(find.text('成长过程'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('case wide desktop survives dark mode and 200 percent text', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await openCase(tester, const Size(1440, 800), textScale: 2, dark: true);

    expect(find.byKey(const Key('v2-case-desktop-columns')), findsOneWidget);
    expect(find.byKey(const Key('v2-case-action-column')), findsOneWidget);
    expect(find.byKey(const Key('v2-case-timeline-column')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
