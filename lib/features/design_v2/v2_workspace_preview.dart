import 'package:flutter/material.dart';

import '../../update/update_installer.dart';
import '../../update/update_service.dart';

import '../../cloud/evidence_attachment_repository.dart';
import '../../cloud/learning_repository.dart';
import '../../cloud/progressive_case_repository.dart';
import 'v2_action_composers.dart';
import 'v2_reopen_composer.dart';
import 'v2_composers.dart';
import 'v2_fixture.dart';
import 'v2_update_flow.dart';
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
              (choice) =>
                  V2ProblemTypeOption(key: choice.key, label: choice.label),
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

Future<void> _showV2CompleteCurrentAction(
  BuildContext context,
  V2Student student,
  V2FocusItem item,
) async {
  final runtime = _V2RuntimeScope.maybeOf(context);
  final controller = runtime?.workflowController;
  final action = controller?.pendingActionFor(item.id);
  if (controller == null || action == null || !action.canComplete) {
    return;
  }
  final operationId = createOperationId();
  final saved = await showV2CompleteActionComposer(
    context,
    actionTitle: action.title,
    onSave: () => controller.completeCurrentAction(
      operationId: operationId,
      caseId: item.id,
    ),
  );
  if (saved && context.mounted) {
    runtime?.onWorkspaceChanged?.call();
  }
}

Future<void> _showV2RescheduleCurrentAction(
  BuildContext context,
  V2Student student,
  V2FocusItem item,
) async {
  final runtime = _V2RuntimeScope.maybeOf(context);
  final controller = runtime?.workflowController;
  final action = controller?.pendingActionFor(item.id);
  if (controller == null || action == null) {
    return;
  }
  final operationId = createOperationId();
  final saved = await showV2RescheduleActionComposer(
    context,
    actionTitle: action.title,
    businessDate: controller.businessDate,
    initialDueOn: action.dueOn,
    onSave: (dueOn) => controller.rescheduleCurrentAction(
      operationId: operationId,
      caseId: item.id,
      dueOn: dueOn,
    ),
  );
  if (saved && context.mounted) {
    runtime?.onWorkspaceChanged?.call();
  }
}

Future<void> _showV2ReopenClosedCase(
  BuildContext context,
  V2Student student,
  V2FocusItem item,
) async {
  final runtime = _V2RuntimeScope.maybeOf(context);
  final controller = runtime?.workflowController;
  if (controller == null || !controller.canReopenClosedCase(item.id)) {
    return;
  }

  V2ReopenDraftSnapshot? pendingDraft;
  try {
    pendingDraft = await controller.loadPendingReopen(item.id);
  } catch (error) {
    if (!context.mounted) return;
    final message = error is V2WorkflowSaveException
        ? error.userMessage
        : '上次未完成的重新跟进暂时无法恢复，请重试。';
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
    return;
  }
  if (!context.mounted) return;

  final saved = await showV2ReopenCaseComposer(
    context,
    studentName: student.name,
    subject: item.subject,
    caseTitle: item.title,
    businessDate: controller.businessDate,
    pendingDraft: pendingDraft,
    onSave: (draft) => controller.reopenClosedCase(
      V2ReopenWrite(
        caseId: item.id,
        recurrenceSummary: draft.recurrenceSummary,
        nextActionTitle: draft.nextActionTitle,
        nextActionDueOn: draft.nextActionDueOn,
      ),
    ),
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

class V2WorkspacePreview extends StatefulWidget {
  const V2WorkspacePreview({
    super.key,
    this.data = v2FixtureWorkspaceData,
    this.workflowController,
    this.evidenceAttachmentRepository,
    this.managementPageBuilder,
    this.updateService,
    this.updateInstaller,
    this.appVersion,
    this.onSignOut,
    this.onWorkspaceChanged,
  });

  final V2WorkspaceData data;
  final V2WorkflowController? workflowController;
  final EvidenceAttachmentRepository? evidenceAttachmentRepository;
  final WidgetBuilder? managementPageBuilder;
  final UpdateService? updateService;
  final UpdateInstaller? updateInstaller;
  final String? appVersion;
  final VoidCallback? onSignOut;
  final VoidCallback? onWorkspaceChanged;

  @override
  State<V2WorkspacePreview> createState() => _V2WorkspacePreviewState();
}

class _V2WorkspacePreviewState extends State<V2WorkspacePreview> {
  int _destination = 1;
  V2Student? _selectedStudent;
  V2FocusItem? _selectedCase;
  bool _showCase = false;
  bool _checkingForUpdates = false;

  @override
  void initState() {
    super.initState();
    _reconcileSelection();
  }

  @override
  void didUpdateWidget(covariant V2WorkspacePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.data, widget.data)) {
      _reconcileSelection();
    }
  }

  void _reconcileSelection() {
    final students = widget.data.students;
    if (students.isEmpty) {
      _selectedStudent = null;
      _selectedCase = null;
      _showCase = false;
      return;
    }

    final currentStudentId = _selectedStudent?.id;
    _selectedStudent = students.firstWhere(
      (student) => student.id == currentStudentId,
      orElse: () => students.first,
    );

    final currentCaseId = _selectedCase?.id;
    if (currentCaseId == null) {
      return;
    }
    final matchingCases = widget.data.focusItems
        .where((item) => item.id == currentCaseId)
        .toList(growable: false);
    if (matchingCases.isEmpty ||
        matchingCases.first.studentId != _selectedStudent!.id) {
      _selectedCase = null;
      _showCase = false;
    } else {
      _selectedCase = matchingCases.first;
    }
  }

  void _openStudent(V2Student student) {
    setState(() {
      _selectedStudent = student;
      _selectedCase = null;
      _showCase = false;
    });
  }

  void _openCase(V2FocusItem item) {
    final student = widget.data.studentForFocusItemOrNull(item);
    if (student == null) {
      return;
    }
    setState(() {
      _destination = 1;
      _selectedStudent = student;
      _selectedCase = item;
      _showCase = true;
    });
  }

  void _closeCase() => setState(() => _showCase = false);

  void _changeDestination(int value) {
    setState(() {
      _destination = value;
      _showCase = false;
    });
  }

  Future<void> _openManagement(BuildContext context) async {
    final builder = widget.managementPageBuilder;
    if (builder == null) return;
    await Navigator.of(context)
        .push<void>(MaterialPageRoute<void>(builder: builder));
  }

  Future<void> _checkForUpdates(BuildContext context) async {
    final service = widget.updateService;
    final installer = widget.updateInstaller;
    if (service == null || installer == null || _checkingForUpdates) return;
    setState(() => _checkingForUpdates = true);
    try {
      await runV2UpdateFlow(context, service: service, installer: installer);
    } finally {
      if (mounted) setState(() => _checkingForUpdates = false);
    }
  }

  void _afterMenuClose(BuildContext menuContext, VoidCallback action) {
    Navigator.of(menuContext).pop();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) action();
    });
  }

  Future<void> _showWorkspaceMenu(BuildContext context) async {
    Widget menu(BuildContext menuContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.managementPageBuilder != null)
              ListTile(
                leading: const Icon(Icons.admin_panel_settings_outlined),
                title: const Text('机构管理'),
                subtitle: const Text('成员、学生、学科与记录导出'),
                onTap: () => _afterMenuClose(
                  menuContext,
                  () => _openManagement(context),
                ),
              ),
            ListTile(
              leading: _checkingForUpdates
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.system_update_alt_outlined),
              title: const Text('检查更新'),
              subtitle: widget.appVersion == null
                  ? null
                  : Text('当前版本 ${widget.appVersion}'),
              onTap:
                  _checkingForUpdates ||
                      widget.updateService == null ||
                      widget.updateInstaller == null
                  ? null
                  : () => _afterMenuClose(
                      menuContext,
                      () => _checkForUpdates(context),
                    ),
            ),
            if (widget.onSignOut != null)
              ListTile(
                leading: const Icon(Icons.logout_outlined),
                title: const Text('退出登录'),
                onTap: () => _afterMenuClose(menuContext, widget.onSignOut!),
              ),
          ],
        ),
      ),
    );

    if (MediaQuery.sizeOf(context).width < 720) {
      await showModalBottomSheet<void>(
        context: context,
        useSafeArea: true,
        showDragHandle: true,
        builder: menu,
      );
    } else {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('设置'),
          content: SizedBox(width: 390, child: menu(dialogContext)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return _V2RuntimeScope(
      workflowController: widget.workflowController,
      evidenceAttachmentRepository: widget.evidenceAttachmentRepository,
      onWorkspaceChanged: widget.onWorkspaceChanged,
      child: V2WorkspaceDataScope(
        data: widget.data,
        child: Builder(
          builder: (context) {
            if (widget.data.students.isEmpty) {
              return const _EmptyWorkspacePreview();
            }
            final selectedStudent =
                _selectedStudent ?? widget.data.students.first;
            return LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 720) {
                  return _CompactWorkspace(
                    destination: _destination,
                    selectedStudent: selectedStudent,
                    selectedCase: _selectedCase,
                    showCase: _showCase,
                    onDestinationChanged: _changeDestination,
                    onStudentSelected: _openStudent,
                    onOpenCase: _openCase,
                    onBackFromCase: _closeCase,
                    onOpenMore: () => _showWorkspaceMenu(context),
                  );
                }
                return _DesktopWorkspace(
                  destination: _destination,
                  selectedStudent: selectedStudent,
                  selectedCase: _selectedCase,
                  showCase: _showCase,
                  onDestinationChanged: _changeDestination,
                  onStudentSelected: _openStudent,
                  onOpenCase: _openCase,
                  onBackFromCase: _closeCase,
                  onManage: widget.managementPageBuilder == null
                      ? null
                      : () => _openManagement(context),
                  onSettings: () => _showWorkspaceMenu(context),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _DesktopWorkspace extends StatelessWidget {
  const _DesktopWorkspace({
    required this.destination,
    required this.selectedStudent,
    required this.selectedCase,
    required this.showCase,
    required this.onDestinationChanged,
    required this.onStudentSelected,
    required this.onOpenCase,
    required this.onBackFromCase,
    required this.onSettings,
    this.onManage,
  });

  final int destination;
  final V2Student selectedStudent;
  final V2FocusItem? selectedCase;
  final bool showCase;
  final ValueChanged<int> onDestinationChanged;
  final ValueChanged<V2Student> onStudentSelected;
  final ValueChanged<V2FocusItem> onOpenCase;
  final VoidCallback onBackFromCase;
  final VoidCallback? onManage;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final border = Theme.of(context).colorScheme.outlineVariant;
    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            SizedBox(
              width: 72,
              child: _NavigationRail(
                selectedIndex: destination,
                onSelected: onDestinationChanged,
                onManage: onManage,
                onSettings: onSettings,
              ),
            ),
            VerticalDivider(width: 1, color: border),
            if (destination == 1) ...[
              SizedBox(
                width: 336,
                child: _StudentListPane(
                  selectedStudent: selectedStudent,
                  onSelected: onStudentSelected,
                ),
              ),
              VerticalDivider(width: 1, color: border),
              Expanded(
                child: showCase && selectedCase != null
                    ? _CaseDetailPane(
                        student: selectedStudent,
                        item: selectedCase!,
                        onBack: onBackFromCase,
                      )
                    : _StudentDetailPane(
                        student: selectedStudent,
                        onOpenCase: onOpenCase,
                      ),
              ),
            ] else if (destination == 0) ...[
              Expanded(child: _TodayPane(onOpenCase: onOpenCase)),
            ] else ...[
              Expanded(child: _CaseIndexPane(onOpenCase: onOpenCase)),
            ],
          ],
        ),
      ),
    );
  }
}

class _CompactWorkspace extends StatefulWidget {
  const _CompactWorkspace({
    required this.destination,
    required this.selectedStudent,
    required this.selectedCase,
    required this.showCase,
    required this.onDestinationChanged,
    required this.onStudentSelected,
    required this.onOpenCase,
    required this.onBackFromCase,
    required this.onOpenMore,
  });

  final int destination;
  final V2Student selectedStudent;
  final V2FocusItem? selectedCase;
  final bool showCase;
  final ValueChanged<int> onDestinationChanged;
  final ValueChanged<V2Student> onStudentSelected;
  final ValueChanged<V2FocusItem> onOpenCase;
  final VoidCallback onBackFromCase;
  final VoidCallback onOpenMore;

  @override
  State<_CompactWorkspace> createState() => _CompactWorkspaceState();
}

class _CompactWorkspaceState extends State<_CompactWorkspace> {
  bool _studentOpen = false;

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (widget.showCase && widget.selectedCase != null) {
      body = _CaseDetailPane(
        student: widget.selectedStudent,
        item: widget.selectedCase!,
        onBack: widget.onBackFromCase,
        compact: true,
      );
    } else if (widget.destination == 1 && _studentOpen) {
      body = _StudentDetailPane(
        student: widget.selectedStudent,
        onOpenCase: widget.onOpenCase,
        compact: true,
        onBack: () => setState(() => _studentOpen = false),
      );
    } else if (widget.destination == 1) {
      body = _StudentListPane(
        selectedStudent: widget.selectedStudent,
        compact: true,
        onSelected: (student) {
          widget.onStudentSelected(student);
          setState(() => _studentOpen = true);
        },
      );
    } else if (widget.destination == 0) {
      body = _TodayPane(onOpenCase: widget.onOpenCase, compact: true);
    } else {
      body = _CaseIndexPane(onOpenCase: widget.onOpenCase, compact: true);
    }

    return Scaffold(
      body: SafeArea(child: body),
      bottomNavigationBar: widget.showCase || _studentOpen
          ? null
          : NavigationBar(
              selectedIndex: widget.destination,
              onDestinationSelected: (value) {
                if (value == 3) {
                  widget.onOpenMore();
                  return;
                }
                setState(() => _studentOpen = false);
                widget.onDestinationChanged(value);
              },
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.today_outlined),
                  selectedIcon: Icon(Icons.today),
                  label: '今日',
                ),
                NavigationDestination(
                  icon: Icon(Icons.people_outline),
                  selectedIcon: Icon(Icons.people),
                  label: '学生',
                ),
                NavigationDestination(
                  icon: Icon(Icons.fact_check_outlined),
                  selectedIcon: Icon(Icons.fact_check),
                  label: '学情',
                ),
                NavigationDestination(
                  icon: Icon(Icons.more_horiz),
                  label: '更多',
                ),
              ],
            ),
    );
  }
}

class _NavigationRail extends StatelessWidget {
  const _NavigationRail({
    required this.selectedIndex,
    required this.onSelected,
    required this.onSettings,
    this.onManage,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final VoidCallback? onManage;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: scheme.surfaceContainerLowest,
      child: Column(
        children: [
          const SizedBox(height: 18),
          Icon(Icons.eco_outlined, color: scheme.primary, size: 27),
          const SizedBox(height: 22),
          for (final item in const [
            (Icons.today_outlined, '今日'),
            (Icons.people_outline, '学生'),
            (Icons.fact_check_outlined, '学情'),
          ].indexed)
            _RailItem(
              icon: item.$2.$1,
              tooltip: item.$2.$2,
              selected: selectedIndex == item.$1,
              onTap: () => onSelected(item.$1),
            ),
          const Spacer(),
          if (onManage != null)
            _RailItem(
              icon: Icons.admin_panel_settings_outlined,
              tooltip: '管理',
              onTap: onManage,
            ),
          _RailItem(
            icon: Icons.settings_outlined,
            tooltip: '设置',
            onTap: onSettings,
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  const _RailItem({
    required this.icon,
    required this.tooltip,
    this.selected = false,
    this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 10),
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: selected ? scheme.primaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
          child: InkWell(
            borderRadius: BorderRadius.circular(7),
            onTap: onTap,
            child: SizedBox(
              width: 48,
              height: 44,
              child: Icon(
                icon,
                size: 20,
                color: selected
                    ? scheme.onPrimaryContainer
                    : scheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StudentListPane extends StatefulWidget {
  const _StudentListPane({
    required this.selectedStudent,
    required this.onSelected,
    this.compact = false,
  });

  final V2Student selectedStudent;
  final ValueChanged<V2Student> onSelected;
  final bool compact;

  @override
  State<_StudentListPane> createState() => _StudentListPaneState();
}

class _StudentListPaneState extends State<_StudentListPane> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<V2Student> _visibleStudents(V2WorkspaceData data) {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) {
      return data.students;
    }
    return data.students
        .where((student) {
          final haystack = [
            student.name,
            student.grade,
            ...student.subjects,
            student.teacherSummary,
          ].join(' ').toLowerCase();
          return haystack.contains(query);
        })
        .toList(growable: false);
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _query = '');
  }

  @override
  Widget build(BuildContext context) {
    final data = V2WorkspaceDataScope.of(context);
    final visibleStudents = _visibleStudents(data);
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              widget.compact ? 18 : 24,
              24,
              widget.compact ? 18 : 20,
              12,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('学生', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 18),
                TextField(
                  key: const Key('v2-student-search'),
                  controller: _searchController,
                  onChanged: (value) => setState(() => _query = value),
                  decoration: InputDecoration(
                    hintText: '搜索姓名、年级、学科或老师…',
                    prefixIcon: const Icon(Icons.search, size: 19),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: '清除搜索',
                            onPressed: _clearSearch,
                            icon: const Icon(Icons.close, size: 18),
                          ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  _query.trim().isEmpty
                      ? '全部 ${data.students.length}'
                      : '找到 ${visibleStudents.length} 位',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          Expanded(
            child: visibleStudents.isEmpty
                ? Center(
                    child: Text(
                      '没有找到匹配的学生',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: visibleStudents.length,
                    itemBuilder: (context, index) {
                      final student = visibleStudents[index];
                      return _StudentRow(
                        student: student,
                        selected: student.id == widget.selectedStudent.id,
                        onTap: () => widget.onSelected(student),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _StudentRow extends StatelessWidget {
  const _StudentRow({
    required this.student,
    required this.selected,
    required this.onTap,
  });

  final V2Student student;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: Material(
        color: selected
            ? scheme.primary.withValues(alpha: 0.07)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(7),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(7),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                _InitialMark(name: student.name),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        student.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${student.grade} · ${student.subjects.join(' / ')}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      student.openCaseCount == 0
                          ? '暂无进行中'
                          : '${student.openCaseCount} 个问题',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      student.updatedLabel,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant.withValues(alpha: 0.72),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InitialMark extends StatelessWidget {
  const _InitialMark({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        shape: BoxShape.circle,
      ),
      child: Text(
        name.characters.first,
        style: Theme.of(context).textTheme.labelLarge,
      ),
    );
  }
}

class _StudentDetailPane extends StatelessWidget {
  const _StudentDetailPane({
    required this.student,
    required this.onOpenCase,
    this.compact = false,
    this.onBack,
  });

  final V2Student student;
  final ValueChanged<V2FocusItem> onOpenCase;
  final bool compact;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final data = V2WorkspaceDataScope.of(context);
    final focusItems = data.focusItemsForStudent(student);
    final closedItems = data.closedItemsForStudent(student);
    final timelineEntries = data.timelineForStudent(student);
    return ColoredBox(
      color: scheme.surface,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    compact ? 18 : 32,
                    22,
                    compact ? 18 : 32,
                    48,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (onBack != null) ...[
                        IconButton(
                          tooltip: '返回学生列表',
                          onPressed: onBack,
                          icon: const Icon(Icons.arrow_back),
                        ),
                        const SizedBox(height: 4),
                      ],
                      _StudentHeader(student: student, compact: compact),
                      const SizedBox(height: 30),
                      _SectionTitle(title: '现在最重要', count: focusItems.length),
                      const SizedBox(height: 8),
                      if (focusItems.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          child: Text(
                            '暂无进行中的问题',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        )
                      else
                        for (var i = 0; i < focusItems.length; i++) ...[
                          _FocusRow(
                            item: focusItems[i],
                            onTap: () => onOpenCase(focusItems[i]),
                          ),
                          if (i < focusItems.length - 1)
                            Divider(height: 1, color: scheme.outlineVariant),
                        ],
                      if (closedItems.isNotEmpty) ...[
                        const SizedBox(height: 34),
                        _SectionTitle(title: '历史问题', count: closedItems.length),
                        const SizedBox(height: 8),
                        for (var i = 0; i < closedItems.length; i++) ...[
                          _FocusRow(
                            item: closedItems[i],
                            onTap: () => onOpenCase(closedItems[i]),
                          ),
                          if (i < closedItems.length - 1)
                            Divider(height: 1, color: scheme.outlineVariant),
                        ],
                      ],
                      const SizedBox(height: 34),
                      const _SectionTitle(title: '最近成长'),
                      const SizedBox(height: 14),
                      _Timeline(entries: timelineEntries),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StudentHeader extends StatelessWidget {
  const _StudentHeader({required this.student, required this.compact});

  final V2Student student;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final data = V2WorkspaceDataScope.of(context);
    final focusItems = data.focusItemsForStudent(student);
    final buttons = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        OutlinedButton.icon(
          onPressed: () => _showV2QuickCaptureForStudent(context, student),
          icon: const Icon(Icons.note_add_outlined, size: 18),
          label: const Text('记录问题'),
        ),
        FilledButton.icon(
          onPressed: focusItems.isEmpty
              ? null
              : () => _showV2ProgressCasePicker(context, student),
          icon: const Icon(Icons.edit_note_outlined, size: 18),
          label: const Text('记进展'),
        ),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '学生  /  ${student.name}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 18),
        if (compact) ...[
          Text(student.name, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 5),
          Text(
            '${student.grade} · ${student.subjects.join(' / ')}',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 5),
          Text(
            student.teacherSummary,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          buttons,
        ] else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student.name,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${student.grade} · ${student.subjects.join(' / ')}',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      student.teacherSummary,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              buttons,
            ],
          ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.count});

  final String title;
  final int? count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        if (count != null) ...[
          const SizedBox(width: 8),
          Text('$count', style: Theme.of(context).textTheme.bodySmall),
        ],
      ],
    );
  }
}

class _FocusRow extends StatelessWidget {
  const _FocusRow({required this.item, required this.onTap, this.studentName});

  final V2FocusItem item;
  final VoidCallback onTap;
  final String? studentName;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 2,
              height: 58,
              color: scheme.primary.withValues(alpha: 0.5),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.summary,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item.closed ? item.nextStep : '下一步  ${item.nextStep}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  studentName == null
                      ? item.subject
                      : '$studentName · ${item.subject}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 17),
                Text(
                  item.dueLabel,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 20),
          ],
        ),
      ),
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.entries, this.resolveEvidencePhotos = false});

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
    final attachmentRepository = _V2RuntimeScope.maybeOf(context)
        ?.evidenceAttachmentRepository;
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
                  height: entry.photoCount > 0 || canResolveRealPhotos
                      ? 144
                      : 96,
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
    final attachments = await widget.repository.listForEvidence(
      widget.evidenceId,
    );
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
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant),
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

class _CaseDetailPane extends StatelessWidget {
  const _CaseDetailPane({
    required this.student,
    required this.item,
    required this.onBack,
    this.compact = false,
  });

  final V2Student student;
  final V2FocusItem item;
  final VoidCallback onBack;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final timelineEntries = V2WorkspaceDataScope.of(context)
        .timelineForCase(item);
    final controller = _V2RuntimeScope.maybeOf(context)?.workflowController;
    final pendingAction = item.closed
        ? null
        : controller?.pendingActionFor(item.id);
    final canReopen =
        item.closed && (controller?.canReopenClosedCase(item.id) ?? false);
    return ColoredBox(
      color: scheme.surface,
      child: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                compact ? 18 : 32,
                20,
                compact ? 18 : 32,
                48,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    tooltip: '返回',
                    onPressed: onBack,
                    icon: const Icon(Icons.arrow_back),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${student.name} · ${item.subject}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ),
                      if (!item.closed) ...[
                        const SizedBox(width: 16),
                        FilledButton.icon(
                          onPressed: () =>
                              _showV2ProgressForCase(context, student, item),
                          icon: const Icon(Icons.edit_note_outlined, size: 18),
                          label: const Text('记进展'),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item.summary,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 28),
                  Text(
                    item.closed ? '状态' : '下一步',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.arrow_forward,
                        size: 17,
                        color: scheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.nextStep,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      Text(
                        item.dueLabel,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  if (canReopen) ...[
                    const SizedBox(height: 16),
                    FilledButton.tonalIcon(
                      key: ValueKey<String>('v2-reopen-${item.id}'),
                      onPressed: () =>
                          _showV2ReopenClosedCase(context, student, item),
                      icon: const Icon(Icons.restart_alt, size: 18),
                      label: const Text('再次出现，重新跟进'),
                    ),
                  ],
                  if (pendingAction != null) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (pendingAction.canComplete)
                          FilledButton.tonalIcon(
                            key: ValueKey<String>('v2-complete-${item.id}'),
                            onPressed: () => _showV2CompleteCurrentAction(
                              context,
                              student,
                              item,
                            ),
                            icon: const Icon(
                              Icons.check_circle_outline,
                              size: 18,
                            ),
                            label: const Text('完成提醒'),
                          ),
                        OutlinedButton.icon(
                          key: ValueKey<String>('v2-reschedule-${item.id}'),
                          onPressed: () => _showV2RescheduleCurrentAction(
                            context,
                            student,
                            item,
                          ),
                          icon: const Icon(
                            Icons.event_repeat_outlined,
                            size: 18,
                          ),
                          label: Text(
                            pendingAction.dueOn == null ? '安排日期' : '改期',
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 30),
                  Divider(color: scheme.outlineVariant),
                  const SizedBox(height: 28),
                  const _SectionTitle(title: '成长过程'),
                  const SizedBox(height: 16),
                  _Timeline(
                    entries: timelineEntries,
                    resolveEvidencePhotos: true,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TodayPane extends StatelessWidget {
  const _TodayPane({required this.onOpenCase, this.compact = false});

  final ValueChanged<V2FocusItem> onOpenCase;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final data = V2WorkspaceDataScope.of(context);
    final validItems = data.focusItems
        .where(
          (item) =>
              data.studentForFocusItemOrNull(item) != null &&
              item.actionTiming != null &&
              item.actionTiming != V2ActionTiming.future,
        )
        .toList(growable: false);
    final actionItems = validItems
        .where((item) => !item.pendingVerification)
        .take(4)
        .toList(growable: false);
    final verificationItems = validItems
        .where((item) => item.pendingVerification)
        .take(4)
        .toList(growable: false);

    return SingleChildScrollView(
      padding: EdgeInsets.all(compact ? 18 : 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('今日', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 5),
              Text(
                _todayLabel(data.businessDate),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 28),
              if (actionItems.isEmpty && verificationItems.isEmpty)
                Text(
                  '今天没有需要处理的学情事项',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              if (actionItems.isNotEmpty) ...[
                const _SectionTitle(title: '需要处理'),
                const SizedBox(height: 8),
                for (final item in actionItems)
                  _TodayAction(item: item, onOpenCase: onOpenCase),
              ],
              if (actionItems.isNotEmpty && verificationItems.isNotEmpty)
                const SizedBox(height: 28),
              if (verificationItems.isNotEmpty) ...[
                const _SectionTitle(title: '待验证'),
                const SizedBox(height: 10),
                for (final item in verificationItems)
                  _TodayAction(
                    item: item,
                    onOpenCase: onOpenCase,
                    verification: true,
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

String _todayLabel(DateTime? businessDate) {
  const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
  final now = businessDate ?? DateTime.now();
  return '${now.month} 月 ${now.day} 日 · ${weekdays[now.weekday - 1]}';
}

class _TodayAction extends StatelessWidget {
  const _TodayAction({
    required this.item,
    required this.onOpenCase,
    this.verification = false,
  });

  final V2FocusItem item;
  final ValueChanged<V2FocusItem> onOpenCase;
  final bool verification;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final student = V2WorkspaceDataScope.of(context)
        .studentForFocusItemOrNull(item);
    if (student == null) {
      return const SizedBox.shrink();
    }
    final controller = _V2RuntimeScope.maybeOf(context)?.workflowController;
    final pendingAction = controller?.pendingActionFor(item.id);
    return InkWell(
      onTap: () => onOpenCase(item),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 15),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 2,
              height: 56,
              color: verification ? scheme.primary : const Color(0xFFB77728),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${student.name} · ${item.subject}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.title,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    verification ? '等待确认是否已经稳定' : '下一步 · ${item.nextStep}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (pendingAction != null) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        if (pendingAction.canComplete)
                          TextButton.icon(
                            key: ValueKey<String>(
                              'v2-today-complete-${item.id}',
                            ),
                            onPressed: () => _showV2CompleteCurrentAction(
                              context,
                              student,
                              item,
                            ),
                            icon: const Icon(
                              Icons.check_circle_outline,
                              size: 17,
                            ),
                            label: const Text('完成'),
                          ),
                        TextButton.icon(
                          key: ValueKey<String>(
                            'v2-today-reschedule-${item.id}',
                          ),
                          onPressed: () => _showV2RescheduleCurrentAction(
                            context,
                            student,
                            item,
                          ),
                          icon: const Icon(
                            Icons.event_repeat_outlined,
                            size: 17,
                          ),
                          label: Text(
                            pendingAction.dueOn == null ? '安排日期' : '改期',
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            Text(
              verification ? '待验证' : item.dueLabel,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 20),
          ],
        ),
      ),
    );
  }
}

class _CaseIndexPane extends StatefulWidget {
  const _CaseIndexPane({required this.onOpenCase, this.compact = false});

  final ValueChanged<V2FocusItem> onOpenCase;
  final bool compact;

  @override
  State<_CaseIndexPane> createState() => _CaseIndexPaneState();
}

class _CaseIndexPaneState extends State<_CaseIndexPane> {
  final _searchController = TextEditingController();
  String _query = '';
  bool _showClosed = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<V2FocusItem> _visibleItems(V2WorkspaceData data) {
    final query = _query.trim().toLowerCase();
    final sourceItems = _showClosed ? data.closedItems : data.focusItems;
    final validItems = sourceItems
        .where((item) => data.studentForFocusItemOrNull(item) != null)
        .toList(growable: false);
    if (query.isEmpty) {
      return validItems;
    }
    return validItems
        .where((item) {
          final student = data.studentForFocusItem(item);
          final haystack = [
            student.name,
            student.grade,
            item.subject,
            item.title,
            item.summary,
            item.nextStep,
            student.teacherSummary,
          ].join(' ').toLowerCase();
          return haystack.contains(query);
        })
        .toList(growable: false);
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _query = '');
  }

  @override
  Widget build(BuildContext context) {
    final data = V2WorkspaceDataScope.of(context);
    final visibleItems = _visibleItems(data);
    return SingleChildScrollView(
      padding: EdgeInsets.all(widget.compact ? 18 : 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('学情', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 5),
              Text(
                _showClosed ? '回看已经结束的跟进记录' : '找到仍需要复盘的问题',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              SegmentedButton<bool>(
                key: const Key('v2-case-history-toggle'),
                segments: const <ButtonSegment<bool>>[
                  ButtonSegment<bool>(value: false, label: Text('跟进中')),
                  ButtonSegment<bool>(value: true, label: Text('历史')),
                ],
                selected: <bool>{_showClosed},
                onSelectionChanged: (selection) {
                  setState(() {
                    _showClosed = selection.first;
                    _query = '';
                    _searchController.clear();
                  });
                },
              ),
              const SizedBox(height: 16),
              TextField(
                key: const Key('v2-case-search'),
                controller: _searchController,
                onChanged: (value) => setState(() => _query = value),
                decoration: InputDecoration(
                  hintText: '搜索学生、学科或问题…',
                  prefixIcon: const Icon(Icons.search, size: 19),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: '清除搜索',
                          onPressed: _clearSearch,
                          icon: const Icon(Icons.close, size: 18),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _query.trim().isEmpty
                    ? (_showClosed
                          ? '历史 ${visibleItems.length}'
                          : '进行中 ${visibleItems.length}')
                    : '找到 ${visibleItems.length} 个问题',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 6),
              if (visibleItems.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 30),
                  child: Center(
                    child: Text(
                      '没有找到匹配的问题',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                )
              else
                for (final item in visibleItems)
                  _FocusRow(
                    item: item,
                    studentName: data.studentForFocusItem(item).name,
                    onTap: () => widget.onOpenCase(item),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyWorkspacePreview extends StatelessWidget {
  const _EmptyWorkspacePreview();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.people_outline,
                    size: 34,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '暂时还没有可查看的学生',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '当你获得任课学生后，这里会自动出现。',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
