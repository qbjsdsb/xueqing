import 'dart:async';

import 'package:flutter/material.dart';

import '../../cloud/composer_draft_store.dart';
import '../../cloud/learning_repository.dart';
import '../../cloud/responsibility_read_repository.dart';
import '../../cloud/responsibility_scoped_learning_repository.dart';
import '../organization_management/presentation/organization_management_page.dart';
import '../teacher_workspace/presentation/teacher_workspace_page.dart';
import '../teacher_workspace/workspace_runtime.dart';
import 'v2_composers.dart';
import 'v2_fixture.dart';
import 'v2_update_flow.dart';
import 'v2_workflow_controller.dart';
import 'v2_workspace_data.dart';

enum _OrganizationSection { learning, management }

enum _OrganizationPageAction { checkUpdate, signOut }

/// Organization-scope workspace for owners/admins.
///
/// Organization authority may supervise the already-authorized workspace and
/// record a new fact without taking over teaching responsibility. Organization
/// Quick Capture stays bound to the selected Profile's current active Lead.
class V2OrganizationWorkspacePage extends StatefulWidget {
  const V2OrganizationWorkspacePage({
    required this.workspace,
    required this.workspaceData,
    required this.responsibility,
    required this.runtime,
    this.rootMode = false,
    this.embedded = false,
    this.onBackFromRoot,
    this.onChanged,
    super.key,
  });

  final TeacherWorkspace workspace;
  final V2WorkspaceData workspaceData;
  final WorkspaceResponsibilityContext responsibility;
  final AuthenticatedWorkspaceRuntime runtime;
  final bool rootMode;
  final bool embedded;
  final VoidCallback? onBackFromRoot;

  /// Reloads the authorized workspace after an organization mutation and also
  /// provides the explicit manual refresh entry for supervisor workflows.
  final VoidCallback? onChanged;

  @override
  State<V2OrganizationWorkspacePage> createState() =>
      _V2OrganizationWorkspacePageState();
}

class _V2OrganizationWorkspacePageState
    extends State<V2OrganizationWorkspacePage> {
  final ScrollController _managementScrollController = ScrollController();
  _OrganizationSection _section = _OrganizationSection.learning;
  bool _checkingForUpdates = false;

  @override
  void dispose() {
    _managementScrollController.dispose();
    super.dispose();
  }

  V2WorkflowController? _organizationWorkflowController() {
    final progressiveRepository = widget.runtime.progressiveCaseRepository;
    final learningRepository = widget.runtime.learningRepository;
    if (progressiveRepository == null ||
        learningRepository is! OrganizationQuickCaptureRepository) {
      return null;
    }
    final organizationRepository =
        learningRepository as OrganizationQuickCaptureRepository;
    return V2WorkflowController(
      workspace: widget.workspace,
      learningRepository: widget.runtime.learningRepository,
      progressiveCaseRepository: progressiveRepository,
      evidenceAttachmentRepository: widget.runtime.evidenceAttachmentRepository,
      quickCaptureCommandHandler: (command) async {
        final leadMembershipId = widget.responsibility
            .leadMembershipIdForProfile(command.profileId);
        if (leadMembershipId == null) {
          throw const V2WorkflowSaveException(
            '这个学科还没有明确主责老师。先设置主责老师后再建立正式学情，避免问题无人跟进。',
            recordMayBeSaved: false,
          );
        }
        try {
          return await organizationRepository.quickCaptureForOrganization(
            command,
            expectedResponsibilityMembershipId: leadMembershipId,
          );
        } catch (error) {
          final detail = error.toString().toLowerCase();
          if (detail.contains('responsibility_conflict')) {
            throw V2WorkflowSaveException(
              '主责老师刚刚发生变化，请关闭当前窗口，刷新学情后再记录。',
              recordMayBeSaved: false,
              cause: error,
            );
          }
          if (detail.contains('case_responsibility_required')) {
            throw V2WorkflowSaveException(
              '这个学科还没有明确主责老师。先设置主责老师后再建立正式学情，避免问题无人跟进。',
              recordMayBeSaved: false,
              cause: error,
            );
          }
          rethrow;
        }
      },
    );
  }

  Future<void> _checkForUpdates() async {
    if (_checkingForUpdates) return;
    setState(() => _checkingForUpdates = true);
    try {
      await runV2UpdateFlow(
        context,
        service: widget.runtime.updateService,
        installer: widget.runtime.updateInstaller,
      );
    } finally {
      if (mounted) setState(() => _checkingForUpdates = false);
    }
  }

  Future<void> _openCaseTypes() async {
    final organizationId = widget.workspace.organizationId;
    if (organizationId == null || !widget.workspace.canManageCaseTypes) {
      return;
    }
    final manager = WorkspaceCaseTypeManager(
      organizationId: organizationId,
      caseTypes: widget.workspace.caseTypes,
      repository: widget.runtime.learningRepository,
      onChanged: () async {
        widget.onChanged?.call();
      },
    );
    if (MediaQuery.sizeOf(context).width < 720) {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        isDismissible: false,
        enableDrag: false,
        useSafeArea: true,
        builder: (_) => manager,
      );
    } else {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760, maxHeight: 720),
            child: manager,
          ),
        ),
      );
    }
  }

  Widget _managementContent() {
    final organizationId = widget.workspace.organizationId;
    final repository = widget.runtime.organizationManagementRepository;
    if (organizationId == null || repository == null) {
      return const Center(child: Text('当前账号没有可用的机构管理权限。'));
    }

    return OrganizationManagementPage(
      repository: repository,
      provisioningRepository: widget.runtime.memberProvisioningRepository,
      evidenceAttachmentRepository: widget.runtime.evidenceAttachmentRepository,
      teacherLearningRecordRepository:
          widget.runtime.teacherLearningRecordRepository,
      studentLearningRecordRepository:
          widget.runtime.studentLearningRecordRepository,
      organizationId: organizationId,
      organizationName: widget.workspace.organizationName,
      roles: widget.workspace.roles,
      canManageCaseTypes: widget.workspace.canManageCaseTypes,
      onOpenCaseTypes: widget.workspace.canManageCaseTypes
          ? () => _openCaseTypes()
          : null,
      onChanged: widget.onChanged,
      showHeaderTitle: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 720;
    final canSignOut = widget.rootMode && widget.runtime.onSignOut != null;
    final handlesInternalBack = _section != _OrganizationSection.learning;
    final interceptsBack = handlesInternalBack || widget.embedded;

    return PopScope<void>(
      canPop: !interceptsBack,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (handlesInternalBack) {
          setState(() => _section = _OrganizationSection.learning);
          return;
        }
        if (widget.embedded) {
          widget.onBackFromRoot?.call();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: !widget.rootMode && !widget.embedded,
          title: const Text('机构'),
          actions: [
            if (widget.onChanged != null)
              IconButton(
                key: const Key('v2-organization-refresh'),
                tooltip: '刷新学情',
                onPressed: widget.onChanged,
                icon: const Icon(Icons.refresh_outlined),
              ),
            if (!compact) ...[
              if (_checkingForUpdates)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              else
                IconButton(
                  tooltip: '检查更新',
                  onPressed: _checkForUpdates,
                  icon: const Icon(Icons.system_update_alt_outlined),
                ),
              if (canSignOut)
                IconButton(
                  tooltip: '退出登录',
                  onPressed: widget.runtime.onSignOut,
                  icon: const Icon(Icons.logout_outlined),
                ),
            ] else
              PopupMenuButton<_OrganizationPageAction>(
                key: const Key('v2-organization-more'),
                tooltip: '更多操作',
                onSelected: (action) {
                  switch (action) {
                    case _OrganizationPageAction.checkUpdate:
                      unawaited(_checkForUpdates());
                    case _OrganizationPageAction.signOut:
                      widget.runtime.onSignOut?.call();
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem<_OrganizationPageAction>(
                    value: _OrganizationPageAction.checkUpdate,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.system_update_alt_outlined),
                      title: const Text('检查更新'),
                      subtitle: Text('当前版本 ${widget.runtime.appVersion}'),
                    ),
                  ),
                  if (canSignOut)
                    const PopupMenuItem<_OrganizationPageAction>(
                      value: _OrganizationPageAction.signOut,
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.logout_outlined),
                        title: Text('退出登录'),
                      ),
                    ),
                ],
              ),
            const SizedBox(width: 6),
          ],
        ),
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  compact ? 16 : 24,
                  12,
                  compact ? 16 : 24,
                  10,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: SegmentedButton<_OrganizationSection>(
                    key: const Key('v2-organization-section-switch'),
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment<_OrganizationSection>(
                        value: _OrganizationSection.learning,
                        icon: Icon(Icons.fact_check_outlined),
                        label: Text('机构学情'),
                      ),
                      ButtonSegment<_OrganizationSection>(
                        value: _OrganizationSection.management,
                        icon: Icon(Icons.admin_panel_settings_outlined),
                        label: Text('机构管理'),
                      ),
                    ],
                    selected: {_section},
                    onSelectionChanged: (selection) {
                      setState(() => _section = selection.single);
                    },
                  ),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: _section == _OrganizationSection.learning
                    ? _OrganizationLearningView(
                        workspace: widget.workspace,
                        data: widget.workspaceData,
                        responsibility: widget.responsibility,
                        workflowController: _organizationWorkflowController(),
                        composerDraftStore: widget.runtime.composerDraftStore,
                        composerDraftScopeKey:
                            widget.runtime.composerDraftStore != null &&
                                widget.runtime.sessionUserId != null
                            ? '${quickCaptureComposerScopeKey(sessionUserId: widget.runtime.sessionUserId!, organizationId: widget.workspace.organizationId)}:organization'
                            : null,
                        onChanged: widget.onChanged,
                      )
                    : Scrollbar(
                        controller: _managementScrollController,
                        thumbVisibility: !compact,
                        interactive: !compact,
                        child: SingleChildScrollView(
                          controller: _managementScrollController,
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          child: !compact
                              ? SelectionArea(child: _managementContent())
                              : _managementContent(),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrganizationLearningView extends StatefulWidget {
  const _OrganizationLearningView({
    required this.workspace,
    required this.data,
    required this.responsibility,
    required this.workflowController,
    required this.composerDraftStore,
    required this.composerDraftScopeKey,
    required this.onChanged,
  });

  final TeacherWorkspace workspace;
  final V2WorkspaceData data;
  final WorkspaceResponsibilityContext responsibility;
  final V2WorkflowController? workflowController;
  final ComposerDraftStore? composerDraftStore;
  final String? composerDraftScopeKey;
  final VoidCallback? onChanged;

  @override
  State<_OrganizationLearningView> createState() =>
      _OrganizationLearningViewState();
}

class _OrganizationLearningViewState extends State<_OrganizationLearningView> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Map<String, String> get _leadLabelByCaseId {
    final result = <String, String>{};
    for (final profile in widget.workspace.students) {
      final leadMembershipId = widget.responsibility.leadMembershipIdForProfile(
        profile.profileId,
      );
      final leadLabel = leadMembershipId == null
          ? '未设置主责'
          : widget.responsibility.displayNameForMembership(leadMembershipId) ??
                '主责老师';
      for (final learningCase in profile.cases) {
        result[learningCase.id] = leadLabel;
      }
    }
    return result;
  }

  Future<void> _openQuickCapture(
    BuildContext context,
    V2Student student,
  ) async {
    final controller = widget.workflowController;
    if (controller == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('当前版本暂时不能安全记录机构学情，请刷新或更新后再试。')),
      );
      return;
    }
    final profiles = widget.workspace.students
        .where((profile) => profile.id == student.id)
        .toList(growable: false);
    if (profiles.isEmpty) return;
    final hasLead = profiles.any(
      (profile) =>
          widget.responsibility.leadMembershipIdForProfile(profile.profileId) !=
          null,
    );
    if (!hasLead) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('这个学生当前学科还没有明确主责老师。先设置主责老师后再建立正式学情，避免问题无人跟进。'),
        ),
      );
      return;
    }

    final draftStore = widget.composerDraftStore;
    final draftScopeKey = widget.composerDraftScopeKey;
    ComposerDraftSnapshot? initialDraft;
    if (draftStore != null && draftScopeKey != null) {
      final stored = await draftStore.load(draftScopeKey);
      if (stored?.studentId == student.id) initialDraft = stored;
    }
    if (!context.mounted) return;
    final storedOperationId = initialDraft?.state['operation_id'];
    final operationId =
        storedOperationId is String && storedOperationId.trim().isNotEmpty
        ? storedOperationId
        : createOperationId();
    final persistence = draftStore != null && draftScopeKey != null
        ? V2QuickCapturePersistence(
            store: draftStore,
            scopeKey: draftScopeKey,
            studentId: student.id,
            operationId: operationId,
            initialDraft: initialDraft,
          )
        : null;
    final activeItems = widget.data.focusItemsForStudent(student);
    final existingCases = activeItems
        .map(
          (item) => V2ExistingCaseOption(
            id: item.id,
            title: item.title,
            subject: item.subject,
            statusLabel: _caseStatusLabel(item),
            nextStepLabel: item.nextStep,
            dueLabel: item.dueLabel,
          ),
        )
        .toList(growable: false);
    final problemTypes = controller.caseTypeChoices
        .map(
          (choice) => V2ProblemTypeOption(key: choice.key, label: choice.label),
        )
        .toList(growable: false);
    final saved = await showV2QuickCapture(
      context,
      studentName: student.name,
      subjects: student.subjects,
      problemTypes: problemTypes,
      existingCases: existingCases,
      persistence: persistence,
      onSave: (draft) => controller.quickCapture(
        V2QuickCaptureWrite(
          operationId: operationId,
          studentId: student.id,
          subject: draft.subject,
          caseTypeKey: draft.caseTypeKey,
          body: draft.body,
          attachments: draft.attachments,
        ),
      ),
    );
    if (saved && context.mounted) {
      widget.onChanged?.call();
    }
  }

  Map<String, List<V2FocusItem>> _itemsByStudentId() {
    final result = <String, List<V2FocusItem>>{};
    for (final item in widget.data.focusItems) {
      result.putIfAbsent(item.studentId, () => <V2FocusItem>[]).add(item);
    }
    for (final item in widget.data.closedItems) {
      result.putIfAbsent(item.studentId, () => <V2FocusItem>[]).add(item);
    }
    return result;
  }

  Map<String, String> _responsibilitySummaryByStudentId() {
    final labelsByStudentId = <String, List<String>>{};
    for (final profile in widget.workspace.students) {
      final leadMembershipId = widget.responsibility.leadMembershipIdForProfile(
        profile.profileId,
      );
      final leadName = leadMembershipId == null
          ? '未设置主责'
          : widget.responsibility.displayNameForMembership(leadMembershipId) ??
                '主责老师';
      labelsByStudentId
          .putIfAbsent(profile.id, () => <String>[])
          .add('${profile.subject} $leadName');
    }
    return <String, String>{
      for (final entry in labelsByStudentId.entries)
        entry.key: entry.value.join(' · '),
    };
  }

  List<V2Student> _visibleStudents({
    required Map<String, List<V2FocusItem>> itemsByStudentId,
    required Map<String, String> responsibilitySummaryByStudentId,
    required Map<String, String> leadLabelByCaseId,
  }) {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return widget.data.students;
    return widget.data.students
        .where((student) {
          final items = itemsByStudentId[student.id] ?? const <V2FocusItem>[];
          final haystack = <String>[
            student.name,
            student.grade,
            ...student.subjects,
            responsibilitySummaryByStudentId[student.id] ?? '主责信息暂不可用',
            for (final item in items) ...[
              item.title,
              item.summary,
              item.nextStep,
              item.subject,
              leadLabelByCaseId[item.id] ?? '主责信息暂不可用',
            ],
          ].join(' ').toLowerCase();
          return haystack.contains(query);
        })
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    // Build immutable lookup maps once per frame. Previously each visible row
    // rescanned every profile/case to derive the same labels and item lists.
    final itemsByStudentId = _itemsByStudentId();
    final responsibilitySummaryByStudentId =
        _responsibilitySummaryByStudentId();
    final leadLabelByCaseId = _leadLabelByCaseId;
    final visibleStudents = _visibleStudents(
      itemsByStudentId: itemsByStudentId,
      responsibilitySummaryByStudentId: responsibilitySummaryByStudentId,
      leadLabelByCaseId: leadLabelByCaseId,
    );
    final activeCaseCount = widget.data.focusItems.length;
    final compact = MediaQuery.sizeOf(context).width < 720;
    final horizontalPadding = compact ? 16.0 : 24.0;

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            18,
            horizontalPadding,
            12,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('机构学情', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 4),
                Text(
                  '${widget.data.students.length} 名学生 · '
                  '$activeCaseCount 个正在跟进的问题。这里用于监督与协作，不改变教师主责。',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  key: const Key('v2-organization-learning-search'),
                  controller: _searchController,
                  onChanged: (value) => setState(() => _query = value),
                  decoration: InputDecoration(
                    hintText: '搜索学生、学科、问题或负责老师…',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: '清除搜索',
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                            icon: const Icon(Icons.close, size: 19),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: visibleStudents.isEmpty
              ? const Center(child: Text('没有找到匹配的机构学情。'))
              : Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1100),
                    child: ListView.separated(
                      padding: EdgeInsets.fromLTRB(
                        horizontalPadding,
                        0,
                        horizontalPadding,
                        28,
                      ),
                      itemCount: visibleStudents.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final student = visibleStudents[index];
                        final items =
                            itemsByStudentId[student.id] ??
                            const <V2FocusItem>[];
                        return _OrganizationStudentRow(
                          student: student,
                          items: items,
                          leadLabelByCaseId: leadLabelByCaseId,
                          responsibilitySummary:
                              responsibilitySummaryByStudentId[student.id] ??
                              '主责信息暂不可用',
                          onQuickCapture: () =>
                              _openQuickCapture(context, student),
                        );
                      },
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

class _OrganizationStudentRow extends StatelessWidget {
  const _OrganizationStudentRow({
    required this.student,
    required this.items,
    required this.leadLabelByCaseId,
    required this.responsibilitySummary,
    required this.onQuickCapture,
  });

  final V2Student student;
  final List<V2FocusItem> items;
  final Map<String, String> leadLabelByCaseId;
  final String responsibilitySummary;
  final VoidCallback onQuickCapture;

  @override
  Widget build(BuildContext context) {
    final activeCount = items.where((item) => !item.closed).length;
    final subjectLabel = student.subjects.join('、');
    if (items.isEmpty) {
      return ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        title: Text(student.name),
        subtitle: Text(
          '${student.grade} · $subjectLabel · 暂无学情记录 · 主责：$responsibilitySummary',
        ),
        isThreeLine: true,
        trailing: IconButton(
          key: Key('v2-organization-quick-capture-${student.id}'),
          tooltip: '记录问题',
          onPressed: onQuickCapture,
          icon: const Icon(Icons.note_add_outlined),
        ),
      );
    }

    return ExpansionTile(
      controlAffinity: ListTileControlAffinity.leading,
      tilePadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      childrenPadding: const EdgeInsets.only(bottom: 8),
      title: Text(student.name),
      subtitle: Text(
        '${student.grade} · $subjectLabel · '
        '${activeCount == 0 ? '暂无进行中问题' : '$activeCount 个进行中问题'} · 主责：$responsibilitySummary',
      ),
      trailing: IconButton(
        key: Key('v2-organization-quick-capture-${student.id}'),
        tooltip: '记录问题',
        onPressed: onQuickCapture,
        icon: const Icon(Icons.note_add_outlined),
      ),
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 2, 4, 8),
            child: ListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              title: Text(item.title),
              subtitle: Text(
                '${item.subject} · ${_caseStatusLabel(item)} · '
                '当前负责：${leadLabelByCaseId[item.id] ?? '主责信息暂不可用'}\n'
                '${item.closed ? '该问题已结束' : '下一步：${item.nextStep} · ${item.dueLabel}'}',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              isThreeLine: true,
            ),
          ),
      ],
    );
  }
}

String _caseStatusLabel(V2FocusItem item) => switch (item.effectiveStatus) {
  V2CaseStatus.newCase => '新记录',
  V2CaseStatus.confirmed => '已确认',
  V2CaseStatus.intervening => '跟进中',
  V2CaseStatus.pendingVerification => '待复检',
  V2CaseStatus.stable => '暂时稳定',
  V2CaseStatus.closed => '已结束',
};
