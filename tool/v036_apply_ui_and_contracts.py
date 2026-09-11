from pathlib import Path


def replace_between(text: str, start: str, end: str, replacement: str) -> str:
    start_index = text.find(start)
    if start_index < 0:
        raise SystemExit(f'missing start marker: {start!r}')
    end_index = text.find(end, start_index)
    if end_index < 0:
        raise SystemExit(f'missing end marker: {end!r}')
    return text[:start_index] + replacement.rstrip() + '\n\n' + text[end_index:]


preview_path = Path('lib/features/design_v2/v2_workspace_preview.dart')
preview = preview_path.read_text(encoding='utf-8')

void_block = r'''Future<bool> _showV2VoidCase(
  BuildContext context,
  V2Student student,
  V2FocusItem item,
) async {
  final runtime = _V2RuntimeScope.maybeOf(context);
  final controller = runtime?.workflowController;
  if (controller == null) return false;
  final operationId = createOperationId();
  final noteController = TextEditingController();
  var selectedReason = CaseVoidReason.mistake;

  try {
    final removed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        var saving = false;
        String? errorText;
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('作废这条学情？'),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${student.name} · ${item.subject}\n${item.title}'),
                    const SizedBox(height: 12),
                    const Text(
                      '仅用于误记录、重复记录或录错学生/学科。作废后不会出现在普通学情、今日提醒和默认导出中，但原有成长记录和图片仍会保留。',
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '如果这个问题真实存在过，只是不再继续跟进，请使用“结束跟进”。',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 18),
                    DropdownButtonFormField<CaseVoidReason>(
                      key: const Key('v2-void-reason'),
                      value: selectedReason,
                      decoration: const InputDecoration(labelText: '作废原因'),
                      items: [
                        for (final reason in CaseVoidReason.values)
                          DropdownMenuItem<CaseVoidReason>(
                            value: reason,
                            child: Text(reason.label),
                          ),
                      ],
                      onChanged: saving
                          ? null
                          : (value) {
                              if (value == null) return;
                              setDialogState(() => selectedReason = value);
                            },
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      key: const Key('v2-void-note'),
                      controller: noteController,
                      enabled: !saving,
                      minLines: 2,
                      maxLines: 4,
                      maxLength: 200,
                      decoration: const InputDecoration(
                        labelText: '补充说明（可选）',
                        hintText: '例如：与上一条重复录入',
                      ),
                    ),
                    if (errorText != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        errorText!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving
                    ? null
                    : () => Navigator.of(dialogContext).pop(false),
                child: const Text('取消'),
              ),
              FilledButton(
                key: const Key('v2-confirm-void-case'),
                onPressed: saving
                    ? null
                    : () async {
                        setDialogState(() {
                          saving = true;
                          errorText = null;
                        });
                        try {
                          await controller.voidCase(
                            operationId: operationId,
                            caseId: item.id,
                            reason: selectedReason,
                            note: noteController.text,
                          );
                          if (dialogContext.mounted) {
                            Navigator.of(dialogContext).pop(true);
                          }
                        } on V2WorkflowSaveException catch (error) {
                          if (dialogContext.mounted) {
                            setDialogState(() {
                              saving = false;
                              errorText = error.userMessage;
                            });
                          }
                        } catch (_) {
                          if (dialogContext.mounted) {
                            setDialogState(() {
                              saving = false;
                              errorText = '这条学情暂时无法作废，请稍后重试。';
                            });
                          }
                        }
                      },
                child: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('确认作废'),
              ),
            ],
          ),
        );
      },
    );

    if (removed == true && context.mounted) {
      runtime?.onWorkspaceChanged?.call();
      return true;
    }
    return false;
  } finally {
    noteController.dispose();
  }
}

Future<void> _showV2VoidedCasesForStudent(
  BuildContext context,
  V2Student student,
) async {
  final controller = _V2RuntimeScope.maybeOf(context)?.workflowController;
  if (controller == null) return;
  final compact = MediaQuery.sizeOf(context).width < 720;
  final content = _V2VoidedCasesView(
    student: student,
    controller: controller,
    onChanged: _V2RuntimeScope.maybeOf(context)?.onWorkspaceChanged,
  );
  if (compact) {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => FractionallySizedBox(heightFactor: 0.82, child: content),
    );
  } else {
    await showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        child: SizedBox(width: 620, height: 600, child: content),
      ),
    );
  }
}

class _V2VoidedCasesView extends StatefulWidget {
  const _V2VoidedCasesView({
    required this.student,
    required this.controller,
    this.onChanged,
  });

  final V2Student student;
  final V2WorkflowController controller;
  final VoidCallback? onChanged;

  @override
  State<_V2VoidedCasesView> createState() => _V2VoidedCasesViewState();
}

class _V2VoidedCasesViewState extends State<_V2VoidedCasesView> {
  late Future<List<V2VoidedCaseItem>> _future;
  String? _errorText;
  String? _restoringCaseId;

  @override
  void initState() {
    super.initState();
    _future = widget.controller.listVoidedCasesForStudent(widget.student.id);
  }

  void _reload() {
    setState(() {
      _errorText = null;
      _future = widget.controller.listVoidedCasesForStudent(widget.student.id);
    });
  }

  String _dateLabel(DateTime value) =>
      '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  Future<void> _restore(V2VoidedCaseItem item) async {
    setState(() {
      _restoringCaseId = item.caseId;
      _errorText = null;
    });
    try {
      await widget.controller.restoreVoidedCase(
        operationId: createOperationId(),
        item: item,
      );
      widget.onChanged?.call();
      if (mounted) _reload();
    } on V2WorkflowSaveException catch (error) {
      if (mounted) setState(() => _errorText = error.userMessage);
    } catch (_) {
      if (mounted) setState(() => _errorText = '这条学情暂时无法恢复，请稍后重试。');
    } finally {
      if (mounted) setState(() => _restoringCaseId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canRestore = widget.controller.workspace.canManageOrganization;
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
                      Text('已作废学情', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 4),
                      Text(
                        '${widget.student.name} · 错误或重复档案',
                        style: Theme.of(context).textTheme.bodySmall,
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
            const SizedBox(height: 10),
            Text(
              canRestore
                  ? '作废只隐藏错误档案，不会删除成长记录。负责人或管理员可以恢复。'
                  : '作废只隐藏错误档案，不会删除成长记录；如需恢复，请联系负责人或管理员。',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (_errorText != null) ...[
              const SizedBox(height: 10),
              Text(
                _errorText!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Expanded(
              child: FutureBuilder<List<V2VoidedCaseItem>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('已作废学情暂时无法读取。'),
                          const SizedBox(height: 10),
                          OutlinedButton(onPressed: _reload, child: const Text('重试')),
                        ],
                      ),
                    );
                  }
                  final items = snapshot.data ?? const <V2VoidedCaseItem>[];
                  if (items.isEmpty) {
                    return Center(
                      child: Text(
                        '没有已作废学情',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    );
                  }
                  return ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, _) => Divider(
                      height: 1,
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final restoring = _restoringCaseId == item.caseId;
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(item.title),
                        subtitle: Text(
                          '${item.subject} · ${item.reasonLabel}\n${item.voidedByName} · ${_dateLabel(item.voidedAt)}${item.note == null ? '' : '\n${item.note}'}',
                        ),
                        isThreeLine: item.note != null,
                        trailing: canRestore
                            ? TextButton(
                                key: ValueKey<String>('v2-restore-${item.caseId}'),
                                onPressed: restoring ? null : () => _restore(item),
                                child: restoring
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : const Text('恢复'),
                              )
                            : null,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}'''
preview = replace_between(
    preview,
    'Future<bool> _showV2VoidCase(',
    'Future<void> _showV2ProgressForCase(',
    void_block,
)

student_header = r'''class _StudentHeader extends StatelessWidget {
  const _StudentHeader({required this.student, required this.compact});

  final V2Student student;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final data = V2WorkspaceDataScope.of(context);
    final focusItems = data.focusItemsForStudent(student);
    final runtime = _V2RuntimeScope.maybeOf(context);
    final exportStudent = runtime?.studentExport;
    final controller = runtime?.workflowController;
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
        if (exportStudent != null || controller != null)
          PopupMenuButton<String>(
            key: const Key('v2-student-more-actions'),
            tooltip: '更多操作',
            icon: const Icon(Icons.more_horiz),
            onSelected: (value) async {
              if (value == 'export' && exportStudent != null) {
                await exportStudent(context, student);
              } else if (value == 'voided' && controller != null) {
                await _showV2VoidedCasesForStudent(context, student);
              }
            },
            itemBuilder: (_) => [
              if (exportStudent != null)
                const PopupMenuItem<String>(
                  value: 'export',
                  child: ListTile(
                    leading: Icon(Icons.download_outlined),
                    title: Text('导出学情记录'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              if (controller != null)
                const PopupMenuItem<String>(
                  value: 'voided',
                  child: ListTile(
                    leading: Icon(Icons.inventory_2_outlined),
                    title: Text('已作废学情'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
            ],
          ),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '学生 · ${student.name}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 18),
        if (compact) ...[
          Text(student.name, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 5),
          Text(
            '${student.grade} · ${student.subjects.join(' / ')}',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          if (student.teacherSummary.trim().isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(
              student.teacherSummary,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 16),
          buttons,
        ] else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student.name,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${student.grade} · ${student.subjects.join(' / ')}',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    if (student.teacherSummary.trim().isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        student.teacherSummary,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
              buttons,
            ],
          ),
      ],
    );
  }
}'''
preview = replace_between(
    preview,
    'class _StudentHeader extends StatelessWidget {',
    'class _SectionTitle extends StatelessWidget {',
    student_header,
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
    final timelineEntries = V2WorkspaceDataScope.of(context).timelineForCase(item);
    final controller = _V2RuntimeScope.maybeOf(context)?.workflowController;
    final pendingAction = item.closed ? null : controller?.pendingActionFor(item.id);
    final canReopen =
        item.closed && (controller?.canReopenClosedCase(item.id) ?? false);
    return ColoredBox(
      color: scheme.surface,
      child: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                compact ? 18 : 32,
                20,
                compact ? 18 : 32,
                48,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    tooltip: '返回',
                    onPressed: onBack,
                    icon: const Icon(Icons.arrow_back),
                  ),
                  const SizedBox(height: 8),
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
                      if (controller != null) ...[
                        const SizedBox(width: 4),
                        PopupMenuButton<String>(
                          key: ValueKey<String>('v2-case-more-${item.id}'),
                          tooltip: '更多操作',
                          icon: const Icon(Icons.more_vert),
                          onSelected: (value) async {
                            if (value != 'void') return;
                            final removed = await _showV2VoidCase(
                              context,
                              student,
                              item,
                            );
                            if (removed && context.mounted) onBack();
                          },
                          itemBuilder: (menuContext) => [
                            PopupMenuItem<String>(
                              key: ValueKey<String>('v2-void-${item.id}'),
                              value: 'void',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.hide_source_outlined,
                                    size: 18,
                                    color: Theme.of(menuContext).colorScheme.error,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    '作废错误学情',
                                    style: TextStyle(
                                      color: Theme.of(menuContext).colorScheme.error,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
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
                  const SizedBox(height: 24),
                  if (item.closed) ...[
                    Text('状态', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 18,
                          color: scheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _displayNextStep(item.nextStep),
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ] else
                    Container(
                      key: ValueKey<String>('v2-case-next-step-${item.id}'),
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer.withValues(alpha: 0.28),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: scheme.primary.withValues(alpha: 0.18),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '下一步',
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                              ),
                              Text(
                                item.dueLabel,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Icon(
                                  Icons.arrow_forward,
                                  size: 18,
                                  color: scheme.primary,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _displayNextStep(item.nextStep),
                                  style: Theme.of(context).textTheme.bodyLarge
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
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
                            icon: const Icon(Icons.check_circle_outline, size: 18),
                            label: const Text('完成这一步'),
                          ),
                        OutlinedButton.icon(
                          key: ValueKey<String>('v2-reschedule-${item.id}'),
                          onPressed: () => _showV2RescheduleCurrentAction(
                            context,
                            student,
                            item,
                          ),
                          icon: const Icon(Icons.event_repeat_outlined, size: 18),
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
}'''
preview = replace_between(
    preview,
    'class _CaseDetailPane extends StatelessWidget {',
    'class _TodayPane extends StatelessWidget {',
    case_detail,
)

preview = preview.replace(
    "body: '负责人/管理员在机构管理维护成员、学生、学科、任课和问题类型；学生详情可按学科导出。',",
    "body: '负责人/管理员在机构管理维护成员、学生、学科、任课和问题类型；学生详情可选择具体学情导出，误建记录可安全作废。',",
)
preview_path.write_text(preview, encoding='utf-8')

# Turn low-level TLS/network exceptions into a teacher-readable message while
# keeping technical details out of the primary UI.
auth_path = Path('lib/features/teacher_workspace/presentation/teacher_workspace_page.dart')
auth = auth_path.read_text(encoding='utf-8')
auth_block = r'''  String _describeAuthError(Object error, {required String action}) {
    final rawDetail = error.toString().trim().toLowerCase();
    final looksLikeNetworkFailure =
        rawDetail.contains('handshake') ||
        rawDetail.contains('socket') ||
        rawDetail.contains('connection') ||
        rawDetail.contains('network') ||
        rawDetail.contains('timeout');
    if (looksLikeNetworkFailure) {
      return '$action失败：暂时无法连接服务器，请检查网络后重试；如果当前 Wi-Fi 不稳定，可以尝试切换网络。';
    }
    if (error is AuthException) {
      final detail = error.message.trim();
      if (detail.toLowerCase() == 'invalid login credentials') {
        return '$action失败：账号或密码不正确。';
      }
      if (detail.isEmpty) {
        return '$action失败，请检查网络后重试。';
      }
      return '$action失败：$detail';
    }
    return '$action失败，请检查网络后重试。';
  }'''
auth = replace_between(
    auth,
    '  String _describeAuthError(Object error, {required String action}) {',
    '  @override\n  Widget build(BuildContext context) {',
    auth_block,
)
auth_path.write_text(auth, encoding='utf-8')

# Update the existing safety contract from the old pseudo-delete to real
# invalidation semantics.
void_test_path = Path('test/features/v032_case_media_void_contract_test.dart')
void_test = void_test_path.read_text(encoding='utf-8')
old_test_start = "  test(\n    'teacher delete remains an audited closure rather than physical delete',"
start = void_test.find(old_test_start)
if start < 0:
    raise SystemExit('old void contract test not found')
void_test = void_test[:start] + r'''  test('teacher invalidation is audited and never physically deletes history', () {
    final controller = File(
      'lib/features/design_v2/v2_workflow_controller.dart',
    ).readAsStringSync();
    final preview = File('lib/features/design_v2/v2_workspace_preview.dart')
        .readAsStringSync();

    expect(controller, contains('repository.voidLearningCase('));
    expect(controller, contains('VoidLearningCaseCommand('));
    expect(controller, isNot(contains("note: '教师删除/作废误建或重复问题'")));
    expect(preview, contains("title: const Text('作废这条学情？')"));
    expect(preview, contains("key: const Key('v2-void-reason')"));
    expect(preview, contains("key: const Key('v2-confirm-void-case')"));
    expect(preview, contains("const Text('确认作废')"));
    expect(preview, contains("'作废错误学情'"));
  });
}'''
void_test_path.write_text(void_test, encoding='utf-8')

contract_test = r'''import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('v0.3.6 keeps record validity independent from teaching lifecycle', () {
    final migration = File(
      'supabase/migrations/20260911183000_learning_case_record_organization.sql',
    ).readAsStringSync();

    expect(migration, contains("record_state text not null default 'active'"));
    expect(migration, contains("'case_voided'"));
    expect(migration, contains("'case_restored'"));
    expect(migration, contains('private.void_learning_case_v2'));
    expect(migration, contains('private.restore_learning_case_v2'));
    expect(migration, contains("closure_reason' = 'not_issue'"));
    expect(
      migration,
      contains("closure_note' = '教师删除/作废误建或重复问题'"),
    );
    expect(migration, contains("record_state = 'active'"));
    expect(migration, isNot(contains('delete from public.case_evidence')));
    expect(migration, isNot(contains('delete from public.interventions')));
    expect(migration, isNot(contains('delete from public.assessments')));
  });

  test('selective export is Case-id based and local to one export', () {
    final picker = File('lib/export/learning_record_case_picker.dart')
        .readAsStringSync();
    final repository = File('lib/cloud/student_learning_record_repository.dart')
        .readAsStringSync();
    final loader = File('lib/features/design_v2/v2_workspace_loader.dart')
        .readAsStringSync();

    expect(picker, contains('选择要导出的学情'));
    expect(picker, contains('仅进行中'));
    expect(picker, contains('仅历史'));
    expect(picker, contains('不会结束、删除或修改任何学情'));
    expect(repository, contains('final String? learningCaseId;'));
    expect(
      repository,
      contains('list_student_subject_learning_records_v2_with_attachments'),
    );
    expect(loader, contains('selectedCaseIds.contains(record.learningCaseId)'));
    expect(loader, contains('showLearningRecordCasePicker('));
  });

  test('raw handshake failures are not exposed as the primary login message', () {
    final source = File(
      'lib/features/teacher_workspace/presentation/teacher_workspace_page.dart',
    ).readAsStringSync();
    expect(source, contains("rawDetail.contains('handshake')"));
    expect(source, contains('暂时无法连接服务器'));
    expect(source, contains('可以尝试切换网络'));
  });
}
'''
Path('test/features/v036_learning_record_organization_contract_test.dart').write_text(
    contract_test,
    encoding='utf-8',
)

# Stable releases must refuse to publish until production has the new schema
# and both v0.3.6 capabilities.
workflow_path = Path('.github/workflows/publish-release-assets.yml')
workflow = workflow_path.read_text(encoding='utf-8')
workflow = workflow.replace(
    'required_schema="20260911153000"',
    'required_schema="20260911183000"',
)
workflow = workflow.replace(
    '("student_profile_edit", "learning_record_export_attachments")',
    '("student_profile_edit", "learning_record_export_attachments", "learning_case_record_organization", "selective_learning_record_export")',
)
if 'required_schema="20260911183000"' not in workflow:
    raise SystemExit('stable release schema gate was not updated')
workflow_path.write_text(workflow, encoding='utf-8')

print('v0.3.6 UI, auth UX, contracts, and stable gate patched')
