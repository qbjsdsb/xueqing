from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
WORKSPACE = ROOT / "lib/features/design_v2/v2_workspace_preview.dart"
DATA_TEST = ROOT / "test/features/design_v2_workspace_data_injection_test.dart"
ERGONOMICS_TEST = ROOT / "test/features/v2_final_ergonomics_test.dart"


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def write(path: Path, text: str) -> None:
    path.write_text(text, encoding="utf-8")


def replace_once(path: Path, old: str, new: str) -> None:
    text = read(path)
    count = text.count(old)
    if count != 1:
        raise SystemExit(
            f"{path}: expected exactly one match, found {count}: {old[:100]!r}"
        )
    write(path, text.replace(old, new, 1))


def replace_segment(path: Path, start: str, end: str, new_segment: str) -> None:
    text = read(path)
    start_index = text.find(start)
    if start_index < 0:
        raise SystemExit(f"{path}: missing segment start {start!r}")
    end_index = text.find(end, start_index + len(start))
    if end_index < 0:
        raise SystemExit(f"{path}: missing segment end {end!r}")
    write(path, text[:start_index] + new_segment + text[end_index:])


replace_once(
    WORKSPACE,
    """String _displayNextStep(String value) {
  final trimmed = value.trim();
  if (_visualContentKey(trimmed) == _visualContentKey('待安排下一步')) {
    return '待安排';
  }
  return trimmed;
}
""",
    """String _displayNextStep(String value) {
  final trimmed = value.trim();
  if (_visualContentKey(trimmed) == _visualContentKey('待安排下一步')) {
    return '待安排';
  }
  return trimmed;
}

String? _displayDueAlongsideNextStep(V2FocusItem item) {
  final dueLabel = item.dueLabel.trim();
  if (dueLabel.isEmpty) return null;

  final nextStep = _displayNextStep(item.nextStep);
  if (_visualContentKey(dueLabel) == _visualContentKey(nextStep)) {
    return null;
  }
  if (!item.closed &&
      _visualContentKey(dueLabel) == _visualContentKey('待安排')) {
    return '日期未定';
  }
  return dueLabel;
}
""",
)

replace_once(
    WORKSPACE,
    """              SizedBox(
                width: 336,
                child: _StudentListPane(
""",
    """              SizedBox(
                width: 320,
                child: _StudentListPane(
""",
)

replace_once(
    WORKSPACE,
    """            padding: EdgeInsets.fromLTRB(
              widget.compact ? 18 : 24,
              24,
              widget.compact ? 18 : 20,
              12,
            ),
""",
    """            padding: EdgeInsets.fromLTRB(
              widget.compact ? 18 : 24,
              widget.compact ? 18 : 24,
              widget.compact ? 18 : 20,
              widget.compact ? 8 : 12,
            ),
""",
)

replace_once(
    WORKSPACE,
    """                const SizedBox(height: 18),
                TextField(
                  key: const Key('v2-student-search'),
""",
    """                SizedBox(height: widget.compact ? 12 : 18),
                TextField(
                  key: const Key('v2-student-search'),
""",
)

replace_once(
    WORKSPACE,
    """                const SizedBox(height: 14),
                Text(
                  _query.trim().isEmpty
                      ? '全部 ${data.students.length}'
""",
    """                SizedBox(height: widget.compact ? 10 : 14),
                Text(
                  _query.trim().isEmpty
                      ? '全部 ${data.students.length}'
""",
)

replace_once(
    WORKSPACE,
    """                      return _StudentRow(
                        student: student,
                        selected: student.id == widget.selectedStudent.id,
                        onTap: () => widget.onSelected(student),
                      );
""",
    """                      return _StudentRow(
                        student: student,
                        selected: student.id == widget.selectedStudent.id,
                        compact: widget.compact,
                        onTap: () => widget.onSelected(student),
                      );
""",
)

student_row = r'''class _StudentRow extends StatelessWidget {
  const _StudentRow({
    required this.student,
    required this.selected,
    required this.onTap,
    this.compact = false,
  });

  final V2Student student;
  final bool selected;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasSecondaryUpdate =
        student.updatedLabel.trim().isNotEmpty &&
        student.updatedLabel.trim() != '暂无记录';
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: 2,
      ),
      child: AnimatedContainer(
        duration: AppMotion.effectiveDuration(context, AppMotion.quick),
        curve: AppMotion.enter,
        decoration: BoxDecoration(
          color: selected && !compact
              ? scheme.primary.withValues(alpha: 0.07)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(9),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 12 : 14,
                vertical: compact ? 10 : 12,
              ),
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
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
                            : '${student.openCaseCount} 个进行中',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (hasSecondaryUpdate) ...[
                        const SizedBox(height: 3),
                        Text(
                          student.updatedLabel,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant.withValues(
                              alpha: 0.72,
                            ),
                          ),
                        ),
                      ],
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

'''
replace_segment(
    WORKSPACE,
    "class _StudentRow extends StatelessWidget {",
    "class _InitialMark",
    student_row,
)

replace_once(
    WORKSPACE,
    """                constraints: const BoxConstraints(maxWidth: 900),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    widget.compact ? 18 : 32,
                    22,
                    widget.compact ? 18 : 32,
                    48,
                  ),
""",
    """                constraints: BoxConstraints(
                  maxWidth: widget.compact ? 900 : 1040,
                ),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    widget.compact ? 18 : 32,
                    widget.compact ? 16 : 22,
                    widget.compact ? 18 : 32,
                    widget.compact ? 40 : 48,
                  ),
""",
)

replace_once(
    WORKSPACE,
    """                      const SizedBox(height: 30),
                      _SectionTitle(
                        title: _showAllFocusItems ? '全部问题' : '现在最重要',
""",
    """                      SizedBox(height: widget.compact ? 24 : 30),
                      _SectionTitle(
                        title: _showAllFocusItems ? '全部问题' : '现在最重要',
""",
)

replace_once(
    WORKSPACE,
    """                          _FocusRow(
                            item: visibleFocusItems[i],
                            onTap: () =>
                                widget.onOpenCase(visibleFocusItems[i]),
                          ),
""",
    """                          _FocusRow(
                            item: visibleFocusItems[i],
                            compact: widget.compact,
                            onTap: () =>
                                widget.onOpenCase(visibleFocusItems[i]),
                          ),
""",
)

replace_once(
    WORKSPACE,
    """                          _FocusRow(
                            item: closedItems[i],
                            onTap: () => widget.onOpenCase(closedItems[i]),
                          ),
""",
    """                          _FocusRow(
                            item: closedItems[i],
                            compact: widget.compact,
                            onTap: () => widget.onOpenCase(closedItems[i]),
                          ),
""",
)

focus_row = r'''class _FocusRow extends StatelessWidget {
  const _FocusRow({
    required this.item,
    required this.onTap,
    this.studentName,
    this.compact = false,
  });

  final V2FocusItem item;
  final VoidCallback onTap;
  final String? studentName;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final nextStep = _displayNextStep(item.nextStep);
    final dueLabel = _displayDueAlongsideNextStep(item);
    final ownerLabel = studentName == null
        ? item.subject
        : '$studentName · ${item.subject}';

    if (compact) {
      return InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 13),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 2,
                height: 72,
                color: scheme.primary.withValues(alpha: 0.5),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (_shouldShowCaseSummary(item)) ...[
                      const SizedBox(height: 3),
                      Text(
                        item.summary,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      ownerLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.closed ? nextStep : '下一步 · $nextStep',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                        if (dueLabel != null) ...[
                          const SizedBox(width: 10),
                          Text(
                            dueLabel,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(Icons.chevron_right, size: 20),
              ),
            ],
          ),
        ),
      );
    }

    return InkWell(
      borderRadius: BorderRadius.circular(10),
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
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (_shouldShowCaseSummary(item)) ...[
                    const SizedBox(height: 4),
                    Text(
                      item.summary,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    item.closed ? nextStep : '下一步  $nextStep',
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
                  ownerLabel,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (dueLabel != null) ...[
                  const SizedBox(height: 17),
                  Text(
                    dueLabel,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
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

'''
replace_segment(
    WORKSPACE,
    "class _FocusRow extends StatelessWidget {",
    "class _Timeline",
    focus_row,
)

case_detail = r'''class _CaseDetailPane extends StatelessWidget {
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
    final dueLabel = _displayDueAlongsideNextStep(item);
    return ColoredBox(
      color: scheme.surface,
      child: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: compact ? 860 : 1040),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                compact ? 18 : 32,
                compact ? 14 : 20,
                compact ? 18 : 32,
                48,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        tooltip: '返回',
                        onPressed: onBack,
                        icon: const Icon(Icons.arrow_back),
                      ),
                      const Spacer(),
                      if (!item.closed && controller != null)
                        PopupMenuButton<String>(
                          key: ValueKey<String>('v2-case-more-${item.id}'),
                          tooltip: '更多操作',
                          icon: const Icon(Icons.more_horiz),
                          onSelected: (value) async {
                            if (value != 'delete') return;
                            final removed = await _showV2VoidCase(
                              context,
                              student,
                              item,
                            );
                            if (removed && context.mounted) onBack();
                          },
                          itemBuilder: (menuContext) => [
                            PopupMenuItem<String>(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.delete_outline,
                                    size: 18,
                                    color: scheme.error,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    '删除问题',
                                    style: Theme.of(menuContext)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(color: scheme.error),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  SizedBox(height: compact ? 4 : 8),
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
                        const SizedBox(width: 12),
                        FilledButton.icon(
                          onPressed: () =>
                              _showV2ProgressForCase(context, student, item),
                          icon: const Icon(Icons.edit_note_outlined, size: 18),
                          label: const Text('记进展'),
                        ),
                      ],
                    ],
                  ),
                  if (_shouldShowCaseSummary(item)) ...[
                    const SizedBox(height: 8),
                    Text(
                      item.summary,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                  SizedBox(height: compact ? 24 : 28),
                  Text(
                    item.closed ? '状态' : '下一步',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          item.closed
                              ? Icons.check_circle_outline
                              : Icons.arrow_forward,
                          size: 18,
                          color: scheme.primary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _displayNextStep(item.nextStep),
                            style: item.closed
                                ? Theme.of(context).textTheme.bodyMedium
                                : Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        if (dueLabel != null) ...[
                          const SizedBox(width: 12),
                          Text(
                            dueLabel,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ],
                    ),
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
                            label: const Text('完成这一步'),
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

'''
replace_segment(
    WORKSPACE,
    "class _CaseDetailPane extends StatelessWidget {",
    "class _TodayPane",
    case_detail,
)

replace_once(
    WORKSPACE,
    """    final futureItems =
        validItems
            .where((item) => item.actionTiming == V2ActionTiming.future)
            .toList(growable: true)
          ..sort(_compare);

    return SingleChildScrollView(
""",
    """    final futureItems =
        validItems
            .where((item) => item.actionTiming == V2ActionTiming.future)
            .toList(growable: true)
          ..sort(_compare);
    final unplannedItems = data.focusItems
        .where(
          (item) =>
              data.studentForFocusItemOrNull(item) != null &&
              item.actionTiming == null,
        )
        .toList(growable: true)
      ..sort((left, right) => left.title.compareTo(right.title));

    return SingleChildScrollView(
""",
)

text = read(WORKSPACE)
today_start = text.index("class _TodayPane extends StatelessWidget {")
today_end = text.index("class _TodayAction extends StatelessWidget {", today_start)
today_segment = text[today_start:today_end]
old_today_constraint = "constraints: const BoxConstraints(maxWidth: 900),"
if today_segment.count(old_today_constraint) != 1:
    raise SystemExit("Today: expected exactly one max-width constraint")
today_segment = today_segment.replace(
    old_today_constraint,
    "constraints: BoxConstraints(maxWidth: compact ? 900 : 1040),",
    1,
)
write(WORKSPACE, text[:today_start] + today_segment + text[today_end:])

replace_once(
    WORKSPACE,
    """              const SizedBox(height: 28),
              if (actionItems.isEmpty && verificationItems.isEmpty)
                Text(
                  '今天没有需要处理的学情事项',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
""",
    """              SizedBox(height: compact ? 22 : 28),
              if (actionItems.isEmpty && verificationItems.isEmpty)
                Text(
                  unplannedItems.isEmpty ? '今天没有需要处理的学情事项' : '今天没有到期事项',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
""",
)

replace_once(
    WORKSPACE,
    """              if (futureItems.isNotEmpty) ...[
                const SizedBox(height: 28),
                Divider(color: Theme.of(context).colorScheme.outlineVariant),
""",
    """              if (unplannedItems.isNotEmpty) ...[
                SizedBox(
                  height:
                      actionItems.isEmpty && verificationItems.isEmpty ? 18 : 28,
                ),
                Divider(color: Theme.of(context).colorScheme.outlineVariant),
                const SizedBox(height: 20),
                _SectionTitle(
                  title: '待安排下一步',
                  count: unplannedItems.length,
                ),
                const SizedBox(height: 4),
                Text(
                  '这些问题还没有明确的后续行动，先安排下一步，跟进才不会断。',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 6),
                for (final item in unplannedItems)
                  _TodayAction(item: item, onOpenCase: onOpenCase),
              ],
              if (futureItems.isNotEmpty) ...[
                const SizedBox(height: 28),
                Divider(color: Theme.of(context).colorScheme.outlineVariant),
""",
)

replace_once(
    WORKSPACE,
    """    final controller = _V2RuntimeScope.maybeOf(context)?.workflowController;
    final pendingAction = controller?.pendingActionFor(item.id);
    return InkWell(
""",
    """    final controller = _V2RuntimeScope.maybeOf(context)?.workflowController;
    final pendingAction = controller?.pendingActionFor(item.id);
    final nextStep = _displayNextStep(item.nextStep);
    final statusLabel = verification
        ? _todayActionStatus(item, verification: true)
        : item.actionTiming == V2ActionTiming.overdue
        ? _todayActionStatus(item, verification: false)
        : _displayDueAlongsideNextStep(item);
    return InkWell(
""",
)

replace_once(
    WORKSPACE,
    """                  Text(
                    verification ? '等待确认是否已经稳定' : '下一步 · ${item.nextStep}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
""",
    """                  Text(
                    verification ? '等待确认是否已经稳定' : '下一步 · $nextStep',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
""",
)

replace_once(
    WORKSPACE,
    """            Text(
              _todayActionStatus(item, verification: verification),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(width: 4),
""",
    """            if (statusLabel != null) ...[
              Text(
                statusLabel,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(width: 4),
            ],
""",
)

text = read(WORKSPACE)
case_index_start = text.index(
    "class _CaseIndexPaneState extends State<_CaseIndexPane> {"
)
case_index_end = text.index("class _V2OperationGuide", case_index_start)
case_index = text[case_index_start:case_index_end]
old_case_constraint = "constraints: const BoxConstraints(maxWidth: 900),"
if case_index.count(old_case_constraint) != 1:
    raise SystemExit("Case index: expected exactly one max-width constraint")
case_index = case_index.replace(
    old_case_constraint,
    "constraints: BoxConstraints(maxWidth: widget.compact ? 900 : 1040),",
    1,
)
old_focus_call = """                  _FocusRow(
                    item: item,
                    studentName: data.studentForFocusItem(item).name,
                    onTap: () => widget.onOpenCase(item),
                  ),
"""
new_focus_call = """                  _FocusRow(
                    item: item,
                    studentName: data.studentForFocusItem(item).name,
                    compact: widget.compact,
                    onTap: () => widget.onOpenCase(item),
                  ),
"""
if case_index.count(old_focus_call) != 1:
    raise SystemExit("Case index: expected exactly one focus row call")
case_index = case_index.replace(old_focus_call, new_focus_call, 1)
write(WORKSPACE, text[:case_index_start] + case_index + text[case_index_end:])

replace_once(
    DATA_TEST,
    """      expect(find.text('近期安排'), findsOneWidget);
      expect(find.text('未来处理'), findsNothing);
      expect(find.text('仅记录事实'), findsNothing);

      await tester.tap(find.text('近期安排'));
""",
    """      expect(find.text('近期安排'), findsOneWidget);
      expect(find.text('未来处理'), findsNothing);
      expect(find.text('待安排下一步'), findsOneWidget);
      expect(find.text('仅记录事实'), findsOneWidget);
      expect(find.text('下一步 · 待安排'), findsOneWidget);

      await tester.tap(find.text('近期安排'));
""",
)

replace_once(
    ERGONOMICS_TEST,
    """  testWidgets(
    'compact shell keeps three primary destinations and moves More to header',
""",
    """  testWidgets('compact case list avoids duplicate pending labels', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const data = V2WorkspaceData(
      students: _students,
      focusItems: [
        V2FocusItem(
          id: 'unplanned',
          studentId: 's1',
          title: '需要安排的问题',
          summary: '尚未确定后续动作。',
          nextStep: '待安排下一步',
          dueLabel: '待安排',
          subject: '语文',
        ),
      ],
      timeline: [],
    );

    await tester.pumpWidget(_app(data));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.fact_check_outlined));
    await tester.pumpAndSettle();

    expect(find.text('需要安排的问题'), findsOneWidget);
    expect(find.text('下一步 · 待安排'), findsOneWidget);
    expect(find.text('待安排'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'compact shell keeps three primary destinations and moves More to header',
""",
)

print("v0.3.3 cross-platform ergonomics patch applied")
