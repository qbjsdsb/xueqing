from pathlib import Path

path = Path('lib/features/design_v2/v2_composers.dart')
text = path.read_text()

adaptive_marker = 'Future<T?> _showAdaptiveComposer<T>('
quick_marker = 'class V2QuickCaptureComposer extends StatefulWidget {'
progress_marker = 'class V2ProgressComposer extends StatefulWidget {'
media_marker = 'class V2MediaDraftStrip extends StatelessWidget {'
scaffold_marker = 'class _ComposerScaffold extends StatelessWidget {'
footer_marker = 'class _ComposerFooter extends StatelessWidget {'
selector_marker = 'class _InlineSelector<T> extends StatelessWidget {'

for marker in [adaptive_marker, quick_marker, progress_marker, media_marker, scaffold_marker, footer_marker, selector_marker]:
    if text.count(marker) != 1:
        raise SystemExit(f'{marker}: expected exactly one match, found {text.count(marker)}')

header = r'''import 'package:flutter/material.dart';

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
        content: Text(
          onSave == null ? 'V2 预览：记录已完成，但没有写入正式学情。' : '已记录问题。',
        ),
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
          onSave: onSave,
          attachmentPicker: attachmentPicker,
        ),
      ) ??
      false;
  if (saved && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          onSave == null ? 'V2 预览：进展已完成，但没有写入正式学情。' : '已保存进展。',
        ),
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

'''

adaptive_start = text.index(adaptive_marker)
text = header + text[adaptive_start:]

quick_start = text.index(quick_marker)
progress_start = text.index(progress_marker)
quick_block = r'''class V2QuickCaptureComposer extends StatefulWidget {
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

  @override
  Widget build(BuildContext context) {
    return _ComposerScaffold(
      title: '记录新问题',
      contextLine: _selectedSubject == null
          ? widget.studentName
          : '${widget.studentName} · $_selectedSubject',
      onClose: _saving ? null : () => Navigator.of(context).pop(false),
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
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
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

'''
text = text[:quick_start] + quick_block + text[progress_start:]

progress_start = text.index(progress_marker)
media_start = text.index(media_marker)
progress_block = r'''class V2ProgressComposer extends StatefulWidget {
  const V2ProgressComposer({
    required this.studentName,
    required this.subject,
    required this.caseTitle,
    required this.attachmentPicker,
    this.canCompleteCurrentAction = false,
    this.onSave,
    super.key,
  });

  final String studentName;
  final String subject;
  final String caseTitle;
  final V2AttachmentPicker attachmentPicker;
  final bool canCompleteCurrentAction;
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
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _reminderDate ?? now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 2, 12, 31),
      helpText: '选择再次检查日期',
      cancelText: '取消',
      confirmText: '确定',
    );
    if (selected != null && mounted) {
      setState(() => _reminderDate = selected);
    }
  }

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

  @override
  Widget build(BuildContext context) {
    return _ComposerScaffold(
      title: '记录进展',
      contextLine:
          '${widget.studentName} · ${widget.subject}\n${widget.caseTitle}',
      onClose: _saving ? null : () => Navigator.of(context).pop(false),
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
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
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

'''
text = text[:progress_start] + progress_block + text[media_start:]

scaffold_start = text.index(scaffold_marker)
footer_start = text.index(footer_marker)
scaffold_block = r'''class _ComposerScaffold extends StatelessWidget {
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
    return AnimatedPadding(
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
  }
}

'''
text = text[:scaffold_start] + scaffold_block + text[footer_start:]

footer_start = text.index(footer_marker)
selector_start = text.index(selector_marker)
footer_block = r'''class _ComposerFooter extends StatelessWidget {
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
          return Row(children: [Expanded(child: note), const SizedBox(width: 16), action]);
        },
      ),
    );
  }
}

'''
text = text[:footer_start] + footer_block + text[selector_start:]

path.write_text(text)

# Extend the controller with a safe read-only capability needed by the UI.
controller_path = Path('lib/features/design_v2/v2_workflow_controller.dart')
controller = controller_path.read_text()
needle = '''  List<V2CaseTypeChoice> get caseTypeChoices {\n'''
if controller.count(needle) != 1:
    raise SystemExit(f'controller insertion point: expected 1, found {controller.count(needle)}')
controller = controller.replace(
    needle,
    '''  bool hasPendingPrimaryAction(String caseId) =>\n      _caseFor(caseId).primaryAction != null;\n\n  List<V2CaseTypeChoice> get caseTypeChoices {\n''',
    1,
)
controller_path.write_text(controller)

# Add a focused retry-safety test to the existing composer tests.
test_path = Path('test/features/design_v2_composers_test.dart')
test = test_path.read_text()
if "import 'dart:typed_data';" not in test:
    test = "import 'dart:typed_data';\n\n" + test
if "evidence_attachment_picker.dart" not in test:
    test = test.replace(
        "import 'package:xueqing/features/design_v2/v2_composers.dart';\n",
        "import 'package:xueqing/features/design_v2/v2_composers.dart';\n"
        "import 'package:xueqing/features/teacher_workspace/presentation/evidence_attachment_picker.dart';\n",
        1,
    )
closing = '\n}\n'
if not test.endswith(closing):
    raise SystemExit('composer test file did not end with expected group brace')
new_test = r'''

  testWidgets(
    'writable Quick Capture keeps text and photo when save fails, then retries',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      var attempts = 0;
      final drafts = <V2QuickCaptureDraft>[];
      final attachment = PickedEvidenceAttachment(
        attachmentId: '00000000-0000-4000-8000-000000000001',
        bytes: Uint8List.fromList([1, 2, 3]),
        fileName: 'work.jpg',
        contentType: 'image/jpeg',
      );

      await tester.pumpWidget(
        app(
          Builder(
            builder: (context) => FilledButton(
              onPressed: () => showV2QuickCapture(
                context,
                studentName: '林同学',
                subjects: const ['语文'],
                problemTypes: const [
                  V2ProblemTypeOption(
                    key: 'unclassified',
                    label: '暂不分类',
                  ),
                  V2ProblemTypeOption(
                    key: 'custom-reading',
                    label: '阅读理解',
                  ),
                ],
                attachmentPicker: (_) async => attachment,
                onSave: (draft) async {
                  attempts += 1;
                  drafts.add(draft);
                  if (attempts == 1) {
                    throw Exception('network timeout');
                  }
                },
              ),
              child: const Text('打开写入'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('打开写入'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('v2-quick-capture-body')),
        '概括题遗漏结果。',
      );
      await tester.tap(find.byKey(const Key('v2-media-add')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('v2-media-remove-0')), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, '记录问题'));
      await tester.pumpAndSettle();

      expect(attempts, 1);
      expect(find.text('记录新问题'), findsOneWidget);
      expect(find.text('概括题遗漏结果。'), findsOneWidget);
      expect(find.byKey(const ValueKey('v2-media-remove-0')), findsOneWidget);
      expect(
        find.text('网络暂时不可用，当前文字和图片仍然保留，可以直接重试。'),
        findsOneWidget,
      );

      await tester.tap(find.widgetWithText(FilledButton, '记录问题'));
      await tester.pumpAndSettle();

      expect(attempts, 2);
      expect(drafts, hasLength(2));
      expect(drafts[0].body, drafts[1].body);
      expect(drafts[0].attachments.single.attachmentId,
          drafts[1].attachments.single.attachmentId);
      expect(find.text('记录新问题'), findsNothing);
    },
  );
'''
test = test[:-len(closing)] + new_test + closing
test_path.write_text(test)
