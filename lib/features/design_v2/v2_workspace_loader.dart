import 'package:flutter/material.dart';

import '../../cloud/learning_repository.dart';
import 'v2_read_model_adapter.dart';
import 'v2_workspace_preview.dart';

typedef V2WorkspaceLoad = Future<TeacherWorkspace> Function();

/// Loads the already-authorized production read model and hands only mapped,
/// presentation-safe data to the V2 workspace.
///
/// This widget intentionally accepts a read callback instead of the full
/// [LearningRepository], so the V2 loading boundary cannot call write methods.
class V2WorkspaceLoader extends StatefulWidget {
  const V2WorkspaceLoader({required this.loadWorkspace, super.key});

  final V2WorkspaceLoad loadWorkspace;

  @override
  State<V2WorkspaceLoader> createState() => _V2WorkspaceLoaderState();
}

class _V2WorkspaceLoaderState extends State<V2WorkspaceLoader> {
  late Future<TeacherWorkspace> _workspaceFuture;

  @override
  void initState() {
    super.initState();
    _workspaceFuture = widget.loadWorkspace();
  }

  @override
  void didUpdateWidget(covariant V2WorkspaceLoader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.loadWorkspace != widget.loadWorkspace) {
      _workspaceFuture = widget.loadWorkspace();
    }
  }

  void _retry() {
    setState(() => _workspaceFuture = widget.loadWorkspace());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<TeacherWorkspace>(
      future: _workspaceFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _V2LoaderStatus(
            icon: Icons.sync,
            title: '正在读取学情…',
            message: '正在准备你的学生与成长记录。',
          );
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return _V2LoaderStatus(
            icon: Icons.cloud_off_outlined,
            title: '学情暂时无法读取',
            message: '请检查网络后重试；已经保存的学情记录不会受影响。',
            action: FilledButton.tonal(
              key: const Key('v2-workspace-retry'),
              onPressed: _retry,
              child: const Text('重试'),
            ),
          );
        }

        final workspace = snapshot.requireData;
        if (!workspace.hasTeachingAccess) {
          return const _V2LoaderStatus(
            icon: Icons.person_off_outlined,
            title: '暂时没有任课学情',
            message: '当前账号暂时没有可查看的任课学生；获得任课关系后，这里会自动出现。',
          );
        }

        final snapshotData = V2ReadModelAdapter.fromWorkspace(workspace);
        return V2WorkspacePreview(data: snapshotData.workspaceData);
      },
    );
  }
}

class _V2LoaderStatus extends StatelessWidget {
  const _V2LoaderStatus({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 34, color: scheme.onSurfaceVariant),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  if (action != null) ...[
                    const SizedBox(height: 18),
                    action!,
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
