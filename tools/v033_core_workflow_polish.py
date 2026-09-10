from pathlib import Path

WORKSPACE = Path('lib/features/design_v2/v2_workspace_preview.dart')
FINAL_TEST = Path('test/features/v2_final_ergonomics_test.dart')
WORKSPACE_TEST = Path('test/features/design_v2_workspace_test.dart')
VISUAL_TEST = Path('test/features/v2_visual_polish_contract_test.dart')


def replace_once(source: str, old: str, new: str, label: str) -> str:
    count = source.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected exactly one match, found {count}')
    return source.replace(old, new, 1)


def polish_workspace() -> None:
    source = WORKSPACE.read_text()

    source = replace_once(
        source,
        """    final border = Theme.of(context).colorScheme.outlineVariant;\n    return Scaffold(\n""",
        """    final border = Theme.of(context).colorScheme.outlineVariant;\n    final width = MediaQuery.sizeOf(context).width;\n    final expandedRail = width >= 1280;\n    final studentPaneWidth = width < 900 ? 288.0 : 320.0;\n    return Scaffold(\n""",
        'desktop responsive metrics',
    )
    source = replace_once(
        source,
        """            SizedBox(\n              width: 72,\n              child: _NavigationRail(\n                selectedIndex: destination,\n""",
        """            SizedBox(\n              width: expandedRail ? 132 : 72,\n              child: _NavigationRail(\n                selectedIndex: destination,\n                expanded: expandedRail,\n""",
        'desktop responsive rail width',
    )
    source = replace_once(
        source,
        """              SizedBox(\n                width: 336,\n                child: _StudentListPane(\n""",
        """              SizedBox(\n                width: studentPaneWidth,\n                child: _StudentListPane(\n""",
        'desktop student pane width',
    )
    source = replace_once(
        source,
        """  const _NavigationRail({\n    required this.selectedIndex,\n    required this.onSelected,\n    required this.onSettings,\n    required this.refreshing,\n    this.onRefresh,\n    this.onManage,\n  });\n\n  final int selectedIndex;\n""",
        """  const _NavigationRail({\n    required this.selectedIndex,\n    required this.onSelected,\n    required this.onSettings,\n    required this.refreshing,\n    this.expanded = false,\n    this.onRefresh,\n    this.onManage,\n  });\n\n  final int selectedIndex;\n  final bool expanded;\n""",
        'navigation rail expanded flag',
    )
    source = replace_once(
        source,
        """              onTap: () => onSelected(item.$1),\n            ),\n""",
        """              onTap: () => onSelected(item.$1),\n              expanded: expanded,\n            ),\n""",
        'primary rail expansion',
    )
    source = replace_once(
        source,
        """              onTap: refreshing ? null : onRefresh,\n            ),\n""",
        """              onTap: refreshing ? null : onRefresh,\n              expanded: expanded,\n            ),\n""",
        'refresh rail expansion',
    )
    source = replace_once(
        source,
        """              onTap: onManage,\n            ),\n""",
        """              onTap: onManage,\n              expanded: expanded,\n            ),\n""",
        'manage rail expansion',
    )
    source = replace_once(
        source,
        """            tooltip: '设置',\n            onTap: onSettings,\n          ),\n""",
        """            tooltip: '设置',\n            onTap: onSettings,\n            expanded: expanded,\n          ),\n""",
        'settings rail expansion',
    )
    source = replace_once(
        source,
        """  const _RailItem({\n    super.key,\n    required this.icon,\n    required this.tooltip,\n    this.selected = false,\n    this.onTap,\n  });\n\n  final IconData icon;\n  final String tooltip;\n  final bool selected;\n  final VoidCallback? onTap;\n\n  @override\n  Widget build(BuildContext context) {\n    final scheme = Theme.of(context).colorScheme;\n""",
        """  const _RailItem({\n    super.key,\n    required this.icon,\n    required this.tooltip,\n    this.selected = false,\n    this.expanded = false,\n    this.onTap,\n  });\n\n  final IconData icon;\n  final String tooltip;\n  final bool selected;\n  final bool expanded;\n  final VoidCallback? onTap;\n\n  @override\n  Widget build(BuildContext context) {\n    final scheme = Theme.of(context).colorScheme;\n    final foreground = selected\n        ? scheme.onPrimaryContainer\n        : scheme.onSurfaceVariant;\n""",
        'rail item expanded flag',
    )
    source = replace_once(
        source,
        """              child: SizedBox(\n                width: 48,\n                height: 48,\n                child: Icon(\n                  icon,\n                  size: 20,\n                  color: selected\n                      ? scheme.onPrimaryContainer\n                      : scheme.onSurfaceVariant,\n                ),\n              ),\n""",
        """              child: SizedBox(\n                width: expanded ? 108 : 48,\n                height: 48,\n                child: Row(\n                  mainAxisAlignment: expanded\n                      ? MainAxisAlignment.start\n                      : MainAxisAlignment.center,\n                  children: [\n                    if (expanded) const SizedBox(width: 12),\n                    Icon(icon, size: 20, color: foreground),\n                    if (expanded) ...[\n                      const SizedBox(width: 10),\n                      Expanded(\n                        child: Text(\n                          tooltip,\n                          maxLines: 1,\n                          overflow: TextOverflow.ellipsis,\n                          style: Theme.of(context).textTheme.labelMedium\n                              ?.copyWith(\n                                color: foreground,\n                                fontWeight: selected\n                                    ? FontWeight.w600\n                                    : FontWeight.w500,\n                              ),\n                        ),\n                      ),\n                      const SizedBox(width: 8),\n                    ],\n                  ],\n                ),\n              ),\n""",
        'rail item label layout',
    )

    source = replace_once(
        source,
        """                        selected: student.id == widget.selectedStudent.id,\n""",
        """                        selected:\n                            !widget.compact &&\n                            student.id == widget.selectedStudent.id,\n""",
        'compact student selection',
    )
    source = replace_once(
        source,
        """                      Text(\n                        student.openCaseCount == 0\n                            ? '暂无进行中'\n                            : '${student.openCaseCount} 个问题',\n                        style: Theme.of(context).textTheme.bodySmall,\n                      ),\n                      const SizedBox(height: 3),\n                      Text(\n                        student.updatedLabel,\n                        style: Theme.of(context).textTheme.bodySmall?.copyWith(\n                          color: scheme.onSurfaceVariant.withValues(\n                            alpha: 0.72,\n                          ),\n                        ),\n                      ),\n""",
        """                      Text(\n                        student.openCaseCount == 0\n                            ? '暂无进行中'\n                            : '${student.openCaseCount} 个进行中',\n                        style: Theme.of(context).textTheme.bodySmall,\n                      ),\n                      if (student.updatedLabel != '暂无记录') ...[\n                        const SizedBox(height: 3),\n                        Text(\n                          student.updatedLabel,\n                          style: Theme.of(context).textTheme.bodySmall?.copyWith(\n                            color: scheme.onSurfaceVariant.withValues(\n                              alpha: 0.72,\n                            ),\n                          ),\n                        ),\n                      ],\n""",
        'student row density',
    )

    source = replace_once(
        source,
        """                  Text(\n                    item.title,\n                    style: Theme.of(context).textTheme.titleMedium,\n                  ),\n                  if (_shouldShowCaseSummary(item)) ...[\n""",
        """                  Text(\n                    item.title,\n                    maxLines: 2,\n                    overflow: TextOverflow.ellipsis,\n                    style: Theme.of(context).textTheme.titleMedium,\n                  ),\n                  if (studentName != null) ...[\n                    const SizedBox(height: 4),\n                    Text(\n                      '$studentName · ${item.subject}',\n                      style: Theme.of(context).textTheme.bodySmall,\n                    ),\n                  ],\n                  if (studentName == null && _shouldShowCaseSummary(item)) ...[\n""",
        'focus row hierarchy',
    )
    source = replace_once(
        source,
        """                  Text(\n                    item.closed\n                        ? _displayNextStep(item.nextStep)\n                        : '下一步  ${_displayNextStep(item.nextStep)}',\n                    style: Theme.of(context).textTheme.bodySmall,\n                  ),\n""",
        """                  Text(\n                    item.closed\n                        ? _displayNextStep(item.nextStep)\n                        : '下一步  ${_displayNextStep(item.nextStep)}',\n                    maxLines: 2,\n                    overflow: TextOverflow.ellipsis,\n                    style: Theme.of(context).textTheme.bodySmall,\n                  ),\n""",
        'focus row next step truncation',
    )
    source = replace_once(
        source,
        """            const SizedBox(width: 16),\n            Column(\n              crossAxisAlignment: CrossAxisAlignment.end,\n              children: [\n                Text(\n                  studentName == null\n                      ? item.subject\n                      : '$studentName · ${item.subject}',\n                  style: Theme.of(context).textTheme.bodySmall,\n                ),\n                const SizedBox(height: 17),\n                Text(\n                  item.dueLabel,\n                  style: Theme.of(context).textTheme.bodySmall,\n                ),\n              ],\n            ),\n            const SizedBox(width: 4),\n""",
        """            if (studentName == null) ...[\n              const SizedBox(width: 16),\n              Column(\n                crossAxisAlignment: CrossAxisAlignment.end,\n                children: [\n                  Text(\n                    item.subject,\n                    style: Theme.of(context).textTheme.bodySmall,\n                  ),\n                  const SizedBox(height: 17),\n                  Text(\n                    item.dueLabel,\n                    style: Theme.of(context).textTheme.bodySmall,\n                  ),\n                ],\n              ),\n            ] else if (!item.closed &&\n                item.dueLabel.trim().isNotEmpty &&\n                item.dueLabel != '待安排') ...[\n              const SizedBox(width: 12),\n              Text(\n                item.dueLabel,\n                style: Theme.of(context).textTheme.bodySmall,\n              ),\n            ],\n            const SizedBox(width: 4),\n""",
        'focus row metadata duplication',
    )

    source = replace_once(
        source,
        """                      if (!item.closed) ...[\n                        const SizedBox(width: 16),\n                        FilledButton.icon(\n                          onPressed: () =>\n                              _showV2ProgressForCase(context, student, item),\n                          icon: const Icon(Icons.edit_note_outlined, size: 18),\n                          label: const Text('记进展'),\n                        ),\n                      ],\n""",
        """                      if (!item.closed) ...[\n                        const SizedBox(width: 12),\n                        FilledButton.icon(\n                          onPressed: () =>\n                              _showV2ProgressForCase(context, student, item),\n                          icon: const Icon(Icons.edit_note_outlined, size: 18),\n                          label: const Text('记进展'),\n                        ),\n                        if (controller != null) ...[\n                          const SizedBox(width: 4),\n                          PopupMenuButton<String>(\n                            key: ValueKey<String>(\n                              'v2-case-more-${item.id}',\n                            ),\n                            tooltip: '更多操作',\n                            icon: const Icon(Icons.more_vert),\n                            onSelected: (value) async {\n                              if (value != 'delete') return;\n                              final removed = await _showV2VoidCase(\n                                context,\n                                student,\n                                item,\n                              );\n                              if (removed && context.mounted) onBack();\n                            },\n                            itemBuilder: (menuContext) => [\n                              PopupMenuItem<String>(\n                                key: ValueKey<String>(\n                                  'v2-void-${item.id}',\n                                ),\n                                value: 'delete',\n                                child: Row(\n                                  children: [\n                                    Icon(\n                                      Icons.delete_outline,\n                                      size: 18,\n                                      color: Theme.of(\n                                        menuContext,\n                                      ).colorScheme.error,\n                                    ),\n                                    const SizedBox(width: 10),\n                                    Text(\n                                      '删除问题',\n                                      style: TextStyle(\n                                        color: Theme.of(\n                                          menuContext,\n                                        ).colorScheme.error,\n                                      ),\n                                    ),\n                                  ],\n                                ),\n                              ),\n                            ],\n                          ),\n                        ],\n                      ],\n""",
        'case destructive menu',
    )
    source = replace_once(
        source,
        """                  const SizedBox(height: 28),\n                  Text(\n                    item.closed ? '状态' : '下一步',\n                    style: Theme.of(context).textTheme.titleMedium,\n                  ),\n                  const SizedBox(height: 6),\n                  Row(\n                    children: [\n                      Icon(\n                        Icons.arrow_forward,\n                        size: 17,\n                        color: scheme.primary,\n                      ),\n                      const SizedBox(width: 8),\n                      Expanded(\n                        child: Text(\n                          _displayNextStep(item.nextStep),\n                          style: Theme.of(context).textTheme.bodyMedium,\n                        ),\n                      ),\n                      Text(\n                        item.dueLabel,\n                        style: Theme.of(context).textTheme.bodySmall,\n                      ),\n                    ],\n                  ),\n""",
        """                  const SizedBox(height: 24),\n                  if (item.closed) ...[\n                    Text(\n                      '状态',\n                      style: Theme.of(context).textTheme.titleMedium,\n                    ),\n                    const SizedBox(height: 6),\n                    Row(\n                      children: [\n                        Icon(\n                          Icons.check_circle_outline,\n                          size: 18,\n                          color: scheme.primary,\n                        ),\n                        const SizedBox(width: 8),\n                        Expanded(\n                          child: Text(\n                            _displayNextStep(item.nextStep),\n                            style: Theme.of(context).textTheme.bodyMedium,\n                          ),\n                        ),\n                      ],\n                    ),\n                  ] else\n                    Container(\n                      key: ValueKey<String>(\n                        'v2-case-next-step-${item.id}',\n                      ),\n                      width: double.infinity,\n                      padding: const EdgeInsets.all(16),\n                      decoration: BoxDecoration(\n                        color: scheme.primaryContainer.withValues(alpha: 0.28),\n                        borderRadius: BorderRadius.circular(12),\n                        border: Border.all(\n                          color: scheme.primary.withValues(alpha: 0.18),\n                        ),\n                      ),\n                      child: Column(\n                        crossAxisAlignment: CrossAxisAlignment.start,\n                        children: [\n                          Row(\n                            children: [\n                              Expanded(\n                                child: Text(\n                                  '下一步',\n                                  style: Theme.of(\n                                    context,\n                                  ).textTheme.titleMedium,\n                                ),\n                              ),\n                              Text(\n                                item.dueLabel,\n                                style: Theme.of(context).textTheme.bodySmall,\n                              ),\n                            ],\n                          ),\n                          const SizedBox(height: 8),\n                          Row(\n                            crossAxisAlignment: CrossAxisAlignment.start,\n                            children: [\n                              Padding(\n                                padding: const EdgeInsets.only(top: 2),\n                                child: Icon(\n                                  Icons.arrow_forward,\n                                  size: 18,\n                                  color: scheme.primary,\n                                ),\n                              ),\n                              const SizedBox(width: 8),\n                              Expanded(\n                                child: Text(\n                                  _displayNextStep(item.nextStep),\n                                  style: Theme.of(context).textTheme.bodyLarge\n                                      ?.copyWith(fontWeight: FontWeight.w600),\n                                ),\n                              ),\n                            ],\n                          ),\n                        ],\n                      ),\n                    ),\n""",
        'case next-step emphasis',
    )
    source = replace_once(
        source,
        """                  if (!item.closed && controller != null) ...[\n                    const SizedBox(height: 14),\n                    TextButton.icon(\n                      key: ValueKey<String>('v2-void-${item.id}'),\n                      onPressed: () async {\n                        final removed = await _showV2VoidCase(\n                          context,\n                          student,\n                          item,\n                        );\n                        if (removed && context.mounted) onBack();\n                      },\n                      style: TextButton.styleFrom(\n                        foregroundColor: scheme.error,\n                      ),\n                      icon: const Icon(Icons.delete_outline, size: 18),\n                      label: const Text('删除问题'),\n                    ),\n                  ],\n""",
        '',
        'remove inline destructive action',
    )

    source = replace_once(
        source,
        """    final validItems = data.focusItems\n        .where(\n          (item) =>\n              data.studentForFocusItemOrNull(item) != null &&\n              item.actionTiming != null,\n        )\n        .toList(growable: false);\n    final actionItems =\n        validItems\n            .where(\n              (item) =>\n                  item.actionTiming != V2ActionTiming.future &&\n                  !item.pendingVerification,\n            )\n""",
        """    final validItems = data.focusItems\n        .where((item) => data.studentForFocusItemOrNull(item) != null)\n        .toList(growable: false);\n    final unplannedItems =\n        validItems\n            .where((item) => item.actionTiming == null)\n            .toList(growable: true)\n          ..sort(_compare);\n    final actionItems =\n        validItems\n            .where(\n              (item) =>\n                  item.actionTiming != null &&\n                  item.actionTiming != V2ActionTiming.future &&\n                  !item.pendingVerification,\n            )\n""",
        'today unplanned collection',
    )
    source = replace_once(
        source,
        """              (item) =>\n                  item.actionTiming != V2ActionTiming.future &&\n                  item.pendingVerification,\n""",
        """              (item) =>\n                  item.actionTiming != null &&\n                  item.actionTiming != V2ActionTiming.future &&\n                  item.pendingVerification,\n""",
        'today verification guard',
    )
    source = replace_once(
        source,
        """              if (actionItems.isEmpty && verificationItems.isEmpty)\n                Text(\n                  '今天没有需要处理的学情事项',\n                  style: Theme.of(context).textTheme.bodyMedium,\n                ),\n""",
        """              if (actionItems.isEmpty &&\n                  verificationItems.isEmpty &&\n                  unplannedItems.isEmpty)\n                Text(\n                  '今天没有需要处理的学情事项',\n                  style: Theme.of(context).textTheme.bodyMedium,\n                ),\n""",
        'today empty-state accuracy',
    )
    source = replace_once(
        source,
        """              if (futureItems.isNotEmpty) ...[\n                const SizedBox(height: 28),\n""",
        """              if ((actionItems.isNotEmpty || verificationItems.isNotEmpty) &&\n                  unplannedItems.isNotEmpty)\n                const SizedBox(height: 28),\n              if (unplannedItems.isNotEmpty) ...[\n                _SectionTitle(\n                  title: '待安排下一步',\n                  count: unplannedItems.length,\n                ),\n                const SizedBox(height: 6),\n                Text(\n                  '这些问题还没有明确的后续行动，先补上下一步，避免从跟进中掉出去。',\n                  style: Theme.of(context).textTheme.bodySmall,\n                ),\n                const SizedBox(height: 6),\n                for (final item in unplannedItems)\n                  _TodayAction(item: item, onOpenCase: onOpenCase),\n              ],\n              if (futureItems.isNotEmpty) ...[\n                const SizedBox(height: 28),\n""",
        'today unplanned section',
    )
    source = replace_once(
        source,
        """                    verification ? '等待确认是否已经稳定' : '下一步 · ${item.nextStep}',\n""",
        """                    verification\n                        ? '等待确认是否已经稳定'\n                        : '下一步 · ${_displayNextStep(item.nextStep)}',\n""",
        'today next-step label',
    )
    source = replace_once(
        source,
        """    final pendingAction = controller?.pendingActionFor(item.id);\n    return InkWell(\n""",
        """    final pendingAction = controller?.pendingActionFor(item.id);\n    final status = _todayActionStatus(item, verification: verification);\n    return InkWell(\n""",
        'today status local',
    )
    source = replace_once(
        source,
        """            Text(\n              _todayActionStatus(item, verification: verification),\n              style: Theme.of(context).textTheme.bodySmall,\n            ),\n            const SizedBox(width: 4),\n""",
        """            if (status.isNotEmpty) ...[\n              Text(status, style: Theme.of(context).textTheme.bodySmall),\n              const SizedBox(width: 4),\n            ],\n""",
        'today status rendering',
    )
    source = replace_once(
        source,
        """String _todayActionStatus(V2FocusItem item, {required bool verification}) {\n  if (verification) {\n""",
        """String _todayActionStatus(V2FocusItem item, {required bool verification}) {\n  if (item.actionTiming == null) return '';\n  if (verification) {\n""",
        'today duplicate unplanned status',
    )

    WORKSPACE.write_text(source)


def polish_tests() -> None:
    source = FINAL_TEST.read_text()
    source = source.replace('  V2ActionTiming timing, {', '  V2ActionTiming? timing, {', 1)
    marker = "  testWidgets('quick capture student picker searches name grade and subject', (\n"
    if source.count(marker) != 1:
        raise SystemExit('final ergonomics insertion marker mismatch')
    new_test = """  testWidgets('Today surfaces open cases that still have no next action', (\n    tester,\n  ) async {\n    await tester.binding.setSurfaceSize(const Size(1100, 800));\n    addTearDown(() => tester.binding.setSurfaceSize(null));\n    const unplanned = V2FocusItem(\n      id: 'unplanned',\n      studentId: 's1',\n      title: '还没有安排下一步的问题',\n      summary: '已经发现问题，但尚未形成后续行动。',\n      nextStep: '待安排下一步',\n      dueLabel: '待安排',\n      subject: '语文',\n    );\n    const data = V2WorkspaceData(\n      students: _students,\n      focusItems: <V2FocusItem>[unplanned],\n      timeline: [],\n    );\n\n    await tester.pumpWidget(_app(data));\n    await tester.pumpAndSettle();\n    await tester.tap(find.byTooltip('今日'));\n    await tester.pumpAndSettle();\n\n    expect(find.text('待安排下一步'), findsOneWidget);\n    expect(find.text('还没有安排下一步的问题'), findsOneWidget);\n    expect(find.text('下一步 · 待安排'), findsOneWidget);\n    expect(find.text('今天没有需要处理的学情事项'), findsNothing);\n  });\n\n"""
    FINAL_TEST.write_text(source.replace(marker, new_test + marker, 1))

    source = WORKSPACE_TEST.read_text()
    source = replace_once(
        source,
        """    expect(find.text('再练 2 道同类题'), findsOneWidget);\n    expect(find.textContaining('数量关系先画成简图'), findsOneWidget);\n""",
        """    expect(find.text('再练 2 道同类题'), findsOneWidget);\n    expect(\n      find.byKey(\n        const ValueKey<String>('v2-case-next-step-case-lin-function'),\n      ),\n      findsOneWidget,\n    );\n    expect(find.textContaining('数量关系先画成简图'), findsOneWidget);\n""",
        'case next-step test',
    )
    source = replace_once(
        source,
        """    expect(find.text('化学方程式配平不稳'), findsOneWidget);\n    expect(find.text('阅读概括不完整'), findsNothing);\n    expect(find.text('找到 1 个问题'), findsOneWidget);\n""",
        """    expect(find.text('化学方程式配平不稳'), findsOneWidget);\n    expect(find.text('周同学 · 化学'), findsOneWidget);\n    expect(find.text('基础反应能完成，遇到系数稍复杂时容易反复试错。'), findsNothing);\n    expect(find.text('阅读概括不完整'), findsNothing);\n    expect(find.text('找到 1 个问题'), findsOneWidget);\n""",
        'case index hierarchy test',
    )
    WORKSPACE_TEST.write_text(source)

    source = VISUAL_TEST.read_text()
    marker = "  test('V2 composers keep release-safe motion and touch targets', () {\n"
    if source.count(marker) != 1:
        raise SystemExit('visual polish insertion marker mismatch')
    contract = r'''  test('V2 core workflow keeps teacher attention on next actions', () {
    final source = File('lib/features/design_v2/v2_workspace_preview.dart')
        .readAsStringSync();

    expect(source, contains("'v2-case-next-step-${item.id}'"));
    expect(source, contains("'v2-case-more-${item.id}'"));
    expect(source, contains("title: '待安排下一步'"));
    expect(source, contains('!widget.compact &&'));
    expect(source, contains('final expandedRail = width >= 1280;'));
    expect(source, isNot(contains("label: const Text('删除问题')")));
  });

'''
    VISUAL_TEST.write_text(source.replace(marker, contract + marker, 1))


if __name__ == '__main__':
    polish_workspace()
    polish_tests()
