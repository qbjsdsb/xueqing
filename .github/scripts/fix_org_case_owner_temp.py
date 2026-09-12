from pathlib import Path


def replace_one(path: str, old: str, new: str, label: str) -> None:
    p = Path(path)
    text = p.read_text()
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected 1 match, found {count}")
    p.write_text(text.replace(old, new, 1))


path = "lib/features/design_v2/v2_organization_workspace_page.dart"
replace_one(
    path,
    """  Map<String, String> get _leadLabelByCaseId {\n    final result = <String, String>{};\n    for (final profile in widget.workspace.students) {\n      final leadMembershipId = widget.responsibility.leadMembershipIdForProfile(\n        profile.profileId,\n      );\n      final leadLabel = leadMembershipId == null\n          ? '未设置主责'\n          : widget.responsibility.displayNameForMembership(leadMembershipId) ??\n                '主责老师';\n      for (final learningCase in profile.cases) {\n        result[learningCase.id] = leadLabel;\n      }\n    }\n    return result;\n  }\n""",
    """  Map<String, String> get _caseOwnerLabelByCaseId {\n    final result = <String, String>{};\n    for (final profile in widget.workspace.students) {\n      for (final learningCase in profile.cases) {\n        // Existing Case responsibility is its persisted owner. The Profile Lead\n        // is only the default responsibility source when a new Case is created;\n        // a later Lead change must not silently rewrite historical/current Case\n        // ownership in the supervision UI.\n        final ownerMembershipId =\n            widget.responsibility.caseOwnerMembershipIds[learningCase.id];\n        result[learningCase.id] = ownerMembershipId == null\n            ? '主责信息暂不可用'\n            : widget.responsibility.displayNameForMembership(ownerMembershipId) ??\n                  '主责老师';\n      }\n    }\n    return result;\n  }\n""",
    "case owner lookup",
)
replace_one(
    path,
    """    required Map<String, String> leadLabelByCaseId,\n""",
    """    required Map<String, String> caseOwnerLabelByCaseId,\n""",
    "visible students parameter",
)
replace_one(
    path,
    """              leadLabelByCaseId[item.id] ?? '主责信息暂不可用',\n""",
    """              caseOwnerLabelByCaseId[item.id] ?? '主责信息暂不可用',\n""",
    "search owner label",
)
replace_one(
    path,
    """    final leadLabelByCaseId = _leadLabelByCaseId;\n    final visibleStudents = _visibleStudents(\n      itemsByStudentId: itemsByStudentId,\n      profilesByStudentId: profilesByStudentId,\n      leadLabelByCaseId: leadLabelByCaseId,\n    );\n""",
    """    final caseOwnerLabelByCaseId = _caseOwnerLabelByCaseId;\n    final visibleStudents = _visibleStudents(\n      itemsByStudentId: itemsByStudentId,\n      profilesByStudentId: profilesByStudentId,\n      caseOwnerLabelByCaseId: caseOwnerLabelByCaseId,\n    );\n""",
    "build owner lookup",
)
replace_one(
    path,
    """                          leadLabelByCaseId: leadLabelByCaseId,\n""",
    """                          caseOwnerLabelByCaseId: caseOwnerLabelByCaseId,\n""",
    "student row owner map pass",
)
replace_one(
    path,
    """    required this.leadLabelByCaseId,\n""",
    """    required this.caseOwnerLabelByCaseId,\n""",
    "student row constructor owner map",
)
replace_one(
    path,
    """  final Map<String, String> leadLabelByCaseId;\n""",
    """  final Map<String, String> caseOwnerLabelByCaseId;\n""",
    "student row owner map field",
)
# Two row call sites: active and historical.
p = Path(path)
text = p.read_text()
old = "leadLabel: leadLabelByCaseId[item.id] ?? '主责信息暂不可用',"
if text.count(old) != 2:
    raise SystemExit(f"case row owner calls: expected 2 matches, found {text.count(old)}")
text = text.replace(
    old,
    "ownerLabel: caseOwnerLabelByCaseId[item.id] ?? '主责信息暂不可用',",
)
p.write_text(text)
replace_one(
    path,
    """    required this.leadLabel,\n""",
    """    required this.ownerLabel,\n""",
    "case row constructor owner label",
)
replace_one(
    path,
    """  final String leadLabel;\n""",
    """  final String ownerLabel;\n""",
    "case row owner label field",
)
replace_one(
    path,
    """    final detail = historical\n        ? '${item.subject} · 已结束 · $leadLabel'\n        : '${item.subject} · ${_caseStatusLabel(item)} · $leadLabel\\n'\n              '下一步：${item.nextStep} · ${item.dueLabel}';\n""",
    """    final detail = historical\n        ? '${item.subject} · 已结束 · 主责：$ownerLabel'\n        : '${item.subject} · ${_caseStatusLabel(item)} · 主责：$ownerLabel\\n'\n              '下一步：${item.nextStep} · ${item.dueLabel}';\n""",
    "case row visible owner label",
)

# Regression tests deliberately keep Profile Lead and Case owner different for
# student B: subject responsibility remains unassigned, while the existing Case
# remains owned by 王老师.
test_path = "test/features/v2_organization_workspace_test.dart"
replace_one(
    test_path,
    """      expect(find.textContaining('语文 · 跟进中 · 张老师'), findsOneWidget);\n""",
    """      expect(\n        find.textContaining('语文 · 跟进中 · 主责：张老师'),\n        findsOneWidget,\n      );\n""",
    "first case owner expectation",
)
replace_one(
    test_path,
    """      expect(find.textContaining('语文 · 跟进中 · 未设置主责'), findsOneWidget);\n\n      await tester.enterText(\n        find.byKey(const Key('v2-organization-learning-search')),\n        '张老师',\n      );\n      await tester.pumpAndSettle();\n      expect(find.text('机构学生一'), findsOneWidget);\n      expect(find.text('机构学生二'), findsNothing);\n""",
    """      expect(\n        find.textContaining('语文 · 跟进中 · 主责：王老师'),\n        findsOneWidget,\n      );\n      // Profile B still has no current Lead. Existing Case B nevertheless keeps\n      // its persisted Case owner instead of inheriting the Profile Lead state.\n      expect(find.textContaining('语文 · 未设置主责'), findsOneWidget);\n\n      await tester.enterText(\n        find.byKey(const Key('v2-organization-learning-search')),\n        '张老师',\n      );\n      await tester.pumpAndSettle();\n      expect(find.text('机构学生一'), findsOneWidget);\n      expect(find.text('机构学生二'), findsNothing);\n\n      await tester.enterText(\n        find.byKey(const Key('v2-organization-learning-search')),\n        '王老师',\n      );\n      await tester.pumpAndSettle();\n      expect(find.text('机构学生一'), findsNothing);\n      expect(find.text('机构学生二'), findsOneWidget);\n""",
    "case owner divergence regression",
)
