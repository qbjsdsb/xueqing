from pathlib import Path


def replace_once(path, old, new):
    p = Path(path)
    text = p.read_text()
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{path}: expected one match, found {count}: {old[:80]!r}')
    p.write_text(text.replace(old, new, 1))


def replace_all_checked(path, old, new, expected):
    p = Path(path)
    text = p.read_text()
    count = text.count(old)
    if count != expected:
        raise SystemExit(f'{path}: expected {expected} matches, found {count}: {old[:80]!r}')
    p.write_text(text.replace(old, new))


# V2 loader: expose a non-blocking refresh that preserves the visible snapshot.
path = 'lib/features/design_v2/v2_workspace_loader.dart'
replace_once(path, "import 'package:flutter/material.dart';", "import 'dart:async';\n\nimport 'package:flutter/material.dart';")
replace_once(
    path,
    """  void _retry() {
    final nextWorkspace = widget.loadWorkspace();
    setState(() {
      _workspaceFuture = nextWorkspace;
    });
  }
""",
    """  void _retry() {
    final nextWorkspace = widget.loadWorkspace();
    setState(() {
      _workspaceFuture = nextWorkspace;
    });
  }

  bool _softRefreshRunning = false;
  bool _softRefreshQueued = false;

  Future<void> _softRefresh() async {
    if (_softRefreshRunning) {
      _softRefreshQueued = true;
      return;
    }
    do {
      _softRefreshQueued = false;
      _softRefreshRunning = true;
      try {
        final workspace = await widget.loadWorkspace();
        if (!mounted) return;
        setState(() {
          _workspaceFuture = Future<TeacherWorkspace>.value(workspace);
        });
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(
            content: Text('刷新失败，请检查网络后重试；当前页面和已保存记录不会受影响。'),
          ),
        );
      } finally {
        _softRefreshRunning = false;
      }
    } while (_softRefreshQueued && mounted);
  }
""",
)
replace_once(
    path,
    """        if (snapshot.connectionState != ConnectionState.done) {
          return const _V2LoaderStatus(
            icon: Icons.sync,
            title: '正在读取学情…',
            message: '正在准备你的学生与成长记录。',
          );
        }
""",
    """        if (!snapshot.hasData &&
            snapshot.connectionState != ConnectionState.done) {
          return const _V2LoaderStatus(
            icon: Icons.sync,
            title: '正在同步学情',
            message: '正在读取学生与学情记录。',
          );
        }
""",
)
replace_all_checked(
    path,
    "onChanged: _retry,",
    "onChanged: () => unawaited(_softRefresh()),",
    2,
)
replace_once(
    path,
    """          onSignOut: runtime?.onSignOut,
          onWorkspaceChanged: workflowController == null ? null : _retry,
""",
    """          onSignOut: runtime?.onSignOut,
          onRefresh: _softRefresh,
          onWorkspaceChanged: workflowController == null
              ? null
              : () => unawaited(_softRefresh()),
""",
)
replace_once(
    path,
    "message: '当前账号暂时没有可查看的任课学生；获得任课关系后，这里会自动出现。',",
    "message: '当前账号暂时没有可查看的任课学生；获得任课关系后可在这里查看。',",
)

# V2 workspace: add explicit refresh affordances, keep mobile secondary actions secondary,
# and remove a decorative generic leaf mark from desktop chrome.
path = 'lib/features/design_v2/v2_workspace_preview.dart'
replace_once(
    path,
    """typedef V2StudentExport = Future<void> Function(
  BuildContext context,
  V2Student student,
);
""",
    """typedef V2StudentExport = Future<void> Function(
  BuildContext context,
  V2Student student,
);
typedef V2WorkspaceRefresh = Future<void> Function();
""",
)
replace_once(
    path,
    """    this.appVersion,
    this.onSignOut,
    this.onWorkspaceChanged,
""",
    """    this.appVersion,
    this.onSignOut,
    this.onRefresh,
    this.onWorkspaceChanged,
""",
)
replace_once(
    path,
    """  final String? appVersion;
  final VoidCallback? onSignOut;
  final VoidCallback? onWorkspaceChanged;
""",
    """  final String? appVersion;
  final VoidCallback? onSignOut;
  final V2WorkspaceRefresh? onRefresh;
  final VoidCallback? onWorkspaceChanged;
""",
)
replace_once(
    path,
    """  bool _showCase = false;
  bool _checkingForUpdates = false;
""",
    """  bool _showCase = false;
  bool _checkingForUpdates = false;
  bool _refreshing = false;
""",
)
replace_once(
    path,
    """  void _afterMenuClose(BuildContext menuContext, VoidCallback action) {
""",
    """  Future<void> _refreshWorkspace() async {
    final refresh = widget.onRefresh;
    if (refresh == null || _refreshing) return;
    setState(() => _refreshing = true);
    try {
      await refresh();
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  void _afterMenuClose(BuildContext menuContext, VoidCallback action) {
""",
)
replace_once(
    path,
    """          children: [
            if (widget.managementPageBuilder != null)
""",
    """          children: [
            if (widget.onRefresh != null)
              ListTile(
                key: const Key('v2-menu-refresh'),
                leading: _refreshing
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_outlined),
                title: Text(_refreshing ? '正在刷新' : '刷新学情'),
                subtitle: const Text('重新读取最新学生与学情记录'),
                onTap: _refreshing
                    ? null
                    : () => _afterMenuClose(
                        menuContext,
                        () => _refreshWorkspace(),
                      ),
              ),
            if (widget.managementPageBuilder != null)
""",
)
replace_once(path, "title: const Text('设置'),", "title: const Text('更多'),")
replace_once(
    path,
    """            final hasMenuActions =
                widget.managementPageBuilder != null ||
                widget.updateService != null &&
                    widget.updateInstaller != null ||
                widget.onSignOut != null;
""",
    """            final hasMenuActions =
                widget.onRefresh != null ||
                widget.managementPageBuilder != null ||
                widget.updateService != null &&
                    widget.updateInstaller != null ||
                widget.onSignOut != null;
""",
)
replace_once(
    path,
    """                  onManage: widget.managementPageBuilder == null
                      ? null
                      : () => _openManagement(context),
                  onSettings: () => _showWorkspaceMenu(context),
""",
    """                  onRefresh: widget.onRefresh == null
                      ? null
                      : () => _refreshWorkspace(),
                  refreshing: _refreshing,
                  onManage: widget.managementPageBuilder == null
                      ? null
                      : () => _openManagement(context),
                  onSettings: () => _showWorkspaceMenu(context),
""",
)
replace_once(
    path,
    """    required this.onBackFromCase,
    required this.onSettings,
    this.onManage,
""",
    """    required this.onBackFromCase,
    required this.onSettings,
    required this.refreshing,
    this.onRefresh,
    this.onManage,
""",
)
replace_once(
    path,
    """  final VoidCallback onBackFromCase;
  final VoidCallback? onManage;
  final VoidCallback onSettings;
""",
    """  final VoidCallback onBackFromCase;
  final VoidCallback? onRefresh;
  final bool refreshing;
  final VoidCallback? onManage;
  final VoidCallback onSettings;
""",
)
replace_once(
    path,
    """                onSelected: onDestinationChanged,
                onManage: onManage,
                onSettings: onSettings,
""",
    """                onSelected: onDestinationChanged,
                onRefresh: onRefresh,
                refreshing: refreshing,
                onManage: onManage,
                onSettings: onSettings,
""",
)
replace_once(
    path,
    """    required this.onSelected,
    required this.onSettings,
    this.onManage,
""",
    """    required this.onSelected,
    required this.onSettings,
    required this.refreshing,
    this.onRefresh,
    this.onManage,
""",
)
replace_once(
    path,
    """  final ValueChanged<int> onSelected;
  final VoidCallback? onManage;
  final VoidCallback onSettings;
""",
    """  final ValueChanged<int> onSelected;
  final VoidCallback? onRefresh;
  final bool refreshing;
  final VoidCallback? onManage;
  final VoidCallback onSettings;
""",
)
replace_once(
    path,
    """          const SizedBox(height: 18),
          Icon(Icons.eco_outlined, color: scheme.primary, size: 27),
          const SizedBox(height: 22),
""",
    """          const SizedBox(height: 18),
          Text(
            '学情',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: scheme.primary,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 22),
""",
)
replace_once(
    path,
    """          const Spacer(),
          if (onManage != null)
""",
    """          const Spacer(),
          if (onRefresh != null)
            _RailItem(
              key: const Key('v2-workspace-refresh'),
              icon: Icons.refresh_outlined,
              tooltip: refreshing ? '正在刷新' : '刷新学情',
              onTap: refreshing ? null : onRefresh,
            ),
          if (onManage != null)
""",
)
replace_once(
    path,
    """class _RailItem extends StatelessWidget {
  const _RailItem({
    required this.icon,
""",
    """class _RailItem extends StatelessWidget {
  const _RailItem({
    super.key,
    required this.icon,
""",
)
replace_once(path, "'学生  /  ${student.name}'", "'学生 · ${student.name}'")
replace_once(
    path,
    "'当你获得任课学生后，这里会自动出现。'",
    "'获得任课学生后，可在这里查看。'",
)

# Management page: keep a direct, non-destructive manual refresh in the
# management surface itself.
path = 'lib/features/organization_management/presentation/organization_management_core.dart'
replace_once(
    path,
    """  bool _busy = false;
  String? _errorMessage;
""",
    """  bool _busy = false;
  bool _manualRefreshing = false;
  String? _errorMessage;
""",
)
replace_once(
    path,
    """  Future<void> _refresh() async {
    final next = _load();
    if (!mounted) return;
    setState(() => _snapshotFuture = next);
    await next;
  }

  void _retryLoad() {
""",
    """  Future<void> _refresh() async {
    final snapshot = await _load();
    if (!mounted) return;
    setState(() {
      _snapshotFuture = Future<_OrganizationManagementSnapshot>.value(snapshot);
    });
  }

  Future<void> _manualRefresh() async {
    if (_manualRefreshing || _busy) return;
    setState(() {
      _manualRefreshing = true;
      _errorMessage = null;
    });
    try {
      await _refresh();
    } catch (error) {
      if (mounted) setState(() => _errorMessage = _describeError(error));
    } finally {
      if (mounted) setState(() => _manualRefreshing = false);
    }
  }

  void _retryLoad() {
""",
)

path = 'lib/features/organization_management/presentation/organization_management_page.dart'
replace_once(
    path,
    """              _ManagementHeader(
                organizationName: widget.organizationName,
                roleLabel: _roleSummary(widget.roles),
              ),
""",
    """              _ManagementHeader(
                organizationName: widget.organizationName,
                roleLabel: _roleSummary(widget.roles),
                refreshing: _manualRefreshing,
                onRefresh: _busy ? null : _manualRefresh,
              ),
""",
)

path = 'lib/features/organization_management/presentation/organization_management_layout.dart'
replace_once(
    path,
    """  const _ManagementHeader({
    required this.organizationName,
    required this.roleLabel,
  });

  final String organizationName;
  final String roleLabel;
""",
    """  const _ManagementHeader({
    required this.organizationName,
    required this.roleLabel,
    required this.refreshing,
    required this.onRefresh,
  });

  final String organizationName;
  final String roleLabel;
  final bool refreshing;
  final VoidCallback? onRefresh;
""",
)
replace_once(
    path,
    """          Text('机构管理', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: AppSpacing.xs),
""",
    """          Row(
            children: [
              Expanded(
                child: Text(
                  '机构管理',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              IconButton(
                key: const Key('management-refresh'),
                tooltip: refreshing ? '正在刷新' : '刷新机构数据',
                onPressed: refreshing ? null : onRefresh,
                icon: refreshing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_outlined),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
""",
)

# Reduce oversized rounded surfaces and tighten the V2 visual system.
path = 'lib/app/theme/app_spacing.dart'
replace_once(path, 'static const dialog = 28.0;', 'static const dialog = 16.0;')

path = 'lib/app/theme/app_theme.dart'
replace_once(
    path,
    'borderRadius: BorderRadius.vertical(top: Radius.circular(28)),',
    'borderRadius: BorderRadius.vertical(top: Radius.circular(18)),',
)

path = 'lib/features/design_v2/v2_theme.dart'
replace_all_checked(path, 'minimumSize: const Size(0, 40),', 'minimumSize: const Size(0, 44),', 3)
replace_once(
    path,
    'shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),',
    'shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),',
)
replace_once(
    path,
    'borderRadius: BorderRadius.vertical(top: Radius.circular(22)),',
    'borderRadius: BorderRadius.vertical(top: Radius.circular(18)),',
)
replace_once(path, 'height: 68,', 'height: 64,')
replace_once(
    path,
    """        indicatorColor: scheme.primaryContainer,
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStatePropertyAll(textTheme.bodySmall),
""",
    """        indicatorColor: scheme.primaryContainer.withValues(alpha: 0.72),
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(9),
        ),
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return textTheme.bodySmall?.copyWith(
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.w400,
          );
        }),
""",
)
replace_once(
    path,
    """      navigationBarTheme: NavigationBarThemeData(
""",
    """      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: scheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: scheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: const Size(44, 44)),
      ),
      navigationBarTheme: NavigationBarThemeData(
""",
)

# Windows: explicitly neutralize the OS accent-color caption/border while
# retaining the native frame and native min/max/close behavior.
path = 'windows/runner/win32_window.cpp'
replace_once(
    path,
    """#ifndef DWMWA_USE_IMMERSIVE_DARK_MODE
#define DWMWA_USE_IMMERSIVE_DARK_MODE 20
#endif
""",
    """#ifndef DWMWA_USE_IMMERSIVE_DARK_MODE
#define DWMWA_USE_IMMERSIVE_DARK_MODE 20
#endif
#ifndef DWMWA_BORDER_COLOR
#define DWMWA_BORDER_COLOR 34
#endif
#ifndef DWMWA_CAPTION_COLOR
#define DWMWA_CAPTION_COLOR 35
#endif
#ifndef DWMWA_TEXT_COLOR
#define DWMWA_TEXT_COLOR 36
#endif
""",
)
replace_once(
    path,
    """    case WM_DWMCOLORIZATIONCOLORCHANGED:
      UpdateTheme(hwnd);
      return 0;
""",
    """    case WM_DWMCOLORIZATIONCOLORCHANGED:
    case WM_SETTINGCHANGE:
      UpdateTheme(hwnd);
      return 0;
""",
)
replace_once(
    path,
    """  if (result == ERROR_SUCCESS) {
    BOOL enable_dark_mode = light_mode == 0;
    DwmSetWindowAttribute(window, DWMWA_USE_IMMERSIVE_DARK_MODE,
                          &enable_dark_mode, sizeof(enable_dark_mode));
  }
}
""",
    """  if (result == ERROR_SUCCESS) {
    const bool is_dark = light_mode == 0;
    BOOL enable_dark_mode = is_dark;
    DwmSetWindowAttribute(window, DWMWA_USE_IMMERSIVE_DARK_MODE,
                          &enable_dark_mode, sizeof(enable_dark_mode));

    // Windows 11 can otherwise inherit the user's accent color here, which
    // makes the native caption/border visually detach from the Flutter shell.
    // Older Windows versions safely ignore unsupported DWM attributes.
    const COLORREF caption_color =
        is_dark ? RGB(21, 24, 22) : RGB(247, 248, 246);
    const COLORREF border_color =
        is_dark ? RGB(48, 54, 50) : RGB(217, 222, 218);
    const COLORREF text_color =
        is_dark ? RGB(231, 233, 230) : RGB(32, 40, 36);
    DwmSetWindowAttribute(window, DWMWA_CAPTION_COLOR, &caption_color,
                          sizeof(caption_color));
    DwmSetWindowAttribute(window, DWMWA_BORDER_COLOR, &border_color,
                          sizeof(border_color));
    DwmSetWindowAttribute(window, DWMWA_TEXT_COLOR, &text_color,
                          sizeof(text_color));
  }
}
""",
)

# Behavior regression: refresh failures keep the current workspace visible.
path = 'test/features/design_v2_workspace_loader_test.dart'
replace_once(
    path,
    """  testWidgets('authorized workspace with zero students uses V2 empty state', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(() async => _workspace(students: const <WorkspaceStudent>[])),
    );
    await tester.pumpAndSettle();

    expect(find.text('暂时还没有可查看的学生'), findsOneWidget);
    expect(find.text('暂时没有任课学情'), findsNothing);
    expect(tester.takeException(), isNull);
  });
""",
    """  testWidgets('authorized workspace with zero students uses V2 empty state', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(() async => _workspace(students: const <WorkspaceStudent>[])),
    );
    await tester.pumpAndSettle();

    expect(find.text('暂时还没有可查看的学生'), findsOneWidget);
    expect(find.text('暂时没有任课学情'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('manual refresh keeps current data on failure and can recover', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var attempts = 0;

    Future<TeacherWorkspace> loadWorkspace() async {
      attempts++;
      if (attempts == 2) throw StateError('offline');
      if (attempts >= 3) {
        return _workspace(students: const <WorkspaceStudent>[]);
      }
      return _workspace();
    }

    await tester.pumpWidget(app(loadWorkspace));
    await tester.pumpAndSettle();
    expect(find.text('真实学生'), findsWidgets);

    await tester.tap(find.byKey(const Key('v2-workspace-refresh')));
    await tester.pumpAndSettle();

    expect(attempts, 2);
    expect(find.text('真实学生'), findsWidgets);
    expect(find.text('学情暂时无法读取'), findsNothing);
    expect(find.textContaining('刷新失败，请检查网络后重试'), findsOneWidget);

    await tester.tap(find.byKey(const Key('v2-workspace-refresh')));
    await tester.pumpAndSettle();

    expect(attempts, 3);
    expect(find.text('暂时还没有可查看的学生'), findsOneWidget);
    expect(find.text('真实学生'), findsNothing);
  });
""",
)
replace_once(path, "expect(find.text('正在读取学情…'), findsOneWidget);", "expect(find.text('正在同步学情'), findsOneWidget);")
replace_once(path, "expect(find.text('正在准备你的学生与成长记录。'), findsOneWidget);", "expect(find.text('正在读取学生与学情记录。'), findsOneWidget);")

Path('test/features/v2_refresh_polish_test.dart').write_text("""import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('V2 exposes explicit refresh without widening data access', () {
    final loader = File(
      'lib/features/design_v2/v2_workspace_loader.dart',
    ).readAsStringSync();
    final preview = File(
      'lib/features/design_v2/v2_workspace_preview.dart',
    ).readAsStringSync();
    final management = File(
      'lib/features/organization_management/presentation/'
      'organization_management_layout.dart',
    ).readAsStringSync();

    expect(loader, contains('Future<void> _softRefresh()'));
    expect(loader, contains('onRefresh: _softRefresh'));
    expect(loader, contains('当前页面和已保存记录不会受影响'));
    expect(preview, contains("Key('v2-workspace-refresh')"));
    expect(preview, contains("Key('v2-menu-refresh')"));
    expect(preview, contains("title: Text(_refreshing ? '正在刷新' : '刷新学情')"));
    expect(management, contains("Key('management-refresh')"));
  });

  test('V2 visual system stays quiet and editorial', () {
    final preview = File(
      'lib/features/design_v2/v2_workspace_preview.dart',
    ).readAsStringSync();
    final theme = File('lib/features/design_v2/v2_theme.dart').readAsStringSync();
    final spacing = File('lib/app/theme/app_spacing.dart').readAsStringSync();

    expect(preview, isNot(contains('Icons.eco_outlined')));
    expect(preview, contains("'学情'"));
    expect(preview, contains("title: const Text('更多')"));
    expect(theme, contains('minimumSize: const Size(0, 44)'));
    expect(theme, contains('height: 64'));
    expect(theme, contains('CardThemeData('));
    expect(theme, contains('PopupMenuThemeData('));
    expect(spacing, contains('static const dialog = 16.0;'));
  });
}
""")

Path('test/windows_window_chrome_contract_test.dart').write_text("""import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Windows keeps native controls but neutralizes accent-colored chrome', () {
    final source = File('windows/runner/win32_window.cpp').readAsStringSync();
    final pubspec = File('pubspec.yaml').readAsStringSync();

    expect(source, contains('DWMWA_CAPTION_COLOR'));
    expect(source, contains('DWMWA_BORDER_COLOR'));
    expect(source, contains('DWMWA_TEXT_COLOR'));
    expect(source, contains('WM_SETTINGCHANGE'));
    expect(source, contains('WS_OVERLAPPEDWINDOW'));
    expect(pubspec, isNot(contains('window_manager:')));
    expect(pubspec, isNot(contains('bitsdojo_window:')));
  });
}
""")

# Keep the release-shell contract aware that refresh is a first-class runtime action.
path = 'test/features/v2_shell_production_capabilities_test.dart'
replace_once(
    path,
    """    expect(preview, contains(\"title: const Text('检查更新')\"));
    expect(preview, contains(\"title: const Text('退出登录')\"));
""",
    """    expect(preview, contains(\"title: const Text('检查更新')\"));
    expect(preview, contains(\"title: const Text('退出登录')\"));
    expect(preview, contains(\"Key('v2-workspace-refresh')\"));
    expect(preview, contains(\"Key('v2-menu-refresh')\"));
""",
)

print('V2 refresh + Windows polish patch applied')
