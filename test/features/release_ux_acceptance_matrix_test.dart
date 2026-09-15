import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xueqing/features/design_v2/v2_theme.dart';
import 'package:xueqing/features/design_v2/v2_workspace_preview.dart';

Widget _app({required bool dark, required double textScale}) => MaterialApp(
  theme: dark ? V2Theme.dark() : V2Theme.light(),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context)
        .copyWith(textScaler: TextScaler.linear(textScale)),
    child: child!,
  ),
  home: const V2WorkspacePreview(),
);

void main() {
  testWidgets('common text scales keep Chinese top-level headers readable', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(390, 844));

    for (final scale in const <double>[1, 1.3, 1.5]) {
      for (final dark in const <bool>[false, true]) {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        await tester.pumpWidget(_app(dark: dark, textScale: scale));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('v2-today-page-header')), findsOneWidget);
        expect(find.text('今日'), findsWidgets);
        expect(
          tester.takeException(),
          isNull,
          reason: 'today header scale=$scale dark=$dark',
        );
      }
    }
  });

  testWidgets('release matrix keeps compact teacher roots usable', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final size in const <Size>[
      Size(320, 640),
      Size(360, 720),
      Size(390, 844),
      Size(412, 915),
    ]) {
      // Each viewport is an independent release scenario. Destroy the previous
      // workspace first so root-navigation state cannot leak across sizes.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(_app(dark: true, textScale: 1.5));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('v2-compact-shell')), findsOneWidget);
      expect(find.byKey(const Key('v2-today-page-header')), findsOneWidget);
      expect(
        find.byKey(const Key('v2-today-quick-capture')).hitTestable(),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('v2-compact-more')).hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull, reason: 'today size=$size');

      var navigation = tester.widget<NavigationBar>(find.byType(NavigationBar));
      navigation.onDestinationSelected!(1);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('v2-students-page-header')), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'students size=$size');

      navigation = tester.widget<NavigationBar>(find.byType(NavigationBar));
      navigation.onDestinationSelected!(2);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('v2-learning-page-header')), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'learning size=$size');
    }
  });

  testWidgets('release matrix keeps desktop roots usable at low height', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final size in const <Size>[
      Size(600, 480),
      Size(800, 480),
      Size(1024, 480),
      Size(1279, 480),
      Size(1280, 480),
      Size(1440, 600),
    ]) {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(_app(dark: true, textScale: 2));
      await tester.pumpAndSettle();

      final expectedShell = size.width < 1024
          ? const Key('v2-medium-shell')
          : const Key('v2-expanded-shell');
      expect(find.byKey(expectedShell), findsOneWidget);
      expect(
        find.byKey(const Key('v2-workspace-more')).hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull, reason: 'size=$size');
    }
  });
}
