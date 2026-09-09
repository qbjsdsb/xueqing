import 'package:flutter/material.dart';

import '../teacher_workspace/workspace_runtime.dart';
import 'v2_theme.dart';
import 'v2_workspace_loader.dart';

/// Production host for the V2 teacher workspace.
///
/// Authentication, onboarding, membership state and disabled-account gates
/// remain owned by TeacherWorkspaceEntryPage. This page starts only after the
/// authenticated runtime has been established and therefore contains no
/// second auth or authorization lifecycle.
class V2WorkspacePage extends StatelessWidget {
  const V2WorkspacePage({required this.runtime, super.key});

  final AuthenticatedWorkspaceRuntime runtime;

  @override
  Widget build(BuildContext context) {
    final workspaceTheme = Theme.of(context).brightness == Brightness.dark
        ? V2Theme.dark()
        : V2Theme.light();

    return Theme(
      data: workspaceTheme,
      child: V2WorkspaceLoader(
        loadWorkspace: runtime.learningRepository.loadWorkspace,
        runtime: runtime,
      ),
    );
  }
}
