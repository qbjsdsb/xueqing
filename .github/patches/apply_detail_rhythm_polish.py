from pathlib import Path

workspace_path = Path('lib/features/design_v2/v2_workspace_preview.dart')
test_path = Path('test/features/v2_student_focus_presentation_test.dart')
workspace = workspace_path.read_text()
tests = test_path.read_text()


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected 1 match, found {count}')
    return text.replace(old, new, 1)

workspace = replace_once(
    workspace,
    """                      if (widget.onBack != null) ...[\n                        IconButton(\n                          tooltip: '返回学生列表',\n                          onPressed: widget.onBack,\n                          icon: const Icon(Icons.arrow_back),\n                        ),\n                        const SizedBox(height: 4),\n                      ],\n                      _StudentHeader(\n                        student: widget.student,\n                        compact: widget.compact,\n                      ),\n""",
    """                      _StudentHeader(\n                        student: widget.student,\n                        compact: widget.compact,\n                        onBack: widget.onBack,\n                      ),\n""",
    'student detail back handoff',
)

workspace = replace_once(
    workspace,
    """class _StudentHeader extends StatelessWidget {\n  const _StudentHeader({required this.student, required this.compact});\n\n  final V2Student student;\n  final bool compact;\n""",
    """class _StudentHeader extends StatelessWidget {\n  const _StudentHeader({\n    required this.student,\n    required this.compact,\n    this.onBack,\n  });\n\n  final V2Student student;\n  final bool compact;\n  final VoidCallback? onBack;\n""",
    'student header signature',
)

old_buttons = """    final buttons = Wrap(\n      spacing: 8,\n      runSpacing: 8,\n      children: [\n        OutlinedButton.icon(\n          onPressed: () => _showV2QuickCaptureForStudent(context, student),\n          icon: const Icon(Icons.note_add_outlined, size: 18),\n          label: const Text('记录问题'),\n        ),\n        FilledButton.icon(\n          onPressed: focusItems.isEmpty\n              ? null\n              : () => _showV2ProgressCasePicker(context, student),\n          icon: const Icon(Icons.edit_note_outlined, size: 18),\n          label: const Text('记进展'),\n        ),\n        if (exportStudent != null || controller != null)\n          PopupMenuButton<String>(\n            key: const Key('v2-student-more-actions'),\n            tooltip: '更多操作',\n            icon: const Icon(Icons.more_horiz),\n            onSelected: (value) async {\n              if (value == 'export' && exportStudent != null) {\n                await exportStudent(context, student);\n              } else if (value == 'voided' && controller != null) {\n                await _showV2VoidedCasesForStudent(context, student);\n              }\n            },\n            itemBuilder: (_) => [\n              if (exportStudent != null)\n                const PopupMenuItem<String>(\n                  value: 'export',\n                  child: ListTile(\n                    leading: Icon(Icons.download_outlined),\n                    title: Text('导出学情记录'),\n                    contentPadding: EdgeInsets.zero,\n                  ),\n                ),\n              if (controller != null)\n                const PopupMenuItem<String>(\n                  value: 'voided',\n                  child: ListTile(\n                    leading: Icon(Icons.inventory_2_outlined),\n                    title: Text('已作废学情'),\n                    contentPadding: EdgeInsets.zero,\n                  ),\n                ),\n            ],\n          ),\n      ],\n    );\n"""
new_buttons = """    final hasFocusItems = focusItems.isNotEmpty;\n    final buttons = Wrap(\n      spacing: 8,\n      runSpacing: 8,\n      children: [\n        if (hasFocusItems)\n          OutlinedButton.icon(\n            onPressed: () => _showV2QuickCaptureForStudent(context, student),\n            icon: const Icon(Icons.note_add_outlined, size: 18),\n            label: const Text('记录问题'),\n          )\n        else\n          FilledButton.icon(\n            onPressed: () => _showV2QuickCaptureForStudent(context, student),\n            icon: const Icon(Icons.note_add_outlined, size: 18),\n            label: const Text('记录问题'),\n          ),\n        if (hasFocusItems)\n          FilledButton.icon(\n            onPressed: () => _showV2ProgressCasePicker(context, student),\n            icon: const Icon(Icons.edit_note_outlined, size: 18),\n            label: const Text('记进展'),\n          ),\n        if (exportStudent != null || controller != null)\n          PopupMenuButton<String>(\n            key: const Key('v2-student-more-actions'),\n            tooltip: '更多操作',\n            icon: const Icon(Icons.more_horiz),\n            onSelected: (value) async {\n              if (value == 'export' && exportStudent != null) {\n                await exportStudent(context, student);\n              } else if (value == 'voided' && controller != null) {\n                await _showV2VoidedCasesForStudent(context, student);\n              }\n            },\n            itemBuilder: (_) => [\n              if (exportStudent != null)\n                const PopupMenuItem<String>(\n                  value: 'export',\n                  child: ListTile(\n                    leading: Icon(Icons.download_outlined),\n                    title: Text('导出学情记录'),\n                    contentPadding: EdgeInsets.zero,\n                  ),\n                ),\n              if (controller != null)\n                const PopupMenuItem<String>(\n                  value: 'voided',\n                  child: ListTile(\n                    leading: Icon(Icons.inventory_2_outlined),\n                    title: Text('已作废学情'),\n                    contentPadding: EdgeInsets.zero,\n                  ),\n                ),\n            ],\n          ),\n      ],\n    );\n"""
workspace = replace_once(workspace, old_buttons, new_buttons, 'student action hierarchy')

workspace = replace_once(
    workspace,
    """      children: [\n        Text(\n          '学生 · ${student.name}',\n          style: Theme.of(context).textTheme.bodySmall,\n        ),\n        const SizedBox(height: 18),\n        if (compact) ...[\n          Text(student.name, style: Theme.of(context).textTheme.headlineSmall),\n""",
    """      children: [\n        if (compact) ...[\n          Row(\n            key: const Key('v2-student-detail-context-row'),\n            crossAxisAlignment: CrossAxisAlignment.center,\n            children: [\n              if (onBack != null) ...[\n                IconButton(\n                  tooltip: '返回学生列表',\n                  onPressed: onBack,\n                  icon: const Icon(Icons.arrow_back),\n                ),\n                const SizedBox(width: 4),\n              ],\n              Expanded(\n                child: Text(\n                  student.name,\n                  maxLines: 2,\n                  overflow: TextOverflow.ellipsis,\n                  style: Theme.of(context).textTheme.headlineSmall,\n                ),\n              ),\n            ],\n          ),\n""",
    'student compact context row',
)

workspace = workspace.replace(
    """                          _FocusRow(\n                            item: visibleFocusItems[i],\n                            onTap: () =>\n                                widget.onOpenCase(visibleFocusItems[i]),\n                          ),\n                          if (i < visibleFocusItems.length - 1)\n                            Divider(height: 1, color: scheme.outlineVariant),\n""",
    """                          _FocusRow(\n                            item: visibleFocusItems[i],\n                            onTap: () =>\n                                widget.onOpenCase(visibleFocusItems[i]),\n                          ),\n""",
)
workspace = workspace.replace(
    """                            _FocusRow(\n                              item: closedItems[i],\n                              onTap: () => widget.onOpenCase(closedItems[i]),\n                            ),\n                            if (i < closedItems.length - 1)\n                              Divider(height: 1, color: scheme.outlineVariant),\n""",
    """                            _FocusRow(\n                              item: closedItems[i],\n                              onTap: () => widget.onOpenCase(closedItems[i]),\n                            ),\n""",
)

workspace = replace_once(
    workspace,
    """                  IconButton(\n                    tooltip: '返回',\n                    onPressed: onBack,\n                    icon: const Icon(Icons.arrow_back),\n                  ),\n                  const SizedBox(height: 8),\n                  Text(\n                    '${student.name} · ${item.subject}',\n                    maxLines: 2,\n                    overflow: TextOverflow.ellipsis,\n                    style: theme.textTheme.bodySmall?.copyWith(\n                      color: scheme.onSurfaceVariant,\n                    ),\n                  ),\n                  const SizedBox(height: 12),\n""",
    """                  Row(\n                    key: const Key('v2-case-context-row'),\n                    children: [\n                      IconButton(\n                        tooltip: '返回',\n                        onPressed: onBack,\n                        icon: const Icon(Icons.arrow_back),\n                      ),\n                      const SizedBox(width: 4),\n                      Expanded(\n                        child: Text(\n                          '${student.name} · ${item.subject}',\n                          maxLines: 2,\n                          overflow: TextOverflow.ellipsis,\n                          style: theme.textTheme.bodySmall?.copyWith(\n                            color: scheme.onSurfaceVariant,\n                          ),\n                        ),\n                      ),\n                    ],\n                  ),\n                  const SizedBox(height: 12),\n""",
    'case context row',
)

workspace = replace_once(
    workspace,
    """                  const SizedBox(height: 30),\n                  Divider(color: scheme.outlineVariant),\n                  const SizedBox(height: 28),\n                  const _SectionTitle(title: '成长过程'),\n""",
    """                  const SizedBox(height: 40),\n                  const _SectionTitle(title: '成长过程'),\n""",
    'case growth divider',
)

# Add behavior-focused regression tests without locking implementation strings.
insert_at = tests.rfind('\n}')
if insert_at < 0:
    raise SystemExit('test insertion point not found')
addition = r'''

  testWidgets(
    'compact student detail keeps one identity row and only actionable primary controls',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(app(dataWith(const [])));
      await tester.pumpAndSettle();
      final navigation = tester.widget<NavigationBar>(find.byType(NavigationBar));
      navigation.onDestinationSelected!(1);
      await tester.pumpAndSettle();
      await tester.tap(find.text('测试学生').first);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('v2-student-detail-context-row')),
        findsOneWidget,
      );
      expect(find.text('学生 · 测试学生'), findsNothing);
      expect(find.widgetWithText(FilledButton, '记录问题'), findsOneWidget);
      expect(find.text('记进展'), findsNothing);
      expect(find.byTooltip('返回学生列表'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'student detail promotes progress only when there is an active case and case context stays compact',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final data = dataWith(const [
        V2FocusItem(
          id: 'active-case',
          studentId: 'student-1',
          title: '阅读概括遗漏要点',
          summary: '概括题容易漏掉条件',
          nextStep: '再做一组概括题',
          dueLabel: '今天',
          subject: '语文',
        ),
      ]);

      await tester.pumpWidget(app(data));
      await tester.pumpAndSettle();
      final navigation = tester.widget<NavigationBar>(find.byType(NavigationBar));
      navigation.onDestinationSelected!(1);
      await tester.pumpAndSettle();
      await tester.tap(find.text('测试学生').first);
      await tester.pumpAndSettle();

      expect(find.widgetWithText(FilledButton, '记进展'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, '记录问题'), findsOneWidget);

      await tester.tap(find.text('阅读概括遗漏要点'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('v2-case-context-row')), findsOneWidget);
      expect(find.byTooltip('返回'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
'''
tests = tests[:insert_at] + addition + tests[insert_at:]

workspace_path.write_text(workspace)
test_path.write_text(tests)
