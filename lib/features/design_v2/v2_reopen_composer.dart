import 'package:flutter/material.dart';

import '../../app/layout/responsive.dart';
import 'v2_workflow_controller.dart';

class V2ReopenComposerDraft {
  const V2ReopenComposerDraft({
    required this.recurrenceSummary,
    required this.nextActionTitle,
    required this.nextActionDueOn,
  });

  final String recurrenceSummary;
  final String nextActionTitle;
  final DateTime? nextActionDueOn;
}

typedef V2ReopenSave = Future<void> Function(V2ReopenComposerDraft draft);

Future<bool> showV2ReopenCaseComposer(
  BuildContext context, {
  required String studentName,
  required String subject,
  required String caseTitle,
  required DateTime businessDate,
  V2ReopenDraftSnapshot? pendingDraft,
  required V2ReopenSave onSave,
}) async {
  final child = V2ReopenCaseComposer(
    studentName: studentName,
    subject: subject,
    caseTitle: caseTitle,
    businessDate: businessDate,
    pendingDraft: pendingDraft,
    onSave: onSave,
  );
  if (ResponsiveBreakpoints.isCompact(context)) {
    return await showModalBottomSheet<bool>(
          context: context,
          useSafeArea: true,
          isScrollControlled: true,
          isDismissible: false,
          enableDrag: false,
          builder: (_) => child,
        ) ??
        false;
  }
  return await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: child,
          ),
        ),
      ) ??
      false;
}

class V2ReopenCaseComposer extends StatefulWidget {
  const V2ReopenCaseComposer({
    required this.studentName,
    required this.subject,
    required this.caseTitle,
    required this.businessDate,
    required this.onSave,
    this.pendingDraft,
    super.key,
  });

  final String studentName;
  final String subject;
  final String caseTitle;
  final DateTime businessDate;
  final V2ReopenDraftSnapshot? pendingDraft;
  final V2ReopenSave onSave;

  @override
  State<V2ReopenCaseComposer> createState() => _V2ReopenCaseComposerState();
}

class _V2ReopenCaseComposerState extends State<V2ReopenCaseComposer> {
  late final TextEditingController _summaryController;
  late final TextEditingController _actionController;
  DateTime? _dueOn;
  bool _saving = false;
  bool _attempted = false;
  String? _error;

  bool get _resumeMode => widget.pendingDraft != null;
  bool get _locked => _resumeMode || _attempted || _saving;

  DateTime get _businessDay => DateTime(
    widget.businessDate.year,
    widget.businessDate.month,
    widget.businessDate.day,
  );

  @override
  void initState() {
    super.initState();
    final pending = widget.pendingDraft;
    _summaryController = TextEditingController(
      text: pending?.recurrenceSummary ?? '',
    );
    _actionController = TextEditingController(
      text: pending?.nextActionTitle ?? '再次检查并继续跟进',
    );
    _dueOn = pending?.nextActionDueOn;
  }

  @override
  void dispose() {
    _summaryController.dispose();
    _actionController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    if (_locked) return;
    final today = _businessDay;
    final current = _dueOn;
    final initial = current != null && !current.isBefore(today)
        ? current
        : today;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: today,
      lastDate: DateTime(today.year + 3, 12, 31),
      helpText: '选择下一次跟进日期',
      cancelText: '取消',
      confirmText: '确定',
    );
    if (picked != null && mounted) {
      setState(() => _dueOn = DateTime(picked.year, picked.month, picked.day));
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    final summary = _summaryController.text.trim();
    final action = _actionController.text.trim();
    if (summary.isEmpty || action.isEmpty) {
      setState(() {
        _error = summary.isEmpty ? '请先写清楚这次为什么需要重新跟进。' : '请写清楚下一步准备做什么。';
      });
      return;
    }
    setState(() {
      _saving = true;
      _attempted = true;
      _error = null;
    });
    try {
      await widget.onSave(
        V2ReopenComposerDraft(
          recurrenceSummary: summary,
          nextActionTitle: action,
          nextActionDueOn: _dueOn,
        ),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = _describeReopenError(error);
      });
    }
  }

  Future<void> _close() async {
    if (_saving) return;
    if (!_attempted && !_resumeMode) {
      Navigator.of(context).pop(false);
      return;
    }
    final retry = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('这次重新跟进还没有完整结束'),
        content: const Text('系统已经保留这次操作。为了避免重复记录“再次出现”的证据，建议直接继续保存，不要重新填写一份。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('稍后继续'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('继续保存'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (retry == true) {
      await _save();
    } else {
      Navigator.of(context).pop(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = _dueOn == null
        ? '暂不设日期'
        : '${_dueOn!.month} 月 ${_dueOn!.day} 日';
    return PopScope<void>(
      canPop: !_saving && !_attempted && !_resumeMode,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_saving) _close();
      },
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('再次出现，重新跟进', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              '${widget.studentName} · ${widget.subject} · ${widget.caseTitle}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (_resumeMode) ...[
              const SizedBox(height: 14),
              Text(
                '检测到上次未完成的重新跟进。为避免重复证据，下面内容按原操作恢复，只需继续保存。',
                key: const Key('v2-reopen-resume-note'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 20),
            TextField(
              key: const Key('v2-reopen-summary'),
              controller: _summaryController,
              enabled: !_locked,
              minLines: 3,
              maxLines: 6,
              textInputAction: TextInputAction.newline,
              decoration: const InputDecoration(
                labelText: '为什么又出现了？',
                hintText: '写这次观察到的具体表现，不需要重复抄旧记录。',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('v2-reopen-next-action'),
              controller: _actionController,
              enabled: !_locked,
              decoration: const InputDecoration(labelText: '下一步准备做什么？'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('v2-reopen-pick-date'),
                    onPressed: _locked ? null : _pickDate,
                    icon: const Icon(Icons.event_outlined),
                    label: Text(dateLabel),
                  ),
                ),
                if (_dueOn != null) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: '清除日期',
                    onPressed: _locked
                        ? null
                        : () => setState(() => _dueOn = null),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '系统会先把“再次出现”记录为一条新证据，再重新开启这个问题；两步使用同一份可恢复操作，不会因为重试重复记录。',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (_error != null) ...[
              const SizedBox(height: 14),
              Text(
                _error!,
                key: const Key('v2-reopen-save-error'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saving ? null : _close,
                    child: Text(_resumeMode || _attempted ? '稍后继续' : '取消'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    key: const Key('v2-reopen-save'),
                    onPressed: _saving ? null : _save,
                    child: Text(
                      _saving
                          ? '保存中…'
                          : _resumeMode || _attempted
                          ? '继续保存'
                          : '重新跟进',
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

String _describeReopenError(Object error) {
  if (error is V2WorkflowSaveException) {
    return error.userMessage;
  }
  final detail = error.toString().toLowerCase();
  if (detail.contains('version_conflict')) {
    return '这个问题刚刚有变化，请刷新后再处理。';
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
  return '重新跟进尚未完整保存。内容已经保留，可以直接继续保存。';
}
