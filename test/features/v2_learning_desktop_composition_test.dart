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

  Future<void> openLearning(
    WidgetTester tester,
    Size size, {
    double textScale = 1,
    bool dark = false,
  }) async {
    await tester.binding.setSurfaceSize(size);
    await tester.pumpWidget(app(textScale: textScale, dark: dark));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('学情'));
    await tester.pumpAndSettle();
  }

  testWidgets('learning stays stacked below expanded desktop breakpoint', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await openLearning(tester, const Size(1024, 720));

    expect(
      find.byKey(const Key('v2-learning-stacked-content')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('v2-learning-desktop-columns')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('learning separates filters from results on wide desktop', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await openLearning(tester, const Size(1440, 800));

    final filters = find.byKey(const Key('v2-learning-filter-column'));
    final results = find.byKey(const Key('v2-learning-primary-column'));
    expect(
      find.byKey(const Key('v2-learning-desktop-columns')),
      findsOneWidget,
    );
    expect(filters, findsOneWidget);
    expect(results, findsOneWidget);
    expect(
      tester.getTopLeft(results).dx,
      greaterThan(tester.getTopLeft(filters).dx),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('learning wide desktop survives dark mode and 200 percent text', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await openLearning(tester, const Size(1440, 800), textScale: 2, dark: true);

    expect(
      find.byKey(const Key('v2-learning-desktop-columns')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('v2-learning-filter-column')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
