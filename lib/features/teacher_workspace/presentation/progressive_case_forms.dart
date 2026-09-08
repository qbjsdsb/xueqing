import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../../app/layout/responsive.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../cloud/learning_repository.dart';
import '../../../cloud/progressive_case_repository.dart';

Future<ProgressiveCaseReceipt?> showCaseProgressForm(
  BuildContext context, {
  required ProgressiveCaseRepository repository,
  required WorkspaceCase learningCase,
  WorkspaceAction? currentAction,
  bool completeCurrentActionInitially = false,
  DateTime? businessDate,
}) {
  final form = CaseProgressForm(
    repository: repository,
    learningCase: learningCase,
    currentAction: currentAction,
    completeCurrentActionInitially: completeCurrentActionInitially,
    businessDate: businessDate,
  );
  final sizeClass = ResponsiveBreakpoints.classify(
    MediaQuery.sizeOf(context).width,
  );
  if (sizeClass == WindowSizeClass.compact) {
    return showModalBottomSheet<ProgressiveCaseReceipt>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      clipBehavior: Clip.antiAlias,
      builder: (_) => form,
    );
  }
  return showDialog<ProgressiveCaseReceipt>(
    context: context,
    barrierDismissible: false,
    builder: (_) => Dialog(child: form),
  );
}

Future<ProgressiveCaseReceipt?> showEndCaseFollowUpForm(
  BuildContext context, {
  required ProgressiveCaseRepository repository,
  required WorkspaceCase learningCase,
}) {
  final form = EndCaseFollowUpForm(
    repository: repository,
    learningCase: learningCase,
  );
  final sizeClass = ResponsiveBreakpoints.classify(
    MediaQuery.sizeOf(context).width,
  );
  if (sizeClass == WindowSizeClass.compact) {
    return showModalBottomSheet<ProgressiveCaseReceipt>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      clipBehavior: Clip.antiAlias,
      builder: (_) => form,
    );
  }
  return showDialog<ProgressiveCaseReceipt>(
    context: context,
    barrierDismissible: false,
    builder: (_) => Dialog(child: form),
  );
}

class CaseProgressForm extends StatefulWidget {
  const CaseProgressForm({
    required this.repository,
    required this.learningCase,
    this.currentAction,
    this.completeCurrentActionInitially = false,
    this.businessDate,
    super.key,
  });

  final ProgressiveCaseRepository repository;
  final WorkspaceCase learningCase;
  final WorkspaceAction? currentAction;
  final bool completeCurrentActionInitially;
  final DateTime? businessDate;

  @override
  State<CaseProgressForm> createState() => _CaseProgressFormState();
}

class _CaseProgressFormState extends State<CaseProgressForm> {
  late final TextEditingController _summaryController;
  late final TextEditingController _reminderController;
  late final TextEditingController _closeNoteController;
  late final String _operationId;

  CaseProgressKind _kind = CaseProgressKind.observation;
  CaseAssessmentResult? _assessmentResult;
  CaseProgressNextStep _nextStep = CaseProgressNextStep.continueTracking;
  CaseClosureReason _closureReason = CaseClosureReason.other;
  late bool _completeCurrentAction;
  DateTime? _reminderDueOn;
  String? _summaryError;
  String? _assessmentError;
  String? _reminderError;
  String? _saveError;
  bool _saving = false;
  bool _submissionAttempted = false;
  bool _showRecordOptions = false;
  bool _showNextStepOptions = false;
  bool _showClosureDetails = false;
  RecordCaseProgressCommand? _submittedCommand;

  bool get _inputsLocked => _saving || _submissionAttempted;

  bool get _isDirty =>
      _summaryController.text.trim().isNotEmpty ||
      _reminderController.text.trim().isNotEmpty ||
      _closeNoteController.text.trim().isNotEmpty ||
      _kind != CaseProgressKind.observation ||
      _nextStep != CaseProgressNextStep.continueTracking ||
      _assessmentResult != null ||
      _closureReason != CaseClosureReason.other ||
      _reminderDueOn != null ||
      _completeCurrentAction != widget.completeCurrentActionInitially;

  @override
  void initState() {
    super.initState();
    _operationId = createOperationId();
    _completeCurrentAction =
        widget.currentAction != null && widget.completeCurrentActionInitially;
    _summaryController = TextEditingController()..addListener(_clearErrors);
    _reminderController = TextEditingController()..addListener(_clearErrors);
    _closeNoteController = TextEditingController();
  }

  @override
  void dispose() {
    _summaryController
      ..removeListener(_clearErrors)
      ..dispose();
    _reminderController
      ..removeListener(_clearErrors)
      ..dispose();
    _closeNoteController.dispose();
    super.dispose();
  }

  void _clearErrors() {
    if (!mounted) {
      return;
    }
    final clearSummary =
        _summaryError != null && _summaryController.text.trim().isNotEmpty;
    final clearReminder =
        _reminderError != null && _reminderController.text.trim().isNotEmpty;
    if (clearSummary || clearReminder) {
      setState(() {
        if (clearSummary) {
          _summaryError = null;
        }
        if (clearReminder) {
          _reminderError = null;
        }
      });
    }
  }

  String get _summaryLabel => switch (_kind) {
    CaseProgressKind.observation => '这次有什么新情况？ *',
    CaseProgressKind.intervention => '这次怎么处理的？ *',
    CaseProgressKind.assessment => '补充说明（可选）',
  };

  String get _summaryHint => switch (_kind) {
    CaseProgressKind.observation => '写下学生这次真实出现的表现或变化',
    CaseProgressKind.intervention => '写下讲解、练习、提示或调整方式',
    CaseProgressKind.assessment => '写下能否独立完成、错在哪里、是否需要提示',
  };

  Future<void> _pickReminderDate() async {
    if (_inputsLocked) {
      return;
    }
    final businessNow = widget.businessDate ?? DateTime.now();
    final today = DateTime(
      businessNow.year,
      businessNow.month,
      businessNow.day,
    );
    final selected = await showDatePicker(
      context: context,
      initialDate: _reminderDueOn ?? today,
      firstDate: today,
      lastDate: DateTime(today.year + 2, 12, 31),
      helpText: '选择提醒日期',
      cancelText: '取消',
      confirmText: '确定',
    );
    if (!mounted || selected == null) {
      return;
    }
    setState(() {
      _reminderDueOn = DateTime(selected.year, selected.month, selected.day);
    });
  }

  RecordCaseProgressCommand? _buildCommand() {
    final summary = _summaryController.text.trim();
    final reminder = _reminderController.text.trim();
    var valid = true;
    if (summary.isEmpty && _kind != CaseProgressKind.assessment) {
      _summaryError = '请写下这次实际发生的情况';
      valid = false;
    }
    if (_kind == CaseProgressKind.assessment && _assessmentResult == null) {
      _assessmentError = '请选择这次检查结果';
      valid = false;
    }
    if (!valid) {
      setState(() {});
      return null;
    }

    final effectiveSummary =
        summary.isEmpty && _kind == CaseProgressKind.assessment
        ? '检查结果：${_assessmentResult!.label}'
        : summary;
    final action = widget.currentAction;
    return RecordCaseProgressCommand(
      operationId: _operationId,
      caseId: widget.learningCase.id,
      expectedCaseVersion: widget.learningCase.version,
      progressKind: _kind,
      summary: effectiveSummary,
      assessmentResult: _kind == CaseProgressKind.assessment
          ? _assessmentResult
          : null,
      completeCurrentAction: _completeCurrentAction,
      currentActionId: _completeCurrentAction ? action?.id : null,
      expectedActionVersion: _completeCurrentAction ? action?.version : null,
      nextStep: _nextStep,
      nextActionTitle:
          _nextStep == CaseProgressNextStep.remind && reminder.isNotEmpty
          ? reminder
          : null,
      nextActionDueOn: _nextStep == CaseProgressNextStep.remind
          ? _reminderDueOn
          : null,
      closeReason: _nextStep == CaseProgressNextStep.close
          ? _closureReason
          : null,
      closeNote:
          _nextStep == CaseProgressNextStep.close &&
              _closeNoteController.text.trim().isNotEmpty
          ? _closeNoteController.text.trim()
          : null,
    );
  }

  Future<void> _save() async {
    if (_saving) {
      return;
    }
    final command = _submittedCommand ?? _buildCommand();
    if (command == null) {
      return;
    }
    try {
      command.validate();
    } on ArgumentError catch (error) {
      setState(() => _saveError = error.message?.toString() ?? '请检查输入。');
      return;
    }

    _submittedCommand ??= command;
    setState(() {
      _saving = true;
      _submissionAttempted = true;
      _saveError = null;
    });
    try {
      final receipt = await widget.repository.recordProgress(command);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(receipt);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _saving = false;
        _saveError =
            '${describeProgressiveCaseError(error)}\n本次提交内容已锁定；重试会沿用同一 operation ID，不会重复记录。';
      });
    }
  }

  Future<void> _close() async {
    if (_saving) {
      return;
    }
    if (_submissionAttempted) {
      final retry = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('提交结果还没确认'),
          content: const Text('上一次提交可能已经到达服务器。建议重试原提交，不要重新填写另一份。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('继续查看'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('重试原提交'),
            ),
          ],
        ),
      );
      if (mounted && retry == true) {
        await _save();
      }
      return;
    }
    if (!_isDirty) {
      Navigator.of(context).pop();
      return;
    }
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('放弃这次进展记录？'),
        content: const Text('当前输入还没有保存。放弃后不会生成新的教学事实。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('继续编辑'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('放弃记录'),
          ),
        ],
      ),
    );
    if (mounted && discard == true) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final action = widget.currentAction;
    return PopScope<void>(
      canPop: !_isDirty && !_saving && !_submissionAttempted,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_saving) {
          unawaited(_close());
        }
      },
      child: SafeArea(
        child: AnimatedPadding(
          duration: const Duration(milliseconds: 180),
          padding: EdgeInsets.only(bottom: bottomInset),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          '记录进展',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      IconButton(
                        tooltip: '关闭',
                        onPressed: _saving ? null : _close,
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '先写下这次真实发生了什么。分类、提醒和结束跟进都按需要再选。',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _ContextLine(label: '当前问题', value: widget.learningCase.title),
                  if (action != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    _ContextLine(label: '当前待办', value: action.title),
                    SwitchListTile.adaptive(
                      key: const Key('progress-complete-current-action'),
                      contentPadding: EdgeInsets.zero,
                      title: const Text('这项待办已经完成'),
                      subtitle: const Text('保存进展时一起把这条待办标记为完成'),
                      value: _completeCurrentAction,
                      onChanged: _inputsLocked
                          ? null
                          : (value) =>
                                setState(() => _completeCurrentAction = value),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    key: const Key('progress-summary'),
                    controller: _summaryController,
                    autofocus: true,
                    enabled: !_inputsLocked,
                    minLines: 3,
                    maxLines: 7,
                    textInputAction: TextInputAction.newline,
                    decoration: InputDecoration(
                      labelText: _summaryLabel,
                      hintText: _summaryHint,
                      errorText: _summaryError,
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      key: const Key('progress-record-options-toggle'),
                      onPressed: _inputsLocked
                          ? null
                          : () => setState(
                              () => _showRecordOptions = !_showRecordOptions,
                            ),
                      icon: Icon(
                        _showRecordOptions
                            ? Icons.expand_less
                            : Icons.label_outline,
                      ),
                      label: Text(_showRecordOptions ? '收起记录方式' : '补充记录方式（可选）'),
                    ),
                  ),
                  if (_showRecordOptions) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: [
                        for (final kind in CaseProgressKind.values)
                          ChoiceChip(
                            key: ValueKey<String>(
                              'progress-kind-${kind.wireValue}',
                            ),
                            label: Text(kind.label),
                            selected: _kind == kind,
                            onSelected: _inputsLocked
                                ? null
                                : (_) => setState(() {
                                    _kind = kind;
                                    _summaryError = null;
                                    if (kind != CaseProgressKind.assessment) {
                                      _assessmentResult = null;
                                      _assessmentError = null;
                                    }
                                  }),
                          ),
                      ],
                    ),
                  ],
                  if (_kind == CaseProgressKind.assessment) ...[
                    const SizedBox(height: AppSpacing.md),
                    DropdownButtonFormField<CaseAssessmentResult>(
                      key: const Key('progress-assessment-result'),
                      initialValue: _assessmentResult,
                      decoration: InputDecoration(
                        labelText: '检查结果 *',
                        errorText: _assessmentError,
                      ),
                      items: [
                        for (final result in CaseAssessmentResult.values)
                          DropdownMenuItem<CaseAssessmentResult>(
                            value: result,
                            child: Text(result.label),
                          ),
                      ],
                      onChanged: _inputsLocked
                          ? null
                          : (result) {
                              if (result != null) {
                                setState(() {
                                  _assessmentResult = result;
                                  _assessmentError = null;
                                });
                              }
                            },
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '先明确选择检查结果；补充说明仍然可以不写。',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: AppSpacing.sm),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      key: const Key('progress-next-options-toggle'),
                      onPressed: _inputsLocked
                          ? null
                          : () => setState(
                              () =>
                                  _showNextStepOptions = !_showNextStepOptions,
                            ),
                      icon: Icon(
                        _showNextStepOptions
                            ? Icons.expand_less
                            : Icons.notifications_none_outlined,
                      ),
                      label: Text(
                        _showNextStepOptions ? '收起后续选项' : '需要提醒或结束跟进？',
                      ),
                    ),
                  ),
                  if (_showNextStepOptions) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: [
                        for (final step in CaseProgressNextStep.values)
                          ChoiceChip(
                            key: ValueKey<String>(
                              'progress-next-${step.wireValue}',
                            ),
                            label: Text(step.label),
                            selected: _nextStep == step,
                            onSelected: _inputsLocked
                                ? null
                                : (_) => setState(() {
                                    _nextStep = step;
                                    _reminderError = null;
                                  }),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(switch (_nextStep) {
                      CaseProgressNextStep.continueTracking =>
                        '默认不生成待办；之后有新情况再记录。',
                      CaseProgressNextStep.remind => '只有确实需要提醒自己时才生成一条待办。',
                      CaseProgressNextStep.close => '结束当前跟进，完整历史仍然保留。',
                    }, style: Theme.of(context).textTheme.bodySmall),
                  ],
                  if (_nextStep == CaseProgressNextStep.remind) ...[
                    const SizedBox(height: AppSpacing.md),
                    TextField(
                      key: const Key('progress-reminder-title'),
                      controller: _reminderController,
                      enabled: !_inputsLocked,
                      decoration: const InputDecoration(
                        labelText: '提醒内容（可选）',
                        hintText: '例如：下周抽查一次同类阅读题',
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '不写也可以，系统会生成一条中性提醒。',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            key: const Key('progress-reminder-date'),
                            onPressed: _inputsLocked ? null : _pickReminderDate,
                            icon: const Icon(Icons.event_outlined),
                            label: Text(
                              _reminderDueOn == null
                                  ? '提醒日期（可选）'
                                  : '提醒日期：${_formatDateOnly(_reminderDueOn!)}',
                            ),
                          ),
                        ),
                        if (_reminderDueOn != null) ...[
                          const SizedBox(width: AppSpacing.xs),
                          IconButton(
                            tooltip: '清除日期',
                            onPressed: _inputsLocked
                                ? null
                                : () => setState(() => _reminderDueOn = null),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ],
                    ),
                  ],
                  if (_nextStep == CaseProgressNextStep.close) ...[
                    const SizedBox(height: AppSpacing.md),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        key: const Key('progress-close-details-toggle'),
                        onPressed: _inputsLocked
                            ? null
                            : () => setState(
                                () =>
                                    _showClosureDetails = !_showClosureDetails,
                              ),
                        icon: Icon(
                          _showClosureDetails
                              ? Icons.expand_less
                              : Icons.notes_outlined,
                        ),
                        label: Text(
                          _showClosureDetails ? '收起结束说明' : '补充结束原因（可选）',
                        ),
                      ),
                    ),
                    if (_showClosureDetails) ...[
                      const SizedBox(height: AppSpacing.xs),
                      DropdownButtonFormField<CaseClosureReason>(
                        key: const Key('progress-close-reason'),
                        initialValue: _closureReason,
                        decoration: const InputDecoration(
                          labelText: '结束原因（可选）',
                        ),
                        items: [
                          for (final reason in CaseClosureReason.values)
                            DropdownMenuItem<CaseClosureReason>(
                              value: reason,
                              child: Text(reason.label),
                            ),
                        ],
                        onChanged: _inputsLocked
                            ? null
                            : (reason) {
                                if (reason != null) {
                                  setState(() => _closureReason = reason);
                                }
                              },
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextField(
                        key: const Key('progress-close-note'),
                        controller: _closeNoteController,
                        enabled: !_inputsLocked,
                        minLines: 2,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: '补充说明（可选）',
                          hintText: '只写对以后重新理解这个问题有帮助的内容',
                          alignLabelWithHint: true,
                        ),
                      ),
                    ],
                  ],
                  if (_saveError != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      _saveError!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _saving ? null : _close,
                          child: const Text('取消'),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: FilledButton(
                          key: const Key('progress-save'),
                          onPressed: _saving ? null : _save,
                          child: Text(
                            _saving
                                ? '保存中…'
                                : _submissionAttempted
                                ? '重试原提交'
                                : switch (_nextStep) {
                                    CaseProgressNextStep.continueTracking =>
                                      '保存记录',
                                    CaseProgressNextStep.remind => '保存并设置提醒',
                                    CaseProgressNextStep.close => '保存并结束跟进',
                                  },
                          ),
                        ),
                      ),
                    ],
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

class EndCaseFollowUpForm extends StatefulWidget {
  const EndCaseFollowUpForm({
    required this.repository,
    required this.learningCase,
    super.key,
  });

  final ProgressiveCaseRepository repository;
  final WorkspaceCase learningCase;

  @override
  State<EndCaseFollowUpForm> createState() => _EndCaseFollowUpFormState();
}

class _EndCaseFollowUpFormState extends State<EndCaseFollowUpForm> {
  late final TextEditingController _noteController;
  late final String _operationId;
  CaseClosureReason _reason = CaseClosureReason.other;
  EndCaseFollowUpCommand? _submittedCommand;
  String? _saveError;
  bool _saving = false;
  bool _submissionAttempted = false;
  bool _showClosureDetails = false;

  @override
  void initState() {
    super.initState();
    _operationId = createOperationId();
    _noteController = TextEditingController();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) {
      return;
    }
    _submittedCommand ??= EndCaseFollowUpCommand(
      operationId: _operationId,
      caseId: widget.learningCase.id,
      expectedCaseVersion: widget.learningCase.version,
      reason: _reason,
      note: _noteController.text.trim().isEmpty
          ? null
          : _noteController.text.trim(),
    );
    final command = _submittedCommand!;
    setState(() {
      _saving = true;
      _submissionAttempted = true;
      _saveError = null;
    });
    try {
      final receipt = await widget.repository.endFollowUp(command);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(receipt);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _saving = false;
        _saveError =
            '${describeProgressiveCaseError(error)}\n本次提交内容已锁定；重试会沿用同一 operation ID。';
      });
    }
  }

  Future<void> _close() async {
    if (_saving) {
      return;
    }
    if (_submissionAttempted) {
      final retry = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('提交结果还没确认'),
          content: const Text('上一次提交可能已经到达服务器。建议重试原提交。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('继续查看'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('重试原提交'),
            ),
          ],
        ),
      );
      if (mounted && retry == true) {
        await _save();
      }
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return PopScope<void>(
      canPop: !_saving && !_submissionAttempted,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_saving) {
          unawaited(_close());
        }
      },
      child: SafeArea(
        child: AnimatedPadding(
          duration: const Duration(milliseconds: 180),
          padding: EdgeInsets.only(bottom: bottomInset),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          '结束跟进',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      IconButton(
                        tooltip: '关闭',
                        onPressed: _saving ? null : _close,
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '结束的是这一次跟进，不会删除问题、学生表现、教学处理和检查记录。以后再次出现时仍可继续跟进。',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _ContextLine(label: '当前问题', value: widget.learningCase.title),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    '直接结束即可；默认只表示“这次先不继续跟进”，不代表问题已经解决。',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      key: const Key('end-follow-up-details-toggle'),
                      onPressed: _saving || _submissionAttempted
                          ? null
                          : () => setState(
                              () => _showClosureDetails = !_showClosureDetails,
                            ),
                      icon: Icon(
                        _showClosureDetails
                            ? Icons.expand_less
                            : Icons.notes_outlined,
                      ),
                      label: Text(
                        _showClosureDetails ? '收起结束说明' : '补充结束原因（可选）',
                      ),
                    ),
                  ),
                  if (_showClosureDetails) ...[
                    const SizedBox(height: AppSpacing.xs),
                    DropdownButtonFormField<CaseClosureReason>(
                      key: const Key('end-follow-up-reason'),
                      initialValue: _reason,
                      decoration: const InputDecoration(labelText: '结束原因（可选）'),
                      items: [
                        for (final reason in CaseClosureReason.values)
                          DropdownMenuItem<CaseClosureReason>(
                            value: reason,
                            child: Text(reason.label),
                          ),
                      ],
                      onChanged: _saving || _submissionAttempted
                          ? null
                          : (reason) {
                              if (reason != null) {
                                setState(() => _reason = reason);
                              }
                            },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextField(
                      key: const Key('end-follow-up-note'),
                      controller: _noteController,
                      enabled: !_saving && !_submissionAttempted,
                      minLines: 2,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        labelText: '补充说明（可选）',
                        hintText: '例如：连续两周未再出现，暂时结束跟进',
                        alignLabelWithHint: true,
                      ),
                    ),
                  ],
                  if (_saveError != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      _saveError!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _saving ? null : _close,
                          child: const Text('取消'),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: FilledButton(
                          key: const Key('end-follow-up-save'),
                          onPressed: _saving ? null : _save,
                          child: Text(
                            _saving
                                ? '保存中…'
                                : _submissionAttempted
                                ? '重试原提交'
                                : '结束跟进',
                          ),
                        ),
                      ),
                    ],
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

class _ContextLine extends StatelessWidget {
  const _ContextLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

String describeProgressiveCaseError(Object error) {
  final detail = error.toString().toLowerCase();
  if (detail.contains('invalid_live_session') ||
      detail.contains('no active session') ||
      detail.contains('not authenticated') ||
      detail.contains('signed out')) {
    return '登录状态已失效。请重新登录后再保存。';
  }
  if (detail.contains('teaching_fact_gate')) {
    return '当前账号已经失去这名学生的教学权限，请刷新后查看最新分配。';
  }
  if (detail.contains('owner_permission_required')) {
    return '当前账号不能修改这条问题，请刷新后确认责任教师。';
  }
  if (detail.contains('case_already_closed') ||
      detail.contains('case_closed')) {
    return '这个问题已经结束跟进，请刷新后查看最新状态。';
  }
  if (detail.contains('action_not_pending')) {
    return '当前待办已经被处理，请刷新后查看最新状态。';
  }
  if (detail.contains('action_not_found')) {
    return '当前待办已不存在，请刷新后再试。';
  }
  if (detail.contains('action_version_conflict')) {
    return '当前待办已经被更新，请刷新后再试。';
  }
  if (detail.contains('version_conflict')) {
    return '这个问题已经被更新，请刷新后确认最新情况。';
  }
  if (_isUnknownResultFailure(error)) {
    return '网络暂时不可用，服务器结果还不能确认。输入已经锁定，请直接重试原提交。';
  }
  return '保存失败。请重试；未确认成功前不会重复记录。';
}

bool _isUnknownResultFailure(Object error) {
  if (error is TimeoutException || error is SocketException) {
    return true;
  }
  final detail = error.toString().toLowerCase();
  return detail.contains('network') ||
      detail.contains('socket') ||
      detail.contains('timeout') ||
      detail.contains('connection reset') ||
      detail.contains('connection closed') ||
      detail.contains('failed host lookup') ||
      detail.contains('clientexception') ||
      detail.contains('status: 0') ||
      detail.contains('status: 502') ||
      detail.contains('status: 503') ||
      detail.contains('status: 504');
}

String _formatDateOnly(DateTime value) {
  final year = value.year.toString().padLeft(4, '0');
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}
