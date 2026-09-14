import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xueqing/features/design_v2/v2_theme.dart';
import 'package:xueqing/features/design_v2/v2_workspace_preview.dart';

void main() {
  Widget app({bool withOrganization = false}) => MaterialApp(
    theme: V2Theme.light(),
    home: V2WorkspacePreview(
      organizationPageBuilder: withOrganization
          ? (
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
            )
          : null,
    ),
  );

  testWidgets('shared size classes drive compact medium and expanded shells', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(599, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('v2-compact-shell')), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);

    await tester.binding.setSurfaceSize(const Size(600, 844));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('v2-medium-shell')), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);

    await tester.binding.setSurfaceSize(const Size(1024, 844));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('v2-expanded-shell')), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('medium Student keeps a rail and drills into one pane', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('我的学生'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('v2-medium-shell')), findsOneWidget);
    expect(find.byKey(const Key('v2-student-search')), findsOneWidget);
    expect(find.text('现在最重要'), findsNothing);

    await tester.tap(find.text('林同学').first);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('v2-student-search')), findsNothing);
    expect(find.text('现在最重要'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets(
    'student detail survives medium expanded medium resize after selection',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('我的学生'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('林同学').first);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('v2-student-search')), findsNothing);
      expect(find.text('现在最重要'), findsOneWidget);

      await tester.binding.setSurfaceSize(const Size(1024, 844));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('v2-expanded-shell')), findsOneWidget);
      expect(find.text('现在最重要'), findsOneWidget);

      await tester.binding.setSurfaceSize(const Size(800, 844));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('v2-medium-shell')), findsOneWidget);
      expect(find.byKey(const Key('v2-student-search')), findsNothing);
      expect(find.text('现在最重要'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('student detail survives compact medium compact resize', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(599, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('学生').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('林同学').first);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('v2-student-search')), findsNothing);
    expect(find.text('现在最重要'), findsOneWidget);

    await tester.binding.setSurfaceSize(const Size(800, 844));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('v2-medium-shell')), findsOneWidget);
    expect(find.byKey(const Key('v2-student-search')), findsNothing);
    expect(find.text('现在最重要'), findsOneWidget);

    await tester.binding.setSurfaceSize(const Size(599, 844));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('v2-compact-shell')), findsOneWidget);
    expect(find.byKey(const Key('v2-student-search')), findsNothing);
    expect(find.text('现在最重要'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('medium Students rail returns an open student detail to list', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('我的学生'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('林同学').first);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('v2-student-search')), findsNothing);

    await tester.tap(find.byTooltip('我的学生'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('v2-student-search')), findsOneWidget);
    expect(find.text('现在最重要'), findsNothing);
  });

  testWidgets('expanded Student preserves master detail', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1024, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('我的学生'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('v2-expanded-shell')), findsOneWidget);
    expect(find.byKey(const Key('v2-student-search')), findsOneWidget);
    expect(find.text('现在最重要'), findsOneWidget);
  });

  testWidgets('600px window uses desktop dialog rather than mobile sheet', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(600, 844);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('v2-today-quick-capture')));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
  });

  testWidgets('599px window keeps mobile quick-capture sheet', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(599, 844);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('v2-today-quick-capture')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('v2-quick-capture-student-search')),
      findsOneWidget,
    );
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('medium manager reaches Organization from the rail', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(app(withOrganization: true));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('v2-medium-shell')), findsOneWidget);
    expect(
      find.byKey(const Key('v2-rail-organization-learning')),
      findsOneWidget,
    );
    expect(find.byType(NavigationBar), findsNothing);
    await tester.tap(find.byTooltip('机构学情监督'));
    await tester.pumpAndSettle();
    expect(find.text('机构测试页'), findsOneWidget);
  });

  test('V2 structural breakpoints come from the shared responsive facts', () {
    const files = [
      'lib/features/design_v2/v2_workspace_preview.dart',
      'lib/features/design_v2/v2_composers.dart',
      'lib/features/design_v2/v2_action_composers.dart',
      'lib/features/design_v2/v2_reopen_composer.dart',
      'lib/features/design_v2/v2_organization_workspace_page.dart',
    ];
    for (final path in files) {
      final source = File(path).readAsStringSync();
      expect(source, isNot(contains('width < 720')), reason: path);
      expect(source, contains('ResponsiveBreakpoints'), reason: path);
    }
  });
}
