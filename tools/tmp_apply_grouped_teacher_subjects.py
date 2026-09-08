from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected exactly one match, got {count}')
    return text.replace(old, new, 1)


workspace = Path('lib/features/teacher_workspace/presentation/teacher_workspace_page.dart')
text = workspace.read_text()
usage = "        const _WorkspaceBoundaryBanner(),\n        const SizedBox(height: AppSpacing.lg),\n"
usage_count = text.count(usage)
if usage_count != 2:
    raise SystemExit(f'workspace banner usages: expected 2, got {usage_count}')
text = text.replace(usage, '')
class_start = text.find('class _WorkspaceBoundaryBanner extends StatelessWidget {\n')
class_end = text.find('class _WorkspaceContextLine extends StatelessWidget {\n', class_start)
if class_start < 0 or class_end < 0:
    raise SystemExit('workspace banner class anchors not found')
removed_class = text[class_start:class_end]
if '开发环境虚构资料 · 只显示当前权限范围 · 保存会写入开发数据库' not in removed_class:
    raise SystemExit('workspace banner class safety marker missing')
text = text[:class_start] + text[class_end:]
workspace.write_text(text)

areas = Path('lib/features/organization_management/presentation/organization_management_areas.dart')
text = areas.read_text()
text = replace_once(
    text,
    "  Widget _buildPeopleArea({\n    required List<OrganizationTeacherSubjectScope> activeScopes,\n    required List<OrganizationTeacherSubjectScope> endedScopes,\n    required Set<String> latestEndedScopeIds,\n  }) {\n    return _ManagementAreaCard(",
    "  Widget _buildPeopleArea({\n    required List<OrganizationTeacherSubjectScope> activeScopes,\n    required List<OrganizationTeacherSubjectScope> endedScopes,\n    required Set<String> latestEndedScopeIds,\n  }) {\n    final activeScopeGroups = _groupTeacherSubjectScopes(activeScopes);\n    return _ManagementAreaCard(",
    'active scope groups declaration',
)
text = replace_once(
    text,
    "            title: '老师可教学科',\n            count: '${activeScopes.length} 条有效',",
    "            title: '老师可教学科',\n            count: '${activeScopeGroups.length} 位老师 · ${activeScopes.length} 科',",
    'scope count',
)
text = replace_once(
    text,
    "                : Column(\n                    children: [\n                      for (final scope in activeScopes)\n                        _TeacherSubjectScopeTile(\n                          scope: scope,\n                          busy: widget.busy,\n                          showReactivate: false,\n                          onToggle: () => widget.onToggleTeacherScope(scope),\n                        ),\n                    ],\n                  ),",
    "                : Column(\n                    children: [\n                      for (final scopes in activeScopeGroups)\n                        _TeacherSubjectScopeGroupTile(\n                          scopes: scopes,\n                          busy: widget.busy,\n                          onToggle: widget.onToggleTeacherScope,\n                        ),\n                    ],\n                  ),",
    'active scope list',
)
insert_anchor = "  Widget _buildPeopleArea({\n"
helper = "  List<List<OrganizationTeacherSubjectScope>> _groupTeacherSubjectScopes(\n    List<OrganizationTeacherSubjectScope> scopes,\n  ) {\n    final grouped = <String, List<OrganizationTeacherSubjectScope>>{};\n    for (final scope in scopes) {\n      grouped.putIfAbsent(scope.membershipId, () => []).add(scope);\n    }\n    final groups = grouped.values.toList(growable: false);\n    for (final group in groups) {\n      group.sort((a, b) => a.subjectName.compareTo(b.subjectName));\n    }\n    groups.sort((a, b) => a.first.teacherName.compareTo(b.first.teacherName));\n    return groups;\n  }\n\n"
if text.count(insert_anchor) != 1:
    raise SystemExit('group helper anchor mismatch')
text = text.replace(insert_anchor, helper + insert_anchor, 1)
areas.write_text(text)

rows = Path('lib/features/organization_management/presentation/organization_management_rows.dart')
text = rows.read_text()
anchor = "class _TeacherSubjectScopeTile extends StatelessWidget {\n"
group_widget = r'''class _TeacherSubjectScopeGroupTile extends StatelessWidget {
  const _TeacherSubjectScopeGroupTile({
    required this.scopes,
    required this.busy,
    required this.onToggle,
  });

  final List<OrganizationTeacherSubjectScope> scopes;
  final bool busy;
  final Future<void> Function(OrganizationTeacherSubjectScope scope) onToggle;

  @override
  Widget build(BuildContext context) {
    assert(scopes.isNotEmpty);
    final first = scopes.first;
    final colorScheme = Theme.of(context).colorScheme;
    return _ManagementRowShell(
      leading: Icon(Icons.menu_book_outlined, color: colorScheme.primary),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(first.teacherName, style: Theme.of(context).textTheme.titleSmall),
          if (first.teacherEmail.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xxs),
            Text(
              first.teacherEmail,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          for (final scope in scopes)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      scope.subjectName,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  _ManagementStatusChip(label: '可教学', isPositive: true),
                  const SizedBox(width: AppSpacing.xxs),
                  TextButton(
                    key: ValueKey<String>('teacher-scope-stop-${scope.scopeId}'),
                    onPressed: busy
                        ? null
                        : () {
                            onToggle(scope);
                          },
                    child: const Text('停用'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

'''
if text.count(anchor) != 1:
    raise SystemExit('group widget anchor mismatch')
text = text.replace(anchor, group_widget + anchor, 1)
rows.write_text(text)

test = Path('test/features/organization_management_test.dart')
text = test.read_text()
text = replace_once(
    text,
    "      expect(find.text('示例老师 · 数学'), findsOneWidget);\n      final stop = find.text('停用该学科');",
    "      expect(find.text('示例老师'), findsOneWidget);\n      expect(find.text('数学'), findsOneWidget);\n      final stop = find.text('停用');",
    'scope UI test',
)
test.write_text(text)
