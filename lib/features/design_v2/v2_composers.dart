import 'package:flutter/material.dart';

import '../teacher_workspace/presentation/evidence_attachment_picker.dart';

typedef V2AttachmentPicker = Future<PickedEvidenceAttachment?> Function(
  BuildContext context,
);

enum V2ProgressKind { observation, intervention, assessment }

extension V2ProgressKindLabel on V2ProgressKind {
  String get label => switch (this) {
    V2ProgressKind.observation => '新表现',
    V2ProgressKind.intervention => '教学处理',
    V2ProgressKind.assessment => '检查结果',
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

Future<void> showV2QuickCapture(
  BuildContext context, {
  required String studentName,
  required List<String> subjects,
  V2AttachmentPicker attachmentPicker = pickEvidenceAttachment,
}) async {
  assert(subjects.isNotEmpty);
  final saved = await _showAdaptiveComposer<bool>(
    context,
    child: V2QuickCaptureComposer(
      studentName: studentName,
      subjects: subjects,
      attachmentPicker: attachmentPicker,
    ),
  );
  if (saved == true && context.mounted) {
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('V2 预览：记录已完成，但没有写入正式学情。')));
  }
}

Future<void> showV2ProgressComposer(
  BuildContext context, {
  required String studentName,
  required String subject,
  required String caseTitle,
  V2AttachmentPicker attachmentPicker = pickEvidenceAttachment,
}) async {
  final saved = await _showAdaptiveComposer<bool>(
    context,
    child: V2ProgressComposer(
      studentName: studentName,
      subject: subject,
      caseTitle: caseTitle,
      attachmentPicker: attachmentPicker,
    ),
  );
  if (saved == true && context.mounted) {
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('V2 预览：进展已完成，但没有写入正式学情。')));
  }
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
    required this.attachmentPicker,
    super.key,
  });

  final String studentName;
  final List<String> subjects;
  final V2AttachmentPicker attachmentPicker;

  @override
  State<V2QuickCaptureComposer> createState() => _V2QuickCaptureComposerState();
}

class _V2QuickCaptureComposerState extends State<V2QuickCaptureComposer> {
  final _controller = TextEditingController();
  final _attachments = <PickedEvidenceAttachment>[];
  String? _selectedSubject;
  bool _showMore = false;
  String _problemType = '暂不分类';
  String? _mediaError;

  @override
  void initState() {
    super.initState();
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
    if (_attachments.length >= 3) {
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
      _selectedSubject != null && _controller.text.trim().isNotEmpty;

  void _save() {
    if (_canSave) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _ComposerScaffold(
      title: '记录新问题',
      contextLine: _selectedSubject == null
          ? widget.studentName
          : '${widget.studentName} · $_selectedSubject',
      onClose: () => Navigator.of(context).pop(false),
      footer: _ComposerFooter(
        primaryLabel: '记录问题',
        onPrimary: _canSave ? _save : null,
      ),
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
                      initialValue: _problemType,
                      decoration: const InputDecoration(labelText: '问题类型'),
                      items: const ['暂不分类', '基础知识', '阅读理解', '写作', '学习习惯', '其他']
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(value),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _problemType = value);
                        }
                      },
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
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
    super.key,
  });

  final String studentName;
  final String subject;
  final String caseTitle;
  final V2AttachmentPicker attachmentPicker;

  @override
  State<V2ProgressComposer> createState() => _V2ProgressComposerState();
}

class _V2ProgressComposerState extends State<V2ProgressComposer> {
  final _controller = TextEditingController();
  final _reminderController = TextEditingController();
  final _attachments = <PickedEvidenceAttachment>[];
  V2ProgressKind _kind = V2ProgressKind.observation;
  V2NextStep _nextStep = V2NextStep.continueTracking;
  String? _assessmentResult;
  String _closeReason = '问题已解决';
  DateTime? _reminderDate;
  String? _mediaError;

  @override
  void dispose() {
    _controller.dispose();
    _reminderController.dispose();
    super.dispose();
  }

  Future<void> _pickAttachment() async {
    if (_attachments.length >= 3) {
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
    if (_controller.text.trim().isEmpty) {
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

  void _save() {
    if (_canSave) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _ComposerScaffold(
      title: '记录进展',
      contextLine:
          '${widget.studentName} · ${widget.subject}\n${widget.caseTitle}',
      onClose: () => Navigator.of(context).pop(false),
      footer: _ComposerFooter(
        primaryLabel: '保存进展',
        onPrimary: _canSave ? _save : null,
      ),
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
                    child: _InlineSelector<String>(
                      key: const Key('v2-assessment-selector'),
                      value: _assessmentResult,
                      values: const ['通过', '部分通过', '未通过'],
                      label: (value) => value,
                      onChanged: (value) =>
                          setState(() => _assessmentResult = value),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          const SizedBox(height: 26),
          Text('下一步', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          for (final step in V2NextStep.values)
            _QuietRadioRow(
              key: ValueKey('v2-next-step-${step.name}'),
              label: step.label,
              selected: _nextStep == step,
              onTap: () => setState(() => _nextStep = step),
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
                child: DropdownButtonFormField<String>(
                  initialValue: _closeReason,
                  decoration: const InputDecoration(labelText: '结束原因'),
                  items: const ['问题已解决', '暂不继续跟进', '确认不是问题', '其他']
                      .map(
                        (value) =>
                            DropdownMenuItem(value: value, child: Text(value)),
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
  final VoidCallback onClose;
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
                    tooltip: '关闭',
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

class _ComposerFooter extends StatelessWidget {
  const _ComposerFooter({required this.primaryLabel, required this.onPrimary});

  final String primaryLabel;
  final VoidCallback? onPrimary;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 360;
          final note = Text(
            'V2 预览 · 不写入正式学情',
            style: Theme.of(context).textTheme.bodySmall,
          );
          final action = FilledButton(
            onPressed: onPrimary,
            child: Text(primaryLabel),
          );
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [note, const SizedBox(height: 8), action],
            );
          }
          return Row(children: [note, const Spacer(), action]);
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
