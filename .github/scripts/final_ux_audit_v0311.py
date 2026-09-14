from pathlib import Path

layout_path = Path('lib/features/organization_management/presentation/organization_management_layout.dart')
layout = layout_path.read_text(encoding='utf-8')
old = """        if (onExport == null) return switcher ?? const SizedBox.shrink();

        final Widget exportAction = constraints.maxWidth < 520
            ? IconButton(
                key: const Key('management-export-records'),
                tooltip: '导出记录',
                onPressed: busy ? null : onExport,
                icon: const Icon(Icons.download_outlined),
              )
            : TextButton.icon(
                key: const Key('management-export-records'),
                onPressed: busy ? null : onExport,
                icon: const Icon(Icons.download_outlined, size: 18),
                label: const Text('导出记录'),
              );

        if (switcher == null) {
          return Align(alignment: Alignment.centerRight, child: exportAction);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: switcher),
            const SizedBox(width: AppSpacing.sm),
            exportAction,
          ],
        );
"""
new = """        if (onExport == null) return switcher ?? const SizedBox.shrink();

        final exportMenu = PopupMenuButton<_ManagementToolbarAction>(
          key: const Key('management-tools-menu'),
          tooltip: '更多管理工具',
          enabled: !busy,
          onSelected: (action) {
            switch (action) {
              case _ManagementToolbarAction.exportRecords:
                onExport?.call();
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem<_ManagementToolbarAction>(
              key: Key('management-export-records'),
              value: _ManagementToolbarAction.exportRecords,
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.download_outlined),
                title: Text('导出记录'),
              ),
            ),
          ],
        );

        if (switcher == null) {
          return Align(alignment: Alignment.centerRight, child: exportMenu);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: switcher),
            const SizedBox(width: AppSpacing.xs),
            exportMenu,
          ],
        );
"""
if old not in layout:
    raise SystemExit('management export toolbar block drifted')
layout = layout.replace(old, new, 1)
marker = "class _ManagementToolbar extends StatelessWidget {"
if marker not in layout:
    raise SystemExit('management toolbar marker missing')
layout = layout.replace(marker, "enum _ManagementToolbarAction { exportRecords }\n\n" + marker, 1)
layout_path.write_text(layout, encoding='utf-8')

visual_path = Path('test/features/management_visual_density_test.dart')
visual = visual_path.read_text(encoding='utf-8')
old_visual = """    expect(layout, contains('class _ManagementToolbar'));
    expect(layout, contains(\"tooltip: '导出记录'\"));
    expect(layout, contains(\"label: const Text('导出记录')\"));
"""
new_visual = """    expect(layout, contains('class _ManagementToolbar'));
    expect(layout, contains('PopupMenuButton<_ManagementToolbarAction>'));
    expect(layout, contains(\"key: const Key('management-tools-menu')\"));
    expect(layout, contains(\"tooltip: '更多管理工具'\"));
    expect(layout, contains(\"key: Key('management-export-records')\"));
    expect(layout, contains(\"title: Text('导出记录')\"));
    expect(layout, isNot(contains(\"label: const Text('导出记录')\")));
"""
if old_visual not in visual:
    raise SystemExit('management visual contract drifted')
visual_path.write_text(visual.replace(old_visual, new_visual, 1), encoding='utf-8')

clarity_path = Path('test/features/management_workflow_clarity_contract_test.dart')
clarity = clarity_path.read_text(encoding='utf-8')
old_clarity = """    expect(layout, contains(\"key: const Key('management-export-records')\"));
    expect(layout, contains(\"tooltip: '导出记录'\"));
    expect(layout, contains(\"label: const Text('导出记录')\"));
"""
new_clarity = """    expect(layout, contains(\"key: const Key('management-tools-menu')\"));
    expect(layout, contains(\"tooltip: '更多管理工具'\"));
    expect(layout, contains(\"key: Key('management-export-records')\"));
    expect(layout, contains(\"title: Text('导出记录')\"));
    expect(layout, isNot(contains(\"label: const Text('导出记录')\")));
"""
if old_clarity not in clarity:
    raise SystemExit('management clarity contract drifted')
clarity_path.write_text(clarity.replace(old_clarity, new_clarity, 1), encoding='utf-8')

matrix = r'''import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xueqing/features/design_v2/v2_theme.dart';
import 'package:xueqing/features/design_v2/v2_workspace_preview.dart';

Widget _app({required bool dark, required double textScale}) => MaterialApp(
  theme: dark ? V2Theme.dark() : V2Theme.light(),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(
      textScaler: TextScaler.linear(textScale),
    ),
    child: child!,
  ),
  home: const V2WorkspacePreview(),
);

void main() {
  testWidgets('release matrix keeps compact teacher roots usable', (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final size in const <Size>[
      Size(320, 640),
      Size(360, 720),
      Size(390, 844),
      Size(412, 915),
    ]) {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(_app(dark: true, textScale: 1.5));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('v2-compact-shell')), findsOneWidget);
      expect(find.byKey(const Key('v2-today-page-header')), findsOneWidget);
      expect(find.byKey(const Key('v2-today-quick-capture')).hitTestable(), findsOneWidget);
      expect(find.byKey(const Key('v2-compact-more')).hitTestable(), findsOneWidget);
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

  testWidgets('release matrix keeps desktop roots usable at low height', (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final size in const <Size>[
      Size(600, 480),
      Size(800, 480),
      Size(1024, 480),
      Size(1279, 480),
      Size(1280, 480),
      Size(1440, 600),
    ]) {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(_app(dark: true, textScale: 2));
      await tester.pumpAndSettle();

      final expectedShell = size.width < 1024
          ? const Key('v2-medium-shell')
          : const Key('v2-expanded-shell');
      expect(find.byKey(expectedShell), findsOneWidget);
      expect(find.byKey(const Key('v2-workspace-more')).hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'size=$size');
    }
  });
}
'''
Path('test/features/release_ux_acceptance_matrix_test.dart').write_text(matrix, encoding='utf-8')

Path('.github/scripts/final_ux_audit_v0311.py').unlink()
Path('.github/workflows/final-ux-audit-v0311.yml').unlink()
