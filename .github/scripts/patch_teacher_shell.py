from pathlib import Path

path = Path('lib/features/teacher_workspace/presentation/teacher_workspace_page.dart')
text = path.read_text(encoding='utf-8')

old_label = '              labelType: NavigationRailLabelType.none,\n'
new_label = '''              labelType: extended
                  ? NavigationRailLabelType.none
                  : NavigationRailLabelType.all,
'''
if text.count(old_label) != 1:
    raise SystemExit(f'Expected one teacher rail label mode, found {text.count(old_label)}')
text = text.replace(old_label, new_label, 1)

old_footer = '''          Padding(
            padding: EdgeInsets.fromLTRB(
              extended ? AppSpacing.lg : AppSpacing.sm,
              AppSpacing.sm,
              AppSpacing.sm,
              AppSpacing.lg,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    extended ? '开发数据 · 仅当前权限范围' : '开发数据',
                    textAlign: extended ? TextAlign.start : TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                if (onCheckForUpdates != null)
                  IconButton(
                    tooltip: '检查更新',
                    onPressed: checkingForUpdates ? null : onCheckForUpdates,
                    icon: checkingForUpdates
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.system_update_alt),
                  ),
                if (extended && onSignOut != null)
                  IconButton(
                    tooltip: '退出登录',
                    onPressed: onSignOut,
                    icon: Icon(Icons.logout),
                  ),
              ],
            ),
          ),
'''
new_footer = '''          Padding(
            padding: EdgeInsets.fromLTRB(
              extended ? AppSpacing.lg : AppSpacing.sm,
              AppSpacing.sm,
              AppSpacing.sm,
              AppSpacing.lg,
            ),
            child: extended
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (onCheckForUpdates != null)
                        IconButton(
                          key: const Key('workspace-rail-update'),
                          tooltip: '检查更新',
                          onPressed: checkingForUpdates
                              ? null
                              : onCheckForUpdates,
                          icon: checkingForUpdates
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.system_update_alt),
                        ),
                      if (onSignOut != null)
                        IconButton(
                          key: const Key('workspace-rail-sign-out'),
                          tooltip: '退出登录',
                          onPressed: onSignOut,
                          icon: const Icon(Icons.logout),
                        ),
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (onCheckForUpdates != null)
                        IconButton(
                          key: const Key('workspace-rail-update'),
                          tooltip: '检查更新',
                          onPressed: checkingForUpdates
                              ? null
                              : onCheckForUpdates,
                          icon: checkingForUpdates
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.system_update_alt),
                        ),
                      if (onSignOut != null)
                        IconButton(
                          key: const Key('workspace-rail-sign-out'),
                          tooltip: '退出登录',
                          onPressed: onSignOut,
                          icon: const Icon(Icons.logout),
                        ),
                    ],
                  ),
          ),
'''
if text.count(old_footer) != 1:
    raise SystemExit(f'Expected one teacher rail footer, found {text.count(old_footer)}')
text = text.replace(old_footer, new_footer, 1)

path.write_text(text, encoding='utf-8')
