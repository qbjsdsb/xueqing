import 'dart:async';

import 'package:flutter/material.dart';

import '../../cloud/composer_draft_store.dart';
import '../../cloud/evidence_attachment_repository.dart';
import '../../cloud/learning_repository.dart';
import '../../cloud/progressive_case_repository.dart';
import '../../cloud/responsibility_read_repository.dart';
import '../../cloud/student_learning_record_repository.dart';
import '../../export/learning_record_case_picker.dart';
import '../../export/learning_record_export.dart';
import '../../export/learning_record_export_feedback.dart';
import '../teacher_workspace/workspace_runtime.dart';
import 'v2_fixture.dart';
import 'v2_management_page.dart';
import 'v2_read_model_adapter.dart';
import 'v2_responsibility_projection.dart';
import 'v2_workflow_controller.dart';
import 'v2_workspace_data.dart';
import 'v2_workspace_preview.dart';

typedef V2WorkspaceLoad = Future<TeacherWorkspace> Function();

class V2WorkspaceLoader extends StatefulWidget {
  const V2WorkspaceLoader({
    required this.loadWorkspace,
    this.runtime,
    this.learningRepository,
    this.progressiveCaseRepository,
    this.evidenceAttachmentRepository,
    this.responsibilityReadRepository,
    super.key,
  });

  final V2WorkspaceLoad loadWorkspace;
  final AuthenticatedWorkspaceRuntime? runtime;
  final LearningRepository? learningRepository;
  final ProgressiveCaseRepository? progressiveCaseRepository;
  final EvidenceAttachmentRepository? evidenceAttachmentRepository;
  final ResponsibilityReadRepository? responsibilityReadRepository;

  @override
  State<V2WorkspaceLoader> createState() => _V2WorkspaceLoaderState();
}

class _V2LoadedWorkspace {
  const _V2LoadedWorkspace({
    required this.rawWorkspace,
    required this.personalProjection,
  });

  final TeacherWorkspace rawWorkspace;
  final V2PersonalWorkspaceProjection? personalProjection;

  TeacherWorkspace get personalWorkspace =>
      personalProjection?.workspace ?? rawWorkspace;

  bool get hasPersonalTeachingResponsibility =>
      personalProjection?.hasPersonalTeachingResponsibility ??
      rawWorkspace.hasTeachingAccess;

  V2ReadModelSnapshot get snapshot =>
      personalProjection?.snapshot ??
      V2ReadModelAdapter.fromWorkspace(rawWorkspace);

  V2WorkspaceData get workspaceData =>
      personalProjection?.workspaceData ?? snapshot.workspaceData;
}

class _V2WorkspaceLoaderState extends State<V2WorkspaceLoader> {
  late Future<_V2LoadedWorkspace> _workspaceFuture;

  @override
  void initState() {
    super.initState();
    _workspaceFuture = _loadWorkspace();
  }

  @override
  void didUpdateWidget(covariant V2WorkspaceLoader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.loadWorkspace != widget.loadWorkspace ||
        oldWidget.responsibilityReadRepository !=
            widget.responsibilityReadRepository) {
      _workspaceFuture = _loadWorkspace();
    }
  }

  Future<_V2LoadedWorkspace> _loadWorkspace() async {
    final workspace = await widget.loadWorkspace();
    final responsibilityRepository = widget.responsibilityReadRepository;
    final organizationId = workspace.organizationId;
    if (responsibilityRepository == null || organizationId == null) {
      return _V2LoadedWorkspace(
        rawWorkspace: workspace,
        personalProjection: null,
      );
    }

    final responsibility = await responsibilityRepository.loadContext(
      organizationId: organizationId,
    );
    return _V2LoadedWorkspace(
      rawWorkspace: workspace,
      personalProjection: V2ResponsibilityProjection.personal(
        workspace: workspace,
        responsibility: responsibility,
      ),
    );
  }

  void _retry() {
    final nextWorkspace = _loadWorkspace();
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
        final workspace = await _loadWorkspace();
        if (!mounted) return;
        setState(() {
          _workspaceFuture = Future<_V2LoadedWorkspace>.value(workspace);
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
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('当前学科没有可导出的有效学情。')));
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
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('没有选择要导出的学情。')));
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
      final exportedCaseIds = selectedRecords
          .map((record) => record.learningCaseId)
          .whereType<String>()
          .toSet();
      if (!context.mounted) {
        return;
      }
      if (selectedRecords.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('所选学情目前没有可导出的记录，请刷新后重试。')));
        return;
      }
      if (exportedCaseIds.length != selectedCaseIds.length ||
          !exportedCaseIds.containsAll(selectedCaseIds)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('部分所选学情刚刚发生变化，请刷新后重新选择导出。')),
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
          summary: '已导出 ${exportedCaseIds.length} 条学情',
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
    return FutureBuilder<_V2LoadedWorkspace>(
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

        final loaded = snapshot.requireData;
        final rawWorkspace = loaded.rawWorkspace;
        final personalWorkspace = loaded.personalWorkspace;
        final runtime = widget.runtime;
        final canOpenManagement =
            rawWorkspace.canManageOrganization &&
            rawWorkspace.organizationId != null &&
            runtime?.organizationManagementRepository != null;
        final WidgetBuilder? managementPageBuilder = canOpenManagement
            ? (_) => V2ManagementPage(
                workspace: rawWorkspace,
                runtime: runtime!,
                onChanged: () => unawaited(_softRefresh()),
              )
            : null;

        if (!loaded.hasPersonalTeachingResponsibility) {
          if (canOpenManagement) {
            return V2ManagementPage(
              workspace: rawWorkspace,
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

        final snapshotData = loaded.snapshot;
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
                workspace: personalWorkspace,
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
                organizationId: personalWorkspace.organizationId,
              )
            : null;
        return V2WorkspacePreview(
          data: loaded.workspaceData,
          composerDraftStore: composerDraftStore,
          composerDraftScopeKey: composerDraftScopeKey,
          workflowController: workflowController,
          evidenceAttachmentRepository: evidenceAttachmentRepository,
          onExportStudent: runtime?.studentLearningRecordRepository == null
              ? null
              : (context, student) =>
                    _exportStudentRecords(context, personalWorkspace, student),
          onExportMyStudents: runtime?.studentLearningRecordRepository != null
              ? (context) =>
                    _exportMyStudentRecords(context, personalWorkspace)
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
