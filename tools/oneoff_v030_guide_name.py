from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    p = Path(path)
    text = p.read_text(encoding="utf-8")
    count = text.count(old)
    if count != 1:
        raise SystemExit(
            f"{path}: expected exactly one match, found {count}: {old[:80]!r}"
        )
    p.write_text(text.replace(old, new, 1), encoding="utf-8")


# Keep internal repository/package/executable identities stable for update compatibility,
# while unifying user-facing product naming as “学情”.
replace_once("lib/app/app.dart", "title: '学情闭环',", "title: '学情',")
replace_once(
    "android/app/src/main/AndroidManifest.xml",
    'android:label="学情闭环"',
    'android:label="学情"',
)
replace_once(
    "windows/runner/main.cpp",
    'window.Create(L"xueqing", origin, size)',
    'window.Create(L"\\u5B66\\u60C5", origin, size)',
)
replace_once(
    "windows/runner/Runner.rc",
    'VALUE "FileDescription", "xueqing" "\\0"',
    'VALUE "FileDescription", "学情" "\\0"',
)
replace_once(
    "windows/runner/Runner.rc",
    'VALUE "ProductName", "xueqing" "\\0"',
    'VALUE "ProductName", "学情" "\\0"',
)
replace_once(
    "installer/windows/xueqing.iss",
    '#define AppName "Xueqing"',
    '#define AppName "学情"',
)
replace_once(
    "lib/features/design_v2/v2_workspace_preview.dart",
    "title: const Text('学情闭环'),",
    "title: const Text('学情'),",
)

workspace_path = Path("lib/features/design_v2/v2_workspace_preview.dart")
workspace = workspace_path.read_text(encoding="utf-8")

marker = "  Future<void> _showWorkspaceMenu(BuildContext context) async {\n"
if workspace.count(marker) != 1:
    raise SystemExit("workspace menu marker not unique")
guide_method = r'''  Future<void> _showOperationGuide(BuildContext context) async {
    if (MediaQuery.sizeOf(context).width < 720) {
      await showModalBottomSheet<void>(
        context: context,
        useSafeArea: true,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (sheetContext) => const FractionallySizedBox(
          heightFactor: 0.82,
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: _V2OperationGuide(showTitle: true),
          ),
        ),
      );
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => const AlertDialog(
        title: Text('操作指南'),
        content: SizedBox(
          width: 520,
          height: 500,
          child: _V2OperationGuide(),
        ),
      ),
    );
  }

'''
workspace = workspace.replace(marker, guide_method + marker, 1)

management_marker = (
    "            if (widget.managementPageBuilder != null)\n"
    "              ListTile(\n"
)
if workspace.count(management_marker) != 1:
    raise SystemExit("management menu marker not unique")
guide_menu = r'''            ListTile(
              key: const Key('v2-menu-operation-guide'),
              leading: const Icon(Icons.help_outline),
              title: const Text('操作指南'),
              subtitle: const Text('常用操作一页看懂'),
              onTap: () => _afterMenuClose(
                menuContext,
                () => _showOperationGuide(context),
              ),
            ),
'''
workspace = workspace.replace(management_marker, guide_menu + management_marker, 1)

# The operation guide is always available, so the existing More surface no longer
# depends on optional refresh/management/update/sign-out capabilities.
old_gate = r'''            final hasMenuActions =
                widget.onRefresh != null ||
                widget.managementPageBuilder != null ||
                widget.updateService != null &&
                    widget.updateInstaller != null ||
                widget.onSignOut != null;
'''
if workspace.count(old_gate) != 1:
    raise SystemExit("menu availability gate marker not unique")
workspace = workspace.replace(old_gate, "", 1)

empty_more = r'''                onOpenMore: hasMenuActions
                    ? () => _showWorkspaceMenu(context)
                    : null,
'''
if workspace.count(empty_more) != 1:
    raise SystemExit("empty More gate marker not unique")
workspace = workspace.replace(
    empty_more,
    "                onOpenMore: () => _showWorkspaceMenu(context),\n",
    1,
)
compact_more = r'''                    onOpenMore: hasMenuActions
                        ? () => _showWorkspaceMenu(context)
                        : null,
'''
if workspace.count(compact_more) != 1:
    raise SystemExit("compact More gate marker not unique")
workspace = workspace.replace(
    compact_more,
    "                    onOpenMore: () => _showWorkspaceMenu(context),\n",
    1,
)

empty_marker = "class _EmptyWorkspacePreview extends StatelessWidget {\n"
if workspace.count(empty_marker) != 1:
    raise SystemExit("empty workspace marker not unique")
guide_widget = r'''class _V2OperationGuide extends StatelessWidget {
  const _V2OperationGuide({this.showTitle = false});

  final bool showTitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showTitle) ...[
            Text('操作指南', style: theme.textTheme.titleLarge),
            const SizedBox(height: 6),
          ],
          Text(
            '记录事实 → 跟进 → 验证 → 下一步',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          const _V2GuideItem(
            icon: Icons.today_outlined,
            title: '先看今日',
            body: '优先处理逾期和今天的提醒；可以直接完成这一步或改期。',
          ),
          const _V2GuideItem(
            icon: Icons.note_add_outlined,
            title: '记录问题',
            body: '在今日或学生页点“记录问题”，选学生和学科，只写真实观察；需要时附照片。',
          ),
          const _V2GuideItem(
            icon: Icons.edit_note_outlined,
            title: '继续跟进',
            body: '进入问题点“记进展”，记录学生表现、教学处理或检查结果，并确定下一步。',
          ),
          const _V2GuideItem(
            icon: Icons.history_outlined,
            title: '历史与复发',
            body: '学情 → 历史可看已结束问题；再次出现时用“再次出现，重新跟进”，不要重复新建。',
          ),
          const _V2GuideItem(
            icon: Icons.admin_panel_settings_outlined,
            title: '管理与导出',
            body: '负责人/管理员在机构管理维护成员、学生、学科、任课和问题类型；学生详情可按学科导出。',
          ),
          const _V2GuideItem(
            icon: Icons.sync_outlined,
            title: '刷新与更新',
            body: '多人协作需要最新数据时点“刷新学情”；在更多/设置里检查更新。',
          ),
        ],
      ),
    );
  }
}

class _V2GuideItem extends StatelessWidget {
  const _V2GuideItem({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              icon,
              size: 20,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(body, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

'''
workspace = workspace.replace(empty_marker, guide_widget + empty_marker, 1)
workspace_path.write_text(workspace, encoding="utf-8")

# Extend focused widget coverage.
test_path = Path("test/features/v2_final_ergonomics_test.dart")
test_text = test_path.read_text(encoding="utf-8")
old_expect = "      expect(find.text('退出登录'), findsOneWidget);\n"
new_expect = (
    "      expect(find.text('操作指南'), findsOneWidget);\n"
    "      expect(find.text('退出登录'), findsOneWidget);\n"
)
if test_text.count(old_expect) != 1:
    raise SystemExit("ergonomics menu expectation marker not unique")
test_text = test_text.replace(old_expect, new_expect, 1)
new_test = r'''

  testWidgets('operation guide stays reachable without optional account actions', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const data = V2WorkspaceData(
      students: _students,
      focusItems: [],
      timeline: [],
    );

    await tester.pumpWidget(_app(data));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('v2-compact-more')), findsOneWidget);
    await tester.tap(find.byKey(const Key('v2-compact-more')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('v2-menu-operation-guide')), findsOneWidget);

    await tester.tap(find.byKey(const Key('v2-menu-operation-guide')));
    await tester.pumpAndSettle();
    expect(find.text('操作指南'), findsOneWidget);
    expect(find.text('先看今日'), findsOneWidget);
    expect(find.text('记录问题'), findsOneWidget);
    expect(find.text('继续跟进'), findsOneWidget);
    expect(find.text('历史与复发'), findsOneWidget);
    expect(find.text('管理与导出'), findsOneWidget);
    expect(find.text('刷新与更新'), findsOneWidget);
    expect(find.text('记录事实 → 跟进 → 验证 → 下一步'), findsOneWidget);
  });
'''
last = test_text.rfind("\n}")
if last < 0:
    raise SystemExit("could not find final test main brace")
test_text = test_text[:last] + new_test + test_text[last:]
test_path.write_text(test_text, encoding="utf-8")

# Release identity contract. Internal xueqing identifiers stay unchanged.
Path("test/release_product_identity_contract_test.dart").write_text(
    r'''import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('user-facing product name is 学情 across release surfaces', () {
    final app = File('lib/app/app.dart').readAsStringSync();
    final android = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    final windowsMain = File('windows/runner/main.cpp').readAsStringSync();
    final windowsResources = File(
      'windows/runner/Runner.rc',
    ).readAsStringSync();
    final installer = File(
      'installer/windows/xueqing.iss',
    ).readAsStringSync();

    expect(app, contains("title: '学情'"));
    expect(android, contains('android:label="学情"'));
    expect(windowsMain, contains(r'L"\u5B66\u60C5"'));
    expect(windowsResources, contains('VALUE "ProductName", "学情"'));
    expect(windowsResources, contains('VALUE "FileDescription", "学情"'));
    expect(installer, contains('#define AppName "学情"'));
  });
}
''',
    encoding="utf-8",
)
