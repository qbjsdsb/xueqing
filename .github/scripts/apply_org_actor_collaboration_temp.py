import re
from pathlib import Path


def replace_one(path: str, old: str, new: str, label: str) -> None:
    p = Path(path)
    text = p.read_text()
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected exactly one match, found {count}")
    p.write_text(text.replace(old, new, 1))


learning = "lib/cloud/learning_repository.dart"
replace_one(
    learning,
    """    required this.text,\n    this.evidenceId,\n  });\n\n  final String id;\n  final DateTime occurredAt;\n  final String typeLabel;\n  final String text;\n  final String? evidenceId;\n}\n""",
    """    required this.text,\n    this.evidenceId,\n    this.responsibilityEventId,\n  });\n\n  final String id;\n  final DateTime occurredAt;\n  final String typeLabel;\n  final String text;\n  final String? evidenceId;\n\n  /// The persisted Case Event that owns Actor semantics for this timeline item.\n  ///\n  /// Evidence / Intervention / Assessment entries use synthetic timeline ids for\n  /// presentation, so their underlying Case Event id must be preserved separately\n  /// if a supervision view needs to resolve who actually recorded the fact.\n  final String? responsibilityEventId;\n}\n""",
    "timeline responsibility event field",
)

# Raw Case Events keep their own id as the Actor lookup id. The two call sites
# currently use different indentation because one lives inside case_created and
# one is the generic path, so match the argument indentation instead of assuming
# a fixed number of spaces.
p = Path(learning)
text = p.read_text()
raw_event_pattern = re.compile(
    r"(?P<indent>[ \t]+)id: _requiredString\(eventRow\['id'\], 'event_id'\),\n"
    r"(?P=indent)occurredAt: _requiredDateTime\(\n"
)
matches = list(raw_event_pattern.finditer(text))
if len(matches) != 2:
    raise SystemExit(
        f"raw timeline event anchors: expected 2, found {len(matches)}"
    )


def raw_event_replacement(match: re.Match[str]) -> str:
    indent = match.group("indent")
    return (
        f"{indent}id: _requiredString(eventRow['id'], 'event_id'),\n"
        f"{indent}responsibilityEventId: _requiredString(\n"
        f"{indent}  eventRow['id'],\n"
        f"{indent}  'event_id',\n"
        f"{indent}),\n"
        f"{indent}occurredAt: _requiredDateTime(\n"
    )


p.write_text(raw_event_pattern.sub(raw_event_replacement, text))

# Derived timeline rows retain the related progress Case Event id even though
# their public timeline id remains evidence:/intervention:/assessment:.
for synthetic in ("evidence", "intervention", "assessment"):
    replace_one(
        learning,
        f"""          id: '{synthetic}:${{item.id}}',\n          occurredAt:""",
        f"""          id: '{synthetic}:${{item.id}}',\n          responsibilityEventId: _stringValue(\n            progressByRecordId[item.id]?['id'],\n          ),\n          occurredAt:""",
        f"{synthetic} actor bridge",
    )

org = "lib/features/design_v2/v2_organization_workspace_page.dart"
replace_one(
    org,
    """  Map<String, String> get _caseOwnerLabelByCaseId {\n    final result = <String, String>{};\n    for (final profile in widget.workspace.students) {\n      for (final learningCase in profile.cases) {\n        // Existing Case responsibility is its persisted owner. The Profile Lead\n        // is only the default responsibility source when a new Case is created;\n        // a later Lead change must not silently rewrite historical/current Case\n        // ownership in the supervision UI.\n        final ownerMembershipId =\n            widget.responsibility.caseOwnerMembershipIds[learningCase.id];\n        result[learningCase.id] = ownerMembershipId == null\n            ? '主责信息暂不可用'\n            : widget.responsibility.displayNameForMembership(\n                    ownerMembershipId,\n                  ) ??\n                  '主责老师';\n      }\n    }\n    return result;\n  }\n""",
    """  Map<String, String> get _caseOwnerLabelByCaseId {\n    final result = <String, String>{};\n    for (final profile in widget.workspace.students) {\n      for (final learningCase in profile.cases) {\n        // Existing Case responsibility is its persisted owner. The Profile Lead\n        // is only the default responsibility source when a new Case is created;\n        // a later Lead change must not silently rewrite historical/current Case\n        // ownership in the supervision UI.\n        final ownerMembershipId =\n            widget.responsibility.caseOwnerMembershipIds[learningCase.id];\n        result[learningCase.id] = ownerMembershipId == null\n            ? '主责信息暂不可用'\n            : widget.responsibility.displayNameForMembership(\n                    ownerMembershipId,\n                  ) ??\n                  '主责老师';\n      }\n    }\n    return result;\n  }\n\n  Map<String, String> get _collaborationLabelByCaseId {\n    final result = <String, String>{};\n    for (final profile in widget.workspace.students) {\n      for (final learningCase in profile.cases) {\n        final ownerMembershipId =\n            widget.responsibility.caseOwnerMembershipIds[learningCase.id];\n        if (ownerMembershipId == null) continue;\n\n        // Timeline is newest-first. Only the latest attributable record decides\n        // whether a collaboration cue is shown. Do not skip a newer owner action\n        // just to surface an older supervisor action.\n        for (final event in learningCase.timeline) {\n          final responsibilityEventId = event.responsibilityEventId;\n          if (responsibilityEventId == null) continue;\n          if (!widget.responsibility.eventActorMembershipIds.containsKey(\n            responsibilityEventId,\n          )) {\n            break;\n          }\n          final actorMembershipId =\n              widget.responsibility.eventActorMembershipIds[responsibilityEventId];\n          if (actorMembershipId == null || actorMembershipId == ownerMembershipId) {\n            break;\n          }\n          final actorLabel = widget.responsibility.displayNameForMembership(\n            actorMembershipId,\n          );\n          if (actorLabel != null) {\n            result[learningCase.id] = '最近记录：$actorLabel · 机构协作';\n          }\n          break;\n        }\n      }\n    }\n    return result;\n  }\n""",
    "organization collaboration lookup",
)
replace_one(
    org,
    """    final caseOwnerLabelByCaseId = _caseOwnerLabelByCaseId;\n    final visibleStudents = _visibleStudents(\n""",
    """    final caseOwnerLabelByCaseId = _caseOwnerLabelByCaseId;\n    final collaborationLabelByCaseId = _collaborationLabelByCaseId;\n    final visibleStudents = _visibleStudents(\n""",
    "build collaboration lookup",
)
replace_one(
    org,
    """                          caseOwnerLabelByCaseId: caseOwnerLabelByCaseId,\n                          responsibilitySummary: _responsibilitySummary(\n""",
    """                          caseOwnerLabelByCaseId: caseOwnerLabelByCaseId,\n                          collaborationLabelByCaseId: collaborationLabelByCaseId,\n                          responsibilitySummary: _responsibilitySummary(\n""",
    "student row collaboration map pass",
)
replace_one(
    org,
    """    required this.caseOwnerLabelByCaseId,\n    required this.responsibilitySummary,\n""",
    """    required this.caseOwnerLabelByCaseId,\n    required this.collaborationLabelByCaseId,\n    required this.responsibilitySummary,\n""",
    "student row collaboration constructor",
)
replace_one(
    org,
    """  final Map<String, String> caseOwnerLabelByCaseId;\n  final String responsibilitySummary;\n""",
    """  final Map<String, String> caseOwnerLabelByCaseId;\n  final Map<String, String> collaborationLabelByCaseId;\n  final String responsibilitySummary;\n""",
    "student row collaboration field",
)
# Both active and historical rows receive the map; historical rows suppress the
# cue inside _OrganizationCaseRow to avoid adding archival noise.
p = Path(org)
text = p.read_text()
old = """            ownerLabel: caseOwnerLabelByCaseId[item.id] ?? '主责信息暂不可用',\n"""
if text.count(old) != 2:
    raise SystemExit(f"case row owner call sites: expected 2, found {text.count(old)}")
text = text.replace(
    old,
    """            ownerLabel: caseOwnerLabelByCaseId[item.id] ?? '主责信息暂不可用',\n            collaborationLabel: collaborationLabelByCaseId[item.id],\n""",
)
p.write_text(text)
replace_one(
    org,
    """    required this.ownerLabel,\n    this.historical = false,\n  });\n\n  final V2FocusItem item;\n  final String ownerLabel;\n  final bool historical;\n""",
    """    required this.ownerLabel,\n    this.collaborationLabel,\n    this.historical = false,\n  });\n\n  final V2FocusItem item;\n  final String ownerLabel;\n  final String? collaborationLabel;\n  final bool historical;\n""",
    "case row collaboration field",
)
replace_one(
    org,
    """    return Padding(\n      padding: const EdgeInsets.fromLTRB(16, 2, 4, 8),\n      child: ListTile(\n        dense: true,\n        contentPadding: const EdgeInsets.symmetric(horizontal: 8),\n        title: Text(item.title),\n        subtitle: Text(\n          detail,\n          maxLines: historical ? 1 : 2,\n          overflow: TextOverflow.ellipsis,\n        ),\n        isThreeLine: !historical,\n      ),\n    );\n""",
    """    return Padding(\n      padding: const EdgeInsets.fromLTRB(16, 2, 4, 8),\n      child: Column(\n        crossAxisAlignment: CrossAxisAlignment.start,\n        children: [\n          ListTile(\n            dense: true,\n            contentPadding: const EdgeInsets.symmetric(horizontal: 8),\n            title: Text(item.title),\n            subtitle: Text(\n              detail,\n              maxLines: historical ? 1 : 2,\n              overflow: TextOverflow.ellipsis,\n            ),\n            isThreeLine: !historical,\n          ),\n          if (!historical && collaborationLabel != null)\n            Padding(\n              padding: const EdgeInsets.fromLTRB(8, 0, 8, 2),\n              child: Text(\n                collaborationLabel!,\n                key: ValueKey<String>(\n                  'v2-organization-collaboration-${item.id}',\n                ),\n                style: Theme.of(context).textTheme.bodySmall?.copyWith(\n                  color: Theme.of(context).colorScheme.onSurfaceVariant,\n                ),\n              ),\n            ),\n        ],\n      ),\n    );\n""",
    "case row quiet collaboration cue",
)

# Widget regression: Case A is owned by 张老师 but its latest attributable
# derived timeline record was written by the manager. Case B's latest record was
# written by its own Case owner and must not display a collaboration cue.
test = "test/features/v2_organization_workspace_test.dart"
replace_one(
    test,
    """      expect(find.textContaining('下一步：下一次继续检查'), findsOneWidget);\n\n      await tester.tap(find.text('机构学生二'));\n""",
    """      expect(find.textContaining('下一步：下一次继续检查'), findsOneWidget);\n      expect(find.text('最近记录：李老师 · 机构协作'), findsOneWidget);\n\n      await tester.tap(find.text('机构学生二'));\n""",
    "collaboration visible assertion",
)
replace_one(
    test,
    """      expect(find.textContaining('语文 · 未设置主责'), findsOneWidget);\n\n      await tester.enterText(\n""",
    """      expect(find.textContaining('语文 · 未设置主责'), findsOneWidget);\n      expect(find.text('最近记录：王老师 · 机构协作'), findsNothing);\n\n      await tester.enterText(\n""",
    "owner actor suppression assertion",
)
replace_one(
    test,
    """    eventActorMembershipIds: const {},\n""",
    """    eventActorMembershipIds: const {\n      'event-manager-a': 'membership-manager',\n      'event-owner-b': 'membership-other',\n    },\n""",
    "test actor mappings",
)
replace_one(
    test,
    """        title: '阅读概括遗漏要点',\n      ),\n""",
    """        title: '阅读概括遗漏要点',\n        timeline: [\n          WorkspaceTimelineEvent(\n            id: 'evidence:evidence-a',\n            responsibilityEventId: 'event-manager-a',\n            occurredAt: DateTime(2026, 9, 12, 11),\n            typeLabel: '学生表现',\n            text: '负责人补充了一次课堂观察。',\n          ),\n        ],\n      ),\n""",
    "case A actor timeline",
)
replace_one(
    test,
    """        title: '作文立意不稳定',\n      ),\n""",
    """        title: '作文立意不稳定',\n        timeline: [\n          WorkspaceTimelineEvent(\n            id: 'event-owner-b',\n            responsibilityEventId: 'event-owner-b',\n            occurredAt: DateTime(2026, 9, 12, 10),\n            typeLabel: '记录',\n            text: '王老师继续跟进。',\n          ),\n        ],\n      ),\n""",
    "case B owner timeline",
)
replace_one(
    test,
    """  required String title,\n}) {\n""",
    """  required String title,\n  List<WorkspaceTimelineEvent> timeline = const <WorkspaceTimelineEvent>[],\n}) {\n""",
    "profile timeline parameter",
)
replace_one(
    test,
    """        timeline: const [],\n""",
    """        timeline: timeline,\n""",
    "profile timeline pass",
)

# Source-level contract test protects the critical bridge that synthetic
# timeline presentation ids cannot themselves resolve responsibility actors.
# Count stable call prefixes instead of multiline formatting so dart format
# cannot invalidate the contract test.
Path("test/cloud/workspace_timeline_responsibility_contract_test.dart").write_text(
    """import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:xueqing/cloud/learning_repository.dart';

void main() {
  test('timeline item can retain its persisted Case Event identity', () {
    final event = WorkspaceTimelineEvent(
      id: 'evidence:evidence-1',
      responsibilityEventId: 'event-1',
      occurredAt: DateTime(2026, 9, 12, 10),
      typeLabel: '学生表现',
      text: '课堂观察',
    );

    expect(event.id, 'evidence:evidence-1');
    expect(event.responsibilityEventId, 'event-1');
  });

  test('derived and raw timeline rows preserve persisted Case Event ids', () {
    final source = File('lib/cloud/learning_repository.dart').readAsStringSync();

    expect(
      source.split('responsibilityEventId: _stringValue(').length - 1,
      3,
    );
    expect(
      source.split('responsibilityEventId: _requiredString(').length - 1,
      2,
    );
  });
}
"""
)
