import 'package:flutter/material.dart';

import '../../cloud/cloud_client.dart';
import '../../cloud/responsibility_read_repository.dart';
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
  const V2WorkspacePage({
    required this.runtime,
    this.responsibilityReadRepository,
    super.key,
  });

  final AuthenticatedWorkspaceRuntime runtime;

  /// Injectable for widget tests. Normal cloud-backed runtime uses the same
  /// already-initialized Supabase client as the existing workspace repository.
  final ResponsibilityReadRepository? responsibilityReadRepository;

  @override
  Widget build(BuildContext context) {
    final workspaceTheme = Theme.of(context).brightness == Brightness.dark
        ? V2Theme.dark()
        : V2Theme.light();
    final responsibilityRepository =
        responsibilityReadRepository ??
        (CloudClient.isInitialized
            ? SupabaseResponsibilityReadRepository(CloudClient.client)
            : null);

    return Theme(
      data: workspaceTheme,
      child: V2WorkspaceLoader(
        loadWorkspace: runtime.learningRepository.loadWorkspace,
        responsibilityReadRepository: responsibilityRepository,
        runtime: runtime,
      ),
    );
  }
}
