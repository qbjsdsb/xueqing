import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xueqing/features/design_v2/v2_theme.dart';
import 'package:xueqing/features/design_v2/v2_workspace_preview.dart';

void main() {
  Widget app() => MaterialApp(
    theme: V2Theme.light(),
    home: V2WorkspacePreview(
      organizationPageBuilder:
          (context, onBackToPersonal, section, onSectionChanged) =>
              PopScope<void>(
                canPop: false,
                onPopInvokedWithResult: (didPop, _) {
                  if (!didPop) onBackToPersonal();
                },
                child: const Center(child: Text('机构测试页')),
              ),
    ),
  );

  testWidgets(
    'compact Personal keeps one editorial header and a quiet Organization entry',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('v2-today-page-header')), findsOneWidget);
      expect(find.text('先处理已经安排好的跟进。'), findsNothing);
      expect(find.text('今天没有已安排的跟进。'), findsNothing);
      final todayX = tester
          .getTopLeft(find.byKey(const Key('v2-today-page-header')))
          .dx;
      expect(find.byKey(const Key('v2-open-organization-scope')), findsNothing);
      expect(find.byType(NavigationBar), findsOneWidget);

      var navigation = tester.widget<NavigationBar>(find.byType(NavigationBar));
      navigation.onDestinationSelected!(1);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('v2-students-page-header')), findsOneWidget);
      final studentsX = tester
          .getTopLeft(find.byKey(const Key('v2-students-page-header')))
          .dx;
      expect(studentsX, closeTo(todayX, 0.01));
      expect(find.byKey(const Key('v2-open-organization-scope')), findsNothing);

      navigation = tester.widget<NavigationBar>(find.byType(NavigationBar));
      navigation.onDestinationSelected!(2);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('v2-learning-page-header')), findsOneWidget);
      final learningX = tester
          .getTopLeft(find.byKey(const Key('v2-learning-page-header')))
          .dx;
      expect(learningX, closeTo(todayX, 0.01));
      expect(find.byKey(const Key('v2-open-organization-scope')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Medium Personal pages share one title baseline', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    final todayX = tester
        .getTopLeft(find.byKey(const Key('v2-today-page-header')))
        .dx;

    await tester.tap(find.byTooltip('学生'));
    await tester.pumpAndSettle();
    final studentsX = tester
        .getTopLeft(find.byKey(const Key('v2-students-page-header')))
        .dx;

    await tester.tap(find.byTooltip('学情'));
    await tester.pumpAndSettle();
    final learningX = tester
        .getTopLeft(find.byKey(const Key('v2-learning-page-header')))
        .dx;

    expect(studentsX, closeTo(todayX, 0.01));
    expect(learningX, closeTo(todayX, 0.01));
    expect(find.byType(NavigationBar), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test('top-level V2 pages use the shared page-header grammar', () {
    final workspace = File('lib/features/design_v2/v2_workspace_preview.dart')
        .readAsStringSync();
    final organization = File(
      'lib/features/design_v2/v2_organization_workspace_page.dart',
    ).readAsStringSync();
    final loader = File('lib/features/design_v2/v2_workspace_loader.dart')
        .readAsStringSync();

    expect(workspace, contains("import 'v2_page_header.dart';"));
    expect(organization, contains("import 'v2_page_header.dart';"));
    expect(workspace, isNot(contains('class _CompactScopeBar')));
    expect(workspace, contains("Key('v2-today-page-header')"));
    expect(workspace, contains("Key('v2-students-page-header')"));
    expect(workspace, contains("Key('v2-learning-page-header')"));
    expect(workspace, contains("Key('v2-menu-open-organization')"));
    expect(workspace, isNot(contains("Key('v2-open-organization-scope')")));
    expect(organization, contains("Key('v2-organization-page-header')"));
    expect(loader, isNot(contains('MediaQuery.sizeOf(context).width < 720')));
    expect(loader, contains('ResponsiveBreakpoints.isCompact(context)'));
  });
}
