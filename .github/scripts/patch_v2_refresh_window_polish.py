from pathlib import Path


def replace_once(path, old, new):
    p = Path(path)
    text = p.read_text()
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{path}: expected one match, found {count}')
    p.write_text(text.replace(old, new, 1))

# --- V2 loader: keep the current workspace visible while a manual refresh runs.
path = 'lib/features/design_v2/v2_workspace_loader.dart'
replace_once(
    path,
    """class _V2WorkspaceLoaderState extends State<V2WorkspaceLoader> {\n  late Future<TeacherWorkspace> _workspaceFuture;\n""",
    """class _V2WorkspaceLoaderState extends State<V2WorkspaceLoader> {\n  late Future<TeacherWorkspace> _workspaceFuture;\n  bool _refreshing = false;\n""",
)
replace_once(
    path,
    """  void _retry() {\n    final nextWorkspace = widget.loadWorkspace();\n    setState(() {\n      _workspaceFuture = nextWorkspace;\n    });\n  }\n""",
    """  void _retry() {\n    final nextWorkspace = widget.loadWorkspace();\n    setState(() {\n      _workspaceFuture = nextWorkspace;\n    });\n  }\n\n  Future<void> _refresh() async {\n    if (_refreshing) return;\n    setState(() => _refreshing = true);\n    try {\n      final workspace = await widget.loadWorkspace();\n      if (!mounted) return;\n      setState(() {\n        _workspaceFuture = Future<TeacherWorkspace>.value(workspace);\n      });\n    } finally {\n      if (mounted) setState(() => _refreshing = false);\n    }\n  }\n""",
)
replace_once(
    path,
    """                onChanged: _retry,\n              )\n""",
    """                onChanged: _retry,\n                onRefresh: _refresh,\n              )\n""",
)
replace_once(
    path,
    """              onChanged: _retry,\n            );\n""",
    """              onChanged: _retry,\n              onRefresh: _refresh,\n            );\n""",
)
replace_once(
    path,
    """          onSignOut: runtime?.onSignOut,\n          onWorkspaceChanged: workflowController == null ? null : _retry,\n""",
    """          onSignOut: runtime?.onSignOut,\n          onRefresh: _refresh,\n          onWorkspaceChanged: workflowController == null ? null : _retry,\n""",
)

# --- V2 management: a visible refresh action that re-reads the authenticated workspace.
path = 'lib/features/design_v2/v2_management_page.dart'
replace_once(
    path,
    """    this.rootMode = false,\n    this.onChanged,\n    super.key,\n""",
    """    this.rootMode = false,\n    this.onChanged,\n    this.onRefresh,\n    super.key,\n""",
)
replace_once(
    path,
    """  final bool rootMode;\n  final VoidCallback? onChanged;\n""",
    """  final bool rootMode;\n  final VoidCallback? onChanged;\n  final Future<void> Function()? onRefresh;\n""",
)
replace_once(
    path,
    """class _V2ManagementPageState extends State<V2ManagementPage> {\n  bool _checkingForUpdates = false;\n""",
    """class _V2ManagementPageState extends State<V2ManagementPage> {\n  bool _checkingForUpdates = false;\n  bool _refreshing = false;\n\n  Future<void> _refresh() async {\n    final refresh = widget.onRefresh;\n    if (refresh == null || _refreshing) return;\n    setState(() => _refreshing = true);\n    try {\n      await refresh();\n      if (!mounted) return;\n      ScaffoldMessenger.of(context).showSnackBar(\n        const SnackBar(content: Text('已刷新最新数据。')),\n      );\n    } catch (_) {\n      if (!mounted) return;\n      ScaffoldMessenger.of(context).showSnackBar(\n        const SnackBar(content: Text('刷新失败，请检查网络后重试。')),\n      );\n    } finally {\n      if (mounted) setState(() => _refreshing = false);\n    }\n  }\n""",
)
replace_once(
    path,
    """        actions: [\n          if (_checkingForUpdates)\n""",
    """        actions: [\n          if (widget.onRefresh != null)\n            IconButton(\n              key: const Key('v2-management-refresh'),\n              tooltip: _refreshing ? '正在刷新' : '刷新数据',\n              onPressed: _refreshing ? null : _refresh,\n              icon: _refreshing\n                  ? const SizedBox(\n                      width: 18,\n                      height: 18,\n                      child: CircularProgressIndicator(strokeWidth: 2),\n                    )\n                  : const Icon(Icons.refresh),\n            ),\n          if (_checkingForUpdates)\n""",
)

# --- Workspace shell refresh.
path = 'lib/features/design_v2/v2_workspace_preview.dart'
replace_once(
    path,
    """    this.appVersion,\n    this.onSignOut,\n    this.onWorkspaceChanged,\n""",
    """    this.appVersion,\n    this.onSignOut,\n    this.onRefresh,\n    this.onWorkspaceChanged,\n""",
)
replace_once(
    path,
    """  final String? appVersion;\n  final VoidCallback? onSignOut;\n  final VoidCallback? onWorkspaceChanged;\n""",
    """  final String? appVersion;\n  final VoidCallback? onSignOut;\n  final Future<void> Function()? onRefresh;\n  final VoidCallback? onWorkspaceChanged;\n""",
)
replace_once(
    path,
    """  bool _showCase = false;\n  bool _checkingForUpdates = false;\n""",
    """  bool _showCase = false;\n  bool _checkingForUpdates = false;\n  bool _refreshing = false;\n""",
)
replace_once(
    path,
    """  Future<void> _openManagement(BuildContext context) async {\n""",
    """  Future<void> _refreshWorkspace(BuildContext context) async {\n    final refresh = widget.onRefresh;\n    if (refresh == null || _refreshing) return;\n    setState(() => _refreshing = true);\n    try {\n      await refresh();\n      if (!mounted || !context.mounted) return;\n      ScaffoldMessenger.of(context).showSnackBar(\n        const SnackBar(content: Text('已刷新最新学情。')),\n      );\n    } catch (_) {\n      if (!mounted || !context.mounted) return;\n      ScaffoldMessenger.of(context).showSnackBar(\n        const SnackBar(content: Text('刷新失败，请检查网络后重试。')),\n      );\n    } finally {\n      if (mounted) setState(() => _refreshing = false);\n    }\n  }\n\n  Future<void> _openManagement(BuildContext context) async {\n""",
)
replace_once(
    path,
    """          children: [\n            if (widget.managementPageBuilder != null)\n""",
    """          children: [\n            if (widget.onRefresh != null)\n              ListTile(\n                key: const Key('v2-refresh-workspace'),\n                leading: _refreshing\n                    ? const SizedBox(\n                        width: 24,\n                        height: 24,\n                        child: CircularProgressIndicator(strokeWidth: 2),\n                      )\n                    : const Icon(Icons.refresh),\n                title: Text(_refreshing ? '正在刷新…' : '刷新学情'),\n                subtitle: const Text('重新读取老师和管理员刚刚更新的数据'),\n                onTap: _refreshing\n                    ? null\n                    : () => _afterMenuClose(\n                        menuContext,\n                        () => _refreshWorkspace(context),\n                      ),\n              ),\n            if (widget.managementPageBuilder != null)\n""",
)
replace_once(
    path,
    """            final hasMenuActions =\n                widget.managementPageBuilder != null ||\n""",
    """            final hasMenuActions =\n                widget.onRefresh != null ||\n                widget.managementPageBuilder != null ||\n""",
)
replace_once(
    path,
    """                  onManage: widget.managementPageBuilder == null\n                      ? null\n                      : () => _openManagement(context),\n                  onSettings: () => _showWorkspaceMenu(context),\n""",
    """                  onRefresh: widget.onRefresh == null\n                      ? null\n                      : () => _refreshWorkspace(context),\n                  refreshing: _refreshing,\n                  onManage: widget.managementPageBuilder == null\n                      ? null\n                      : () => _openManagement(context),\n                  onSettings: () => _showWorkspaceMenu(context),\n""",
)
replace_once(
    path,
    """    required this.onSettings,\n    this.onManage,\n  });\n""",
    """    required this.onSettings,\n    required this.refreshing,\n    this.onRefresh,\n    this.onManage,\n  });\n""",
)
replace_once(
    path,
    """  final VoidCallback onBackFromCase;\n  final VoidCallback? onManage;\n  final VoidCallback onSettings;\n""",
    """  final VoidCallback onBackFromCase;\n  final VoidCallback? onRefresh;\n  final bool refreshing;\n  final VoidCallback? onManage;\n  final VoidCallback onSettings;\n""",
)
replace_once(
    path,
    """                onSelected: onDestinationChanged,\n                onManage: onManage,\n                onSettings: onSettings,\n""",
    """                onSelected: onDestinationChanged,\n                onRefresh: onRefresh,\n                refreshing: refreshing,\n                onManage: onManage,\n                onSettings: onSettings,\n""",
)
replace_once(
    path,
    """    required this.onSettings,\n    this.onManage,\n  });\n\n  final int selectedIndex;\n""",
    """    required this.onSettings,\n    required this.refreshing,\n    this.onRefresh,\n    this.onManage,\n  });\n\n  final int selectedIndex;\n""",
)
replace_once(
    path,
    """  final ValueChanged<int> onSelected;\n  final VoidCallback? onManage;\n  final VoidCallback onSettings;\n""",
    """  final ValueChanged<int> onSelected;\n  final VoidCallback? onRefresh;\n  final bool refreshing;\n  final VoidCallback? onManage;\n  final VoidCallback onSettings;\n""",
)
replace_once(
    path,
    """          const Spacer(),\n          if (onManage != null)\n""",
    """          const Spacer(),\n          if (onRefresh != null)\n            _RailItem(\n              icon: Icons.refresh,\n              tooltip: refreshing ? '正在刷新' : '刷新学情',\n              onTap: refreshing ? null : onRefresh,\n              progress: refreshing,\n            ),\n          if (onManage != null)\n""",
)
replace_once(
    path,
    """    this.selected = false,\n    this.onTap,\n  });\n\n  final IconData icon;\n""",
    """    this.selected = false,\n    this.progress = false,\n    this.onTap,\n  });\n\n  final IconData icon;\n""",
)
replace_once(
    path,
    """  final bool selected;\n  final VoidCallback? onTap;\n""",
    """  final bool selected;\n  final bool progress;\n  final VoidCallback? onTap;\n""",
)
replace_once(
    path,
    """              child: Icon(\n                icon,\n                size: 20,\n                color: selected\n                    ? scheme.onPrimaryContainer\n                    : scheme.onSurfaceVariant,\n              ),\n""",
    """              child: progress\n                  ? const SizedBox(\n                      width: 18,\n                      height: 18,\n                      child: CircularProgressIndicator(strokeWidth: 2),\n                    )\n                  : Icon(\n                      icon,\n                      size: 20,\n                      color: selected\n                          ? scheme.onPrimaryContainer\n                          : scheme.onSurfaceVariant,\n                    ),\n""",
)

# --- V2 theme: quiet native-tool polish, fewer floating/rounded surfaces.
path = 'lib/features/design_v2/v2_theme.dart'
replace_once(
    path,
    """      dividerColor: scheme.outlineVariant,\n""",
    """      appBarTheme: AppBarTheme(\n        backgroundColor: scheme.surfaceContainerLowest,\n        foregroundColor: scheme.onSurface,\n        surfaceTintColor: Colors.transparent,\n        elevation: 0,\n        scrolledUnderElevation: 0,\n        centerTitle: false,\n        titleTextStyle: textTheme.titleMedium?.copyWith(color: scheme.onSurface),\n      ),\n      cardTheme: CardThemeData(\n        color: scheme.surfaceContainerLowest,\n        surfaceTintColor: Colors.transparent,\n        elevation: 0,\n        margin: EdgeInsets.zero,\n        shape: RoundedRectangleBorder(\n          borderRadius: BorderRadius.circular(10),\n          side: BorderSide(color: scheme.outlineVariant),\n        ),\n      ),\n      dividerColor: scheme.outlineVariant,\n""",
)
replace_once(path, "minimumSize: const Size(0, 40)", "minimumSize: const Size(0, 42)")
replace_once(path, "minimumSize: const Size(0, 40)", "minimumSize: const Size(0, 42)")
replace_once(path, "minimumSize: const Size(0, 40)", "minimumSize: const Size(0, 42)")
replace_once(
    path,
    """      dialogTheme: DialogThemeData(\n        backgroundColor: scheme.surfaceContainerLowest,\n        surfaceTintColor: Colors.transparent,\n        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),\n      ),\n""",
    """      dialogTheme: DialogThemeData(\n        backgroundColor: scheme.surfaceContainerLowest,\n        surfaceTintColor: Colors.transparent,\n        elevation: 12,\n        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),\n      ),\n      popupMenuTheme: PopupMenuThemeData(\n        color: scheme.surfaceContainerLowest,\n        surfaceTintColor: Colors.transparent,\n        elevation: 8,\n        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),\n      ),\n      snackBarTheme: SnackBarThemeData(\n        behavior: SnackBarBehavior.floating,\n        backgroundColor: scheme.inverseSurface,\n        contentTextStyle: textTheme.bodyMedium?.copyWith(\n          color: scheme.onInverseSurface,\n        ),\n        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),\n      ),\n      tooltipTheme: TooltipThemeData(\n        waitDuration: const Duration(milliseconds: 450),\n        showDuration: const Duration(seconds: 2),\n        decoration: BoxDecoration(\n          color: scheme.inverseSurface,\n          borderRadius: BorderRadius.circular(6),\n        ),\n        textStyle: textTheme.bodySmall?.copyWith(color: scheme.onInverseSurface),\n      ),\n      scrollbarTheme: ScrollbarThemeData(\n        thickness: const WidgetStatePropertyAll(6),\n        radius: const Radius.circular(4),\n        thumbVisibility: const WidgetStatePropertyAll(false),\n        thumbColor: WidgetStatePropertyAll(\n          scheme.onSurfaceVariant.withValues(alpha: 0.32),\n        ),\n      ),\n""",
)
replace_once(
    path,
    """        shape: const RoundedRectangleBorder(\n          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),\n        ),\n""",
    """        shape: const RoundedRectangleBorder(\n          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),\n        ),\n""",
)
replace_once(path, "height: 68,", "height: 64,")

# --- Windows native caption: neutral light/dark colors, no system accent-blue strip.
path = 'windows/runner/win32_window.cpp'
replace_once(
    path,
    """#ifndef DWMWA_USE_IMMERSIVE_DARK_MODE\n#define DWMWA_USE_IMMERSIVE_DARK_MODE 20\n#endif\n""",
    """#ifndef DWMWA_USE_IMMERSIVE_DARK_MODE\n#define DWMWA_USE_IMMERSIVE_DARK_MODE 20\n#endif\n#ifndef DWMWA_BORDER_COLOR\n#define DWMWA_BORDER_COLOR 34\n#endif\n#ifndef DWMWA_CAPTION_COLOR\n#define DWMWA_CAPTION_COLOR 35\n#endif\n#ifndef DWMWA_TEXT_COLOR\n#define DWMWA_TEXT_COLOR 36\n#endif\n""",
)
replace_once(
    path,
    """    case WM_DWMCOLORIZATIONCOLORCHANGED:\n      UpdateTheme(hwnd);\n      return 0;\n""",
    """    case WM_DWMCOLORIZATIONCOLORCHANGED:\n    case WM_THEMECHANGED:\n    case WM_SETTINGCHANGE:\n      UpdateTheme(hwnd);\n      return 0;\n""",
)
replace_once(
    path,
    """    BOOL enable_dark_mode = light_mode == 0;\n    DwmSetWindowAttribute(window, DWMWA_USE_IMMERSIVE_DARK_MODE,\n                          &enable_dark_mode, sizeof(enable_dark_mode));\n""",
    """    BOOL enable_dark_mode = light_mode == 0;\n    DwmSetWindowAttribute(window, DWMWA_USE_IMMERSIVE_DARK_MODE,\n                          &enable_dark_mode, sizeof(enable_dark_mode));\n\n    // Keep the native Windows caption visually continuous with Xueqing's\n    // quiet workspace instead of inheriting the user's accent-blue caption.\n    // Windows versions that do not support these attributes simply ignore\n    // the calls and retain the normal system caption.\n    COLORREF caption_color = enable_dark_mode\n                                 ? RGB(21, 24, 22)\n                                 : RGB(247, 248, 246);\n    COLORREF text_color = enable_dark_mode\n                              ? RGB(231, 233, 230)\n                              : RGB(32, 40, 36);\n    COLORREF border_color = enable_dark_mode\n                                ? RGB(48, 54, 50)\n                                : RGB(217, 222, 218);\n    DwmSetWindowAttribute(window, DWMWA_CAPTION_COLOR, &caption_color,\n                          sizeof(caption_color));\n    DwmSetWindowAttribute(window, DWMWA_TEXT_COLOR, &text_color,\n                          sizeof(text_color));\n    DwmSetWindowAttribute(window, DWMWA_BORDER_COLOR, &border_color,\n                          sizeof(border_color));\n""",
)

# --- Focused source/behavior contract test.
Path('test/features/v2_refresh_window_polish_test.dart').write_text(r'''import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xueqing/features/design_v2/v2_theme.dart';
import 'package:xueqing/features/design_v2/v2_workspace_preview.dart';

void main() {
  testWidgets('desktop refresh action invokes the real refresh callback', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var refreshCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: V2Theme.light(),
        home: V2WorkspacePreview(
          onRefresh: () async => refreshCount++,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('刷新学情'));
    await tester.pumpAndSettle();
    expect(refreshCount, 1);
    expect(find.text('已刷新最新学情。'), findsOneWidget);
  });

  testWidgets('compact More menu exposes refresh without adding a fourth tab', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var refreshCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: V2Theme.light(),
        home: V2WorkspacePreview(
          onRefresh: () async => refreshCount++,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final navigationBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(navigationBar.destinations.length, 3);
    await tester.tap(find.byKey(const Key('v2-compact-more')));
    await tester.pumpAndSettle();
    expect(find.text('刷新学情'), findsOneWidget);
    await tester.tap(find.text('刷新学情'));
    await tester.pumpAndSettle();
    expect(refreshCount, 1);
  });

  test('Windows caption uses neutral DWM caption, text, and border colors', () {
    final source = File('windows/runner/win32_window.cpp').readAsStringSync();
    expect(source, contains('DWMWA_CAPTION_COLOR'));
    expect(source, contains('DWMWA_TEXT_COLOR'));
    expect(source, contains('DWMWA_BORDER_COLOR'));
    expect(source, contains('WM_THEMECHANGED'));
    expect(source, contains('WM_SETTINGCHANGE'));
  });
}
''')

print('refresh/window polish patch applied')
