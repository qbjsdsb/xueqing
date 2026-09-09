from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected 1 match, found {count}')
    return text.replace(old, new, 1)

# 1) Authenticated builder can pass the already-created write repositories.
path = Path('lib/features/teacher_workspace/presentation/teacher_workspace_page.dart')
text = path.read_text()
text = replace_once(
    text,
    '''typedef AuthenticatedWorkspaceBuilder = Widget Function(\n  BuildContext context,\n  LearningRepository repository,\n  VoidCallback? onSignOut,\n);''',
    '''typedef AuthenticatedWorkspaceBuilder = Widget Function(\n  BuildContext context,\n  LearningRepository repository,\n  ProgressiveCaseRepository? progressiveCaseRepository,\n  EvidenceAttachmentRepository? evidenceAttachmentRepository,\n  VoidCallback? onSignOut,\n);''',
    'authenticated builder typedef',
)
text = replace_once(
    text,
    '''            child: authenticatedWorkspaceBuilder(\n              context,\n              _learningRepository!,\n              _busy ? null : _signOut,\n            ),''',
    '''            child: authenticatedWorkspaceBuilder(\n              context,\n              _learningRepository!,\n              _progressiveCaseRepository,\n              _evidenceAttachmentRepository,\n              _busy ? null : _signOut,\n            ),''',
    'authenticated builder call',
)
path.write_text(text)

# 2) Router wires the V2 development route to the same repositories used by V1.
path = Path('lib/app/router/app_router.dart')
text = path.read_text()
text = replace_once(
    text,
    '''            authenticatedWorkspaceBuilder: (context, repository, onSignOut) =>\n                V2RealPreviewPage(\n                  loadWorkspace: repository.loadWorkspace,\n                  onSignOut: onSignOut,\n                ),''',
    '''            authenticatedWorkspaceBuilder:\n                (\n                  context,\n                  repository,\n                  progressiveCaseRepository,\n                  evidenceAttachmentRepository,\n                  onSignOut,\n                ) => V2RealPreviewPage(\n                  learningRepository: repository,\n                  progressiveCaseRepository: progressiveCaseRepository,\n                  evidenceAttachmentRepository: evidenceAttachmentRepository,\n                  onSignOut: onSignOut,\n                ),''',
    'V2 router builder',
)
path.write_text(text)

# 3) V2 real preview keeps orchestration outside the presentation widgets.
Path('lib/features/design_v2/v2_real_preview_page.dart').write_text(r'''import 'package:flutter/material.dart';

import '../../cloud/evidence_attachment_repository.dart';
import '../../cloud/learning_repository.dart';
import '../../cloud/progressive_case_repository.dart';
import 'v2_theme.dart';
import 'v2_workspace_loader.dart';

/// Development-only host for exercising V2 against authenticated production
/// read/write boundaries before the V2 shell becomes the default workspace.
///
/// The page itself never issues learning commands. It passes the repositories
/// to [V2WorkspaceLoader], which creates one [V2WorkflowController] for the
/// exact workspace snapshot that supplied the visible optimistic-lock versions.
class V2RealPreviewPage extends StatelessWidget {
  const V2RealPreviewPage({
    required this.learningRepository,
    this.progressiveCaseRepository,
    this.evidenceAttachmentRepository,
    this.onSignOut,
    super.key,
  });

  final LearningRepository learningRepository;
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
                loadWorkspace: learningRepository.loadWorkspace,
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
''')

# 4) Loader creates a controller from the same snapshot it renders and reloads
# after successful writes, so optimistic versions are never reused after save.
Path('lib/features/design_v2/v2_workspace_loader.dart').write_text(r'''import 'package:flutter/material.dart';

import '../../cloud/evidence_attachment_repository.dart';
import '../../cloud/learning_repository.dart';
import '../../cloud/progressive_case_repository.dart';
import 'v2_read_model_adapter.dart';
import 'v2_workflow_controller.dart';
import 'v2_workspace_preview.dart';

typedef V2WorkspaceLoad = Future<TeacherWorkspace> Function();

class V2WorkspaceLoader extends StatefulWidget {
  const V2WorkspaceLoader({
    required this.loadWorkspace,
    this.learningRepository,
    this.progressiveCaseRepository,
    this.evidenceAttachmentRepository,
    super.key,
  });

  final V2WorkspaceLoad loadWorkspace;
  final LearningRepository? learningRepository;
  final ProgressiveCaseRepository? progressiveCaseRepository;
  final EvidenceAttachmentRepository? evidenceAttachmentRepository;

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
    final nextWorkspace = widget.loadWorkspace();
    setState(() {
      _workspaceFuture = nextWorkspace;
    });
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
        final learningRepository = widget.learningRepository;
        final progressiveCaseRepository = widget.progressiveCaseRepository;
        final workflowController =
            learningRepository != null && progressiveCaseRepository != null
            ? V2WorkflowController(
                workspace: workspace,
                learningRepository: learningRepository,
                progressiveCaseRepository: progressiveCaseRepository,
                evidenceAttachmentRepository: widget.evidenceAttachmentRepository,
              )
            : null;
        return V2WorkspacePreview(
          data: snapshotData.workspaceData,
          workflowController: workflowController,
          evidenceAttachmentRepository: widget.evidenceAttachmentRepository,
          onWorkspaceChanged: workflowController == null ? null : _retry,
        );
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
                  Icon(
                    icon,
                    size: 34,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
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
                  if (action != null) ...[const SizedBox(height: 18), action!],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
''')

# 5) Carry optional Evidence identity through the existing workspace timeline.
path = Path('lib/cloud/learning_repository.dart')
text = path.read_text()
text = replace_once(
    text,
    '''class WorkspaceTimelineEvent {\n  const WorkspaceTimelineEvent({\n    required this.id,\n    required this.occurredAt,\n    required this.typeLabel,\n    required this.text,\n  });\n\n  final String id;\n  final DateTime occurredAt;\n  final String typeLabel;\n  final String text;\n}''',
    '''class WorkspaceTimelineEvent {\n  const WorkspaceTimelineEvent({\n    required this.id,\n    required this.occurredAt,\n    required this.typeLabel,\n    required this.text,\n    this.evidenceId,\n  });\n\n  final String id;\n  final DateTime occurredAt;\n  final String typeLabel;\n  final String text;\n  final String? evidenceId;\n}''',
    'WorkspaceTimelineEvent evidence identity',
)
old = '''            typeLabel: '发现问题',\n            text: initialEvidence == null'''
new = '''            typeLabel: '发现问题',\n            evidenceId: initialEvidenceId,\n            text: initialEvidence == null'''
text = replace_once(text, old, new, 'initial evidence timeline identity')
old = '''          typeLabel: '学生表现',\n          text: '${item.summary}${progressSuffix(progressByRecordId[item.id])}',\n        ),'''
new = '''          typeLabel: '学生表现',\n          text: '${item.summary}${progressSuffix(progressByRecordId[item.id])}',\n          evidenceId: item.id,\n        ),'''
text = replace_once(text, old, new, 'evidence timeline identity')
path.write_text(text)

# 6) V2 timeline presentation model preserves evidence identity.
path = Path('lib/features/design_v2/v2_fixture.dart')
text = path.read_text()
text = replace_once(
    text,
    '''    required this.teacher,\n    required this.time,\n    this.photoCount = 0,\n  });\n\n  final String caseId;\n  final String date;\n  final String kind;\n  final String body;\n  final String teacher;\n  final String time;\n  final int photoCount;''',
    '''    required this.teacher,\n    required this.time,\n    this.photoCount = 0,\n    this.evidenceId,\n  });\n\n  final String caseId;\n  final String date;\n  final String kind;\n  final String body;\n  final String teacher;\n  final String time;\n  final int photoCount;\n  final String? evidenceId;''',
    'V2 timeline evidence identity',
)
path.write_text(text)

path = Path('lib/features/design_v2/v2_read_model_adapter.dart')
text = path.read_text()
text = replace_once(
    text,
    '''              teacher: '',\n              time: _timeLabel(event.occurredAt),''',
    '''              teacher: '',\n              time: _timeLabel(event.occurredAt),\n              evidenceId: event.evidenceId,''',
    'adapter evidence identity',
)
path.write_text(text)

# 7) Replace the top of the workspace preview with controlled write helpers.
path = Path('lib/features/design_v2/v2_workspace_preview.dart')
text = path.read_text()
class_marker = 'class V2WorkspacePreview extends StatefulWidget {'
idx = text.index(class_marker)
new_top = r'''import 'package:flutter/material.dart';

import '../../cloud/evidence_attachment_repository.dart';
import '../../cloud/learning_repository.dart';
import '../../cloud/progressive_case_repository.dart';
import 'v2_composers.dart';
import 'v2_fixture.dart';
import 'v2_workflow_controller.dart';
import 'v2_workspace_data.dart';

class _V2RuntimeScope extends InheritedWidget {
  const _V2RuntimeScope({
    required this.workflowController,
    required this.evidenceAttachmentRepository,
    required this.onWorkspaceChanged,
    required super.child,
  });

  final V2WorkflowController? workflowController;
  final EvidenceAttachmentRepository? evidenceAttachmentRepository;
  final VoidCallback? onWorkspaceChanged;

  static _V2RuntimeScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_V2RuntimeScope>();

  @override
  bool updateShouldNotify(_V2RuntimeScope oldWidget) =>
      workflowController != oldWidget.workflowController ||
      evidenceAttachmentRepository != oldWidget.evidenceAttachmentRepository ||
      onWorkspaceChanged != oldWidget.onWorkspaceChanged;
}

Future<void> _showV2QuickCaptureForStudent(
  BuildContext context,
  V2Student student,
) async {
  final runtime = _V2RuntimeScope.maybeOf(context);
  final controller = runtime?.workflowController;
  final operationId = controller == null ? null : createOperationId();
  final problemTypes = controller == null
      ? v2PreviewProblemTypeOptions
      : controller.caseTypeChoices
            .map(
              (choice) => V2ProblemTypeOption(
                key: choice.key,
                label: choice.label,
              ),
            )
            .toList(growable: false);

  final saved = await showV2QuickCapture(
    context,
    studentName: student.name,
    subjects: student.subjects,
    problemTypes: problemTypes,
    onSave: controller == null
        ? null
        : (draft) async {
            await controller.quickCapture(
              V2QuickCaptureWrite(
                operationId: operationId!,
                studentId: student.id,
                subject: draft.subject,
                caseTypeKey: draft.caseTypeKey,
                body: draft.body,
                attachments: draft.attachments,
              ),
            );
          },
  );
  if (saved && context.mounted) {
    runtime?.onWorkspaceChanged?.call();
  }
}

Future<void> _showV2ProgressForCase(
  BuildContext context,
  V2Student student,
  V2FocusItem item,
) async {
  final runtime = _V2RuntimeScope.maybeOf(context);
  final controller = runtime?.workflowController;
  final operationId = controller == null ? null : createOperationId();
  final photoEvidenceOperationId = controller == null
      ? null
      : createOperationId();
  final saved = await showV2ProgressComposer(
    context,
    studentName: student.name,
    subject: item.subject,
    caseTitle: item.title,
    canCompleteCurrentAction:
        controller?.hasPendingPrimaryAction(item.id) ?? false,
    onSave: controller == null
        ? null
        : (draft) async {
            await controller.recordProgress(
              V2ProgressWrite(
                operationId: operationId!,
                photoEvidenceOperationId: photoEvidenceOperationId!,
                caseId: item.id,
                progressKind: _domainProgressKind(draft.kind),
                summary: draft.body,
                assessmentResult: draft.kind == V2ProgressKind.assessment
                    ? _domainAssessmentResult(draft.assessmentResult)
                    : null,
                completeCurrentAction: draft.completeCurrentAction,
                nextStep: _domainNextStep(draft.nextStep),
                nextActionTitle: draft.nextStep == V2NextStep.remind
                    ? draft.reminderTitle
                    : null,
                nextActionDueOn: draft.nextStep == V2NextStep.remind
                    ? draft.reminderDate
                    : null,
                closeReason: draft.nextStep == V2NextStep.close
                    ? _domainCloseReason(draft.closeReason)
                    : null,
                attachments: draft.attachments,
              ),
            );
          },
  );
  if (saved && context.mounted) {
    runtime?.onWorkspaceChanged?.call();
  }
}

CaseProgressKind _domainProgressKind(V2ProgressKind kind) => switch (kind) {
  V2ProgressKind.observation => CaseProgressKind.observation,
  V2ProgressKind.intervention => CaseProgressKind.intervention,
  V2ProgressKind.assessment => CaseProgressKind.assessment,
};

CaseAssessmentResult? _domainAssessmentResult(V2AssessmentResult? result) =>
    switch (result) {
      null => null,
      V2AssessmentResult.passed => CaseAssessmentResult.passed,
      V2AssessmentResult.partial => CaseAssessmentResult.partial,
      V2AssessmentResult.notPassed => CaseAssessmentResult.notPassed,
    };

CaseProgressNextStep _domainNextStep(V2NextStep step) => switch (step) {
  V2NextStep.continueTracking => CaseProgressNextStep.continueTracking,
  V2NextStep.remind => CaseProgressNextStep.remind,
  V2NextStep.close => CaseProgressNextStep.close,
};

CaseClosureReason _domainCloseReason(V2CloseReason reason) => switch (reason) {
  V2CloseReason.resolved => CaseClosureReason.resolved,
  V2CloseReason.pauseTracking => CaseClosureReason.pauseTracking,
  V2CloseReason.notIssue => CaseClosureReason.notIssue,
  V2CloseReason.other => CaseClosureReason.other,
};

Future<void> _showV2ProgressCasePicker(
  BuildContext context,
  V2Student student,
) async {
  final items = V2WorkspaceDataScope.of(context).focusItemsForStudent(student);
  if (items.isEmpty) {
    return;
  }

  Widget choices(BuildContext sheetContext) => ListView.separated(
    shrinkWrap: true,
    itemCount: items.length,
    separatorBuilder: (_, _) => Divider(
      height: 1,
      color: Theme.of(sheetContext).colorScheme.outlineVariant,
    ),
    itemBuilder: (_, index) {
      final item = items[index];
      return ListTile(
        title: Text(item.title),
        subtitle: Text(item.subject),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(sheetContext).pop(item),
      );
    },
  );

  final compact = MediaQuery.sizeOf(context).width < 720;
  final selected = compact
      ? await showModalBottomSheet<V2FocusItem>(
          context: context,
          useSafeArea: true,
          builder: (sheetContext) => Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '选择要记录进展的问题',
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                choices(sheetContext),
              ],
            ),
          ),
        )
      : await showDialog<V2FocusItem>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('选择要记录进展的问题'),
            content: SizedBox(width: 420, child: choices(dialogContext)),
          ),
        );
  if (selected == null || !context.mounted) {
    return;
  }
  await _showV2ProgressForCase(context, student, selected);
}

'''
text = new_top + text[idx:]

# Expand preview constructor/runtime scope.
text = replace_once(
    text,
    '''class V2WorkspacePreview extends StatefulWidget {\n  const V2WorkspacePreview({super.key, this.data = v2FixtureWorkspaceData});\n\n  final V2WorkspaceData data;''',
    '''class V2WorkspacePreview extends StatefulWidget {\n  const V2WorkspacePreview({\n    super.key,\n    this.data = v2FixtureWorkspaceData,\n    this.workflowController,\n    this.evidenceAttachmentRepository,\n    this.onWorkspaceChanged,\n  });\n\n  final V2WorkspaceData data;\n  final V2WorkflowController? workflowController;\n  final EvidenceAttachmentRepository? evidenceAttachmentRepository;\n  final VoidCallback? onWorkspaceChanged;''',
    'workspace preview constructor',
)
text = replace_once(
    text,
    '''    return V2WorkspaceDataScope(\n      data: widget.data,\n      child: Builder(''',
    '''    return _V2RuntimeScope(\n      workflowController: widget.workflowController,\n      evidenceAttachmentRepository: widget.evidenceAttachmentRepository,\n      onWorkspaceChanged: widget.onWorkspaceChanged,\n      child: V2WorkspaceDataScope(\n        data: widget.data,\n        child: Builder(''',
    'workspace runtime wrapper start',
)
text = replace_once(
    text,
    '''        },\n      ),\n    );\n  }\n}\n\nclass _DesktopWorkspace''',
    '''        },\n      ),\n      ),\n    );\n  }\n}\n\nclass _DesktopWorkspace''',
    'workspace runtime wrapper end',
)

# Route existing buttons through the controlled helpers.
text = replace_once(
    text,
    '''          onPressed: () => showV2QuickCapture(\n            context,\n            studentName: student.name,\n            subjects: student.subjects,\n          ),''',
    '''          onPressed: () => _showV2QuickCaptureForStudent(context, student),''',
    'student quick capture button',
)
text = replace_once(
    text,
    '''                        onPressed: () => showV2ProgressComposer(\n                          context,\n                          studentName: student.name,\n                          subject: item.subject,\n                          caseTitle: item.title,\n                        ),''',
    '''                        onPressed: () =>\n                            _showV2ProgressForCase(context, student, item),''',
    'case progress button',
)

# Case detail resolves real Evidence attachments lazily; student summary stays cheap.
needle = '_Timeline(entries: timelineEntries),'
if text.count(needle) != 2:
    raise SystemExit(f'timeline call count: expected 2, found {text.count(needle)}')
last = text.rfind(needle)
text = text[:last] + '_Timeline(\n                    entries: timelineEntries,\n                    resolveEvidencePhotos: true,\n                  ),' + text[last + len(needle):]

# Replace timeline rendering block with a lazy Evidence photo resolver.
start = text.index('class _Timeline extends StatelessWidget')
end = text.index('class _CaseDetailPane extends StatelessWidget')
timeline_block = r'''class _Timeline extends StatelessWidget {
  const _Timeline({
    required this.entries,
    this.resolveEvidencePhotos = false,
  });

  final List<V2TimelineEntry> entries;
  final bool resolveEvidencePhotos;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return Text('暂时还没有成长记录', style: Theme.of(context).textTheme.bodyMedium);
    }
    return Column(
      children: [
        for (var i = 0; i < entries.length; i++)
          _TimelineRow(
            entry: entries[i],
            last: i == entries.length - 1,
            resolveEvidencePhotos: resolveEvidencePhotos,
          ),
      ],
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.entry,
    required this.last,
    required this.resolveEvidencePhotos,
  });

  final V2TimelineEntry entry;
  final bool last;
  final bool resolveEvidencePhotos;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final attachmentRepository =
        _V2RuntimeScope.maybeOf(context)?.evidenceAttachmentRepository;
    final canResolveRealPhotos =
        resolveEvidencePhotos &&
        entry.evidenceId != null &&
        attachmentRepository != null;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 74,
          child: Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Text(
              entry.date,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ),
        SizedBox(
          width: 24,
          child: Column(
            children: [
              Container(
                width: 7,
                height: 7,
                margin: const EdgeInsets.only(top: 7),
                decoration: BoxDecoration(
                  color: entry.kind == '新表现' ? scheme.primary : scheme.outline,
                  shape: BoxShape.circle,
                ),
              ),
              if (!last)
                Container(
                  width: 1,
                  height: entry.photoCount > 0 || canResolveRealPhotos ? 144 : 96,
                  color: scheme.outlineVariant,
                ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.kind,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 5),
                Text(entry.body, style: Theme.of(context).textTheme.bodyMedium),
                if (canResolveRealPhotos) ...[
                  const SizedBox(height: 12),
                  _EvidencePhotoStrip(
                    evidenceId: entry.evidenceId!,
                    repository: attachmentRepository,
                  ),
                ] else if (entry.photoCount > 0) ...[
                  const SizedBox(height: 12),
                  _PhotoStrip(count: entry.photoCount),
                ],
                const SizedBox(height: 9),
                Text(
                  entry.teacher.trim().isEmpty
                      ? entry.time
                      : '${entry.teacher} · ${entry.time}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _EvidencePhotoStrip extends StatefulWidget {
  const _EvidencePhotoStrip({
    required this.evidenceId,
    required this.repository,
  });

  final String evidenceId;
  final EvidenceAttachmentRepository repository;

  @override
  State<_EvidencePhotoStrip> createState() => _EvidencePhotoStripState();
}

class _EvidencePhotoStripState extends State<_EvidencePhotoStrip> {
  late Future<List<String>> _signedUrls;

  @override
  void initState() {
    super.initState();
    _signedUrls = _loadSignedUrls();
  }

  @override
  void didUpdateWidget(covariant _EvidencePhotoStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.evidenceId != widget.evidenceId ||
        oldWidget.repository != widget.repository) {
      _signedUrls = _loadSignedUrls();
    }
  }

  Future<List<String>> _loadSignedUrls() async {
    final attachments = await widget.repository.listForEvidence(widget.evidenceId);
    final result = <String>[];
    for (final attachment in attachments.take(3)) {
      result.add(
        await widget.repository.createSignedUrl(attachment.storagePath),
      );
    }
    return List<String>.unmodifiable(result);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FutureBuilder<List<String>>(
      future: _signedUrls,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 1.5),
              ),
              const SizedBox(width: 8),
              Text('正在加载图片…', style: Theme.of(context).textTheme.bodySmall),
            ],
          );
        }
        if (snapshot.hasError) {
          return Text(
            '图片暂时无法加载',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          );
        }
        final urls = snapshot.data ?? const <String>[];
        if (urls.isEmpty) {
          return const SizedBox.shrink();
        }
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final url in urls)
              ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: SizedBox(
                  width: 96,
                  height: 72,
                  child: Image.network(
                    url,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => ColoredBox(
                      color: scheme.surfaceContainer,
                      child: Icon(
                        Icons.broken_image_outlined,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _PhotoStrip extends StatelessWidget {
  const _PhotoStrip({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var i = 0; i < count.clamp(0, 3); i++)
          Container(
            width: 86,
            height: 66,
            decoration: BoxDecoration(
              color: scheme.surfaceContainer,
              border: Border.all(color: scheme.outlineVariant),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(
              Icons.description_outlined,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
      ],
    );
  }
}

'''
text = text[:start] + timeline_block + text[end:]
path.write_text(text)

# 8) Update the contract test from read-only to controlled-write boundaries.
Path('test/features/design_v2_real_preview_contract_test.dart').write_text(r'''import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('real V2 preview uses controlled repositories and remains dev-only', () {
    final entry = File(
      'lib/features/teacher_workspace/presentation/teacher_workspace_page.dart',
    ).readAsStringSync();
    final router = File('lib/app/router/app_router.dart').readAsStringSync();
    final preview = File('lib/features/design_v2/v2_real_preview_page.dart')
        .readAsStringSync();
    final loader = File('lib/features/design_v2/v2_workspace_loader.dart')
        .readAsStringSync();
    final workspace = File('lib/features/design_v2/v2_workspace_preview.dart')
        .readAsStringSync();

    expect(entry, contains('ProgressiveCaseRepository? progressiveCaseRepository'));
    expect(entry, contains('EvidenceAttachmentRepository? evidenceAttachmentRepository'));
    expect(
      RegExp(r'case AppRoutes\.v2RealPreview:').allMatches(router).length,
      2,
    );
    expect(router, contains('progressiveCaseRepository: progressiveCaseRepository'));
    expect(router, contains('evidenceAttachmentRepository: evidenceAttachmentRepository'));
    expect(preview, contains('V2WorkspaceLoader('));
    expect(preview, isNot(contains('quickCapture(')));
    expect(preview, isNot(contains('recordProgress(')));
    expect(loader, contains('V2WorkflowController('));
    expect(loader, contains('onWorkspaceChanged: workflowController == null ? null : _retry'));
    expect(workspace, contains('operationId = controller == null ? null : createOperationId()'));
    expect(workspace, contains('await controller.quickCapture('));
    expect(workspace, contains('await controller.recordProgress('));
    expect(workspace, contains('listForEvidence(widget.evidenceId)'));
    expect(workspace, contains('createSignedUrl(attachment.storagePath)'));
  });
}
''')

# 9) Prove evidence identity survives the read adapter, enabling lazy attachment lookup.
path = Path('test/features/design_v2_read_model_adapter_test.dart')
text = path.read_text()
text = replace_once(
    text,
    '''        expect(timeline.first.body, '第二次检查仍漏结果。');\n        expect(timeline.last.body, '第一次发现概括遗漏。');''',
    '''        expect(timeline.first.body, '第二次检查仍漏结果。');\n        expect(timeline.first.evidenceId, 'evidence-timeline');\n        expect(timeline.last.body, '第一次发现概括遗漏。');''',
    'adapter evidence assertion',
)
text = replace_once(
    text,
    '''                typeLabel: '新表现',\n                text: '第二次检查仍漏结果。',\n              ),''',
    '''                typeLabel: '新表现',\n                text: '第二次检查仍漏结果。',\n                evidenceId: 'evidence-timeline',\n              ),''',
    'adapter evidence fixture',
)
path.write_text(text)
