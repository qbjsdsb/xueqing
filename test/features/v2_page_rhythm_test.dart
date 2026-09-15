import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xueqing/app/theme/app_theme.dart';
import 'package:xueqing/features/design_v2/v2_page_header.dart';
import 'package:xueqing/features/design_v2/v2_theme.dart';
import 'package:xueqing/features/design_v2/v2_workspace_preview.dart';

void main() {
  Widget app() => MaterialApp(
    theme: V2Theme.light(),
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

  int auxiliaryLineCount(V2PageHeader header) {
    var count = 0;
    if (header.meta?.trim().isNotEmpty == true) count++;
    if (header.description?.trim().isNotEmpty == true) count++;
    return count;
  }

  testWidgets(
    'compact Personal keeps one editorial header and a quiet Organization entry',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      final todayHeaderFinder = find.byKey(const Key('v2-today-page-header'));
      expect(todayHeaderFinder, findsOneWidget);
      expect(
        auxiliaryLineCount(tester.widget<V2PageHeader>(todayHeaderFinder)),
        lessThanOrEqualTo(1),
      );
      expect(find.text('先处理已经安排好的跟进。'), findsNothing);
      expect(find.text('今天没有已安排的跟进。'), findsNothing);
      final todayX = tester.getTopLeft(todayHeaderFinder).dx;
      expect(find.byKey(const Key('v2-open-organization-scope')), findsNothing);
      expect(find.byType(NavigationBar), findsOneWidget);

      var navigation = tester.widget<NavigationBar>(find.byType(NavigationBar));
      navigation.onDestinationSelected!(1);
      await tester.pumpAndSettle();
      final studentsHeaderFinder = find.byKey(
        const Key('v2-students-page-header'),
      );
      expect(studentsHeaderFinder, findsOneWidget);
      expect(
        auxiliaryLineCount(tester.widget<V2PageHeader>(studentsHeaderFinder)),
        lessThanOrEqualTo(1),
      );
      final studentsX = tester.getTopLeft(studentsHeaderFinder).dx;
      expect(studentsX, closeTo(todayX, 0.01));
      expect(find.byKey(const Key('v2-open-organization-scope')), findsNothing);

      navigation = tester.widget<NavigationBar>(find.byType(NavigationBar));
      navigation.onDestinationSelected!(2);
      await tester.pumpAndSettle();
      final learningHeaderFinder = find.byKey(
        const Key('v2-learning-page-header'),
      );
      expect(learningHeaderFinder, findsOneWidget);
      expect(
        auxiliaryLineCount(tester.widget<V2PageHeader>(learningHeaderFinder)),
        lessThanOrEqualTo(1),
      );
      final learningX = tester.getTopLeft(learningHeaderFinder).dx;
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

    await tester.tap(find.byTooltip('我的学生'));
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

  testWidgets(
    'page-header actions keep a 48dp target with a quieter default icon',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: V2PageHeader(
              title: '学情',
              actions: [
                IconButton(
                  key: const Key('page-header-test-action'),
                  tooltip: '更多操作',
                  onPressed: () {},
                  icon: const Icon(Icons.more_vert),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final action = find.byKey(const Key('page-header-test-action'));
      final icon = find.descendant(of: action, matching: find.byIcon(Icons.more_vert));
      expect(action, findsOneWidget);
      expect(icon, findsOneWidget);
      expect(tester.getSize(action).width, greaterThanOrEqualTo(48));
      expect(tester.getSize(action).height, greaterThanOrEqualTo(48));
      expect(IconTheme.of(tester.element(icon)).size, 20);
      expect(tester.takeException(), isNull);
    },
  );

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
    expect(
      organization,
      contains('meta: widget.embedded ? null : _organizationMeta,'),
    );
    expect(loader, isNot(contains('MediaQuery.sizeOf(context).width < 720')));
    expect(loader, contains('ResponsiveBreakpoints.isCompact(context)'));
  });
}
