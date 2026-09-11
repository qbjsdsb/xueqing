import 'dart:async';

import 'package:flutter/material.dart';

import '../../cloud/composer_draft_store.dart';
import '../../cloud/evidence_attachment_repository.dart';
import '../../cloud/learning_repository.dart';
import '../../cloud/progressive_case_repository.dart';
import '../../cloud/student_learning_record_repository.dart';
import '../../export/learning_record_case_picker.dart';
import '../../export/learning_record_export.dart';
import '../../export/learning_record_export_feedback.dart';
import '../teacher_workspace/workspace_runtime.dart';
import 'v2_fixture.dart';
import 'v2_management_page.dart';
import 'v2_read_model_adapter.dart';
import 'v2_workflow_controller.dart';
import 'v2_workspace_preview.dart';

typedef V2WorkspaceLoad = Future<TeacherWorkspace> Function();

class V2WorkspaceLoader extends StatefulWidget {
  const V2WorkspaceLoader({
    required this.loadWorkspace,
    this.runtime,
    this.learningRepository,
    this.progressiveCaseRepository,
    this.evidenceAttachmentRepository,
    super.key,
  });

  final V2WorkspaceLoad loadWorkspace;
  final AuthenticatedWorkspaceRuntime? runtime;
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

  bool _softRefreshRunning = false;
  bool _softRefreshQueued = false;

  Future<void> _softRefresh() async {
    if (_softRefreshRunning) {
      _softRefreshQueued = true;
      return;
    }
    do {
      _softRefreshQueued = false;
      _softRefreshRunning = true;
      try {
        final workspace = await widget.loadWorkspace();
        if (!mounted) return;
        setState(() {
          _workspaceFuture = Future<TeacherWorkspace>.value(workspace);
        });
      } catch (_) {
        if (!mounted) return;
        final messenger = ScaffoldMessenger.maybeOf(context);
        messenger?.hideCurrentSnackBar();
        messenger?.showSnackBar(
          SnackBar(
            content: const Text('刷新失败，请检查网络后重试；当前页面和已保存记录不会受影响。'),
            action: SnackBarAction(
              label: '重试',
              onPressed: () => unawaited(_softRefresh()),
            ),
          ),
        );
      } finally {
        _softRefreshRunning = false;
      }
    } while (_softRefreshQueued && mounted);
  }

  Future<WorkspaceStudent?> _pickStudentSubjectProfile(
    BuildContext context,
    List<WorkspaceStudent> profiles,
  ) async {
    if (profiles.isEmpty) {
      return null;
    }
    if (profiles.length == 1) {
      return profiles.single;
    }
    final sorted = List<WorkspaceStudent>.of(profiles)
      ..sort((left, right) => left.subject.compareTo(right.subject));

    Widget choices(BuildContext selectionContext) => ListView.separated(
      shrinkWrap: true,
      itemCount: sorted.length,
      separatorBuilder: (_, _) => Divider(
        height: 1,
        color: Theme.of(selectionContext).colorScheme.outlineVariant,
      ),
      itemBuilder: (_, index) {
        final profile = sorted[index];
        return ListTile(
          title: Text(profile.subject),
          subtitle: Text('${profile.name} · ${profile.grade}'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(selectionContext).pop(profile),
        );
      },
    );

    if (MediaQuery.sizeOf(context).width < 720) {
      return showModalBottomSheet<WorkspaceStudent>(
        context: context,
        useSafeArea: true,
        showDragHandle: true,
        builder: (sheetContext) => Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '选择要导出的学科',
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 420),
                child: choices(sheetContext),
              ),
            ],
          ),
        ),
      );
    }
    return showDialog<WorkspaceStudent>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('选择要导出的学科'),
        content: SizedBox(width: 420, child: choices(dialogContext)),
      ),
    );
  }

  Future<void> _exportStudentRecords(
    BuildContext context,
    TeacherWorkspace workspace,
    V2Student student,
  ) async {
    final repository = widget.runtime?.studentLearningRecordRepository;
    if (repository == null) {
      return;
    }
    final profiles = workspace.students
        .where((profile) => profile.id == student.id)
        .toList(growable: false);
    final profile = await _pickStudentSubjectProfile(context, profiles);
    if (profile == null || !context.mounted) {
      return;
    }
    if (profile.cases.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('当前学科没有可导出的有效学情。')),
      );
      return;
    }

    final selectedCaseIds = await showLearningRecordCasePicker(
      context,
      studentName: profile.name,
      subjectName: profile.subject,
      cases: profile.cases,
    );
    if (selectedCaseIds == null || !context.mounted) {
      return;
    }
    if (selectedCaseIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('没有选择要导出的学情。')),
      );
      return;
    }

    try {
      final records = await repository.listStudentSubjectRecords(
        profileId: profile.profileId,
      );
      final selectedRecords = records
          .where(
            (record) =>
                record.learningCaseId != null &&
                selectedCaseIds.contains(record.learningCaseId),
          )
          .toList(growable: false);
      if (!context.mounted) {
        return;
      }
      if (selectedRecords.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('所选学情目前没有可导出的记录，请刷新后重试。')),
        );
        return;
      }
      final rows = LearningRecordExport.rowsForStudentRecords(selectedRecords);
      final preparedRows =
          await LearningRecordExport.prepareRowsWithAttachmentImages(
            rows: rows,
            repository:
                widget.runtime?.evidenceAttachmentRepository ??
                widget.evidenceAttachmentRepository,
          );
      if (!context.mounted) {
        return;
      }
      final savedPath = await LearningRecordExport.saveAsXlsx(
        fileNameWithoutExtension: LearningRecordExport.studentSubjectFileName(
          profile,
        ),
        rows: preparedRows,
      );
      if (!context.mounted) {
        return;
      }
      if (savedPath == null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('已取消导出。')));
      } else {
        showLearningRecordExportSuccess(
          context,
          savedPath: savedPath,
          summary: '已导出 ${selectedCaseIds.length} 条学情',
        );
      }
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      final message =
          learningRecordImageExportErrorMessage(error) ??
          studentLearningRecordExportErrorMessage(error) ??
          '学情记录暂时无法读取，请检查网络后重试。';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _exportMyStudentRecords(
    BuildContext context,
    TeacherWorkspace workspace,
  ) async {
    final repository = widget.runtime?.studentLearningRecordRepository;
    if (repository == null) return;

    final profilesById = <String, WorkspaceStudent>{};
    for (final profile in workspace.students) {
      profilesById[profile.profileId] = profile;
    }
    final profiles = profilesById.values.toList(growable: false);
    if (profiles.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('当前没有可导出的任课学生。')));
      return;
    }

    try {
      final records = <StudentLearningRecord>[];
      const requestBatchSize = 4;
      for (var start = 0; start < profiles.length; start += requestBatchSize) {
        final end = (start + requestBatchSize).clamp(0, profiles.length);
        final batch = profiles.sublist(start, end);
        final batches = await Future.wait([
          for (final profile in batch)
            repository.listStudentSubjectRecords(profileId: profile.profileId),
        ]);
        for (final batchRecords in batches) {
          records.addAll(batchRecords);
        }
      }
      if (!context.mounted) return;
      if (records.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('我的任课学生目前还没有可导出的学情记录。')));
        return;
      }

      final rows = LearningRecordExport.rowsForStudentRecords(records);
      final preparedRows =
          await LearningRecordExport.prepareRowsWithAttachmentImages(
            rows: rows,
            repository:
                widget.runtime?.evidenceAttachmentRepository ??
                widget.evidenceAttachmentRepository,
          );
      final studentCount = profiles.map((profile) => profile.id).toSet().length;
      final savedPath = await LearningRecordExport.saveAsXlsx(
        fileNameWithoutExtension: LearningRecordExport.studentBatchFileName(
          studentCount: studentCount,
          profileCount: profiles.length,
        ),
        rows: preparedRows,
      );
      if (!context.mounted) return;
      if (savedPath == null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('已取消导出。')));
        return;
      }
      showLearningRecordExportSuccess(
        context,
        savedPath: savedPath,
        summary: '已导出 $studentCount 名任课学生的学情记录',
      );
    } catch (error) {
      if (!context.mounted) return;
      final message =
          learningRecordImageExportErrorMessage(error) ??
          studentLearningRecordExportErrorMessage(error) ??
          '学情记录暂时无法导出，请检查网络后重试。';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<TeacherWorkspace>(
      future: _workspaceFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData &&
            snapshot.connectionState != ConnectionState.done) {
          return const _V2LoaderStatus(
            icon: Icons.sync,
            title: '正在同步学情',
            message: '正在读取学生与学情记录。',
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
        final runtime = widget.runtime;
        final canOpenManagement =
            workspace.canManageOrganization &&
            workspace.organizationId != null &&
            runtime?.organizationManagementRepository != null;
        final WidgetBuilder? managementPageBuilder = canOpenManagement
            ? (_) => V2ManagementPage(
                workspace: workspace,
                runtime: runtime!,
                onChanged: () => unawaited(_softRefresh()),
              )
            : null;

        if (!workspace.hasTeachingAccess) {
          if (canOpenManagement) {
            return V2ManagementPage(
              workspace: workspace,
              runtime: runtime!,
              rootMode: true,
              onChanged: () => unawaited(_softRefresh()),
            );
          }
          return const _V2LoaderStatus(
            icon: Icons.person_off_outlined,
            title: '暂时没有任课学情',
            message: '当前账号暂时没有可查看的任课学生；获得任课关系后可在这里查看。',
          );
        }

        final snapshotData = V2ReadModelAdapter.fromWorkspace(workspace);
        final learningRepository =
            widget.runtime?.learningRepository ?? widget.learningRepository;
        final progressiveCaseRepository =
            widget.runtime?.progressiveCaseRepository ??
            widget.progressiveCaseRepository;
        final evidenceAttachmentRepository =
            widget.runtime?.evidenceAttachmentRepository ??
            widget.evidenceAttachmentRepository;
        final workflowController =
            learningRepository != null && progressiveCaseRepository != null
            ? V2WorkflowController(
                workspace: workspace,
                learningRepository: learningRepository,
                progressiveCaseRepository: progressiveCaseRepository,
                evidenceAttachmentRepository: evidenceAttachmentRepository,
                caseReopenDraftStore: widget.runtime?.caseReopenDraftStore,
                sessionUserId: widget.runtime?.sessionUserId,
              )
            : null;
        final composerDraftStore = runtime?.composerDraftStore;
        final sessionUserId = runtime?.sessionUserId;
        final composerDraftScopeKey =
            composerDraftStore != null && sessionUserId != null
            ? quickCaptureComposerScopeKey(
                sessionUserId: sessionUserId,
                organizationId: workspace.organizationId,
              )
            : null;
        return V2WorkspacePreview(
          data: snapshotData.workspaceData,
          composerDraftStore: composerDraftStore,
          composerDraftScopeKey: composerDraftScopeKey,
          workflowController: workflowController,
          evidenceAttachmentRepository: evidenceAttachmentRepository,
          onExportStudent: runtime?.studentLearningRecordRepository == null
              ? null
              : (context, student) =>
                    _exportStudentRecords(context, workspace, student),
          onExportMyStudents:
              runtime?.studentLearningRecordRepository != null &&
                  !workspace.canManageOrganization
              ? (context) => _exportMyStudentRecords(context, workspace)
              : null,
          managementPageBuilder: managementPageBuilder,
          updateService: runtime?.updateService,
          updateInstaller: runtime?.updateInstaller,
          appVersion: runtime?.appVersion,
          onSignOut: runtime?.onSignOut,
          onRefresh: _softRefresh,
          onWorkspaceChanged: workflowController == null
              ? null
              : () => unawaited(_softRefresh()),
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
                  Container(
                    width: 54,
                    height: 54,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainer,
                      shape: BoxShape.circle,
                    ),
                    child: icon == Icons.sync
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2.2),
                          )
                        : Icon(icon, size: 26, color: scheme.onSurfaceVariant),
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
