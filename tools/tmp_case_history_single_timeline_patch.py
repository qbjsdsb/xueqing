from pathlib import Path

PAGE = Path('lib/features/teacher_workspace/presentation/teacher_workspace_page.dart')
TEST = Path('test/features/teacher_workspace_test.dart')

page = PAGE.read_text(encoding='utf-8')


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise SystemExit(f'anchor not found: {label}')
    return text.replace(old, new, 1)


page = replace_once(
    page,
    "  bool _showAllStudentCases = false;\n  bool _showAllCaseTimeline = false;\n",
    "  bool _showAllStudentCases = false;\n"
    "  bool _showAllCaseTimeline = false;\n"
    "  bool _showCaseCategoryDetails = false;\n",
    'case detail state',
)

page = replace_once(
    page,
    "  void _openCase(WorkspaceStudent student, WorkspaceCase learningCase) {\n"
    "    setState(() {\n"
    "      _selectedStudent = student;\n"
    "      _selectedCase = learningCase;\n",
    "  void _openCase(WorkspaceStudent student, WorkspaceCase learningCase) {\n"
    "    setState(() {\n"
    "      _selectedStudent = student;\n"
    "      _selectedCase = learningCase;\n"
    "      _showAllCaseTimeline = false;\n"
    "      _showCaseCategoryDetails = false;\n",
    'open case reset',
)

case_method = page.index('  Widget _buildCaseDetail(')
start = page.index('        _WorkspaceEvidenceSection(\n', case_method)
end_marker = '      ],\n    );\n  }\n}\n\nclass _WorkspaceReopenCaseForm'
end = page.index(end_marker, start)

replacement = '''        _WorkspaceSection(
          title: '成长记录',
          count: learningCase.timeline.isEmpty
              ? null
              : '${learningCase.timeline.length} 条',
          showTopDivider: true,
          action: learningCase.timeline.length > _caseTimelinePreviewLimit
              ? TextButton(
                  key: const Key('workspace-case-timeline-toggle'),
                  onPressed: () => setState(
                    () => _showAllCaseTimeline = !_showAllCaseTimeline,
                  ),
                  child: Text(_showAllCaseTimeline ? '收起记录' : '查看更早记录'),
                )
              : null,
          child: learningCase.timeline.isEmpty
              ? const _WorkspaceStateNotice(
                  title: '暂时没有更多历史',
                  message: '新的课堂记录、教学处理和检查结果会按时间追加在这里。',
                  icon: Icons.history_outlined,
                )
              : _WorkspaceTimelineGroupedList(events: visibleTimeline),
        ),
        const SizedBox(height: AppSpacing.sm),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: const Key('workspace-case-category-toggle'),
            onPressed: () => setState(
              () => _showCaseCategoryDetails = !_showCaseCategoryDetails,
            ),
            icon: Icon(
              _showCaseCategoryDetails
                  ? Icons.expand_less
                  : Icons.view_list_outlined,
            ),
            label: Text(
              _showCaseCategoryDetails ? '收起分类记录' : '按类别查看与照片',
            ),
          ),
        ),
        if (_showCaseCategoryDetails) ...[
          Text(
            '这里按类别核对学生表现、教学处理和检查结果；成长过程仍以时间顺序为主。',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          _WorkspaceEvidenceSection(
            learningCase: learningCase,
            organizationId: workspace.organizationId,
            repository: widget.evidenceAttachmentRepository,
          ),
          _WorkspaceNarrativeSection(
            title: '教学处理',
            content: learningCase.interventions.isEmpty
                ? '尚未记录教学处理。'
                : learningCase.interventions
                      .map(
                        (item) =>
                            '${_formatDate(item.occurredAt)}：${item.strategy}',
                      )
                      .join('\\n\\n'),
          ),
          _WorkspaceNarrativeSection(
            title: '检查结果',
            content: learningCase.assessments.isEmpty
                ? '尚未记录检查结果。'
                : learningCase.assessments
                      .map(
                        (item) =>
                            '${_formatDate(item.assessedAt)} ${_assessmentLabel(item.result)}：${item.evidenceSummary}',
                      )
                      .join('\\n\\n'),
          ),
        ],
'''
page = page[:start] + replacement + page[end:]

old_timeline_class_start = page.index('class _WorkspaceTimelineItem extends StatelessWidget {')
old_timeline_class_end = page.index('class _WorkspaceSubheading extends StatelessWidget {', old_timeline_class_start)
new_timeline_classes = '''class _WorkspaceTimelineGroupedList extends StatelessWidget {
  const _WorkspaceTimelineGroupedList({required this.events});

  final Iterable<WorkspaceTimelineEvent> events;

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<WorkspaceTimelineEvent>>{};
    for (final event in events) {
      final local = event.occurredAt.toLocal();
      final dateLabel = _formatDate(local);
      groups.putIfAbsent(dateLabel, () => <WorkspaceTimelineEvent>[]).add(event);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final entry in groups.entries) ...[
          Padding(
            padding: const EdgeInsets.only(
              top: AppSpacing.sm,
              bottom: AppSpacing.xxs,
            ),
            child: Text(
              entry.key,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          for (final event in entry.value)
            _WorkspaceTimelineItem(event: event, timeOnly: true),
        ],
      ],
    );
  }
}

class _WorkspaceTimelineItem extends StatelessWidget {
  const _WorkspaceTimelineItem({required this.event, this.timeOnly = false});

  final WorkspaceTimelineEvent event;
  final bool timeOnly;

  @override
  Widget build(BuildContext context) {
    final local = event.occurredAt.toLocal();
    final timeLabel =
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: timeOnly ? 48 : 72,
            child: Text(
              timeOnly ? timeLabel : _formatDate(local),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Icon(
              Icons.circle,
              size: 8,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.typeLabel,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(event.text, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

'''
page = page[:old_timeline_class_start] + new_timeline_classes + page[old_timeline_class_end:]
PAGE.write_text(page, encoding='utf-8')

test = TEST.read_text(encoding='utf-8')
test = replace_once(
    test,
    "    expect(find.text('待整理问题'), findsNothing);\n"
    "    expect(find.text('尚未记录教学处理。'), findsOneWidget);\n",
    "    expect(find.text('待整理问题'), findsNothing);\n"
    "    expect(find.text('成长记录'), findsOneWidget);\n"
    "    expect(find.text('尚未记录教学处理。'), findsNothing);\n"
    "    final categoryToggle = find.byKey(\n"
    "      const Key('workspace-case-category-toggle'),\n"
    "    );\n"
    "    await tester.ensureVisible(categoryToggle);\n"
    "    await tester.tap(categoryToggle);\n"
    "    await tester.pumpAndSettle();\n"
    "    expect(find.text('学生表现'), findsOneWidget);\n"
    "    expect(find.text('尚未记录教学处理。'), findsOneWidget);\n"
    "    expect(find.text('尚未记录检查结果。'), findsOneWidget);\n",
    'default category disclosure test',
)

test = replace_once(
    test,
    "      expect(find.text('历史记录 3'), findsOneWidget);\n"
    "      expect(find.text('历史记录 4'), findsNothing);\n",
    "      expect(find.text('历史记录 3'), findsOneWidget);\n"
    "      expect(find.text('9 月 7 日'), findsOneWidget);\n"
    "      expect(find.text('9 月 6 日'), findsOneWidget);\n"
    "      expect(find.text('历史记录 4'), findsNothing);\n",
    'date grouping assertions',
)

test = replace_once(
    test,
    "      expect(find.text('历史记录 5'), findsOneWidget);\n"
    "      expect(find.text('收起记录'), findsOneWidget);\n\n"
    "      final backButton = find.byTooltip('返回学生详情');\n",
    "      expect(find.text('历史记录 5'), findsOneWidget);\n"
    "      expect(find.text('收起记录'), findsOneWidget);\n\n"
    "      final categoryToggle = find.byKey(\n"
    "        const Key('workspace-case-category-toggle'),\n"
    "      );\n"
    "      await tester.ensureVisible(categoryToggle);\n"
    "      await tester.tap(categoryToggle);\n"
    "      await tester.pumpAndSettle();\n"
    "      expect(find.text('尚未记录教学处理。'), findsOneWidget);\n\n"
    "      final backButton = find.byTooltip('返回学生详情');\n",
    'category reset setup',
)

test = replace_once(
    test,
    "      expect(find.text('历史记录 4'), findsNothing);\n"
    "      expect(find.text('查看更早记录'), findsOneWidget);\n",
    "      expect(find.text('历史记录 4'), findsNothing);\n"
    "      expect(find.text('查看更早记录'), findsOneWidget);\n"
    "      expect(find.text('尚未记录教学处理。'), findsNothing);\n"
    "      expect(find.text('按类别查看与照片'), findsOneWidget);\n",
    'category reset assertion',
)
TEST.write_text(test, encoding='utf-8')
