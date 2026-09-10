import 'package:flutter/material.dart';

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
        content: const Text('建议直接重新保存；系统会沿用这次操作，不会重复完成这一步。'),
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
            Text('完成这一步', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              widget.actionTitle,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
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
                      _saving
                          ? '保存中…'
                          : _attempted
                          ? '重新保存'
                          : '完成这一步',
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
            Text(
              widget.actionTitle,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
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
                      _saving
                          ? '保存中…'
                          : _attempted
                          ? '重新保存'
                          : '保存日期',
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
