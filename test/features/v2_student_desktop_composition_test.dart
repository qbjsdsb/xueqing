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

  Future<void> openFirstStudent(
    WidgetTester tester,
    Size size, {
    double textScale = 1,
    bool dark = false,
  }) async {
    await tester.binding.setSurfaceSize(size);
    await tester.pumpWidget(app(textScale: textScale, dark: dark));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('我的学生'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'student detail stays stacked below expanded desktop breakpoint',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await openFirstStudent(tester, const Size(1024, 720));

      expect(
        find.byKey(const Key('v2-student-stacked-sections')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('v2-student-desktop-columns')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'student detail separates current work and growth on wide desktop',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await openFirstStudent(tester, const Size(1440, 800));

      final primary = find.byKey(const Key('v2-student-primary-column'));
      final growth = find.byKey(const Key('v2-student-growth-column'));
      expect(
        find.byKey(const Key('v2-student-desktop-columns')),
        findsOneWidget,
      );
      expect(primary, findsOneWidget);
      expect(growth, findsOneWidget);
      expect(
        tester.getTopLeft(growth).dx,
        greaterThan(tester.getTopLeft(primary).dx),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('student wide desktop survives dark mode and 200 percent text', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await openFirstStudent(
      tester,
      const Size(1440, 800),
      textScale: 2,
      dark: true,
    );

    expect(find.byKey(const Key('v2-student-desktop-columns')), findsOneWidget);
    expect(find.byKey(const Key('v2-student-growth-column')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
