import 'package:flutter/material.dart';

import '../cloud/learning_repository.dart';

/// Lets a teacher choose complete Learning Cases for one export without
/// changing any teaching or archive state.
Future<Set<String>?> showLearningRecordCasePicker(
  BuildContext context, {
  required String studentName,
  required String subjectName,
  required List<WorkspaceCase> cases,
}) async {
  if (cases.isEmpty) {
    return <String>{};
  }

  final sorted = List<WorkspaceCase>.of(cases)
    ..sort((left, right) {
      final leftClosed = left.status == LearningCaseStatus.closed;
      final rightClosed = right.status == LearningCaseStatus.closed;
      if (leftClosed != rightClosed) return leftClosed ? 1 : -1;
      return right.firstObservedAt.compareTo(left.firstObservedAt);
    });

  final compact = MediaQuery.sizeOf(context).width < 720;
  final result = compact
      ? await showModalBottomSheet<Set<String>>(
          context: context,
          useSafeArea: true,
          showDragHandle: true,
          isScrollControlled: true,
          builder: (sheetContext) => FractionallySizedBox(
            heightFactor: 0.88,
            child: _LearningRecordCasePicker(
              studentName: studentName,
              subjectName: subjectName,
              cases: sorted,
            ),
          ),
        )
      : await showDialog<Set<String>>(
          context: context,
          builder: (dialogContext) => Dialog(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680, maxHeight: 720),
              child: _LearningRecordCasePicker(
                studentName: studentName,
                subjectName: subjectName,
                cases: sorted,
              ),
            ),
          ),
        );
  return result == null ? null : Set<String>.unmodifiable(result);
}

class _LearningRecordCasePicker extends StatefulWidget {
  const _LearningRecordCasePicker({
    required this.studentName,
    required this.subjectName,
    required this.cases,
  });

  final String studentName;
  final String subjectName;
  final List<WorkspaceCase> cases;

  @override
  State<_LearningRecordCasePicker> createState() =>
      _LearningRecordCasePickerState();
}

class _LearningRecordCasePickerState
    extends State<_LearningRecordCasePicker> {
  late Set<String> _selectedIds;

  @override
  void initState() {
    super.initState();
    _selectedIds = {for (final item in widget.cases) item.id};
  }

  void _selectWhere(bool Function(WorkspaceCase item) predicate) {
    setState(() {
      _selectedIds = {
        for (final item in widget.cases)
          if (predicate(item)) item.id,
      };
    });
  }

  String _dateLabel(DateTime value) =>
      '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedCount = _selectedIds.length;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '选择要导出的学情',
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${widget.studentName} · ${widget.subjectName}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: '关闭',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '只决定这一次 Excel 的范围，不会结束、删除或修改任何学情。',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  key: const Key('export-cases-select-all'),
                  onPressed: () => _selectWhere((_) => true),
                  child: const Text('全选'),
                ),
                OutlinedButton(
                  key: const Key('export-cases-select-none'),
                  onPressed: () => _selectWhere((_) => false),
                  child: const Text('清空'),
                ),
                OutlinedButton(
                  key: const Key('export-cases-select-open'),
                  onPressed: () => _selectWhere(
                    (item) => item.status != LearningCaseStatus.closed,
                  ),
                  child: const Text('仅进行中'),
                ),
                OutlinedButton(
                  key: const Key('export-cases-select-history'),
                  onPressed: () => _selectWhere(
                    (item) => item.status == LearningCaseStatus.closed,
                  ),
                  child: const Text('仅历史'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Divider(color: theme.colorScheme.outlineVariant),
            Expanded(
              child: ListView.separated(
                itemCount: widget.cases.length,
                separatorBuilder: (_, _) => Divider(
                  height: 1,
                  color: theme.colorScheme.outlineVariant,
                ),
                itemBuilder: (context, index) {
                  final item = widget.cases[index];
                  final closed = item.status == LearningCaseStatus.closed;
                  return CheckboxListTile(
                    key: ValueKey<String>('export-case-${item.id}'),
                    value: _selectedIds.contains(item.id),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (selected) {
                      setState(() {
                        if (selected == true) {
                          _selectedIds.add(item.id);
                        } else {
                          _selectedIds.remove(item.id);
                        }
                      });
                    },
                    title: Text(item.title),
                    subtitle: Text(
                      '${closed ? '已结束' : item.status.label} · ${_dateLabel(item.firstObservedAt)}',
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '已选择 $selectedCount / ${widget.cases.length} 条学情',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                FilledButton.icon(
                  key: const Key('export-selected-cases'),
                  onPressed: selectedCount == 0
                      ? null
                      : () => Navigator.of(context).pop(_selectedIds),
                  icon: const Icon(Icons.download_outlined, size: 18),
                  label: Text('导出 $selectedCount 条学情'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
