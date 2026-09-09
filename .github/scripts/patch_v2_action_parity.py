from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    file = Path(path)
    text = file.read_text(encoding='utf-8')
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{path}: expected one match, found {count}: {old[:120]!r}')
    file.write_text(text.replace(old, new, 1), encoding='utf-8')


# 1) Controller: derive the exact pending action from the production workspace
# snapshot and preserve case/action optimistic-lock versions for direct actions.
controller = 'lib/features/design_v2/v2_workflow_controller.dart'
replace_once(
    controller,
    "class V2WorkflowResult {\n",
    """class V2PendingActionSnapshot {
  const V2PendingActionSnapshot({
    required this.caseId,
    required this.caseVersion,
    required this.actionId,
    required this.actionVersion,
    required this.title,
    required this.dueOn,
    required this.canComplete,
  });

  final String caseId;
  final int caseVersion;
  final String actionId;
  final int actionVersion;
  final String title;
  final DateTime? dueOn;
  final bool canComplete;
}

class V2WorkflowResult {
""",
)
replace_once(
    controller,
    """  bool hasPendingPrimaryAction(String caseId) =>
      _caseFor(caseId).primaryAction != null;

  List<V2CaseTypeChoice> get caseTypeChoices {
""",
    """  bool hasPendingPrimaryAction(String caseId) =>
      _caseFor(caseId).primaryAction != null;

  DateTime get businessDate => workspace.businessDate ?? _now();

  V2PendingActionSnapshot? pendingActionFor(String caseId) {
    final learningCase = _caseFor(caseId);
    final action = learningCase.primaryAction;
    if (action == null) {
      return null;
    }
    return V2PendingActionSnapshot(
      caseId: learningCase.id,
      caseVersion: learningCase.version,
      actionId: action.id,
      actionVersion: action.version,
      title: action.title,
      dueOn: action.businessDueDate ?? action.dueAt,
      canComplete: learningCase.status != LearningCaseStatus.newCase,
    );
  }

  Future<void> completeCurrentAction({
    required String operationId,
    required String caseId,
  }) async {
    final action = pendingActionFor(caseId);
    if (action == null) {
      throw const V2WorkflowSaveException(
        '当前提醒已经变化，请刷新后再试。',
        recordMayBeSaved: false,
      );
    }
    if (!action.canComplete) {
      throw const V2WorkflowSaveException(
        '这个新问题还需要先确认，再完成后续提醒。',
        recordMayBeSaved: false,
      );
    }
    await learningRepository.completeCaseAction(
      CompleteCaseActionCommand(
        operationId: operationId,
        actionId: action.actionId,
        caseId: action.caseId,
        expectedCaseVersion: action.caseVersion,
        expectedActionVersion: action.actionVersion,
      ),
    );
  }

  Future<void> rescheduleCurrentAction({
    required String operationId,
    required String caseId,
    required DateTime? dueOn,
  }) async {
    final action = pendingActionFor(caseId);
    if (action == null) {
      throw const V2WorkflowSaveException(
        '当前提醒已经变化，请刷新后再试。',
        recordMayBeSaved: false,
      );
    }
    await learningRepository.rescheduleCaseAction(
      RescheduleCaseActionCommand(
        operationId: operationId,
        actionId: action.actionId,
        caseId: action.caseId,
        expectedCaseVersion: action.caseVersion,
        expectedActionVersion: action.actionVersion,
        dueOn: dueOn,
      ),
    );
  }

  List<V2CaseTypeChoice> get caseTypeChoices {
""",
)

# 2) Small adaptive composers. The operation id deliberately lives in the
# caller; repeated saves within one open composer therefore use the same key.
Path('lib/features/design_v2/v2_action_composers.dart').write_text(r'''import 'package:flutter/material.dart';

import 'v2_workflow_controller.dart';

typedef V2CompleteActionSave = Future<void> Function();
typedef V2RescheduleActionSave = Future<void> Function(DateTime? dueOn);

Future<bool> showV2CompleteActionComposer(
  BuildContext context, {
  required String actionTitle,
  required V2CompleteActionSave onSave,
}) async {
  return await _showActionComposer<bool>(
        context,
        child: V2CompleteActionComposer(
          actionTitle: actionTitle,
          onSave: onSave,
        ),
      ) ??
      false;
}

Future<bool> showV2RescheduleActionComposer(
  BuildContext context, {
  required String actionTitle,
  required DateTime businessDate,
  required DateTime? initialDueOn,
  required V2RescheduleActionSave onSave,
}) async {
  return await _showActionComposer<bool>(
        context,
        child: V2RescheduleActionComposer(
          actionTitle: actionTitle,
          businessDate: businessDate,
          initialDueOn: initialDueOn,
          onSave: onSave,
        ),
      ) ??
      false;
}

Future<T?> _showActionComposer<T>(
  BuildContext context, {
  required Widget child,
}) {
  if (MediaQuery.sizeOf(context).width < 720) {
    return showModalBottomSheet<T>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => child,
    );
  }
  return showDialog<T>(
    context: context,
    barrierDismissible: false,
    builder: (_) => Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: child,
      ),
    ),
  );
}

String _describeActionSaveError(Object error) {
  if (error is V2WorkflowSaveException) {
    return error.userMessage;
  }
  final detail = error.toString().toLowerCase();
  if (detail.contains('version_conflict')) {
    return '这条提醒刚刚有变化，请刷新后再处理。';
  }
  if (detail.contains('invalid_live_session') ||
      detail.contains('session') ||
      detail.contains('jwt')) {
    return '登录状态已变化，请重新登录后再操作。';
  }
  if (detail.contains('permission') ||
      detail.contains('forbidden') ||
      detail.contains('assignment')) {
    return '当前任课关系或权限已经变化，请刷新后再试。';
  }
  if (detail.contains('network') ||
      detail.contains('socket') ||
      detail.contains('timeout') ||
      detail.contains('connection')) {
    return '网络暂时不可用。当前操作仍保留，可以直接重试，不会重复保存。';
  }
  return '暂时保存失败。当前操作仍保留，可以直接重试。';
}

class V2CompleteActionComposer extends StatefulWidget {
  const V2CompleteActionComposer({
    required this.actionTitle,
    required this.onSave,
    super.key,
  });

  final String actionTitle;
  final V2CompleteActionSave onSave;

  @override
  State<V2CompleteActionComposer> createState() =>
      _V2CompleteActionComposerState();
}

class _V2CompleteActionComposerState extends State<V2CompleteActionComposer> {
  bool _saving = false;
  bool _attempted = false;
  String? _error;

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _attempted = true;
      _error = null;
    });
    try {
      await widget.onSave();
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = _describeActionSaveError(error);
      });
    }
  }

  Future<void> _close() async {
    if (_saving) return;
    if (!_attempted) {
      Navigator.of(context).pop(false);
      return;
    }
    final retry = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('刚才是否保存成功还不能确认'),
        content: const Text('建议直接重新保存；系统会沿用这次操作，不会重复完成提醒。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('继续查看'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('重新保存'),
          ),
        ],
      ),
    );
    if (mounted && retry == true) await _save();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<void>(
      canPop: !_saving && !_attempted,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_saving) _close();
      },
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('完成提醒', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(widget.actionTitle, style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 8),
            Text(
              '只把这件已经做完的事标记为完成，不会自动生成新的提醒。',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (_error != null) ...[
              const SizedBox(height: 14),
              Text(
                _error!,
                key: const Key('v2-action-save-error'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saving ? null : _close,
                    child: const Text('取消'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    key: const Key('v2-complete-action-save'),
                    onPressed: _saving ? null : _save,
                    child: Text(
                      _saving ? '保存中…' : _attempted ? '重新保存' : '完成提醒',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class V2RescheduleActionComposer extends StatefulWidget {
  const V2RescheduleActionComposer({
    required this.actionTitle,
    required this.businessDate,
    required this.initialDueOn,
    required this.onSave,
    super.key,
  });

  final String actionTitle;
  final DateTime businessDate;
  final DateTime? initialDueOn;
  final V2RescheduleActionSave onSave;

  @override
  State<V2RescheduleActionComposer> createState() =>
      _V2RescheduleActionComposerState();
}

class _V2RescheduleActionComposerState
    extends State<V2RescheduleActionComposer> {
  DateTime? _dueOn;
  bool _saving = false;
  bool _attempted = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialDueOn;
    _dueOn = initial == null
        ? null
        : DateTime(initial.year, initial.month, initial.day);
  }

  DateTime get _today => DateTime(
    widget.businessDate.year,
    widget.businessDate.month,
    widget.businessDate.day,
  );

  Future<void> _pickDate() async {
    if (_saving || _attempted) return;
    final today = _today;
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueOn != null && !_dueOn!.isBefore(today) ? _dueOn! : today,
      firstDate: today,
      lastDate: DateTime(today.year + 3, 12, 31),
      helpText: '选择提醒日期',
      cancelText: '取消',
      confirmText: '确定',
    );
    if (picked != null && mounted) {
      setState(() => _dueOn = DateTime(picked.year, picked.month, picked.day));
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _attempted = true;
      _error = null;
    });
    try {
      await widget.onSave(_dueOn);
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = _describeActionSaveError(error);
      });
    }
  }

  Future<void> _close() async {
    if (_saving) return;
    if (!_attempted) {
      Navigator.of(context).pop(false);
      return;
    }
    final retry = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('刚才是否保存成功还不能确认'),
        content: const Text('建议直接重新保存；系统会沿用这次操作，不会重复改期。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('继续查看'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('重新保存'),
          ),
        ],
      ),
    );
    if (mounted && retry == true) await _save();
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = _dueOn == null
        ? '不设日期'
        : '${_dueOn!.month} 月 ${_dueOn!.day} 日';
    return PopScope<void>(
      canPop: !_saving && !_attempted,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_saving) _close();
      },
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('安排提醒日期', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(widget.actionTitle, style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('v2-action-pick-date'),
                    onPressed: _saving || _attempted ? null : _pickDate,
                    icon: const Icon(Icons.event_outlined),
                    label: Text(dateLabel),
                  ),
                ),
                if (_dueOn != null) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: '清除日期',
                    onPressed: _saving || _attempted
                        ? null
                        : () => setState(() => _dueOn = null),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '日期按机构业务日计算；也可以清除日期，保留为未安排提醒。',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (_error != null) ...[
              const SizedBox(height: 14),
              Text(
                _error!,
                key: const Key('v2-action-save-error'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saving ? null : _close,
                    child: const Text('取消'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    key: const Key('v2-reschedule-action-save'),
                    onPressed: _saving ? null : _save,
                    child: Text(
                      _saving ? '保存中…' : _attempted ? '重新保存' : '保存日期',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
''', encoding='utf-8')

# 3) Wire direct action flows from V2 UI. Both case detail and Today remain thin
# presenters; production identity/version truth stays in V2WorkflowController.
preview = 'lib/features/design_v2/v2_workspace_preview.dart'
replace_once(
    preview,
    "import 'v2_composers.dart';\n",
    "import 'v2_action_composers.dart';\nimport 'v2_composers.dart';\n",
)
replace_once(
    preview,
    """Future<void> _showV2ProgressForCase(
""",
    """Future<void> _showV2CompleteCurrentAction(
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

Future<void> _showV2ProgressForCase(
""",
)
replace_once(
    preview,
    """    final scheme = Theme.of(context).colorScheme;
    final timelineEntries = V2WorkspaceDataScope.of(context)
        .timelineForCase(item);
    return ColoredBox(
""",
    """    final scheme = Theme.of(context).colorScheme;
    final timelineEntries = V2WorkspaceDataScope.of(context)
        .timelineForCase(item);
    final controller = _V2RuntimeScope.maybeOf(context)?.workflowController;
    final pendingAction = controller?.pendingActionFor(item.id);
    return ColoredBox(
""",
)
replace_once(
    preview,
    """                  Row(
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
                  const SizedBox(height: 30),
""",
    """                  Row(
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
                            icon: const Icon(Icons.check_circle_outline, size: 18),
                            label: const Text('完成提醒'),
                          ),
                        OutlinedButton.icon(
                          key: ValueKey<String>('v2-reschedule-${item.id}'),
                          onPressed: () => _showV2RescheduleCurrentAction(
                            context,
                            student,
                            item,
                          ),
                          icon: const Icon(Icons.event_repeat_outlined, size: 18),
                          label: Text(pendingAction.dueOn == null ? '安排日期' : '改期'),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 30),
""",
)
replace_once(
    preview,
    """    final student = V2WorkspaceDataScope.of(context)
        .studentForFocusItemOrNull(item);
    if (student == null) {
      return const SizedBox.shrink();
    }
    return InkWell(
""",
    """    final student = V2WorkspaceDataScope.of(context)
        .studentForFocusItemOrNull(item);
    if (student == null) {
      return const SizedBox.shrink();
    }
    final controller = _V2RuntimeScope.maybeOf(context)?.workflowController;
    final pendingAction = controller?.pendingActionFor(item.id);
    return InkWell(
""",
)
replace_once(
    preview,
    """                  Text(
                    verification ? '等待确认是否已经稳定' : '下一步 · ${item.nextStep}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
""",
    """                  Text(
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
                            key: ValueKey<String>('v2-today-complete-${item.id}'),
                            onPressed: () => _showV2CompleteCurrentAction(
                              context,
                              student,
                              item,
                            ),
                            icon: const Icon(Icons.check_circle_outline, size: 17),
                            label: const Text('完成'),
                          ),
                        TextButton.icon(
                          key: ValueKey<String>('v2-today-reschedule-${item.id}'),
                          onPressed: () => _showV2RescheduleCurrentAction(
                            context,
                            student,
                            item,
                          ),
                          icon: const Icon(Icons.event_repeat_outlined, size: 17),
                          label: Text(pendingAction.dueOn == null ? '安排日期' : '改期'),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
""",
)

# 4) Controller tests pin exact action identity/version and business rules.
test = 'test/features/design_v2_workflow_controller_test.dart'
replace_once(
    test,
    """    test(
      'case type choices use real active types and one unclassified option',
""",
    """    test('direct action completion keeps exact optimistic-lock identity', () async {
      final learning = _FakeLearningRepository();
      final controller = V2WorkflowController(
        workspace: _workspace(),
        learningRepository: learning,
        progressiveCaseRepository: _FakeProgressiveCaseRepository(),
      );

      final action = controller.pendingActionFor('case-existing');
      expect(action, isNotNull);
      expect(action!.actionId, 'action-current');
      expect(action.actionVersion, 2);
      expect(action.caseVersion, 3);
      expect(action.canComplete, isTrue);

      await controller.completeCurrentAction(
        operationId: 'operation-complete-1',
        caseId: 'case-existing',
      );

      final command = learning.completeActionCalls.single;
      expect(command.operationId, 'operation-complete-1');
      expect(command.actionId, 'action-current');
      expect(command.caseId, 'case-existing');
      expect(command.expectedCaseVersion, 3);
      expect(command.expectedActionVersion, 2);
      expect(command.nextActionTitle, isNull);
    });

    test('direct action reschedule keeps identity and accepts undated', () async {
      final learning = _FakeLearningRepository();
      final controller = V2WorkflowController(
        workspace: _workspace(),
        learningRepository: learning,
        progressiveCaseRepository: _FakeProgressiveCaseRepository(),
      );

      await controller.rescheduleCurrentAction(
        operationId: 'operation-reschedule-1',
        caseId: 'case-existing',
        dueOn: null,
      );

      final command = learning.rescheduleActionCalls.single;
      expect(command.operationId, 'operation-reschedule-1');
      expect(command.actionId, 'action-current');
      expect(command.expectedCaseVersion, 3);
      expect(command.expectedActionVersion, 2);
      expect(command.dueOn, isNull);
    });

    test('new case action cannot be completed before confirmation', () async {
      final learning = _FakeLearningRepository();
      final controller = V2WorkflowController(
        workspace: _workspaceWithCase(_case(status: LearningCaseStatus.newCase)),
        learningRepository: learning,
        progressiveCaseRepository: _FakeProgressiveCaseRepository(),
      );

      expect(controller.pendingActionFor('case-existing')!.canComplete, isFalse);
      await expectLater(
        controller.completeCurrentAction(
          operationId: 'operation-blocked',
          caseId: 'case-existing',
        ),
        throwsA(isA<V2WorkflowSaveException>()),
      );
      expect(learning.completeActionCalls, isEmpty);
    });

    test(
      'case type choices use real active types and one unclassified option',
""",
)
replace_once(
    test,
    """TeacherWorkspace _workspace() => TeacherWorkspace(
""",
    """TeacherWorkspace _workspaceWithCase(WorkspaceCase learningCase) => TeacherWorkspace(
  organizationId: 'org-1',
  viewerName: '王老师',
  organizationName: '测试机构',
  organizationTimeZone: 'Asia/Shanghai',
  hasTeachingAccess: true,
  students: [
    _profile(
      studentId: 'student-1',
      profileId: 'profile-chinese',
      profileVersion: 2,
      name: '林同学',
      subject: '语文',
      cases: [learningCase],
    ),
  ],
  loadedAt: DateTime(2026, 9, 9),
);

TeacherWorkspace _workspace() => TeacherWorkspace(
""",
)
replace_once(
    test,
    """WorkspaceCase _case() => WorkspaceCase(
""",
    """WorkspaceCase _case({
  LearningCaseStatus status = LearningCaseStatus.confirmed,
}) => WorkspaceCase(
""",
)
replace_once(
    test,
    """  status: LearningCaseStatus.confirmed,
""",
    """  status: status,
""",
)
replace_once(
    test,
    """  final addEvidenceCalls = <AddCaseEvidenceCommand>[];
""",
    """  final addEvidenceCalls = <AddCaseEvidenceCommand>[];
  final completeActionCalls = <CompleteCaseActionCommand>[];
  final rescheduleActionCalls = <RescheduleCaseActionCommand>[];
""",
)
replace_once(
    test,
    """  @override
  Future<CaseCommandReceipt> addCaseEvidence(
""",
    """  @override
  Future<CaseCommandReceipt> completeCaseAction(
    CompleteCaseActionCommand command,
  ) async {
    completeActionCalls.add(command);
    return CaseCommandReceipt(
      operationId: command.operationId,
      caseId: command.caseId,
      eventId: 'event-complete',
      status: 'confirmed',
      caseVersion: command.expectedCaseVersion + 1,
      recordId: command.actionId,
    );
  }

  @override
  Future<CaseCommandReceipt> rescheduleCaseAction(
    RescheduleCaseActionCommand command,
  ) async {
    rescheduleActionCalls.add(command);
    return CaseCommandReceipt(
      operationId: command.operationId,
      caseId: command.caseId,
      eventId: 'event-reschedule',
      status: 'confirmed',
      caseVersion: command.expectedCaseVersion + 1,
      recordId: command.actionId,
    );
  }

  @override
  Future<CaseCommandReceipt> addCaseEvidence(
""",
)

# 5) Widget-level retry test: failed action keeps state and reuses the same
# callback/selected date instead of silently closing or resetting.
Path('test/features/v2_action_composers_test.dart').write_text(r'''import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xueqing/features/design_v2/v2_action_composers.dart';

void main() {
  testWidgets('reschedule failure keeps selected date and retries in place', (
    tester,
  ) async {
    var calls = 0;
    final seenDates = <DateTime?>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: V2RescheduleActionComposer(
            actionTitle: '再检查一次',
            businessDate: DateTime(2026, 9, 10),
            initialDueOn: DateTime(2026, 9, 12),
            onSave: (dueOn) async {
              calls++;
              seenDates.add(dueOn);
              if (calls == 1) throw Exception('network timeout');
            },
          ),
        ),
      ),
    );

    expect(find.text('9 月 12 日'), findsOneWidget);
    await tester.tap(find.byKey(const Key('v2-reschedule-action-save')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('v2-action-save-error')), findsOneWidget);
    expect(find.text('9 月 12 日'), findsOneWidget);
    expect(calls, 1);

    await tester.tap(find.byKey(const Key('v2-reschedule-action-save')));
    await tester.pumpAndSettle();

    expect(calls, 2);
    expect(seenDates, [DateTime(2026, 9, 12), DateTime(2026, 9, 12)]);
  });

  testWidgets('completion failure stays open for safe retry', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: V2CompleteActionComposer(
            actionTitle: '再检查一次',
            onSave: () async {
              calls++;
              if (calls == 1) throw Exception('network timeout');
            },
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('v2-complete-action-save')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('v2-action-save-error')), findsOneWidget);
    expect(calls, 1);

    await tester.tap(find.byKey(const Key('v2-complete-action-save')));
    await tester.pumpAndSettle();
    expect(calls, 2);
  });
}
''', encoding='utf-8')

print('V2 action parity patch applied')
