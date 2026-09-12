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

enum _OrganizationLearningFilter {
  all,
  attention,
  pendingVerification,
  overdue,
  unassigned,
}

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
                        label: Text('学情'),
                      ),
                      ButtonSegment<_OrganizationSection>(
                        value: _OrganizationSection.management,
                        icon: Icon(Icons.admin_panel_settings_outlined),
                        label: Text('管理'),
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
  _OrganizationLearningFilter _filter = _OrganizationLearningFilter.all;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Map<String, String> get _caseOwnerLabelByCaseId {
    final result = <String, String>{};
    for (final profile in widget.workspace.students) {
      for (final learningCase in profile.cases) {
        // Existing Case responsibility is its persisted owner. The Profile Lead
        // is only the default responsibility source when a new Case is created;
        // a later Lead change must not silently rewrite historical/current Case
        // ownership in the supervision UI.
        final ownerMembershipId =
            widget.responsibility.caseOwnerMembershipIds[learningCase.id];
        result[learningCase.id] = ownerMembershipId == null
            ? '主责信息暂不可用'
            : widget.responsibility.displayNameForMembership(
                    ownerMembershipId,
                  ) ??
                  '主责老师';
      }
    }
    return result;
  }

  Map<String, String> get _collaborationLabelByCaseId {
    final result = <String, String>{};
    for (final profile in widget.workspace.students) {
      for (final learningCase in profile.cases) {
        final ownerMembershipId =
            widget.responsibility.caseOwnerMembershipIds[learningCase.id];
        if (ownerMembershipId == null) continue;

        // Timeline is newest-first. Only the latest attributable record decides
        // whether a collaboration cue is shown. Do not skip a newer owner action
        // just to surface an older supervisor action.
        for (final event in learningCase.timeline) {
          final responsibilityEventId = event.responsibilityEventId;
          if (responsibilityEventId == null) continue;
          if (!widget.responsibility.eventActorMembershipIds.containsKey(
            responsibilityEventId,
          )) {
            break;
          }
          final actorMembershipId = widget
              .responsibility
              .eventActorMembershipIds[responsibilityEventId];
          if (actorMembershipId == null ||
              actorMembershipId == ownerMembershipId) {
            break;
          }
          final actorLabel = widget.responsibility.displayNameForMembership(
            actorMembershipId,
          );
          if (actorLabel != null) {
            result[learningCase.id] = '最近记录：$actorLabel · 机构协作';
          }
          break;
        }
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
    final subjectContexts = <String, V2QuickCaptureSubjectContext>{};
    for (final subject in student.subjects) {
      final matchingProfiles = profiles
          .where((profile) => profile.subject == subject)
          .toList(growable: false);
      if (matchingProfiles.length != 1) {
        subjectContexts[subject] = const V2QuickCaptureSubjectContext(
          label: '主责信息暂不可用',
          helperText: '当前学科的责任关系无法安全确认，请刷新学情后再记录。',
          canSave: false,
        );
        continue;
      }
      final profile = matchingProfiles.single;
      final leadMembershipId = widget.responsibility.leadMembershipIdForProfile(
        profile.profileId,
      );
      if (leadMembershipId == null) {
        subjectContexts[subject] = const V2QuickCaptureSubjectContext(
          label: '尚未明确主责老师',
          helperText: '正式学情必须有人持续负责。请先在机构管理中设置主责老师。',
          canSave: false,
        );
        continue;
      }
      final leadLabel =
          widget.responsibility.displayNameForMembership(leadMembershipId) ??
          '主责老师';
      final currentTeacherSuffix =
          leadMembershipId == widget.responsibility.currentMembershipId
          ? '（你）'
          : '';
      subjectContexts[subject] = V2QuickCaptureSubjectContext(
        label: '教学主责：$leadLabel$currentTeacherSuffix',
        helperText: '你正在以机构视角记录，本次记录不会改变主责老师。',
      );
    }
    final hasLead = subjectContexts.values.any((context) => context.canSave);
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
      subjectContexts: subjectContexts,
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

  Map<String, List<WorkspaceStudent>> _profilesByStudentId() {
    final result = <String, List<WorkspaceStudent>>{};
    for (final profile in widget.workspace.students) {
      result.putIfAbsent(profile.id, () => <WorkspaceStudent>[]).add(profile);
    }
    return result;
  }

  String _leadLabelForProfile(WorkspaceStudent profile) {
    final membershipId = widget.responsibility.leadMembershipIdForProfile(
      profile.profileId,
    );
    if (membershipId == null) return '未设置主责';
    return widget.responsibility.displayNameForMembership(membershipId) ??
        '主责老师';
  }

  bool _hasUnassignedProfile(List<WorkspaceStudent> profiles) => profiles.any(
    (profile) =>
        widget.responsibility.leadMembershipIdForProfile(profile.profileId) ==
        null,
  );

  String _responsibilitySummary(List<WorkspaceStudent> profiles) {
    final assigned = <String>{};
    var hasUnassigned = false;
    for (final profile in profiles) {
      final lead = _leadLabelForProfile(profile);
      if (lead == '未设置主责') {
        hasUnassigned = true;
      } else {
        assigned.add(lead);
      }
    }

    final teacherSummary = switch (assigned.length) {
      0 => '未设置主责',
      1 => '${assigned.single}负责',
      _ => '${assigned.first}等 ${assigned.length} 位老师负责',
    };
    return hasUnassigned && assigned.isNotEmpty
        ? '$teacherSummary · 有学科未明确主责'
        : teacherSummary;
  }

  bool _isAttentionItem(V2FocusItem item) {
    if (item.closed) return false;
    return item.pendingVerification ||
        item.effectiveStatus == V2CaseStatus.pendingVerification ||
        item.actionTiming == V2ActionTiming.overdue ||
        item.actionTiming == V2ActionTiming.undated;
  }

  bool _matchesFilter(
    V2Student student, {
    required List<V2FocusItem> items,
    required List<WorkspaceStudent> profiles,
  }) {
    final activeItems = items.where((item) => !item.closed);
    return switch (_filter) {
      _OrganizationLearningFilter.all => true,
      _OrganizationLearningFilter.attention =>
        activeItems.any(_isAttentionItem) || _hasUnassignedProfile(profiles),
      _OrganizationLearningFilter.pendingVerification => activeItems.any(
        (item) =>
            item.pendingVerification ||
            item.effectiveStatus == V2CaseStatus.pendingVerification,
      ),
      _OrganizationLearningFilter.overdue => activeItems.any(
        (item) => item.actionTiming == V2ActionTiming.overdue,
      ),
      _OrganizationLearningFilter.unassigned => _hasUnassignedProfile(profiles),
    };
  }

  List<V2Student> _visibleStudents({
    required Map<String, List<V2FocusItem>> itemsByStudentId,
    required Map<String, List<WorkspaceStudent>> profilesByStudentId,
    required Map<String, String> caseOwnerLabelByCaseId,
  }) {
    final query = _query.trim().toLowerCase();
    return widget.data.students
        .where((student) {
          final items = itemsByStudentId[student.id] ?? const <V2FocusItem>[];
          final profiles =
              profilesByStudentId[student.id] ?? const <WorkspaceStudent>[];
          if (!_matchesFilter(student, items: items, profiles: profiles)) {
            return false;
          }
          if (query.isEmpty) return true;
          final haystack = <String>[
            student.name,
            student.grade,
            ...student.subjects,
            _responsibilitySummary(profiles),
            for (final profile in profiles) ...[
              profile.subject,
              _leadLabelForProfile(profile),
            ],
            for (final item in items) ...[
              item.title,
              item.summary,
              item.nextStep,
              item.subject,
              caseOwnerLabelByCaseId[item.id] ?? '主责信息暂不可用',
            ],
          ].join(' ').toLowerCase();
          return haystack.contains(query);
        })
        .toList(growable: false);
  }

  String _summaryText({
    required int activeCount,
    required int pendingCount,
    required int overdueCount,
    required int unassignedProfileCount,
  }) {
    final parts = <String>[
      '${widget.data.students.length} 名学生',
      '$activeCount 个问题正在跟进',
      if (pendingCount > 0) '$pendingCount 个待复检',
      if (overdueCount > 0) '$overdueCount 个已逾期',
      if (unassignedProfileCount > 0) '$unassignedProfileCount 个学科未明确主责',
    ];
    return parts.join(' · ');
  }

  String _filterLabel(_OrganizationLearningFilter filter) => switch (filter) {
    _OrganizationLearningFilter.all => '全部',
    _OrganizationLearningFilter.attention => '需关注',
    _OrganizationLearningFilter.pendingVerification => '待复检',
    _OrganizationLearningFilter.overdue => '已逾期',
    _OrganizationLearningFilter.unassigned => '未明确主责',
  };

  @override
  Widget build(BuildContext context) {
    // Build immutable lookup maps once per frame. This keeps the organization
    // view responsive without changing the underlying responsibility contract.
    final itemsByStudentId = _itemsByStudentId();
    final profilesByStudentId = _profilesByStudentId();
    final caseOwnerLabelByCaseId = _caseOwnerLabelByCaseId;
    final collaborationLabelByCaseId = _collaborationLabelByCaseId;
    final visibleStudents = _visibleStudents(
      itemsByStudentId: itemsByStudentId,
      profilesByStudentId: profilesByStudentId,
      caseOwnerLabelByCaseId: caseOwnerLabelByCaseId,
    );
    final activeItems = widget.data.focusItems.where((item) => !item.closed);
    final activeCaseCount = activeItems.length;
    final pendingCount = activeItems
        .where(
          (item) =>
              item.pendingVerification ||
              item.effectiveStatus == V2CaseStatus.pendingVerification,
        )
        .length;
    final overdueCount = activeItems
        .where((item) => item.actionTiming == V2ActionTiming.overdue)
        .length;
    final unassignedProfileCount = widget.workspace.students
        .where(
          (profile) =>
              widget.responsibility.leadMembershipIdForProfile(
                profile.profileId,
              ) ==
              null,
        )
        .length;
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
                Text(
                  _summaryText(
                    activeCount: activeCaseCount,
                    pendingCount: pendingCount,
                    overdueCount: overdueCount,
                    unassignedProfileCount: unassignedProfileCount,
                  ),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 5),
                Text(
                  '监督全机构学情与协作进度；机构操作不会自动改变教师主责。',
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
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final filter
                          in _OrganizationLearningFilter.values) ...[
                        ChoiceChip(
                          key: ValueKey<String>(
                            'v2-organization-filter-${filter.name}',
                          ),
                          label: Text(_filterLabel(filter)),
                          selected: _filter == filter,
                          onSelected: (_) => setState(() => _filter = filter),
                        ),
                        if (filter != _OrganizationLearningFilter.values.last)
                          const SizedBox(width: 8),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: visibleStudents.isEmpty
              ? Center(
                  child: Text(
                    _query.trim().isEmpty &&
                            _filter != _OrganizationLearningFilter.all
                        ? '当前没有符合这个关注条件的学生。'
                        : '没有找到匹配的机构学情。',
                  ),
                )
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
                        final profiles =
                            profilesByStudentId[student.id] ??
                            const <WorkspaceStudent>[];
                        return _OrganizationStudentRow(
                          student: student,
                          items: items,
                          profiles: profiles,
                          caseOwnerLabelByCaseId: caseOwnerLabelByCaseId,
                          collaborationLabelByCaseId:
                              collaborationLabelByCaseId,
                          responsibilitySummary: _responsibilitySummary(
                            profiles,
                          ),
                          leadLabelForProfile: _leadLabelForProfile,
                          compact: compact,
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
    required this.profiles,
    required this.caseOwnerLabelByCaseId,
    required this.collaborationLabelByCaseId,
    required this.responsibilitySummary,
    required this.leadLabelForProfile,
    required this.compact,
    required this.onQuickCapture,
  });

  final V2Student student;
  final List<V2FocusItem> items;
  final List<WorkspaceStudent> profiles;
  final Map<String, String> caseOwnerLabelByCaseId;
  final Map<String, String> collaborationLabelByCaseId;
  final String responsibilitySummary;
  final String Function(WorkspaceStudent profile) leadLabelForProfile;
  final bool compact;
  final VoidCallback onQuickCapture;

  Widget _recordButton() => compact
      ? IconButton(
          key: Key('v2-organization-quick-capture-${student.id}'),
          tooltip: '记录问题',
          onPressed: onQuickCapture,
          icon: const Icon(Icons.note_add_outlined),
        )
      : TextButton.icon(
          key: Key('v2-organization-quick-capture-${student.id}'),
          onPressed: onQuickCapture,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('记录问题'),
        );

  String _statusSummary(List<V2FocusItem> activeItems) {
    final pendingCount = activeItems
        .where(
          (item) =>
              item.pendingVerification ||
              item.effectiveStatus == V2CaseStatus.pendingVerification,
        )
        .length;
    final overdueCount = activeItems
        .where((item) => item.actionTiming == V2ActionTiming.overdue)
        .length;
    final parts = <String>[
      '${activeItems.length} 个跟进中',
      if (pendingCount > 0) '$pendingCount 个待复检',
      if (overdueCount > 0) '$overdueCount 个已逾期',
    ];
    return parts.join(' · ');
  }

  String _subjectResponsibilityPreview() {
    if (profiles.isEmpty) return responsibilitySummary;
    final rows = [
      for (final profile in profiles)
        '${profile.subject} · ${leadLabelForProfile(profile)}',
    ];
    if (rows.length <= 2) return rows.join('  /  ');
    return '${rows.take(2).join('  /  ')}  /  另 ${rows.length - 2} 门';
  }

  @override
  Widget build(BuildContext context) {
    final activeItems = items
        .where((item) => !item.closed)
        .toList(growable: false);
    final closedItems = items
        .where((item) => item.closed)
        .toList(growable: false);
    final subtitleStyle = Theme.of(context).textTheme.bodySmall;

    if (items.isEmpty) {
      return ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        title: Row(
          children: [
            Expanded(
              child: Text(
                student.name,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Text(student.grade, style: subtitleStyle),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Text('当前没有需要跟进的问题\n${_subjectResponsibilityPreview()}'),
        ),
        isThreeLine: true,
        trailing: _recordButton(),
      );
    }

    return ExpansionTile(
      controlAffinity: ListTileControlAffinity.leading,
      tilePadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
      childrenPadding: const EdgeInsets.only(bottom: 10),
      title: Row(
        children: [
          Expanded(
            child: Text(
              student.name,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          const SizedBox(width: 12),
          Text(student.grade, style: subtitleStyle),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 5),
        child: Text(
          activeItems.isEmpty
              ? '当前没有需要跟进的问题${closedItems.isEmpty ? '' : ' · ${closedItems.length} 个历史问题'}\n${_subjectResponsibilityPreview()}'
              : '${_statusSummary(activeItems)}\n${_subjectResponsibilityPreview()}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      trailing: _recordButton(),
      children: [
        for (final item in activeItems)
          _OrganizationCaseRow(
            item: item,
            ownerLabel: caseOwnerLabelByCaseId[item.id] ?? '主责信息暂不可用',
            collaborationLabel: collaborationLabelByCaseId[item.id],
          ),
        if (closedItems.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 12, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '历史问题 ${closedItems.length}',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          for (final item in closedItems)
            _OrganizationCaseRow(
              item: item,
              ownerLabel: caseOwnerLabelByCaseId[item.id] ?? '主责信息暂不可用',
              collaborationLabel: collaborationLabelByCaseId[item.id],
              historical: true,
            ),
        ],
      ],
    );
  }
}

class _OrganizationCaseRow extends StatelessWidget {
  const _OrganizationCaseRow({
    required this.item,
    required this.ownerLabel,
    this.collaborationLabel,
    this.historical = false,
  });

  final V2FocusItem item;
  final String ownerLabel;
  final String? collaborationLabel;
  final bool historical;

  @override
  Widget build(BuildContext context) {
    final detail = historical
        ? '${item.subject} · 已结束 · 主责：$ownerLabel'
        : '${item.subject} · ${_caseStatusLabel(item)} · 主责：$ownerLabel\n'
              '下一步：${item.nextStep} · ${item.dueLabel}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 4, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            dense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
            title: Text(item.title),
            subtitle: Text(
              detail,
              maxLines: historical ? 1 : 2,
              overflow: TextOverflow.ellipsis,
            ),
            isThreeLine: !historical,
          ),
          if (!historical && collaborationLabel != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 2),
              child: Text(
                collaborationLabel!,
                key: ValueKey<String>(
                  'v2-organization-collaboration-${item.id}',
                ),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
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
