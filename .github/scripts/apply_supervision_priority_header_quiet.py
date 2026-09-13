from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    file = Path(path)
    text = file.read_text(encoding="utf-8")
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{path}: expected one replacement, found {count}")
    file.write_text(text.replace(old, new, 1), encoding="utf-8")


workspace_path = "lib/features/design_v2/v2_workspace_preview.dart"
organization_path = "lib/features/design_v2/v2_organization_workspace_page.dart"
organization_test_path = "test/features/v2_organization_workspace_test.dart"
rhythm_test_path = "test/features/v2_page_rhythm_test.dart"

# Top-level Today already explains current work immediately below the header.
# Keep only the date as persistent context so the header has one auxiliary line.
replace_once(
    workspace_path,
    """                meta: _todayLabel(data.businessDate),
                description: currentItems.isEmpty && undatedItems.isEmpty
                    ? '今天没有已安排的跟进。'
                    : '先处理已经安排好的跟进。',
                actions: [
""",
    """                meta: _todayLabel(data.businessDate),
                actions: [
""",
)

organization = Path(organization_path)
organization_text = organization.read_text(encoding="utf-8")

# Expanded student list already has spacing and selection treatment; row dividers
# add noise without adding hierarchy.
old_list = """                            : ListView.separated(
                                key: const Key('v2-organization-student-list'),
                                itemCount: visibleStudents.length,
                                separatorBuilder: (_, _) => Divider(
                                  height: 1,
                                  color: scheme.outlineVariant,
                                ),
                                itemBuilder: (context, index) {
"""
new_list = """                            : ListView.builder(
                                key: const Key('v2-organization-student-list'),
                                itemCount: visibleStudents.length,
                                itemBuilder: (context, index) {
"""
if organization_text.count(old_list) != 1:
    raise SystemExit("organization list: expected exact separated-list anchor")
organization_text = organization_text.replace(old_list, new_list, 1)

start_marker = "class _OrganizationStudentDetail extends StatelessWidget {"
end_marker = "\nclass _OrganizationStudentRow extends StatelessWidget {"
start = organization_text.find(start_marker)
end = organization_text.find(end_marker, start)
if start < 0 or end < 0:
    raise SystemExit("organization detail class anchors not found")

replacement = r'''int _organizationCasePriority(V2FocusItem item) {
  if (item.actionTiming == V2ActionTiming.overdue) return 0;
  if (item.pendingVerification ||
      item.effectiveStatus == V2CaseStatus.pendingVerification) {
    return 1;
  }
  return switch (item.actionTiming) {
    V2ActionTiming.today => 2,
    V2ActionTiming.undated => 3,
    V2ActionTiming.future => 4,
    V2ActionTiming.overdue => 0,
    null => 5,
  };
}

V2FocusItem? _organizationPriorityItem(List<V2FocusItem> items) {
  final ranked = items.where((item) => !item.closed).toList(growable: true);
  if (ranked.isEmpty) return null;
  ranked.sort((left, right) {
    final priority = _organizationCasePriority(
      left,
    ).compareTo(_organizationCasePriority(right));
    if (priority != 0) return priority;

    final leftDue = left.dueOn;
    final rightDue = right.dueOn;
    if (leftDue != null && rightDue != null) {
      final due = leftDue.compareTo(rightDue);
      if (due != 0) return due;
    } else if (leftDue != null) {
      return -1;
    } else if (rightDue != null) {
      return 1;
    }
    return left.title.compareTo(right.title);
  });
  return ranked.first;
}

class _OrganizationStudentDetail extends StatelessWidget {
  const _OrganizationStudentDetail({
    required this.student,
    required this.items,
    required this.profiles,
    required this.responsibilitySummary,
    required this.leadLabelForProfile,
    required this.caseOwnerLabelByCaseId,
    required this.collaborationLabelByCaseId,
    required this.onQuickCapture,
  });

  final V2Student student;
  final List<V2FocusItem> items;
  final List<WorkspaceStudent> profiles;
  final String responsibilitySummary;
  final String Function(WorkspaceStudent profile) leadLabelForProfile;
  final Map<String, String> caseOwnerLabelByCaseId;
  final Map<String, String> collaborationLabelByCaseId;
  final VoidCallback onQuickCapture;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final activeItems = items
        .where((item) => !item.closed)
        .toList(growable: false);
    final closedItems = items
        .where((item) => item.closed)
        .toList(growable: false);
    final priorityItem = _organizationPriorityItem(activeItems);
    final otherActiveItems = priorityItem == null
        ? const <V2FocusItem>[]
        : activeItems
              .where((item) => item.id != priorityItem.id)
              .toList(growable: false);
    final priorityOwnerLabel = priorityItem == null
        ? null
        : caseOwnerLabelByCaseId[priorityItem.id] ?? '主责信息暂不可用';
    final priorityCollaborationLabel = priorityItem == null
        ? null
        : collaborationLabelByCaseId[priorityItem.id];
    final leadLabels = profiles.map(leadLabelForProfile).toSet();
    final showResponsibilityBreakdown =
        leadLabels.length > 1 || leadLabels.contains('未设置主责');
    final singleLeadLabel = leadLabels.length == 1 ? leadLabels.single : null;
    final responsibilityDiffersFromPriority =
        priorityItem != null &&
        singleLeadLabel != null &&
        singleLeadLabel != '未设置主责' &&
        priorityOwnerLabel != null &&
        singleLeadLabel != priorityOwnerLabel;
    final showTeachingResponsibility =
        priorityItem == null ||
        showResponsibilityBreakdown ||
        responsibilitySummary.contains('未') ||
        responsibilityDiffersFromPriority ||
        (priorityOwnerLabel?.contains('不可用') ?? false);

    final mutedStyle = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );

    return ListView(
      key: const Key('v2-organization-student-detail'),
      padding: const EdgeInsets.fromLTRB(4, 2, 4, 20),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(student.name, style: theme.textTheme.headlineSmall),
                  const SizedBox(height: 5),
                  Text(
                    '${student.grade} · ${student.subjects.join(' / ')}',
                    style: mutedStyle,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            TextButton.icon(
              key: ValueKey<String>(
                'v2-organization-quick-capture-${student.id}',
              ),
              onPressed: onQuickCapture,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('记录问题'),
            ),
          ],
        ),
        if (priorityItem != null) ...[
          const SizedBox(height: 18),
          Text(
            '优先处理',
            key: const Key('v2-organization-priority-label'),
            style: theme.textTheme.labelLarge?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            priorityItem.title,
            key: ValueKey<String>(
              'v2-organization-priority-${priorityItem.id}',
            ),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 14,
            runSpacing: 4,
            children: [
              Text(priorityItem.subject, style: mutedStyle),
              Text(_caseStatusLabel(priorityItem), style: mutedStyle),
              Text(
                '负责：$priorityOwnerLabel',
                style: mutedStyle?.copyWith(
                  color: priorityOwnerLabel?.contains('不可用') == true
                      ? scheme.error
                      : scheme.onSurfaceVariant,
                  fontWeight: priorityOwnerLabel?.contains('不可用') == true
                      ? FontWeight.w600
                      : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '下一步：${priorityItem.nextStep}',
            key: ValueKey<String>(
              'v2-organization-priority-next-${priorityItem.id}',
            ),
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 4),
          Text(priorityItem.dueLabel, style: mutedStyle),
          if (priorityCollaborationLabel != null) ...[
            const SizedBox(height: 5),
            Text(
              priorityCollaborationLabel,
              key: ValueKey<String>(
                'v2-organization-collaboration-${priorityItem.id}',
              ),
              style: mutedStyle,
            ),
          ],
        ] else ...[
          const SizedBox(height: 18),
          Text(
            '当前没有需要跟进的问题。',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
        if (showTeachingResponsibility) ...[
          const SizedBox(height: 14),
          Text(
            '教学主责：$responsibilitySummary',
            style: theme.textTheme.bodySmall?.copyWith(
              color: responsibilitySummary.contains('未')
                  ? scheme.error
                  : scheme.onSurfaceVariant,
              fontWeight: responsibilitySummary.contains('未')
                  ? FontWeight.w600
                  : null,
            ),
          ),
          if (showResponsibilityBreakdown && profiles.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              runSpacing: 5,
              children: [
                for (final profile in profiles)
                  Text(
                    '${profile.subject} · ${leadLabelForProfile(profile)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: leadLabelForProfile(profile) == '未设置主责'
                          ? scheme.error
                          : scheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ],
        ],
        if (otherActiveItems.isNotEmpty) ...[
          const SizedBox(height: 22),
          Divider(color: scheme.outlineVariant),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Text('其他当前问题', style: theme.textTheme.titleMedium),
              ),
              Text(
                '${otherActiveItems.length}',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final item in otherActiveItems)
            _OrganizationCaseRow(
              item: item,
              ownerLabel: caseOwnerLabelByCaseId[item.id] ?? '主责信息暂不可用',
              collaborationLabel: collaborationLabelByCaseId[item.id],
              leadingInset: 0,
            ),
        ],
        if (closedItems.isNotEmpty) ...[
          const SizedBox(height: 18),
          Divider(color: scheme.outlineVariant),
          const SizedBox(height: 14),
          Text(
            '历史问题 ${closedItems.length}',
            style: theme.textTheme.labelLarge?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          for (final item in closedItems)
            _OrganizationCaseRow(
              item: item,
              ownerLabel: caseOwnerLabelByCaseId[item.id] ?? '主责信息暂不可用',
              collaborationLabel: collaborationLabelByCaseId[item.id],
              historical: true,
              leadingInset: 0,
            ),
        ],
      ],
    );
  }
}
'''

organization_text = organization_text[:start] + replacement + organization_text[end:]
organization.write_text(organization_text, encoding="utf-8")

# Behavioral tests: selected student first answers what/owner/next, does not
# repeat the same Case below, and the list no longer relies on separators.
replace_once(
    organization_test_path,
    """      expect(find.widgetWithText(TextButton, '记录问题'), findsOneWidget);

      await tester.tap(
""",
    """      expect(find.widgetWithText(TextButton, '记录问题'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('v2-organization-student-list')),
          matching: find.byType(Divider),
        ),
        findsNothing,
      );

      await tester.tap(
""",
)
replace_once(
    organization_test_path,
    """      expect(find.text('跟进中'), findsWidgets);
      expect(find.text('主责：张老师'), findsOneWidget);
      expect(find.text('下一步：下一次继续检查'), findsOneWidget);
      expect(find.text('最近记录：李老师 · 机构协作'), findsOneWidget);
""",
    """      expect(find.text('跟进中'), findsWidgets);
      expect(
        find.byKey(const ValueKey<String>('v2-organization-priority-case-a')),
        findsOneWidget,
      );
      expect(find.text('优先处理'), findsOneWidget);
      expect(find.text('负责：张老师'), findsOneWidget);
      expect(find.text('下一步：下一次继续检查'), findsOneWidget);
      expect(find.text('其他当前问题'), findsNothing);
      expect(find.text('最近记录：李老师 · 机构协作'), findsOneWidget);
""",
)
replace_once(
    organization_test_path,
    """      expect(find.text('主责：王老师'), findsOneWidget);
      // Profile B still has no current Lead. Existing Case B nevertheless keeps
      // its persisted Case owner instead of inheriting the Profile Lead state.
      expect(find.textContaining('语文 · 未设置主责'), findsOneWidget);
""",
    """      expect(
        find.byKey(const ValueKey<String>('v2-organization-priority-case-b')),
        findsOneWidget,
      );
      expect(find.text('负责：王老师'), findsOneWidget);
      // Profile B still has no current Lead. Existing Case B nevertheless keeps
      // its persisted Case owner instead of inheriting the Profile Lead state.
      expect(find.text('教学主责：未设置主责'), findsOneWidget);
      expect(find.textContaining('语文 · 未设置主责'), findsOneWidget);
""",
)

# Today title remains contextual but no longer repeats instructions that the
# content sections and empty state already communicate.
replace_once(
    rhythm_test_path,
    """      expect(find.byKey(const Key('v2-today-page-header')), findsOneWidget);
      final todayX = tester
""",
    """      expect(find.byKey(const Key('v2-today-page-header')), findsOneWidget);
      expect(find.text('先处理已经安排好的跟进。'), findsNothing);
      expect(find.text('今天没有已安排的跟进。'), findsNothing);
      final todayX = tester
""",
)

print("supervision priority/header quiet patch applied")
