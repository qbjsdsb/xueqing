from pathlib import Path

page_path = Path('lib/features/design_v2/v2_organization_workspace_page.dart')
page = page_path.read_text()

old = """  bool _hasUnassignedProfile(List<WorkspaceStudent> profiles) => profiles.any(
    (profile) =>
        widget.responsibility.leadMembershipIdForProfile(profile.profileId) ==
        null,
  );
"""
new = """  int _unassignedProfileCount(List<WorkspaceStudent> profiles) => profiles
      .where(
        (profile) =>
            widget.responsibility.leadMembershipIdForProfile(
              profile.profileId,
            ) ==
            null,
      )
      .length;

  bool _hasUnassignedProfile(List<WorkspaceStudent> profiles) =>
      _unassignedProfileCount(profiles) > 0;
"""
if old not in page:
    raise SystemExit('unassigned helper anchor not found')
page = page.replace(old, new, 1)

old = """                                  return _OrganizationStudentSelectionRow(
                                    student: student,
                                    items: items,
                                    responsibilitySummary:
                                        _responsibilitySummary(profiles),
                                    selected: student.id == selectedStudent?.id,
                                    onTap: () => setState(
                                      () => _selectedStudentId = student.id,
                                    ),
                                  );
"""
new = """                                  return _OrganizationStudentSelectionRow(
                                    student: student,
                                    items: items,
                                    unassignedProfileCount:
                                        _unassignedProfileCount(profiles),
                                    selected: student.id == selectedStudent?.id,
                                    onTap: () => setState(
                                      () => _selectedStudentId = student.id,
                                    ),
                                  );
"""
if old not in page:
    raise SystemExit('expanded student row constructor anchor not found')
page = page.replace(old, new, 1)

old = """                            return _OrganizationStudentRow(
                              student: student,
                              items: items,
                              profiles: profiles,
                              caseOwnerLabelByCaseId: caseOwnerLabelByCaseId,
                              collaborationLabelByCaseId:
                                  collaborationLabelByCaseId,
                              responsibilitySummary: _responsibilitySummary(
                                profiles,
                              ),
                              leadLabelForProfile: _leadLabelForProfile,
                              compact: compact,
                              onQuickCapture: () =>
                                  _openQuickCapture(context, student),
                            );
"""
new = """                            return _OrganizationStudentRow(
                              student: student,
                              items: items,
                              unassignedProfileCount:
                                  _unassignedProfileCount(profiles),
                              caseOwnerLabelByCaseId: caseOwnerLabelByCaseId,
                              collaborationLabelByCaseId:
                                  collaborationLabelByCaseId,
                              compact: compact,
                              onQuickCapture: () =>
                                  _openQuickCapture(context, student),
                            );
"""
if old not in page:
    raise SystemExit('stacked student row constructor anchor not found')
page = page.replace(old, new, 1)

anchor = """class _OrganizationStudentSelectionRow extends StatelessWidget {
"""
helper = """class _OrganizationStudentAttentionSummary {
  const _OrganizationStudentAttentionSummary({
    required this.label,
    required this.needsAttention,
  });

  final String label;
  final bool needsAttention;
}

_OrganizationStudentAttentionSummary _organizationStudentAttentionSummary(
  List<V2FocusItem> activeItems, {
  required int unassignedProfileCount,
}) {
  final overdueCount = activeItems
      .where((item) => item.actionTiming == V2ActionTiming.overdue)
      .length;
  final pendingCount = activeItems
      .where(
        (item) =>
            item.actionTiming != V2ActionTiming.overdue &&
            (item.pendingVerification ||
                item.effectiveStatus == V2CaseStatus.pendingVerification),
      )
      .length;
  final undatedCount = activeItems
      .where(
        (item) =>
            item.actionTiming == V2ActionTiming.undated &&
            !item.pendingVerification &&
            item.effectiveStatus != V2CaseStatus.pendingVerification,
      )
      .length;

  final attentionCount =
      overdueCount + pendingCount + unassignedProfileCount + undatedCount;
  if (attentionCount == 0) {
    return _OrganizationStudentAttentionSummary(
      label: activeItems.isEmpty ? '暂无跟进' : '${activeItems.length} 个跟进中',
      needsAttention: false,
    );
  }

  late final String primaryLabel;
  late final int primaryCount;
  if (overdueCount > 0) {
    primaryCount = overdueCount;
    primaryLabel = '$overdueCount 个已逾期';
  } else if (pendingCount > 0) {
    primaryCount = pendingCount;
    primaryLabel = '$pendingCount 个待复检';
  } else if (unassignedProfileCount > 0) {
    primaryCount = unassignedProfileCount;
    primaryLabel = '$unassignedProfileCount 门学科未明确主责';
  } else {
    primaryCount = undatedCount;
    primaryLabel = '$undatedCount 个待安排日期';
  }

  final remainingCount = attentionCount - primaryCount;
  return _OrganizationStudentAttentionSummary(
    label: remainingCount > 0
        ? '$primaryLabel · 另 $remainingCount 项需关注'
        : primaryLabel,
    needsAttention: true,
  );
}

class _OrganizationStudentSelectionRow extends StatelessWidget {
"""
if anchor not in page:
    raise SystemExit('selection row class anchor not found')
page = page.replace(anchor, helper, 1)

old = """  const _OrganizationStudentSelectionRow({
    required this.student,
    required this.items,
    required this.responsibilitySummary,
    required this.selected,
    required this.onTap,
  });

  final V2Student student;
  final List<V2FocusItem> items;
  final String responsibilitySummary;
  final bool selected;
"""
new = """  const _OrganizationStudentSelectionRow({
    required this.student,
    required this.items,
    required this.unassignedProfileCount,
    required this.selected,
    required this.onTap,
  });

  final V2Student student;
  final List<V2FocusItem> items;
  final int unassignedProfileCount;
  final bool selected;
"""
if old not in page:
    raise SystemExit('selection row fields anchor not found')
page = page.replace(old, new, 1)

old = """    final pendingCount = activeItems
        .where(
          (item) =>
              item.pendingVerification ||
              item.effectiveStatus == V2CaseStatus.pendingVerification,
        )
        .length;
    final overdueCount = activeItems
        .where((item) => item.actionTiming == V2ActionTiming.overdue)
        .length;
    final statusParts = <String>[
      activeItems.isEmpty ? '暂无跟进' : '${activeItems.length} 个跟进中',
      if (pendingCount > 0) '$pendingCount 个待复检',
      if (overdueCount > 0) '$overdueCount 个已逾期',
    ];
"""
new = """    final attention = _organizationStudentAttentionSummary(
      activeItems,
      unassignedProfileCount: unassignedProfileCount,
    );
"""
if old not in page:
    raise SystemExit('selection row status calculation anchor not found')
page = page.replace(old, new, 1)

old = """              Text(
                statusParts.join(' · '),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              if (responsibilitySummary.contains('未')) ...[
                const SizedBox(height: 4),
                Text(
                  responsibilitySummary,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
"""
new = """              Text(
                attention.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: attention.needsAttention
                      ? scheme.onSurface
                      : scheme.onSurfaceVariant,
                  fontWeight: attention.needsAttention
                      ? FontWeight.w600
                      : null,
                ),
              ),
"""
if old not in page:
    raise SystemExit('selection row status rendering anchor not found')
page = page.replace(old, new, 1)

old = """  const _OrganizationStudentRow({
    required this.student,
    required this.items,
    required this.profiles,
    required this.caseOwnerLabelByCaseId,
    required this.collaborationLabelByCaseId,
    required this.responsibilitySummary,
    required this.leadLabelForProfile,
    required this.compact,
    required this.onQuickCapture,
  });

  final V2Student student;
  final List<V2FocusItem> items;
  final List<WorkspaceStudent> profiles;
  final Map<String, String> caseOwnerLabelByCaseId;
  final Map<String, String> collaborationLabelByCaseId;
  final String responsibilitySummary;
  final String Function(WorkspaceStudent profile) leadLabelForProfile;
"""
new = """  const _OrganizationStudentRow({
    required this.student,
    required this.items,
    required this.unassignedProfileCount,
    required this.caseOwnerLabelByCaseId,
    required this.collaborationLabelByCaseId,
    required this.compact,
    required this.onQuickCapture,
  });

  final V2Student student;
  final List<V2FocusItem> items;
  final int unassignedProfileCount;
  final Map<String, String> caseOwnerLabelByCaseId;
  final Map<String, String> collaborationLabelByCaseId;
"""
if old not in page:
    raise SystemExit('stacked row fields anchor not found')
page = page.replace(old, new, 1)

start = page.find("  String _statusSummary(List<V2FocusItem> activeItems) {")
end = page.find("  @override\n  Widget build(BuildContext context) {", start)
if start < 0 or end < 0:
    raise SystemExit('stacked row helper block not found')
page = page[:start] + page[end:]

old = """    final subtitleStyle = Theme.of(context).textTheme.bodySmall;

    if (items.isEmpty) {
"""
new = """    final subtitleStyle = Theme.of(context).textTheme.bodySmall;
    final attention = _organizationStudentAttentionSummary(
      activeItems,
      unassignedProfileCount: unassignedProfileCount,
    );

    if (items.isEmpty) {
"""
if old not in page:
    raise SystemExit('stacked row attention insertion anchor not found')
page = page.replace(old, new, 1)

old = """        subtitle: Padding(
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
"""
new = """        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            attention.needsAttention
                ? attention.label
                : '当前没有需要跟进的问题',
            style: subtitleStyle?.copyWith(
              fontWeight: attention.needsAttention ? FontWeight.w600 : null,
            ),
          ),
        ),
"""
if old not in page:
    raise SystemExit('empty stacked row subtitle anchor not found')
page = page.replace(old, new, 1)

old = """      subtitle: Padding(
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
"""
new = """      subtitle: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(
          activeItems.isEmpty && !attention.needsAttention
              ? '当前没有需要跟进的问题${closedItems.isEmpty ? '' : ' · ${closedItems.length} 个历史问题'}'
              : '${attention.label}${activeItems.isEmpty && closedItems.isNotEmpty ? ' · ${closedItems.length} 个历史问题' : ''}',
          style: subtitleStyle?.copyWith(
            fontWeight: attention.needsAttention ? FontWeight.w600 : null,
          ),
        ),
      ),
"""
if old not in page:
    raise SystemExit('stacked row subtitle anchor not found')
page = page.replace(old, new, 1)

page_path.write_text(page)

test_path = Path('test/features/v2_organization_workspace_test.dart')
test = test_path.read_text()
old = """      expect(find.textContaining('语文 · 张老师'), findsNothing);
      expect(find.widgetWithText(TextButton, '记录问题'), findsOneWidget);

      await tester.tap(
"""
new = """      expect(find.textContaining('语文 · 张老师'), findsNothing);
      expect(find.text('1 个跟进中'), findsOneWidget);
      expect(find.text('1 门学科未明确主责'), findsOneWidget);
      expect(find.textContaining('个跟进中 ·'), findsNothing);
      expect(find.widgetWithText(TextButton, '记录问题'), findsOneWidget);

      await tester.tap(
"""
if old not in test:
    raise SystemExit('expanded attention assertions anchor not found')
test = test.replace(old, new, 1)

old = """    expect(find.byType(ExpansionTile), findsWidgets);
    expect(find.widgetWithText(TextButton, '记录问题'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
"""
new = """    expect(find.byType(ExpansionTile), findsWidgets);
    expect(find.text('1 个跟进中'), findsOneWidget);
    expect(find.text('1 门学科未明确主责'), findsOneWidget);
    expect(find.textContaining('语文 · 张老师'), findsNothing);
    expect(find.widgetWithText(TextButton, '记录问题'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
"""
if old not in test:
    raise SystemExit('medium attention assertions anchor not found')
test = test.replace(old, new, 1)

test_path.write_text(test)
