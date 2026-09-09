from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    file = Path(path)
    text = file.read_text(encoding='utf-8')
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{path}: expected one match, found {count}: {old[:120]!r}')
    file.write_text(text.replace(old, new, 1), encoding='utf-8')


runtime_path = Path('lib/features/teacher_workspace/workspace_runtime.dart')
if runtime_path.exists():
    raise SystemExit('workspace_runtime.dart already exists')
runtime_path.write_text('''import 'package:flutter/widgets.dart';

import '../../cloud/case_reopen_draft_store.dart';
import '../../cloud/evidence_attachment_repository.dart';
import '../../cloud/learning_repository.dart';
import '../../cloud/organization_management_repository.dart';
import '../../cloud/organization_member_provisioning_repository.dart';
import '../../cloud/progressive_case_repository.dart';
import '../../cloud/student_learning_record_repository.dart';
import '../../cloud/teacher_learning_record_repository.dart';
import '../../update/update_installer.dart';
import '../../update/update_service.dart';

typedef AuthenticatedWorkspaceBuilder = Widget Function(
  BuildContext context,
  AuthenticatedWorkspaceRuntime runtime,
);

/// Capabilities that are safe to expose after the existing authentication,
/// onboarding, membership and disabled-account gates have all passed.
///
/// This deliberately does not expose AuthRepository or the membership lifecycle
/// repository. V2 consumes business capabilities; identity/session governance
/// remains owned by TeacherWorkspaceEntryPage.
class AuthenticatedWorkspaceRuntime {
  const AuthenticatedWorkspaceRuntime({
    required this.learningRepository,
    required this.updateService,
    required this.updateInstaller,
    required this.caseReopenDraftStore,
    required this.appVersion,
    this.progressiveCaseRepository,
    this.evidenceAttachmentRepository,
    this.organizationManagementRepository,
    this.invitationAcceptanceRepository,
    this.memberProvisioningRepository,
    this.teacherLearningRecordRepository,
    this.studentLearningRecordRepository,
    this.sessionUserId,
    this.onSignOut,
  });

  final LearningRepository learningRepository;
  final ProgressiveCaseRepository? progressiveCaseRepository;
  final EvidenceAttachmentRepository? evidenceAttachmentRepository;
  final OrganizationManagementRepository? organizationManagementRepository;
  final OrganizationInvitationAcceptanceRepository?
      invitationAcceptanceRepository;
  final OrganizationMemberProvisioningRepository? memberProvisioningRepository;
  final TeacherLearningRecordRepository? teacherLearningRecordRepository;
  final StudentLearningRecordRepository? studentLearningRecordRepository;
  final UpdateService updateService;
  final UpdateInstaller updateInstaller;
  final CaseReopenDraftStore caseReopenDraftStore;
  final String appVersion;
  final String? sessionUserId;
  final VoidCallback? onSignOut;
}
''', encoding='utf-8')

entry = 'lib/features/teacher_workspace/presentation/teacher_workspace_page.dart'
replace_once(
    entry,
    "import '../../organization_management/presentation/organization_management_page.dart';\nimport 'member_onboarding_page.dart';\n",
    "import '../../organization_management/presentation/organization_management_page.dart';\nimport '../workspace_runtime.dart';\nimport 'member_onboarding_page.dart';\n",
)
replace_once(
    entry,
    "typedef AuthenticatedWorkspaceBuilder = Widget Function(\n  BuildContext context,\n  LearningRepository repository,\n  ProgressiveCaseRepository? progressiveCaseRepository,\n  EvidenceAttachmentRepository? evidenceAttachmentRepository,\n  VoidCallback? onSignOut,\n);\n\n",
    "",
)
old_builder = '''        if (authenticatedWorkspaceBuilder != null) {
          return KeyedSubtree(
            key: ValueKey('authenticated-workspace-$_activeUserId'),
            child: authenticatedWorkspaceBuilder(
              context,
              _learningRepository!,
              _progressiveCaseRepository,
              _evidenceAttachmentRepository,
              _busy ? null : _signOut,
            ),
          );
        }
'''
new_builder = '''        if (authenticatedWorkspaceBuilder != null) {
          final runtime = AuthenticatedWorkspaceRuntime(
            learningRepository: _learningRepository!,
            progressiveCaseRepository: _progressiveCaseRepository,
            evidenceAttachmentRepository: _evidenceAttachmentRepository,
            organizationManagementRepository: _organizationManagementRepository,
            invitationAcceptanceRepository: _invitationAcceptanceRepository,
            memberProvisioningRepository:
                _organizationMemberProvisioningRepository,
            teacherLearningRecordRepository: _teacherLearningRecordRepository,
            studentLearningRecordRepository: _studentLearningRecordRepository,
            updateService: _updateService,
            updateInstaller: _updateInstaller,
            caseReopenDraftStore: _caseReopenDraftStore,
            appVersion: widget.config.appVersion,
            sessionUserId: _activeUserId,
            onSignOut: _busy ? null : _signOut,
          );
          return KeyedSubtree(
            key: ValueKey('authenticated-workspace-$_activeUserId'),
            child: authenticatedWorkspaceBuilder(context, runtime),
          );
        }
'''
replace_once(entry, old_builder, new_builder)

router = 'lib/app/router/app_router.dart'
replace_once(
    router,
    '''            authenticatedWorkspaceBuilder:
                (
                  context,
                  repository,
                  progressiveCaseRepository,
                  evidenceAttachmentRepository,
                  onSignOut,
                ) => V2RealPreviewPage(
                  learningRepository: repository,
                  progressiveCaseRepository: progressiveCaseRepository,
                  evidenceAttachmentRepository: evidenceAttachmentRepository,
                  onSignOut: onSignOut,
                ),
''',
    '''            authenticatedWorkspaceBuilder: (context, runtime) =>
                V2RealPreviewPage(runtime: runtime),
''',
)

preview = 'lib/features/design_v2/v2_real_preview_page.dart'
replace_once(
    preview,
    "import '../../cloud/progressive_case_repository.dart';\nimport 'v2_theme.dart';\n",
    "import '../../cloud/progressive_case_repository.dart';\nimport '../teacher_workspace/workspace_runtime.dart';\nimport 'v2_theme.dart';\n",
)
replace_once(
    preview,
    '''  V2RealPreviewPage({
    LearningRepository? learningRepository,
    V2WorkspaceLoad? loadWorkspace,
    this.progressiveCaseRepository,
    this.evidenceAttachmentRepository,
    this.onSignOut,
    super.key,
  }) : assert(learningRepository != null || loadWorkspace != null),
       learningRepository = learningRepository,
       loadWorkspace = loadWorkspace ?? learningRepository!.loadWorkspace;

  final LearningRepository? learningRepository;
  final V2WorkspaceLoad loadWorkspace;
  final ProgressiveCaseRepository? progressiveCaseRepository;
  final EvidenceAttachmentRepository? evidenceAttachmentRepository;
  final VoidCallback? onSignOut;
''',
    '''  V2RealPreviewPage({
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
           runtime?.evidenceAttachmentRepository ?? evidenceAttachmentRepository,
       onSignOut = runtime?.onSignOut ?? onSignOut;

  final AuthenticatedWorkspaceRuntime? runtime;
  final LearningRepository? learningRepository;
  final V2WorkspaceLoad loadWorkspace;
  final ProgressiveCaseRepository? progressiveCaseRepository;
  final EvidenceAttachmentRepository? evidenceAttachmentRepository;
  final VoidCallback? onSignOut;
''',
)
replace_once(
    preview,
    '''              child: V2WorkspaceLoader(
                loadWorkspace: loadWorkspace,
                learningRepository: learningRepository,
''',
    '''              child: V2WorkspaceLoader(
                loadWorkspace: loadWorkspace,
                runtime: runtime,
                learningRepository: learningRepository,
''',
)

loader = 'lib/features/design_v2/v2_workspace_loader.dart'
replace_once(
    loader,
    "import '../../cloud/progressive_case_repository.dart';\nimport 'v2_read_model_adapter.dart';\n",
    "import '../../cloud/progressive_case_repository.dart';\nimport '../teacher_workspace/workspace_runtime.dart';\nimport 'v2_read_model_adapter.dart';\n",
)
replace_once(
    loader,
    '''  const V2WorkspaceLoader({
    required this.loadWorkspace,
    this.learningRepository,
''',
    '''  const V2WorkspaceLoader({
    required this.loadWorkspace,
    this.runtime,
    this.learningRepository,
''',
)
replace_once(
    loader,
    '''  final V2WorkspaceLoad loadWorkspace;
  final LearningRepository? learningRepository;
''',
    '''  final V2WorkspaceLoad loadWorkspace;
  final AuthenticatedWorkspaceRuntime? runtime;
  final LearningRepository? learningRepository;
''',
)
replace_once(
    loader,
    '''        final snapshotData = V2ReadModelAdapter.fromWorkspace(workspace);
        final learningRepository = widget.learningRepository;
        final progressiveCaseRepository = widget.progressiveCaseRepository;
''',
    '''        final snapshotData = V2ReadModelAdapter.fromWorkspace(workspace);
        final learningRepository =
            widget.runtime?.learningRepository ?? widget.learningRepository;
        final progressiveCaseRepository =
            widget.runtime?.progressiveCaseRepository ??
            widget.progressiveCaseRepository;
        final evidenceAttachmentRepository =
            widget.runtime?.evidenceAttachmentRepository ??
            widget.evidenceAttachmentRepository;
''',
)
replace_once(
    loader,
    '''                evidenceAttachmentRepository:
                    widget.evidenceAttachmentRepository,
''',
    '''                evidenceAttachmentRepository: evidenceAttachmentRepository,
''',
)
replace_once(
    loader,
    '''          evidenceAttachmentRepository: widget.evidenceAttachmentRepository,
''',
    '''          evidenceAttachmentRepository: evidenceAttachmentRepository,
''',
)

contract = 'test/features/design_v2_real_preview_contract_test.dart'
replace_once(
    contract,
    "    final router = File('lib/app/router/app_router.dart').readAsStringSync();\n",
    "    final router = File('lib/app/router/app_router.dart').readAsStringSync();\n    final runtime = File(\n      'lib/features/teacher_workspace/workspace_runtime.dart',\n    ).readAsStringSync();\n",
)
replace_once(
    contract,
    '''    expect(
      entry,
      contains('ProgressiveCaseRepository? progressiveCaseRepository'),
    );
    expect(
      entry,
      contains('EvidenceAttachmentRepository? evidenceAttachmentRepository'),
    );
''',
    '''    expect(entry, contains('AuthenticatedWorkspaceRuntime('));
    expect(entry, contains('organizationManagementRepository:'));
    expect(entry, contains('teacherLearningRecordRepository:'));
    expect(entry, contains('studentLearningRecordRepository:'));
    expect(runtime, contains('OrganizationManagementRepository?'));
    expect(runtime, contains('OrganizationMemberProvisioningRepository?'));
    expect(runtime, contains('TeacherLearningRecordRepository?'));
    expect(runtime, contains('StudentLearningRecordRepository?'));
    expect(runtime, contains('UpdateService updateService'));
    expect(runtime, contains('UpdateInstaller updateInstaller'));
    expect(runtime, contains('CaseReopenDraftStore caseReopenDraftStore'));
    expect(runtime, contains('String appVersion'));
    expect(runtime, isNot(contains('AuthRepository')));
    expect(runtime, isNot(contains('OrganizationMemberLifecycleRepository')));
''',
)
replace_once(
    contract,
    '''    expect(
      router,
      contains('progressiveCaseRepository: progressiveCaseRepository'),
    );
    expect(
      router,
      contains('evidenceAttachmentRepository: evidenceAttachmentRepository'),
    );
''',
    '''    expect(router, contains('V2RealPreviewPage(runtime: runtime)'));
''',
)
replace_once(
    contract,
    "    expect(preview, contains('V2WorkspaceLoader('));\n",
    "    expect(preview, contains('V2WorkspaceLoader('));\n    expect(preview, contains('runtime: runtime'));\n",
)
replace_once(
    contract,
    "    expect(loader, contains('V2WorkflowController('));\n",
    "    expect(loader, contains('widget.runtime?.learningRepository'));\n    expect(loader, contains('V2WorkflowController('));\n",
)

print('V2 runtime bridge patch applied')
