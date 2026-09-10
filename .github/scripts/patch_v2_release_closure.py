from pathlib import Path


def read(path: str) -> str:
    return Path(path).read_text(encoding="utf-8")


def write(path: str, text: str) -> None:
    Path(path).write_text(text, encoding="utf-8")


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"{label}: expected exactly one match, found {count}")
    return text.replace(old, new, 1)


def replace_between(text: str, start: str, end: str, replacement: str, label: str) -> str:
    start_index = text.find(start)
    if start_index < 0:
        raise RuntimeError(f"{label}: start marker not found")
    end_index = text.find(end, start_index)
    if end_index < 0:
        raise RuntimeError(f"{label}: end marker not found")
    return text[:start_index] + replacement + text[end_index:]


# ---------------------------------------------------------------------------
# V2 workspace: no silent Today truncation, future visibility, global capture,
# zero-student capability access, truthful search, student export hook.
# ---------------------------------------------------------------------------
preview_path = "lib/features/design_v2/v2_workspace_preview.dart"
preview = read(preview_path)

preview = replace_once(
    preview,
    "class _V2RuntimeScope extends InheritedWidget {",
    "typedef V2StudentExport = Future<void> Function(\n  BuildContext context,\n  V2Student student,\n);\n\nclass _V2RuntimeScope extends InheritedWidget {",
    "preview export typedef",
)
preview = replace_once(
    preview,
    "    required this.evidenceAttachmentRepository,\n    required this.onWorkspaceChanged,",
    "    required this.evidenceAttachmentRepository,\n    required this.studentExport,\n    required this.onWorkspaceChanged,",
    "runtime scope constructor",
)
preview = replace_once(
    preview,
    "  final EvidenceAttachmentRepository? evidenceAttachmentRepository;\n  final VoidCallback? onWorkspaceChanged;",
    "  final EvidenceAttachmentRepository? evidenceAttachmentRepository;\n  final V2StudentExport? studentExport;\n  final VoidCallback? onWorkspaceChanged;",
    "runtime scope fields",
)
preview = replace_once(
    preview,
    "      evidenceAttachmentRepository != oldWidget.evidenceAttachmentRepository ||\n      onWorkspaceChanged != oldWidget.onWorkspaceChanged;",
    "      evidenceAttachmentRepository != oldWidget.evidenceAttachmentRepository ||\n      studentExport != oldWidget.studentExport ||\n      onWorkspaceChanged != oldWidget.onWorkspaceChanged;",
    "runtime scope notifications",
)

picker = r'''Future<void> _showV2QuickCaptureStudentPicker(BuildContext context) async {
  final students = V2WorkspaceDataScope.of(context).students;
  if (students.isEmpty) {
    return;
  }
  if (students.length == 1) {
    await _showV2QuickCaptureForStudent(context, students.single);
    return;
  }

  Widget choices(BuildContext selectionContext) => ListView.separated(
    shrinkWrap: true,
    itemCount: students.length,
    separatorBuilder: (_, _) => Divider(
      height: 1,
      color: Theme.of(selectionContext).colorScheme.outlineVariant,
    ),
    itemBuilder: (_, index) {
      final student = students[index];
      return ListTile(
        title: Text(student.name),
        subtitle: Text('${student.grade} · ${student.subjects.join(' / ')}'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(selectionContext).pop(student),
      );
    },
  );

  final compact = MediaQuery.sizeOf(context).width < 720;
  final selected = compact
      ? await showModalBottomSheet<V2Student>(
          context: context,
          useSafeArea: true,
          showDragHandle: true,
          builder: (sheetContext) => Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '选择学生',
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 480),
                  child: choices(sheetContext),
                ),
              ],
            ),
          ),
        )
      : await showDialog<V2Student>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('选择学生'),
            content: SizedBox(
              width: 420,
              height: 480,
              child: choices(dialogContext),
            ),
          ),
        );
  if (selected == null || !context.mounted) {
    return;
  }
  await _showV2QuickCaptureForStudent(context, selected);
}

'''
preview = replace_once(
    preview,
    "Future<void> _showV2CompleteCurrentAction(\n",
    picker + "Future<void> _showV2CompleteCurrentAction(\n",
    "global quick capture picker",
)
preview = replace_once(
    preview,
    "    canCompleteCurrentAction:\n        controller?.hasPendingPrimaryAction(item.id) ?? false,\n    onSave:",
    "    canCompleteCurrentAction:\n        controller?.hasPendingPrimaryAction(item.id) ?? false,\n    businessDate: controller?.businessDate,\n    onSave:",
    "progress business date wiring",
)
preview = replace_once(
    preview,
    "    this.evidenceAttachmentRepository,\n    this.managementPageBuilder,",
    "    this.evidenceAttachmentRepository,\n    this.onExportStudent,\n    this.managementPageBuilder,",
    "preview constructor export",
)
preview = replace_once(
    preview,
    "  final EvidenceAttachmentRepository? evidenceAttachmentRepository;\n  final WidgetBuilder? managementPageBuilder;",
    "  final EvidenceAttachmentRepository? evidenceAttachmentRepository;\n  final V2StudentExport? onExportStudent;\n  final WidgetBuilder? managementPageBuilder;",
    "preview export field",
)
preview = replace_once(
    preview,
    "      evidenceAttachmentRepository: widget.evidenceAttachmentRepository,\n      onWorkspaceChanged: widget.onWorkspaceChanged,",
    "      evidenceAttachmentRepository: widget.evidenceAttachmentRepository,\n      studentExport: widget.onExportStudent,\n      onWorkspaceChanged: widget.onWorkspaceChanged,",
    "preview runtime export wiring",
)
preview = replace_once(
    preview,
    "            if (widget.data.students.isEmpty) {\n              return const _EmptyWorkspacePreview();\n            }",
    "            if (widget.data.students.isEmpty) {\n              final hasMenuActions =\n                  widget.managementPageBuilder != null ||\n                  widget.updateService != null && widget.updateInstaller != null ||\n                  widget.onSignOut != null;\n              return _EmptyWorkspacePreview(\n                onOpenManagement: widget.managementPageBuilder == null\n                    ? null\n                    : () => _openManagement(context),\n                onOpenMore: hasMenuActions\n                    ? () => _showWorkspaceMenu(context)\n                    : null,\n              );\n            }",
    "zero student capability shell",
)
preview = replace_once(
    preview,
    "            student.grade,\n            ...student.subjects,\n            student.teacherSummary,",
    "            student.grade,\n            ...student.subjects,",
    "truthful student search haystack",
)
preview = replace_once(
    preview,
    "hintText: '搜索姓名、年级、学科或老师…',",
    "hintText: '搜索姓名、年级或学科…',",
    "truthful student search hint",
)

old_buttons = '''    final buttons = Wrap(
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
    );'''
new_buttons = '''    final exportStudent = _V2RuntimeScope.maybeOf(context)?.studentExport;
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
        if (exportStudent != null)
          PopupMenuButton<String>(
            key: const Key('v2-student-more-actions'),
            tooltip: '更多操作',
            icon: const Icon(Icons.more_horiz),
            onSelected: (value) async {
              if (value == 'export') {
                await exportStudent(context, student);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem<String>(
                value: 'export',
                child: ListTile(
                  leading: Icon(Icons.download_outlined),
                  title: Text('导出学情记录'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
      ],
    );'''
preview = replace_once(preview, old_buttons, new_buttons, "student export menu")

preview = replace_once(
    preview,
    "          const SizedBox(height: 5),\n          Text(\n            student.teacherSummary,\n            style: Theme.of(context).textTheme.bodySmall,\n          ),\n          const SizedBox(height: 16),",
    "          if (student.teacherSummary.trim().isNotEmpty) ...[\n            const SizedBox(height: 5),\n            Text(\n              student.teacherSummary,\n              style: Theme.of(context).textTheme.bodySmall,\n            ),\n          ],\n          const SizedBox(height: 16),",
    "compact truthful teacher summary",
)
preview = replace_once(
    preview,
    "                    const SizedBox(height: 5),\n                    Text(\n                      student.teacherSummary,\n                      style: Theme.of(context).textTheme.bodySmall,\n                    ),",
    "                    if (student.teacherSummary.trim().isNotEmpty) ...[\n                      const SizedBox(height: 5),\n                      Text(\n                        student.teacherSummary,\n                        style: Theme.of(context).textTheme.bodySmall,\n                      ),\n                    ],",
    "desktop truthful teacher summary",
)

new_today = r'''class _TodayPane extends StatelessWidget {
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
              item.actionTiming != null,
        )
        .toList(growable: false);
    final actionItems = validItems
        .where(
          (item) =>
              item.actionTiming != V2ActionTiming.future &&
              !item.pendingVerification,
        )
        .toList(growable: false);
    final verificationItems = validItems
        .where(
          (item) =>
              item.actionTiming != V2ActionTiming.future &&
              item.pendingVerification,
        )
        .toList(growable: false);
    final futureItems = validItems
        .where((item) => item.actionTiming == V2ActionTiming.future)
        .toList(growable: false);

    return SingleChildScrollView(
      padding: EdgeInsets.all(compact ? 18 : 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '今日',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 5),
                        Text(
                          _todayLabel(data.businessDate),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.tonalIcon(
                    key: const Key('v2-today-quick-capture'),
                    onPressed: () => _showV2QuickCaptureStudentPicker(context),
                    icon: const Icon(Icons.note_add_outlined, size: 18),
                    label: const Text('记录问题'),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              if (actionItems.isEmpty && verificationItems.isEmpty)
                Text(
                  '今天没有需要处理的学情事项',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              if (actionItems.isNotEmpty) ...[
                _SectionTitle(title: '需要处理', count: actionItems.length),
                const SizedBox(height: 8),
                for (final item in actionItems)
                  _TodayAction(item: item, onOpenCase: onOpenCase),
              ],
              if (actionItems.isNotEmpty && verificationItems.isNotEmpty)
                const SizedBox(height: 28),
              if (verificationItems.isNotEmpty) ...[
                _SectionTitle(title: '待验证', count: verificationItems.length),
                const SizedBox(height: 10),
                for (final item in verificationItems)
                  _TodayAction(
                    item: item,
                    onOpenCase: onOpenCase,
                    verification: true,
                  ),
              ],
              if (futureItems.isNotEmpty) ...[
                const SizedBox(height: 28),
                Divider(color: Theme.of(context).colorScheme.outlineVariant),
                ExpansionTile(
                  key: const Key('v2-today-future-section'),
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event_outlined),
                  title: const Text('近期安排'),
                  subtitle: Text('${futureItems.length} 项已安排的后续行动'),
                  children: [
                    for (final item in futureItems)
                      _TodayAction(
                        item: item,
                        onOpenCase: onOpenCase,
                        verification: item.pendingVerification,
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

'''
preview = replace_between(
    preview,
    "class _TodayPane extends StatelessWidget {",
    "String _todayLabel(DateTime? businessDate)",
    new_today,
    "Today pane replacement",
)

preview = preview.replace("label: const Text('完成提醒'),", "label: const Text('完成这一步'),", 1)

new_empty = r'''class _EmptyWorkspacePreview extends StatelessWidget {
  const _EmptyWorkspacePreview({this.onOpenManagement, this.onOpenMore});

  final VoidCallback? onOpenManagement;
  final VoidCallback? onOpenMore;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: onOpenManagement == null && onOpenMore == null
          ? null
          : AppBar(
              title: const Text('学情闭环'),
              actions: [
                if (onOpenManagement != null)
                  IconButton(
                    key: const Key('v2-empty-management'),
                    tooltip: '机构管理',
                    onPressed: onOpenManagement,
                    icon: const Icon(Icons.admin_panel_settings_outlined),
                  ),
                if (onOpenMore != null)
                  IconButton(
                    key: const Key('v2-empty-more'),
                    tooltip: '更多',
                    onPressed: onOpenMore,
                    icon: const Icon(Icons.more_horiz),
                  ),
                const SizedBox(width: 6),
              ],
            ),
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
                    onOpenManagement == null
                        ? '当你获得任课学生后，这里会自动出现。'
                        : '当前还没有可查看的学生。可以先进入机构管理完成学生、学科和任课配置。',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  if (onOpenManagement != null) ...[
                    const SizedBox(height: 20),
                    FilledButton.tonalIcon(
                      onPressed: onOpenManagement,
                      icon: const Icon(Icons.admin_panel_settings_outlined),
                      label: const Text('进入机构管理'),
                    ),
                  ],
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
empty_start = preview.find("class _EmptyWorkspacePreview extends StatelessWidget {")
if empty_start < 0:
    raise RuntimeError("empty workspace class not found")
preview = preview[:empty_start] + new_empty
write(preview_path, preview)


# ---------------------------------------------------------------------------
# V2 read model: never claim the current viewer is the historical/current
# responsible teacher when the read model does not actually carry assignments.
# ---------------------------------------------------------------------------
adapter_path = "lib/features/design_v2/v2_read_model_adapter.dart"
adapter = read(adapter_path)
adapter = replace_once(
    adapter,
    "          teacherSummary: _workspaceSummary(\n            viewerName: workspace.viewerName,\n            subjects: subjects,\n          ),",
    "          teacherSummary: '',",
    "truthful teacher summary mapping",
)
adapter = replace_between(
    adapter,
    "  static String _workspaceSummary({",
    "  static String _dateLabel(DateTime value)",
    "",
    "remove misleading workspace summary helper",
)
write(adapter_path, adapter)


# ---------------------------------------------------------------------------
# Composer safety: use organization business date and make both close button
# and Android system Back protect unsaved/failed drafts.
# ---------------------------------------------------------------------------
composers_path = "lib/features/design_v2/v2_composers.dart"
composers = read(composers_path)
composers = replace_once(
    composers,
    "  bool canCompleteCurrentAction = false,\n  V2ProgressSave? onSave,",
    "  bool canCompleteCurrentAction = false,\n  DateTime? businessDate,\n  V2ProgressSave? onSave,",
    "progress show business date",
)
composers = replace_once(
    composers,
    "          caseTitle: caseTitle,\n          canCompleteCurrentAction: canCompleteCurrentAction,\n          onSave: onSave,",
    "          caseTitle: caseTitle,\n          canCompleteCurrentAction: canCompleteCurrentAction,\n          businessDate: businessDate,\n          onSave: onSave,",
    "progress composer business date pass-through",
)

close_helper = r'''enum _V2DraftCloseAction { keepEditing, retry, discard }

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
          onPressed: () => Navigator.of(dialogContext)
              .pop(_V2DraftCloseAction.keepEditing),
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

'''
composers = replace_once(
    composers,
    "Future<T?> _showAdaptiveComposer<T>(",
    close_helper + "Future<T?> _showAdaptiveComposer<T>(",
    "draft close helper",
)
composers = replace_once(
    composers,
    "  bool get _canSave =>\n      !_saving &&",
    "  bool get _hasDraft =>\n      _controller.text.trim().isNotEmpty || _attachments.isNotEmpty;\n\n  bool get _canSave =>\n      !_saving &&",
    "quick capture dirty state",
)
quick_close = r'''  Future<void> _close() async {
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
    if (!mounted || action == null || action == _V2DraftCloseAction.keepEditing) {
      return;
    }
    if (action == _V2DraftCloseAction.retry) {
      await _save();
      return;
    }
    Navigator.of(context).pop(false);
  }

'''
composers = replace_once(
    composers,
    "  @override\n  Widget build(BuildContext context) {\n    return _ComposerScaffold(\n      title: '记录新问题',",
    quick_close + "  @override\n  Widget build(BuildContext context) {\n    return _ComposerScaffold(\n      title: '记录新问题',",
    "quick capture close protection",
)
composers = replace_once(
    composers,
    "      onClose: _saving ? null : () => Navigator.of(context).pop(false),\n      footer: _ComposerFooter(\n        primaryLabel: '记录问题',",
    "      onClose: _saving ? null : _close,\n      footer: _ComposerFooter(\n        primaryLabel: '记录问题',",
    "quick capture close callback",
)
composers = replace_once(
    composers,
    "    this.canCompleteCurrentAction = false,\n    this.onSave,",
    "    this.canCompleteCurrentAction = false,\n    this.businessDate,\n    this.onSave,",
    "progress constructor business date",
)
composers = replace_once(
    composers,
    "  final bool canCompleteCurrentAction;\n  final V2ProgressSave? onSave;",
    "  final bool canCompleteCurrentAction;\n  final DateTime? businessDate;\n  final V2ProgressSave? onSave;",
    "progress field business date",
)
composers = replace_once(
    composers,
    "  Future<void> _chooseReminderDate() async {\n    final now = DateTime.now();\n    final selected = await showDatePicker(\n      context: context,\n      initialDate: _reminderDate ?? now,\n      firstDate: DateTime(now.year, now.month, now.day),\n      lastDate: DateTime(now.year + 2, 12, 31),",
    "  Future<void> _chooseReminderDate() async {\n    final referenceDate = widget.businessDate ?? DateTime.now();\n    final today = DateTime(\n      referenceDate.year,\n      referenceDate.month,\n      referenceDate.day,\n    );\n    final selected = await showDatePicker(\n      context: context,\n      initialDate: _reminderDate ?? today,\n      firstDate: today,\n      lastDate: DateTime(today.year + 2, 12, 31),",
    "progress business date picker",
)
composers = replace_once(
    composers,
    "  bool get _canSave {\n    if (_saving || _controller.text.trim().isEmpty) {",
    "  bool get _hasDraft =>\n      _controller.text.trim().isNotEmpty ||\n      _attachments.isNotEmpty ||\n      _kind != V2ProgressKind.observation ||\n      _nextStep != V2NextStep.continueTracking ||\n      _assessmentResult != null ||\n      _reminderController.text.trim().isNotEmpty ||\n      _reminderDate != null ||\n      _completeCurrentAction;\n\n  bool get _canSave {\n    if (_saving || _controller.text.trim().isEmpty) {",
    "progress dirty state",
)
progress_close = r'''  Future<void> _close() async {
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
    if (!mounted || action == null || action == _V2DraftCloseAction.keepEditing) {
      return;
    }
    if (action == _V2DraftCloseAction.retry) {
      await _save();
      return;
    }
    Navigator.of(context).pop(false);
  }

'''
composers = replace_once(
    composers,
    "  @override\n  Widget build(BuildContext context) {\n    return _ComposerScaffold(\n      title: '记录进展',",
    progress_close + "  @override\n  Widget build(BuildContext context) {\n    return _ComposerScaffold(\n      title: '记录进展',",
    "progress close protection",
)
composers = replace_once(
    composers,
    "      onClose: _saving ? null : () => Navigator.of(context).pop(false),\n      footer: _ComposerFooter(\n        primaryLabel: '保存进展',",
    "      onClose: _saving ? null : _close,\n      footer: _ComposerFooter(\n        primaryLabel: '保存进展',",
    "progress close callback",
)
composers = replace_once(
    composers,
    "    return PopScope(canPop: onClose != null, child: body);",
    "    return PopScope<void>(\n      canPop: false,\n      onPopInvokedWithResult: (didPop, _) {\n        if (!didPop) {\n          onClose?.call();\n        }\n      },\n      child: body,\n    );",
    "composer Android back protection",
)
write(composers_path, composers)


# ---------------------------------------------------------------------------
# Action wording: this is an actual teacher action, not merely a notification.
# ---------------------------------------------------------------------------
action_path = "lib/features/design_v2/v2_action_composers.dart"
action_text = read(action_path)
action_text = action_text.replace("完成提醒", "完成这一步")
write(action_path, action_text)


# ---------------------------------------------------------------------------
# Make the mature Case Type manager reusable by the production V2 management
# host without duplicating repository/domain logic.
# ---------------------------------------------------------------------------
teacher_path = "lib/features/teacher_workspace/presentation/teacher_workspace_page.dart"
teacher = read(teacher_path)
teacher = teacher.replace("_WorkspaceCaseTypeManager(", "WorkspaceCaseTypeManager(")
teacher = replace_once(
    teacher,
    "class _WorkspaceCaseTypeManager extends StatefulWidget {",
    "class WorkspaceCaseTypeManager extends StatefulWidget {",
    "public case type manager class",
)
teacher = replace_once(
    teacher,
    "  State<_WorkspaceCaseTypeManager> createState() =>\n      _WorkspaceCaseTypeManagerState();",
    "  State<WorkspaceCaseTypeManager> createState() =>\n      _WorkspaceCaseTypeManagerState();",
    "public case type manager state type",
)
teacher = replace_once(
    teacher,
    "class _WorkspaceCaseTypeManagerState extends State<_WorkspaceCaseTypeManager> {",
    "class _WorkspaceCaseTypeManagerState extends State<WorkspaceCaseTypeManager> {",
    "public case type manager state binding",
)
write(teacher_path, teacher)


# ---------------------------------------------------------------------------
# V2 management: restore existing custom problem-type management.
# ---------------------------------------------------------------------------
management_path = "lib/features/design_v2/v2_management_page.dart"
management = read(management_path)
management = replace_once(
    management,
    "import '../teacher_workspace/workspace_runtime.dart';",
    "import '../teacher_workspace/presentation/teacher_workspace_page.dart';\nimport '../teacher_workspace/workspace_runtime.dart';",
    "management case type import",
)
open_case_types = r'''  Future<void> _openCaseTypes() async {
    final organizationId = widget.workspace.organizationId;
    if (organizationId == null || !widget.workspace.canManageCaseTypes) {
      return;
    }
    final manager = WorkspaceCaseTypeManager(
      organizationId: organizationId,
      caseTypes: widget.workspace.caseTypes,
      repository: widget.runtime.learningRepository,
      onChanged: () async {
        widget.onChanged?.call();
      },
    );
    if (MediaQuery.sizeOf(context).width < 720) {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        isDismissible: false,
        enableDrag: false,
        useSafeArea: true,
        builder: (_) => manager,
      );
    } else {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => Dialog(child: manager),
      );
    }
  }

'''
management = replace_once(
    management,
    "  @override\n  Widget build(BuildContext context) {",
    open_case_types + "  @override\n  Widget build(BuildContext context) {",
    "management open case types",
)
management = replace_once(
    management,
    "            canManageCaseTypes: false,\n            onChanged: widget.onChanged,",
    "            canManageCaseTypes: widget.workspace.canManageCaseTypes,\n            onOpenCaseTypes: widget.workspace.canManageCaseTypes\n                ? () {\n                    _openCaseTypes();\n                  }\n                : null,\n            onChanged: widget.onChanged,",
    "management case types wiring",
)
write(management_path, management)


# ---------------------------------------------------------------------------
# V2 loader: reuse the production StudentLearningRecordRepository + XLSX export
# from inside the student context. Multi-subject students choose a profile first.
# ---------------------------------------------------------------------------
loader_path = "lib/features/design_v2/v2_workspace_loader.dart"
loader = read(loader_path)
loader = replace_once(
    loader,
    "import '../../cloud/progressive_case_repository.dart';",
    "import '../../cloud/progressive_case_repository.dart';\nimport '../../cloud/student_learning_record_repository.dart';\nimport '../../export/learning_record_export.dart';",
    "loader export imports",
)
loader = replace_once(
    loader,
    "import 'v2_workflow_controller.dart';\nimport 'v2_workspace_preview.dart';",
    "import 'v2_workflow_controller.dart';\nimport 'v2_workspace_data.dart';\nimport 'v2_workspace_preview.dart';",
    "loader V2 student import",
)
export_methods = r'''  Future<WorkspaceStudent?> _pickStudentSubjectProfile(
    BuildContext context,
    List<WorkspaceStudent> profiles,
  ) async {
    if (profiles.isEmpty) {
      return null;
    }
    if (profiles.length == 1) {
      return profiles.single;
    }
    final sorted = List<WorkspaceStudent>.of(profiles)
      ..sort((left, right) => left.subject.compareTo(right.subject));

    Widget choices(BuildContext selectionContext) => ListView.separated(
      shrinkWrap: true,
      itemCount: sorted.length,
      separatorBuilder: (_, _) => Divider(
        height: 1,
        color: Theme.of(selectionContext).colorScheme.outlineVariant,
      ),
      itemBuilder: (_, index) {
        final profile = sorted[index];
        return ListTile(
          title: Text(profile.subject),
          subtitle: Text('${profile.name} · ${profile.grade}'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(selectionContext).pop(profile),
        );
      },
    );

    if (MediaQuery.sizeOf(context).width < 720) {
      return showModalBottomSheet<WorkspaceStudent>(
        context: context,
        useSafeArea: true,
        showDragHandle: true,
        builder: (sheetContext) => Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '选择要导出的学科',
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 420),
                child: choices(sheetContext),
              ),
            ],
          ),
        ),
      );
    }
    return showDialog<WorkspaceStudent>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('选择要导出的学科'),
        content: SizedBox(width: 420, child: choices(dialogContext)),
      ),
    );
  }

  Future<void> _exportStudentRecords(
    BuildContext context,
    TeacherWorkspace workspace,
    V2Student student,
  ) async {
    final repository = widget.runtime?.studentLearningRecordRepository;
    if (repository == null) {
      return;
    }
    final profiles = workspace.students
        .where((profile) => profile.id == student.id)
        .toList(growable: false);
    final profile = await _pickStudentSubjectProfile(context, profiles);
    if (profile == null || !context.mounted) {
      return;
    }

    try {
      final records = await repository.listStudentSubjectRecords(
        profileId: profile.profileId,
      );
      final rows = LearningRecordExport.rowsForStudentRecords(records);
      if (!context.mounted) {
        return;
      }
      if (rows.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('当前没有可导出的记录。')),
        );
        return;
      }
      final savedPath = await LearningRecordExport.saveAsXlsx(
        fileNameWithoutExtension:
            LearningRecordExport.studentSubjectFileName(profile),
        rows: rows,
      );
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(savedPath == null ? '已取消导出。' : '学情记录表已生成。')),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      final message =
          studentLearningRecordExportErrorMessage(error) ??
          '学情记录暂时无法读取，请检查网络后重试。';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

'''
loader = replace_once(
    loader,
    "  @override\n  Widget build(BuildContext context) {",
    export_methods + "  @override\n  Widget build(BuildContext context) {",
    "loader student export flow",
)
loader = replace_once(
    loader,
    "          evidenceAttachmentRepository: evidenceAttachmentRepository,\n          managementPageBuilder: managementPageBuilder,",
    "          evidenceAttachmentRepository: evidenceAttachmentRepository,\n          onExportStudent: runtime?.studentLearningRecordRepository == null\n              ? null\n              : (context, student) =>\n                    _exportStudentRecords(context, workspace, student),\n          managementPageBuilder: managementPageBuilder,",
    "loader student export wiring",
)
write(loader_path, loader)


# ---------------------------------------------------------------------------
# Tests: turn the audited gaps into release contracts.
# ---------------------------------------------------------------------------
data_test_path = "test/features/design_v2_workspace_data_injection_test.dart"
data_test = read(data_test_path)
data_test = replace_once(
    data_test,
    "  testWidgets('Today hides future and no-action work and uses business date', (",
    "  testWidgets('Today separates future from current work and uses business date', (",
    "Today test title",
)
data_test = replace_once(
    data_test,
    "    expect(find.text('今天处理'), findsOneWidget);\n    expect(find.text('未来处理'), findsNothing);\n    expect(find.text('仅记录事实'), findsNothing);",
    "    expect(find.text('今天处理'), findsOneWidget);\n    expect(find.text('近期安排'), findsOneWidget);\n    expect(find.text('未来处理'), findsNothing);\n    expect(find.text('仅记录事实'), findsNothing);\n\n    await tester.tap(find.text('近期安排'));\n    await tester.pumpAndSettle();\n    expect(find.text('未来处理'), findsOneWidget);",
    "future section behavior",
)
many_actions_test = r'''
  testWidgets('Today never silently drops the fifth current action', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final items = <V2FocusItem>[
      for (var index = 1; index <= 6; index++)
        V2FocusItem(
          id: 'many-$index',
          studentId: 'real-student',
          title: '待处理事项 $index',
          summary: '用于验证 Today 不会静默截断。',
          nextStep: '完成第 $index 项',
          dueLabel: '今天',
          subject: '语文',
          actionTiming: V2ActionTiming.today,
        ),
    ];
    final data = V2WorkspaceData(
      businessDate: DateTime(2026, 9, 12),
      students: _injectedData.students,
      focusItems: items,
      timeline: const [],
    );

    await tester.pumpWidget(app(data));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('今日'));
    await tester.pumpAndSettle();

    expect(find.text('需要处理'), findsOneWidget);
    expect(find.text('6'), findsOneWidget);
    for (var index = 1; index <= 6; index++) {
      expect(find.text('待处理事项 $index'), findsOneWidget);
    }
  });
'''
data_test = replace_once(
    data_test,
    "\n  testWidgets('empty workspace is a first-class state on desktop', (",
    many_actions_test + "\n  testWidgets('empty workspace is a first-class state on desktop', (",
    "many Today actions regression test",
)
write(data_test_path, data_test)

workspace_test_path = "test/features/design_v2_workspace_test.dart"
workspace_test = read(workspace_test_path)
workspace_test = replace_once(
    workspace_test,
    "    await tester.enterText(find.byKey(const Key('v2-student-search')), '陈老师');\n    await tester.pump();\n\n    expect(find.text('王同学'), findsOneWidget);\n    expect(find.text('吴同学'), findsOneWidget);\n    expect(\n      find.descendant(of: find.byType(ListView), matching: find.text('林同学')),\n      findsNothing,\n    );\n    expect(find.text('找到 2 位'), findsOneWidget);",
    "    await tester.enterText(find.byKey(const Key('v2-student-search')), '王同学');\n    await tester.pump();\n\n    expect(find.text('王同学'), findsOneWidget);\n    expect(\n      find.descendant(of: find.byType(ListView), matching: find.text('林同学')),\n      findsNothing,\n    );\n    expect(find.text('找到 1 位'), findsOneWidget);",
    "truthful student search widget test",
)
write(workspace_test_path, workspace_test)

composer_test_path = "test/features/design_v2_composers_test.dart"
composer_test = read(composer_test_path)
composer_test = replace_once(
    composer_test,
    "      await tester.tap(find.widgetWithText(FilledButton, '记录问题'));\n      await tester.pumpAndSettle();\n\n      expect(attempts, 2);",
    "      await tester.tap(find.byTooltip('关闭'));\n      await tester.pumpAndSettle();\n      expect(find.text('这条记录还没有确认保存'), findsOneWidget);\n      expect(find.text('概括题遗漏结果。'), findsOneWidget);\n\n      await tester.tap(find.text('重新保存'));\n      await tester.pumpAndSettle();\n\n      expect(attempts, 2);",
    "failed draft close retry test",
)
write(composer_test_path, composer_test)

shell_test_path = "test/features/v2_shell_production_capabilities_test.dart"
shell_test = read(shell_test_path)
shell_test = replace_once(
    shell_test,
    "      final updateFlow = File('lib/features/design_v2/v2_update_flow.dart')\n          .readAsStringSync();",
    "      final updateFlow = File('lib/features/design_v2/v2_update_flow.dart')\n          .readAsStringSync();\n      final composers = File('lib/features/design_v2/v2_composers.dart')\n          .readAsStringSync();\n      final teacherWorkspace = File(\n        'lib/features/teacher_workspace/presentation/teacher_workspace_page.dart',\n      ).readAsStringSync();",
    "shell contract extra sources",
)
shell_test = replace_once(
    shell_test,
    "      expect(preview, contains(\"title: const Text('检查更新')\"));\n      expect(preview, contains(\"title: const Text('退出登录')\"));",
    "      expect(preview, contains(\"title: const Text('检查更新')\"));\n      expect(preview, contains(\"title: const Text('退出登录')\"));\n      expect(preview, contains(\"const Text('近期安排')\"));\n      expect(preview, contains(\"Key('v2-today-quick-capture')\"));\n      expect(preview, isNot(contains('.take(4)')));\n      expect(preview, contains(\"Key('v2-empty-management')\"));\n      expect(preview, contains(\"Key('v2-student-more-actions')\"));",
    "shell preview closure contracts",
)
shell_test = replace_once(
    shell_test,
    "      expect(loader, contains('managementPageBuilder: managementPageBuilder'));\n      expect(management, contains('OrganizationManagementPage('));",
    "      expect(loader, contains('managementPageBuilder: managementPageBuilder'));\n      expect(loader, contains('onExportStudent:'));\n      expect(management, contains('OrganizationManagementPage('));",
    "shell export contract",
)
shell_test = replace_once(
    shell_test,
    "      expect(management, contains(\"tooltip: '退出登录'\"));\n\n      expect(updateFlow, contains('service.checkForUpdate()'));",
    "      expect(management, contains(\"tooltip: '退出登录'\"));\n      expect(\n        management,\n        contains('canManageCaseTypes: widget.workspace.canManageCaseTypes'),\n      );\n      expect(teacherWorkspace, contains('class WorkspaceCaseTypeManager'));\n      expect(composers, contains('DateTime? businessDate'));\n      expect(composers, contains('这条记录还没有确认保存'));\n      expect(composers, contains('onPopInvokedWithResult'));\n\n      expect(updateFlow, contains('service.checkForUpdate()'));",
    "shell management and draft contracts",
)
write(shell_test_path, shell_test)

print("V2 release closure patch applied")
