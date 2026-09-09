import 'package:flutter/material.dart';

import '../../cloud/evidence_attachment_repository.dart';
import '../../cloud/learning_repository.dart';
import '../../cloud/progressive_case_repository.dart';
import '../teacher_workspace/workspace_runtime.dart';
import 'v2_theme.dart';
import 'v2_workspace_loader.dart';

/// Development-only host for exercising V2 against authenticated production
/// read/write boundaries before the V2 shell becomes the default workspace.
///
/// The page itself never issues learning commands. It passes the repositories
/// to [V2WorkspaceLoader], which creates one [V2WorkflowController] for the
/// exact workspace snapshot that supplied the visible optimistic-lock versions.
class V2RealPreviewPage extends StatelessWidget {
  V2RealPreviewPage({
    this.runtime,
    LearningRepository? learningRepository,
    V2WorkspaceLoad? loadWorkspace,
    ProgressiveCaseRepository? progressiveCaseRepository,
    EvidenceAttachmentRepository? evidenceAttachmentRepository,
    VoidCallback? onSignOut,
    super.key,
  }) : assert(
         runtime != null || learningRepository != null || loadWorkspace != null,
       ),
       learningRepository = runtime?.learningRepository ?? learningRepository,
       loadWorkspace =
           loadWorkspace ??
           runtime?.learningRepository.loadWorkspace ??
           learningRepository!.loadWorkspace,
       progressiveCaseRepository =
           runtime?.progressiveCaseRepository ?? progressiveCaseRepository,
       evidenceAttachmentRepository =
           runtime?.evidenceAttachmentRepository ??
           evidenceAttachmentRepository,
       onSignOut = runtime?.onSignOut ?? onSignOut;

  final AuthenticatedWorkspaceRuntime? runtime;
  final LearningRepository? learningRepository;
  final V2WorkspaceLoad loadWorkspace;
  final ProgressiveCaseRepository? progressiveCaseRepository;
  final EvidenceAttachmentRepository? evidenceAttachmentRepository;
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
                        'V2 真实学情预览',
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
              child: V2WorkspaceLoader(
                loadWorkspace: loadWorkspace,
                runtime: runtime,
                learningRepository: learningRepository,
                progressiveCaseRepository: progressiveCaseRepository,
                evidenceAttachmentRepository: evidenceAttachmentRepository,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
