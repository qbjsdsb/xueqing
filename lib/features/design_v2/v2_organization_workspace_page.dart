import 'dart:async';

import 'package:flutter/material.dart';

import '../../cloud/learning_repository.dart';
import '../../cloud/responsibility_read_repository.dart';
import '../organization_management/presentation/organization_management_page.dart';
import '../teacher_workspace/presentation/teacher_workspace_page.dart';
import '../teacher_workspace/workspace_runtime.dart';
import 'v2_fixture.dart';
import 'v2_update_flow.dart';
import 'v2_workspace_data.dart';

enum _OrganizationSection { learning, management }

enum _OrganizationPageAction { checkUpdate, signOut }

/// Organization-scope workspace for owners/admins.
///
/// D1a is deliberately read-only on the learning side. Organization authority
/// may inspect the already-authorized workspace and see the current teaching
/// responsibility, but Quick Capture remains a separate D1b write boundary.
class V2OrganizationWorkspacePage extends StatefulWidget {
  const V2OrganizationWorkspacePage({
    required this.workspace,
    required this.workspaceData,
    required this.responsibility,
    required this.runtime,
    this.rootMode = false,
    this.onChanged,
    super.key,
  });

  final TeacherWorkspace workspace;
  final V2WorkspaceData workspaceData;
  final WorkspaceResponsibilityContext responsibility;
  final AuthenticatedWorkspaceRuntime runtime;
  final bool rootMode;
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

    return PopScope<void>(
      canPop: !handlesInternalBack,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || !handlesInternalBack) return;
        setState(() => _section = _OrganizationSection.learning);
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: !widget.rootMode,
          title: const Text('机构'),
          actions: [
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
  });

  final TeacherWorkspace workspace;
  final V2WorkspaceData data;
  final WorkspaceResponsibilityContext responsibility;

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

  List<V2FocusItem> _itemsForStudent(V2Student student) => [
    ...widget.data.focusItemsForStudent(student),
    ...widget.data.closedItemsForStudent(student),
  ];

  List<V2Student> get _visibleStudents {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return widget.data.students;
    final leadLabelByCase = _leadLabelByCaseId;
    return widget.data.students
        .where((student) {
          final items = _itemsForStudent(student);
          final haystack = <String>[
            student.name,
            student.grade,
            ...student.subjects,
            for (final item in items) ...[
              item.title,
              item.summary,
              item.nextStep,
              item.subject,
              leadLabelByCase[item.id] ?? '主责信息暂不可用',
            ],
          ].join(' ').toLowerCase();
          return haystack.contains(query);
        })
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final visibleStudents = _visibleStudents;
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
                        final items = _itemsForStudent(student);
                        return _OrganizationStudentRow(
                          student: student,
                          items: items,
                          leadLabelByCaseId: _leadLabelByCaseId,
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
  });

  final V2Student student;
  final List<V2FocusItem> items;
  final Map<String, String> leadLabelByCaseId;

  @override
  Widget build(BuildContext context) {
    final activeCount = items.where((item) => !item.closed).length;
    final subjectLabel = student.subjects.join('、');
    if (items.isEmpty) {
      return ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        title: Text(student.name),
        subtitle: Text('${student.grade} · $subjectLabel · 暂无学情记录'),
      );
    }

    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      childrenPadding: const EdgeInsets.only(bottom: 8),
      title: Text(student.name),
      subtitle: Text(
        '${student.grade} · $subjectLabel · '
        '${activeCount == 0 ? '暂无进行中问题' : '$activeCount 个进行中问题'}',
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
