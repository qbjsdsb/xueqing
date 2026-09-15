from pathlib import Path
import re

source_path = Path('lib/features/design_v2/v2_management_page.dart')
source = source_path.read_text()

material_import = "import 'package:flutter/material.dart';\n"
spacing_import = "import '../../app/theme/app_spacing.dart';\n"
if spacing_import not in source:
    if source.count(material_import) != 1:
        raise SystemExit('material import did not match exactly once')
    source = source.replace(material_import, material_import + '\n' + spacing_import)

runtime_import = "import '../teacher_workspace/workspace_runtime.dart';\n"
header_import = "import 'v2_page_header.dart';\n"
if header_import not in source:
    if source.count(runtime_import) != 1:
        raise SystemExit('runtime import did not match exactly once')
    source = source.replace(runtime_import, runtime_import + header_import)

pattern = re.compile(
    r"    return Scaffold\(\n      appBar: AppBar\(.*?\n    \);\n  \}\n\}",
    re.S,
)
replacement = '''    final organizationName = widget.workspace.organizationName.trim();
    final headerPadding = desktop ? AppSpacing.xl : AppSpacing.mdPlus;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                headerPadding,
                headerPadding,
                headerPadding,
                AppSpacing.sm,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: V2PageHeader(
                    key: const Key('v2-management-page-header'),
                    title: '机构管理',
                    meta: organizationName.isEmpty ? null : organizationName,
                    leading: widget.rootMode
                        ? null
                        : IconButton(
                            tooltip: '返回',
                            onPressed: () => Navigator.of(context).maybePop(),
                            icon: const Icon(Icons.arrow_back),
                          ),
                    actions: [
                      PopupMenuButton<_ManagementPageAction>(
                        key: const Key('v2-management-more'),
                        tooltip: '更多操作',
                        onSelected: (action) {
                          switch (action) {
                            case _ManagementPageAction.checkUpdate:
                              unawaited(_checkForUpdates());
                            case _ManagementPageAction.signOut:
                              widget.runtime.onSignOut?.call();
                          }
                        },
                        itemBuilder: (_) => [
                          PopupMenuItem<_ManagementPageAction>(
                            value: _ManagementPageAction.checkUpdate,
                            enabled: !_checkingForUpdates,
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(
                                Icons.system_update_alt_outlined,
                              ),
                              title: Text(
                                _checkingForUpdates
                                    ? '正在检查更新…'
                                    : '检查更新',
                              ),
                              subtitle: Text(
                                '当前版本 ${widget.runtime.appVersion}',
                              ),
                            ),
                          ),
                          if (canSignOut)
                            const PopupMenuItem<_ManagementPageAction>(
                              value: _ManagementPageAction.signOut,
                              child: ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: Icon(Icons.logout_outlined),
                                title: Text('退出登录'),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: Scrollbar(
                controller: _scrollController,
                thumbVisibility: desktop,
                interactive: desktop,
                child: SingleChildScrollView(
                  controller: _scrollController,
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  child: desktop
                      ? SelectionArea(child: managementContent)
                      : managementContent,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}'''
source, count = pattern.subn(replacement, source, count=1)
if count != 1:
    raise SystemExit(f'management scaffold block matched {count} times')
source_path.write_text(source)

contract_path = Path('test/features/v2_management_page_header_contract_test.dart')
contract_path.write_text("""import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('standalone management uses the quiet V2 header action model', () {
    final source = File(
      'lib/features/design_v2/v2_management_page.dart',
    ).readAsStringSync();

    expect(source, contains("import 'v2_page_header.dart';"));
    expect(source, contains('V2PageHeader('));
    expect(source, contains("key: const Key('v2-management-page-header')"));
    expect(source, contains("key: const Key('v2-management-more')"));
    expect(source, contains('PopupMenuButton<_ManagementPageAction>'));
    expect(source, contains("tooltip: '更多操作'"));
    expect(source, contains("'检查更新'"));
    expect(source, contains("'退出登录'"));
    expect(source, contains("'当前版本 \\${widget.runtime.appVersion}'"));

    expect(source, isNot(contains('appBar: AppBar(')));
    expect(source, isNot(contains("tooltip: '检查更新'")));
    expect(source, isNot(contains("tooltip: '退出登录'")));

    // Preserve existing local modal/scroll ergonomics; this visual cut does
    // not redefine the management feature's behavior or data boundary.
    expect(source, contains('MediaQuery.sizeOf(context).width < 720'));
    expect(source, contains('MediaQuery.sizeOf(context).width >= 720'));
    expect(source, contains('showHeaderTitle: false'));
  });
}
""")
