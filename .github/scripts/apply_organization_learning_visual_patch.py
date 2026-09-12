from pathlib import Path


page_path = Path('lib/features/design_v2/v2_organization_workspace_page.dart')
page = page_path.read_text()


def replace_once(source: str, old: str, new: str, label: str) -> str:
    count = source.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected one match, got {count}')
    return source.replace(old, new)


page = replace_once(
    page,
    """  String _summaryText({
    required int activeCount,
    required int pendingCount,
    required int overdueCount,
    required int unassignedProfileCount,
  }) {
    final parts = <String>[
      '${widget.data.students.length} 名学生',
      '$activeCount 个问题正在跟进',
      if (pendingCount > 0) '$pendingCount 个待复检',
      if (overdueCount > 0) '$overdueCount 个已逾期',
      if (unassignedProfileCount > 0) '$unassignedProfileCount 个学科未明确主责',
    ];
    return parts.join(' · ');
  }
""",
    """  String _summaryText({required int activeCount}) =>
      '${widget.data.students.length} 名学生 · $activeCount 个问题正在跟进';

  String? _attentionSummaryText({
    required int pendingCount,
    required int overdueCount,
    required int unassignedProfileCount,
  }) {
    final parts = <String>[
      if (pendingCount > 0) '$pendingCount 个待复检',
      if (overdueCount > 0) '$overdueCount 个已逾期',
      if (unassignedProfileCount > 0) '$unassignedProfileCount 个学科未明确主责',
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }
""",
    'summary helper',
)

page = replace_once(
    page,
    """    final compact = MediaQuery.sizeOf(context).width < 720;
    final horizontalPadding = compact ? 16.0 : 24.0;

    return Column(""",
    """    final attentionSummary = _attentionSummaryText(
      pendingCount: pendingCount,
      overdueCount: overdueCount,
      unassignedProfileCount: unassignedProfileCount,
    );
    final compact = MediaQuery.sizeOf(context).width < 720;
    final horizontalPadding = compact ? 16.0 : 24.0;

    return Column(""",
    'attention summary value',
)

page = replace_once(
    page,
    """                Text(
                  _summaryText(
                    activeCount: activeCaseCount,
                    pendingCount: pendingCount,
                    overdueCount: overdueCount,
                    unassignedProfileCount: unassignedProfileCount,
                  ),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 5),
                Text(
                  '监督全机构学情与协作进度；机构操作不会自动改变教师主责。',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
""",
    """                Text(
                  _summaryText(activeCount: activeCaseCount),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (attentionSummary != null) ...[
                  const SizedBox(height: 5),
                  Text(
                    '需要关注：$attentionSummary',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: 5),
                Text(
                  '查看全机构当前问题、主责与下一步；机构操作不会自动改变教师主责。',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
""",
    'organization header hierarchy',
)

page = replace_once(
    page,
    """  String _subjectResponsibilityPreview() {
    if (profiles.isEmpty) return responsibilitySummary;
    final rows = [
      for (final profile in profiles)
        '${profile.subject} · ${leadLabelForProfile(profile)}',
    ];
    if (rows.length <= 2) return rows.join('  /  ');
    return '${rows.take(2).join('  /  ')}  /  另 ${rows.length - 2} 门';
  }
""",
    """  Widget _subjectResponsibilityPreview(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    if (profiles.isEmpty) {
      return Text(responsibilitySummary, style: style);
    }
    final limit = compact ? 2 : 3;
    final visibleProfiles = profiles.take(limit).toList(growable: false);
    return Wrap(
      spacing: 16,
      runSpacing: 4,
      children: [
        for (final profile in visibleProfiles)
          Text(
            '${profile.subject} · ${leadLabelForProfile(profile)}',
            style: style,
          ),
        if (profiles.length > visibleProfiles.length)
          Text('另 ${profiles.length - visibleProfiles.length} 门学科', style: style),
      ],
    );
  }
""",
    'subject responsibility preview',
)

page = replace_once(
    page,
    """        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Text('当前没有需要跟进的问题\\n${_subjectResponsibilityPreview()}'),
        ),
        isThreeLine: true,
""",
    """        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('当前没有需要跟进的问题', style: subtitleStyle),
              const SizedBox(height: 6),
              _subjectResponsibilityPreview(context),
            ],
          ),
        ),
""",
    'empty student subtitle',
)

page = replace_once(
    page,
    """      subtitle: Padding(
        padding: const EdgeInsets.only(top: 5),
        child: Text(
          activeItems.isEmpty
              ? '当前没有需要跟进的问题${closedItems.isEmpty ? '' : ' · ${closedItems.length} 个历史问题'}\\n${_subjectResponsibilityPreview()}'
              : '${_statusSummary(activeItems)}\\n${_subjectResponsibilityPreview()}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
""",
    """      subtitle: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              activeItems.isEmpty
                  ? '当前没有需要跟进的问题${closedItems.isEmpty ? '' : ' · ${closedItems.length} 个历史问题'}'
                  : _statusSummary(activeItems),
              style: subtitleStyle,
            ),
            const SizedBox(height: 6),
            _subjectResponsibilityPreview(context),
          ],
        ),
      ),
""",
    'expandable student subtitle',
)

old_case_build = """  @override
  Widget build(BuildContext context) {
    final detail = historical
        ? '${item.subject} · 已结束 · 主责：$ownerLabel'
        : '${item.subject} · ${_caseStatusLabel(item)} · 主责：$ownerLabel\\n'
              '下一步：${item.nextStep} · ${item.dueLabel}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 4, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            dense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
            title: Text(item.title),
            subtitle: Text(
              detail,
              maxLines: historical ? 1 : 2,
              overflow: TextOverflow.ellipsis,
            ),
            isThreeLine: !historical,
          ),
          if (!historical && collaborationLabel != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 2),
              child: Text(
                collaborationLabel!,
                key: ValueKey<String>(
                  'v2-organization-collaboration-${item.id}',
                ),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }
"""
new_case_build = """  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mutedStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(40, historical ? 7 : 10, 8, historical ? 7 : 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item.title, style: theme.textTheme.titleSmall),
          const SizedBox(height: 5),
          Wrap(
            spacing: 14,
            runSpacing: 4,
            children: [
              Text(item.subject, style: mutedStyle),
              Text(
                historical ? '已结束' : _caseStatusLabel(item),
                style: mutedStyle,
              ),
              Text('主责：$ownerLabel', style: mutedStyle),
            ],
          ),
          if (!historical) ...[
            const SizedBox(height: 7),
            Wrap(
              spacing: 14,
              runSpacing: 4,
              children: [
                Text('下一步：${item.nextStep}', style: theme.textTheme.bodyMedium),
                Text(item.dueLabel, style: mutedStyle),
              ],
            ),
          ],
          if (!historical && collaborationLabel != null) ...[
            const SizedBox(height: 5),
            Text(
              collaborationLabel!,
              key: ValueKey<String>(
                'v2-organization-collaboration-${item.id}',
              ),
              style: mutedStyle,
            ),
          ],
        ],
      ),
    );
  }
"""
page = replace_once(page, old_case_build, new_case_build, 'case row hierarchy')

page_path.write_text(page)


test_path = Path('test/features/v2_organization_workspace_test.dart')
test = test_path.read_text()
test = replace_once(
    test,
    """      expect(find.text('2 名学生 · 2 个问题正在跟进 · 1 个学科未明确主责'), findsOneWidget);
""",
    """      expect(find.text('2 名学生 · 2 个问题正在跟进'), findsOneWidget);
      expect(find.text('需要关注：1 个学科未明确主责'), findsOneWidget);
""",
    'organization summary assertion',
)
test = replace_once(
    test,
    """      expect(find.textContaining('语文 · 跟进中 · 主责：张老师'), findsOneWidget);
      expect(find.textContaining('下一步：下一次继续检查'), findsOneWidget);
""",
    """      expect(find.text('跟进中'), findsWidgets);
      expect(find.text('主责：张老师'), findsOneWidget);
      expect(find.text('下一步：下一次继续检查'), findsOneWidget);
""",
    'lead case assertion',
)
test = replace_once(
    test,
    """      expect(find.textContaining('语文 · 跟进中 · 主责：王老师'), findsOneWidget);
""",
    """      expect(find.text('主责：王老师'), findsOneWidget);
""",
    'persisted owner assertion',
)
test_path.write_text(test)
