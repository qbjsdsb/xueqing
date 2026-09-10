import 'package:flutter/material.dart';

import '../teacher_workspace/presentation/evidence_attachment_picker.dart';
import 'v2_workflow_controller.dart';

typedef V2AttachmentPicker = Future<PickedEvidenceAttachment?> Function(
  BuildContext context,
);

class V2ProblemTypeOption {
  const V2ProblemTypeOption({required this.key, required this.label});

  final String key;
  final String label;
}

const v2PreviewProblemTypeOptions = <V2ProblemTypeOption>[
  V2ProblemTypeOption(key: 'unclassified', label: '暂不分类'),
  V2ProblemTypeOption(key: 'builtin:knowledge', label: '知识漏洞'),
  V2ProblemTypeOption(key: 'builtin:habit', label: '学习习惯'),
  V2ProblemTypeOption(key: 'builtin:exam_strategy', label: '考试技巧'),
];

enum V2ProgressKind { observation, intervention, assessment }

extension V2ProgressKindLabel on V2ProgressKind {
  String get label => switch (this) {
    V2ProgressKind.observation => '新表现',
    V2ProgressKind.intervention => '教学处理',
    V2ProgressKind.assessment => '检查结果',
  };
}

enum V2AssessmentResult { passed, partial, notPassed }

extension V2AssessmentResultLabel on V2AssessmentResult {
  String get label => switch (this) {
    V2AssessmentResult.passed => '通过',
    V2AssessmentResult.partial => '部分通过',
    V2AssessmentResult.notPassed => '未通过',
  };
}

enum V2NextStep { continueTracking, remind, close }

extension V2NextStepLabel on V2NextStep {
  String get label => switch (this) {
    V2NextStep.continueTracking => '继续跟进',
    V2NextStep.remind => '提醒我再检查',
    V2NextStep.close => '结束跟进',
  };
}

enum V2CloseReason { resolved, pauseTracking, notIssue, other }

extension V2CloseReasonLabel on V2CloseReason {
  String get label => switch (this) {
    V2CloseReason.resolved => '问题已解决',
    V2CloseReason.pauseTracking => '暂不继续跟进',
    V2CloseReason.notIssue => '确认不是问题',
    V2CloseReason.other => '其他',
  };
}

class V2QuickCaptureDraft {
  const V2QuickCaptureDraft({
    required this.subject,
    required this.caseTypeKey,
    required this.body,
    required this.attachments,
  });

  final String subject;
  final String caseTypeKey;
  final String body;
  final List<PickedEvidenceAttachment> attachments;
}

class V2ProgressDraft {
  const V2ProgressDraft({
    required this.kind,
    required this.body,
    required this.attachments,
    required this.nextStep,
    required this.closeReason,
    required this.completeCurrentAction,
    this.assessmentResult,
    this.reminderTitle,
    this.reminderDate,
  });

  final V2ProgressKind kind;
  final String body;
  final List<PickedEvidenceAttachment> attachments;
  final V2AssessmentResult? assessmentResult;
  final V2NextStep nextStep;
  final String? reminderTitle;
  final DateTime? reminderDate;
  final V2CloseReason closeReason;
  final bool completeCurrentAction;
}

typedef V2QuickCaptureSave = Future<void> Function(V2QuickCaptureDraft draft);
typedef V2ProgressSave = Future<void> Function(V2ProgressDraft draft);

Future<bool> showV2QuickCapture(
  BuildContext context, {
  required String studentName,
  required List<String> subjects,
  List<V2ProblemTypeOption> problemTypes = v2PreviewProblemTypeOptions,
  V2QuickCaptureSave? onSave,
  V2AttachmentPicker attachmentPicker = pickEvidenceAttachment,
}) async {
  assert(subjects.isNotEmpty);
  assert(problemTypes.isNotEmpty);
  final saved =
      await _showAdaptiveComposer<bool>(
        context,
        child: V2QuickCaptureComposer(
          studentName: studentName,
          subjects: subjects,
          problemTypes: problemTypes,
          onSave: onSave,
          attachmentPicker: attachmentPicker,
        ),
      ) ??
      false;
  if (saved && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(onSave == null ? 'V2 预览：记录已完成，但没有写入正式学情。' : '已记录问题。'),
      ),
    );
  }
  return saved;
}

Future<bool> showV2ProgressComposer(
  BuildContext context, {
  required String studentName,
  required String subject,
  required String caseTitle,
  bool canCompleteCurrentAction = false,
  DateTime? businessDate,
  V2ProgressSave? onSave,
  V2AttachmentPicker attachmentPicker = pickEvidenceAttachment,
}) async {
  final saved =
      await _showAdaptiveComposer<bool>(
        context,
        child: V2ProgressComposer(
          studentName: studentName,
          subject: subject,
          caseTitle: caseTitle,
          canCompleteCurrentAction: canCompleteCurrentAction,
          businessDate: businessDate,
          onSave: onSave,
          attachmentPicker: attachmentPicker,
        ),
      ) ??
      false;
  if (saved && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(onSave == null ? 'V2 预览：进展已完成，但没有写入正式学情。' : '已保存进展。'),
      ),
    );
  }
  return saved;
}

String _describeV2SaveError(Object error) {
  if (error is V2WorkflowSaveException) {
    return error.userMessage;
  }
  final detail = error.toString().toLowerCase();
  if (detail.contains('version_conflict')) {
    return '学情刚刚有更新，请关闭当前窗口，刷新后再记录。';
  }
  if (detail.contains('invalid_live_session') ||
      detail.contains('session') ||
      detail.contains('jwt')) {
    return '登录状态已变化，请重新登录后再保存。';
  }
  if (detail.contains('permission') ||
      detail.contains('forbidden') ||
      detail.contains('teaching_fact_gate') ||
      detail.contains('owner_permission_required') ||
      detail.contains('assignment')) {
    return '当前任课关系或权限已经变化，请刷新后再试。';
  }
  if (detail.contains('network') ||
      detail.contains('socket') ||
      detail.contains('timeout') ||
      detail.contains('connection')) {
    return '网络暂时不可用，当前文字和图片仍然保留，可以直接重试。';
  }
  return '暂时保存失败，当前输入没有清空，请重试。';
}

enum _V2DraftCloseAction { keepEditing, retry, discard }

Future<_V2DraftCloseAction?> _showV2DraftCloseDialog(
  BuildContext context, {
  required bool saveFailed,
}) {
  return showDialog<_V2DraftCloseAction>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(saveFailed ? '这条记录还没有确认保存' : '放弃这段记录？'),
      content: Text(
        saveFailed
            ? '当前文字和图片仍然保留。建议直接重新保存；如果放弃，这段未确认保存的内容会丢失。'
            : '当前输入还没有保存。确定放弃后，这段文字和图片不会进入学生成长记录。',
      ),
      actions: [
        TextButton(
          onPressed: () =>
              Navigator.of(dialogContext).pop(_V2DraftCloseAction.keepEditing),
          child: const Text('继续编辑'),
        ),
        if (saveFailed)
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(_V2DraftCloseAction.discard),
            child: const Text('放弃记录'),
          ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(
            saveFailed
                ? _V2DraftCloseAction.retry
                : _V2DraftCloseAction.discard,
          ),
          child: Text(saveFailed ? '重新保存' : '放弃记录'),
        ),
      ],
    ),
  );
}

Future<T?> _showAdaptiveComposer<T>(
  BuildContext context, {
  required Widget child,
}) {
  final compact = MediaQuery.sizeOf(context).width < 720;
  if (compact) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      builder: (_) => child,
    );
  }
  return showDialog<T>(
    context: context,
    barrierDismissible: false,
    builder: (_) => Dialog(
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 820),
        child: child,
      ),
    ),
  );
}

class V2QuickCaptureComposer extends StatefulWidget {
  const V2QuickCaptureComposer({
    required this.studentName,
    required this.subjects,
    required this.problemTypes,
    required this.attachmentPicker,
    this.onSave,
    super.key,
  });

  final String studentName;
  final List<String> subjects;
  final List<V2ProblemTypeOption> problemTypes;
  final V2AttachmentPicker attachmentPicker;
  final V2QuickCaptureSave? onSave;

  @override
  State<V2QuickCaptureComposer> createState() => _V2QuickCaptureComposerState();
}

class _V2QuickCaptureComposerState extends State<V2QuickCaptureComposer> {
  final _controller = TextEditingController();
  final _attachments = <PickedEvidenceAttachment>[];
  String? _selectedSubject;
  bool _showMore = false;
  late String _problemTypeKey;
  String? _mediaError;
  String? _saveError;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _problemTypeKey = widget.problemTypes.first.key;
    if (widget.subjects.length == 1) {
      _selectedSubject = widget.subjects.single;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickAttachment() async {
    if (_saving || _attachments.length >= 3) {
      return;
    }
    try {
      final picked = await widget.attachmentPicker(context);
      if (!mounted || picked == null) {
        return;
      }
      setState(() {
        _attachments.add(picked);
        _mediaError = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _mediaError = describeEvidenceAttachmentError(error));
    }
  }

  bool get _hasDraft =>
      _controller.text.trim().isNotEmpty || _attachments.isNotEmpty;

  bool get _canSave =>
      !_saving &&
      _selectedSubject != null &&
      _controller.text.trim().isNotEmpty;

  Future<void> _save() async {
    if (!_canSave) {
      return;
    }
    final onSave = widget.onSave;
    if (onSave == null) {
      Navigator.of(context).pop(true);
      return;
    }
    final draft = V2QuickCaptureDraft(
      subject: _selectedSubject!,
      caseTypeKey: _problemTypeKey,
      body: _controller.text.trim(),
      attachments: List<PickedEvidenceAttachment>.unmodifiable(_attachments),
    );
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      await onSave(draft);
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _saveError = _describeV2SaveError(error);
        });
      }
    }
  }

  Future<void> _close() async {
    if (_saving) {
      return;
    }
    if (!_hasDraft) {
      Navigator.of(context).pop(false);
      return;
    }
    final action = await _showV2DraftCloseDialog(
      context,
      saveFailed: _saveError != null,
    );
    if (!mounted ||
        action == null ||
        action == _V2DraftCloseAction.keepEditing) {
      return;
    }
    if (action == _V2DraftCloseAction.retry) {
      await _save();
      return;
    }
    Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    return _ComposerScaffold(
      title: '记录新问题',
      contextLine: _selectedSubject == null
          ? widget.studentName
          : '${widget.studentName} · $_selectedSubject',
      onClose: _saving ? null : _close,
      footer: _ComposerFooter(
        primaryLabel: '记录问题',
        onPrimary: _canSave ? _save : null,
        saving: _saving,
        previewMode: widget.onSave == null,
        errorText: _saveError,
      ),
      child: AbsorbPointer(
        absorbing: _saving,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.subjects.length > 1) ...[
              Text('选择学科', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 4),
              _InlineSelector<String>(
                key: const Key('v2-quick-capture-subject-selector'),
                value: _selectedSubject,
                values: widget.subjects,
                label: (value) => value,
                onChanged: (value) => setState(() => _selectedSubject = value),
              ),
              const SizedBox(height: 22),
            ],
            Text('今天发现什么？', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            TextField(
              key: const Key('v2-quick-capture-body'),
              controller: _controller,
              autofocus: true,
              minLines: 4,
              maxLines: 7,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: '写下刚才真实看到的题目、行为或表现…',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 12),
            V2MediaDraftStrip(
              attachments: _attachments,
              onAdd: _pickAttachment,
              onRemove: (index) => setState(() => _attachments.removeAt(index)),
            ),
            if (_mediaError != null) ...[
              const SizedBox(height: 8),
              Text(
                _mediaError!,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 8),
            TextButton.icon(
              key: const Key('v2-quick-capture-more'),
              onPressed: () => setState(() => _showMore = !_showMore),
              icon: Icon(_showMore ? Icons.expand_less : Icons.tune, size: 18),
              label: Text(_showMore ? '收起更多选项' : '更多选项'),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 180),
              alignment: Alignment.topCenter,
              child: _showMore
                  ? Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: DropdownButtonFormField<String>(
                        initialValue: _problemTypeKey,
                        decoration: const InputDecoration(labelText: '问题类型'),
                        items: widget.problemTypes
                            .map(
                              (option) => DropdownMenuItem(
                                value: option.key,
                                child: Text(option.label),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _problemTypeKey = value);
                          }
                        },
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

class V2ProgressComposer extends StatefulWidget {
  const V2ProgressComposer({
    required this.studentName,
    required this.subject,
    required this.caseTitle,
    required this.attachmentPicker,
    this.canCompleteCurrentAction = false,
    this.businessDate,
    this.onSave,
    super.key,
  });

  final String studentName;
  final String subject;
  final String caseTitle;
  final V2AttachmentPicker attachmentPicker;
  final bool canCompleteCurrentAction;
  final DateTime? businessDate;
  final V2ProgressSave? onSave;

  @override
  State<V2ProgressComposer> createState() => _V2ProgressComposerState();
}

class _V2ProgressComposerState extends State<V2ProgressComposer> {
  final _controller = TextEditingController();
  final _reminderController = TextEditingController();
  final _attachments = <PickedEvidenceAttachment>[];
  V2ProgressKind _kind = V2ProgressKind.observation;
  V2NextStep _nextStep = V2NextStep.continueTracking;
  V2AssessmentResult? _assessmentResult;
  V2CloseReason _closeReason = V2CloseReason.resolved;
  DateTime? _reminderDate;
  bool _completeCurrentAction = false;
  String? _mediaError;
  String? _saveError;
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    _reminderController.dispose();
    super.dispose();
  }

  Future<void> _pickAttachment() async {
    if (_saving || _attachments.length >= 3) {
      return;
    }
    try {
      final picked = await widget.attachmentPicker(context);
      if (!mounted || picked == null) {
        return;
      }
      setState(() {
        _attachments.add(picked);
        _mediaError = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _mediaError = describeEvidenceAttachmentError(error));
    }
  }

  Future<void> _chooseReminderDate() async {
    final referenceDate = widget.businessDate ?? DateTime.now();
    final today = DateTime(
      referenceDate.year,
      referenceDate.month,
      referenceDate.day,
    );
    final selected = await showDatePicker(
      context: context,
      initialDate: _reminderDate ?? today,
      firstDate: today,
      lastDate: DateTime(today.year + 2, 12, 31),
      helpText: '选择再次检查日期',
      cancelText: '取消',
      confirmText: '确定',
    );
    if (selected != null && mounted) {
      setState(() => _reminderDate = selected);
    }
  }

  bool get _hasDraft =>
      _controller.text.trim().isNotEmpty ||
      _attachments.isNotEmpty ||
      _kind != V2ProgressKind.observation ||
      _nextStep != V2NextStep.continueTracking ||
      _assessmentResult != null ||
      _reminderController.text.trim().isNotEmpty ||
      _reminderDate != null ||
      _completeCurrentAction;

  bool get _canSave {
    if (_saving || _controller.text.trim().isEmpty) {
      return false;
    }
    if (_kind == V2ProgressKind.assessment && _assessmentResult == null) {
      return false;
    }
    if (_nextStep == V2NextStep.remind && _reminderDate == null) {
      return false;
    }
    return true;
  }

  Future<void> _save() async {
    if (!_canSave) {
      return;
    }
    final onSave = widget.onSave;
    if (onSave == null) {
      Navigator.of(context).pop(true);
      return;
    }
    final reminderTitle = _reminderController.text.trim();
    final draft = V2ProgressDraft(
      kind: _kind,
      body: _controller.text.trim(),
      attachments: List<PickedEvidenceAttachment>.unmodifiable(_attachments),
      assessmentResult: _assessmentResult,
      nextStep: _nextStep,
      reminderTitle: reminderTitle.isEmpty ? null : reminderTitle,
      reminderDate: _reminderDate,
      closeReason: _closeReason,
      completeCurrentAction:
          widget.canCompleteCurrentAction &&
          _nextStep != V2NextStep.close &&
          _completeCurrentAction,
    );
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      await onSave(draft);
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _saveError = _describeV2SaveError(error);
        });
      }
    }
  }

  Future<void> _close() async {
    if (_saving) {
      return;
    }
    if (!_hasDraft) {
      Navigator.of(context).pop(false);
      return;
    }
    final action = await _showV2DraftCloseDialog(
      context,
      saveFailed: _saveError != null,
    );
    if (!mounted ||
        action == null ||
        action == _V2DraftCloseAction.keepEditing) {
      return;
    }
    if (action == _V2DraftCloseAction.retry) {
      await _save();
      return;
    }
    Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    return _ComposerScaffold(
      title: '记录进展',
      contextLine:
          '${widget.studentName} · ${widget.subject}\n${widget.caseTitle}',
      onClose: _saving ? null : _close,
      footer: _ComposerFooter(
        primaryLabel: '保存进展',
        onPrimary: _canSave ? _save : null,
        saving: _saving,
        previewMode: widget.onSave == null,
        errorText: _saveError,
      ),
      child: AbsorbPointer(
        absorbing: _saving,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('这次发生了什么？', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            TextField(
              key: const Key('v2-progress-body'),
              controller: _controller,
              autofocus: true,
              minLines: 4,
              maxLines: 7,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: '写下这次真实出现的表现、处理或检查结果…',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 12),
            V2MediaDraftStrip(
              attachments: _attachments,
              onAdd: _pickAttachment,
              onRemove: (index) => setState(() => _attachments.removeAt(index)),
            ),
            if (_mediaError != null) ...[
              const SizedBox(height: 8),
              Text(
                _mediaError!,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 22),
            Text('记录方式', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 4),
            _InlineSelector<V2ProgressKind>(
              key: const Key('v2-progress-kind-selector'),
              value: _kind,
              values: V2ProgressKind.values,
              label: (value) => value.label,
              onChanged: (value) => setState(() {
                _kind = value;
                if (value != V2ProgressKind.assessment) {
                  _assessmentResult = null;
                }
              }),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 180),
              child: _kind == V2ProgressKind.assessment
                  ? Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: _InlineSelector<V2AssessmentResult>(
                        key: const Key('v2-assessment-selector'),
                        value: _assessmentResult,
                        values: V2AssessmentResult.values,
                        label: (value) => value.label,
                        onChanged: (value) =>
                            setState(() => _assessmentResult = value),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            if (widget.canCompleteCurrentAction) ...[
              const SizedBox(height: 18),
              InkWell(
                key: const Key('v2-complete-current-action'),
                onTap: _nextStep == V2NextStep.close
                    ? null
                    : () => setState(
                        () => _completeCurrentAction = !_completeCurrentAction,
                      ),
                borderRadius: BorderRadius.circular(5),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Checkbox(
                        value: _nextStep == V2NextStep.close
                            ? false
                            : _completeCurrentAction,
                        onChanged: _nextStep == V2NextStep.close
                            ? null
                            : (value) => setState(
                                () => _completeCurrentAction = value ?? false,
                              ),
                      ),
                      const SizedBox(width: 4),
                      const Expanded(child: Text('同时完成当前待办')),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 26),
            Text('下一步', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            for (final step in V2NextStep.values)
              _QuietRadioRow(
                key: ValueKey('v2-next-step-${step.name}'),
                label: step.label,
                selected: _nextStep == step,
                onTap: () => setState(() {
                  _nextStep = step;
                  if (step == V2NextStep.close) {
                    _completeCurrentAction = false;
                  }
                }),
              ),
            AnimatedSize(
              duration: const Duration(milliseconds: 180),
              alignment: Alignment.topCenter,
              child: switch (_nextStep) {
                V2NextStep.continueTracking => const SizedBox.shrink(),
                V2NextStep.remind => Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Column(
                    children: [
                      TextField(
                        key: const Key('v2-reminder-title'),
                        controller: _reminderController,
                        decoration: const InputDecoration(
                          labelText: '提醒内容（可选）',
                          hintText: '例如：再检查一次同类题',
                        ),
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton.icon(
                          key: const Key('v2-reminder-date'),
                          onPressed: _chooseReminderDate,
                          icon: const Icon(
                            Icons.calendar_today_outlined,
                            size: 17,
                          ),
                          label: Text(
                            _reminderDate == null
                                ? '选择日期'
                                : '${_reminderDate!.month} 月 ${_reminderDate!.day} 日',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                V2NextStep.close => Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: DropdownButtonFormField<V2CloseReason>(
                    initialValue: _closeReason,
                    decoration: const InputDecoration(labelText: '结束原因'),
                    items: V2CloseReason.values
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(value.label),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _closeReason = value);
                      }
                    },
                  ),
                ),
              },
            ),
          ],
        ),
      ),
    );
  }
}

class V2MediaDraftStrip extends StatelessWidget {
  const V2MediaDraftStrip({
    required this.attachments,
    required this.onAdd,
    required this.onRemove,
    super.key,
  });

  final List<PickedEvidenceAttachment> attachments;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            TextButton.icon(
              key: const Key('v2-media-add'),
              onPressed: attachments.length >= 3 ? null : onAdd,
              icon: const Icon(Icons.photo_camera_outlined, size: 18),
              label: Text(attachments.isEmpty ? '拍照 / 相册' : '继续添加'),
            ),
            const SizedBox(width: 6),
            Text(
              '${attachments.length}/3',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        if (attachments.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var index = 0; index < attachments.length; index++)
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(7),
                      child: Container(
                        width: 92,
                        height: 72,
                        decoration: BoxDecoration(
                          border: Border.all(color: scheme.outlineVariant),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Image.memory(
                          attachments[index].bytes,
                          fit: BoxFit.cover,
                          gaplessPlayback: true,
                        ),
                      ),
                    ),
                    Positioned(
                      right: -7,
                      top: -7,
                      child: Material(
                        color: scheme.surfaceContainerHighest,
                        shape: const CircleBorder(),
                        child: InkWell(
                          key: ValueKey('v2-media-remove-$index'),
                          customBorder: const CircleBorder(),
                          onTap: () => onRemove(index),
                          child: const SizedBox(
                            width: 26,
                            height: 26,
                            child: Icon(Icons.close, size: 15),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _ComposerScaffold extends StatelessWidget {
  const _ComposerScaffold({
    required this.title,
    required this.contextLine,
    required this.onClose,
    required this.child,
    required this.footer,
  });

  final String title;
  final String contextLine;
  final VoidCallback? onClose;
  final Widget child;
  final Widget footer;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final body = AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 14, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 5),
                        Text(
                          contextLine,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: onClose == null ? '正在保存' : '关闭',
                    onPressed: onClose,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Divider(
              height: 1,
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
                child: child,
              ),
            ),
            Divider(
              height: 1,
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            footer,
          ],
        ),
      ),
    );
    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          onClose?.call();
        }
      },
      child: body,
    );
  }
}

class _ComposerFooter extends StatelessWidget {
  const _ComposerFooter({
    required this.primaryLabel,
    required this.onPrimary,
    required this.saving,
    required this.previewMode,
    this.errorText,
  });

  final String primaryLabel;
  final VoidCallback? onPrimary;
  final bool saving;
  final bool previewMode;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final error = errorText?.trim();
    final note = Text(
      error != null && error.isNotEmpty
          ? error
          : previewMode
          ? 'V2 预览 · 不写入正式学情'
          : '保存到学生成长记录',
      key: const Key('v2-composer-save-status'),
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: error != null && error.isNotEmpty
            ? Theme.of(context).colorScheme.error
            : null,
      ),
    );
    final action = FilledButton(
      onPressed: saving ? null : onPrimary,
      child: saving
          ? const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 15,
                  height: 15,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 8),
                Text('保存中…'),
              ],
            )
          : Text(primaryLabel),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 360;
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [note, const SizedBox(height: 8), action],
            );
          }
          return Row(
            children: [
              Expanded(child: note),
              const SizedBox(width: 16),
              action,
            ],
          );
        },
      ),
    );
  }
}

class _InlineSelector<T> extends StatelessWidget {
  const _InlineSelector({
    required this.value,
    required this.values,
    required this.label,
    required this.onChanged,
    super.key,
  });

  final T? value;
  final List<T> values;
  final String Function(T value) label;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        for (final option in values)
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => onChanged(option),
              borderRadius: BorderRadius.circular(5),
              child: Container(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 7),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      width: 2,
                      color: option == value
                          ? scheme.primary
                          : Colors.transparent,
                    ),
                  ),
                ),
                child: Text(
                  label(option),
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: option == value
                        ? scheme.primary
                        : scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _QuietRadioRow extends StatelessWidget {
  const _QuietRadioRow({
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(5),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 16,
              height: 16,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? scheme.primary : scheme.outline,
                  width: 1.4,
                ),
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? scheme.primary : Colors.transparent,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
