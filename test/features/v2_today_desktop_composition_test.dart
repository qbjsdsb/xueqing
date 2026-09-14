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

  Future<void> pumpAt(
    WidgetTester tester,
    Size size, {
    double textScale = 1,
    bool dark = false,
  }) async {
    await tester.binding.setSurfaceSize(size);
    await tester.pumpWidget(app(textScale: textScale, dark: dark));
    await tester.pumpAndSettle();
  }

  testWidgets('Today stays stacked below the expanded desktop breakpoint', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpAt(tester, const Size(1024, 720));

    expect(find.byKey(const Key('v2-today-stacked-content')), findsOneWidget);
    expect(find.byKey(const Key('v2-today-desktop-columns')), findsNothing);
    expect(find.byKey(const Key('v2-today-recent-stacked')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Today promotes recent students to a wide desktop side column', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpAt(tester, const Size(1440, 800));

    final primary = find.byKey(const Key('v2-today-primary-column'));
    final recent = find.byKey(const Key('v2-today-recent-column'));
    expect(find.byKey(const Key('v2-today-desktop-columns')), findsOneWidget);
    expect(primary, findsOneWidget);
    expect(recent, findsOneWidget);
    expect(find.byKey(const Key('v2-today-recent-stacked')), findsNothing);
    expect(
      tester.getTopLeft(recent).dx,
      greaterThan(tester.getTopLeft(primary).dx),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Today wide desktop remains stable in dark mode at 200 percent text',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await pumpAt(tester, const Size(1440, 800), textScale: 2, dark: true);

      expect(find.byKey(const Key('v2-today-desktop-columns')), findsOneWidget);
      expect(find.byKey(const Key('v2-today-recent-column')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
