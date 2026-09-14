import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xueqing/features/design_v2/v2_theme.dart';
import 'package:xueqing/features/design_v2/v2_workspace_preview.dart';

void main() {
  Widget app({double textScale = 1.0, bool dark = false}) => MaterialApp(
    theme: dark ? V2Theme.dark() : V2Theme.light(),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: V2WorkspacePreview(
      organizationPageBuilder:
          (
            context,
            onBackToPersonal,
            section,
            onSectionChanged,
            managementArea,
            onManagementAreaChanged,
          ) => PopScope<void>(
            canPop: false,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop) onBackToPersonal();
            },
            child: const Center(child: Text('机构测试页')),
          ),
    ),
  );

  testWidgets(
    'Windows rail breakpoint stays usable at low height with 200 percent text scale',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.binding.setSurfaceSize(const Size(1279, 480));
      await tester.pumpWidget(app(textScale: 2, dark: true));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('v2-expanded-shell')), findsOneWidget);
      final organizationLearning = find.byKey(
        const Key('v2-rail-organization-learning'),
      );
      expect(organizationLearning, findsOneWidget);
      final collapsedItemWidth = tester.getSize(organizationLearning).width;
      expect(collapsedItemWidth, lessThan(100));
      expect(
        find.byKey(const Key('v2-workspace-more')).hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);

      await tester.binding.setSurfaceSize(const Size(1280, 480));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('v2-expanded-shell')), findsOneWidget);
      final expandedItemWidth = tester.getSize(organizationLearning).width;
      expect(expandedItemWidth, greaterThan(150));
      expect(expandedItemWidth, greaterThan(collapsedItemWidth));
      expect(
        find.byKey(const Key('v2-workspace-more')).hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);

      await tester.tap(find.byTooltip('机构设置'));
      await tester.pumpAndSettle();
      expect(find.text('机构测试页'), findsOneWidget);
      expect(tester.takeException(), isNull);

      for (final size in const <Size>[
        Size(1024, 600),
        Size(1440, 600),
        Size(1920, 900),
      ]) {
        await tester.binding.setSurfaceSize(size);
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('v2-expanded-shell')), findsOneWidget);
        expect(
          find.byKey(const Key('v2-rail-organization-settings')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('v2-workspace-more')).hitTestable(),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull, reason: 'size=$size');
      }
    },
  );
}
