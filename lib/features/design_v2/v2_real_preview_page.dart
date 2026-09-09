import 'package:flutter/material.dart';

import 'v2_theme.dart';
import 'v2_workspace_loader.dart';

/// Development-only host for evaluating the V2 workspace with the existing
/// authenticated read boundary.
///
/// The page accepts only [V2WorkspaceLoad], so this surface cannot issue
/// learning writes even though authentication and membership checks are reused
/// from the normal teacher workspace entry.
class V2RealPreviewPage extends StatelessWidget {
  const V2RealPreviewPage({
    required this.loadWorkspace,
    this.onSignOut,
    super.key,
  });

  final V2WorkspaceLoad loadWorkspace;
  final VoidCallback? onSignOut;

  @override
  Widget build(BuildContext context) {
    final previewTheme = Theme.of(context).brightness == Brightness.dark
        ? V2Theme.dark()
        : V2Theme.light();

    return Theme(
      data: previewTheme,
      child: Column(
        children: [
          Material(
            color: previewTheme.colorScheme.surface,
            child: SafeArea(
              bottom: false,
              child: SizedBox(
                height: 56,
                child: Row(
                  children: [
                    IconButton(
                      key: const Key('v2-real-preview-back'),
                      tooltip: '返回开发工具',
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.arrow_back),
                    ),
                    const SizedBox(width: 4),
                    const Expanded(
                      child: Text(
                        '真实数据只读预览',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (onSignOut != null)
                      TextButton.icon(
                        key: const Key('v2-real-preview-sign-out'),
                        onPressed: onSignOut,
                        icon: const Icon(Icons.logout, size: 18),
                        label: const Text('退出登录'),
                      ),
                    const SizedBox(width: 8),
                  ],
                ),
              ),
            ),
          ),
          Divider(height: 1, color: previewTheme.colorScheme.outlineVariant),
          Expanded(
            child: MediaQuery.removePadding(
              context: context,
              removeTop: true,
              child: V2WorkspaceLoader(loadWorkspace: loadWorkspace),
            ),
          ),
        ],
      ),
    );
  }
}
