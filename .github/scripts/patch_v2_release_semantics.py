from pathlib import Path
import re


def replace_once(path: str, old: str, new: str) -> None:
    file = Path(path)
    text = file.read_text(encoding="utf-8")
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{path}: expected one match, found {count}: {old[:80]!r}")
    file.write_text(text.replace(old, new, 1), encoding="utf-8")


# Presentation contract: carry action timing without coupling V2 widgets to cloud enums.
replace_once(
    "lib/features/design_v2/v2_fixture.dart",
    "class V2FocusItem {\n",
    "enum V2ActionTiming { overdue, today, future, undated }\n\nclass V2FocusItem {\n",
)
replace_once(
    "lib/features/design_v2/v2_fixture.dart",
    "    required this.subject,\n    this.pendingVerification = false,\n",
    "    required this.subject,\n    this.actionTiming,\n    this.pendingVerification = false,\n",
)
replace_once(
    "lib/features/design_v2/v2_fixture.dart",
    "  final String subject;\n  final bool pendingVerification;\n",
    "  final String subject;\n  final V2ActionTiming? actionTiming;\n  final bool pendingVerification;\n",
)
fixture_path = Path("lib/features/design_v2/v2_fixture.dart")
fixture = fixture_path.read_text(encoding="utf-8")
start = fixture.index("const v2FocusItems = <V2FocusItem>[")
end = fixture.index("\n];", start)
block = fixture[start:end]
block, count = re.subn(
    r"(\n    subject: '[^']+',)(?!\n    actionTiming:)",
    r"\1\n    actionTiming: V2ActionTiming.today,",
    block,
)
if count < 1:
    raise SystemExit("v2_fixture.dart: expected fixture focus items to receive action timing")
fixture_path.write_text(fixture[:start] + block + fixture[end:], encoding="utf-8")

# Workspace presentation data carries the organization business date.
replace_once(
    "lib/features/design_v2/v2_workspace_data.dart",
    "    required this.timeline,\n  });\n\n  final List<V2Student> students;\n",
    "    required this.timeline,\n    this.businessDate,\n  });\n\n  final List<V2Student> students;\n",
)
replace_once(
    "lib/features/design_v2/v2_workspace_data.dart",
    "  final List<V2TimelineEntry> timeline;\n\n  List<V2FocusItem>",
    "  final List<V2TimelineEntry> timeline;\n  final DateTime? businessDate;\n\n  List<V2FocusItem>",
)

# Read model: stable is still an active follow-up state, preserve action timing and org date.
replace_once(
    "lib/features/design_v2/v2_read_model_adapter.dart",
    "    required this.caseBindings,\n  });\n\n  final String viewerName;\n",
    "    required this.caseBindings,\n    required this.businessDate,\n  });\n\n  final String viewerName;\n",
)
replace_once(
    "lib/features/design_v2/v2_read_model_adapter.dart",
    "  final List<V2CaseBinding> caseBindings;\n\n  V2WorkspaceData get workspaceData => V2WorkspaceData(\n",
    "  final List<V2CaseBinding> caseBindings;\n  final DateTime? businessDate;\n\n  V2WorkspaceData get workspaceData => V2WorkspaceData(\n",
)
replace_once(
    "lib/features/design_v2/v2_read_model_adapter.dart",
    "    timeline: timeline,\n  );\n",
    "    timeline: timeline,\n    businessDate: businessDate,\n  );\n",
)
replace_once(
    "lib/features/design_v2/v2_read_model_adapter.dart",
    "            subject: profile.subject,\n            pendingVerification:\n",
    "            subject: profile.subject,\n            actionTiming: _actionTiming(primaryAction),\n            pendingVerification:\n",
)
replace_once(
    "lib/features/design_v2/v2_read_model_adapter.dart",
    "      caseBindings: List<V2CaseBinding>.unmodifiable(bindings),\n    );\n",
    "      caseBindings: List<V2CaseBinding>.unmodifiable(bindings),\n      businessDate: workspace.businessDate,\n    );\n",
)
replace_once(
    "lib/features/design_v2/v2_read_model_adapter.dart",
    "  static bool _isActiveCase(WorkspaceCase learningCase) =>\n      learningCase.status != LearningCaseStatus.stable &&\n      learningCase.status != LearningCaseStatus.closed;\n\n  static String _caseSummary",
    "  static bool _isActiveCase(WorkspaceCase learningCase) =>\n      learningCase.status != LearningCaseStatus.closed;\n\n  static V2ActionTiming? _actionTiming(WorkspaceAction? action) =>\n      switch (action?.bucket) {\n        WorkspaceActionBucket.overdue => V2ActionTiming.overdue,\n        WorkspaceActionBucket.today => V2ActionTiming.today,\n        WorkspaceActionBucket.future => V2ActionTiming.future,\n        WorkspaceActionBucket.undated => V2ActionTiming.undated,\n        null => null,\n      };\n\n  static String _caseSummary",
)

# UI: Today only contains actionable non-future work, uses organization business date,
# and removes a visible no-op student action.
replace_once(
    "lib/features/design_v2/v2_workspace_preview.dart",
    "        IconButton(\n          onPressed: () {},\n          tooltip: '更多',\n          icon: const Icon(Icons.more_horiz),\n        ),\n",
    "",
)
replace_once(
    "lib/features/design_v2/v2_workspace_preview.dart",
    "    final validItems = data.focusItems\n        .where((item) => data.studentForFocusItemOrNull(item) != null)\n        .toList(growable: false);\n",
    "    final validItems = data.focusItems\n        .where(\n          (item) =>\n              data.studentForFocusItemOrNull(item) != null &&\n              item.actionTiming != null &&\n              item.actionTiming != V2ActionTiming.future,\n        )\n        .toList(growable: false);\n",
)
replace_once(
    "lib/features/design_v2/v2_workspace_preview.dart",
    "              Text(_todayLabel(), style: Theme.of(context).textTheme.bodySmall),\n",
    "              Text(\n                _todayLabel(data.businessDate),\n                style: Theme.of(context).textTheme.bodySmall,\n              ),\n",
)
replace_once(
    "lib/features/design_v2/v2_workspace_preview.dart",
    "String _todayLabel() {\n  const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];\n  final now = DateTime.now();\n",
    "String _todayLabel(DateTime? businessDate) {\n  const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];\n  final now = businessDate ?? DateTime.now();\n",
)

# Adapter tests: stable must remain visible and carry a real next action.
replace_once(
    "test/features/design_v2_read_model_adapter_test.dart",
    "      expect(grouped.openCaseCount, 2);\n",
    "      expect(grouped.openCaseCount, 3);\n",
)
replace_once(
    "test/features/design_v2_read_model_adapter_test.dart",
    "      expect(snapshot.focusItems.map((item) => item.id).toSet(), {\n        'case-cn',\n        'case-math',\n      });\n      expect(\n        snapshot.focusItems.any((item) => item.id == 'case-cn-stable'),\n        isFalse,\n      );\n",
    "      expect(snapshot.focusItems.map((item) => item.id).toSet(), {\n        'case-cn',\n        'case-cn-stable',\n        'case-math',\n      });\n      final stable = snapshot.focusItems.firstWhere(\n        (item) => item.id == 'case-cn-stable',\n      );\n      expect(stable.nextStep, '两周后复查');\n      expect(stable.actionTiming, V2ActionTiming.future);\n",
)
replace_once(
    "test/features/design_v2_read_model_adapter_test.dart",
    "          _case(\n            id: 'case-cn-stable',\n            profileId: 'profile-cn',\n            title: '已暂时稳定的问题',\n            status: LearningCaseStatus.stable,\n            version: 4,\n          ),\n",
    "          _case(\n            id: 'case-cn-stable',\n            profileId: 'profile-cn',\n            title: '已暂时稳定的问题',\n            status: LearningCaseStatus.stable,\n            version: 4,\n            actions: [\n              WorkspaceAction(\n                id: 'action-stable',\n                caseId: 'case-cn-stable',\n                title: '两周后复查',\n                actionType: 'review',\n                status: WorkspaceActionStatus.pending,\n                isPrimary: true,\n                bucket: WorkspaceActionBucket.future,\n                version: 1,\n                dueAt: DateTime(2026, 9, 23, 10),\n                businessDueDate: DateTime(2026, 9, 23),\n              ),\n            ],\n          ),\n",
)

# Injection tests: keep pending-verification item actionable and add release-semantics coverage.
replace_once(
    "test/features/design_v2_workspace_data_injection_test.dart",
    "      subject: '语文',\n      pendingVerification: true,\n",
    "      subject: '语文',\n      actionTiming: V2ActionTiming.today,\n      pendingVerification: true,\n",
)
insert_marker = "  testWidgets('empty workspace is a first-class state on desktop', (\n"
path = Path("test/features/design_v2_workspace_data_injection_test.dart")
text = path.read_text(encoding="utf-8")
if insert_marker not in text:
    raise SystemExit("workspace injection test marker missing")
extra_tests = r'''  testWidgets('Today hides future and no-action work and uses business date', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final data = V2WorkspaceData(
      businessDate: DateTime(2026, 9, 12),
      students: _injectedData.students,
      focusItems: const [
        V2FocusItem(
          id: 'today-case',
          studentId: 'real-student',
          title: '今天处理',
          summary: '今天应该出现。',
          nextStep: '今天复查',
          dueLabel: '今天',
          subject: '语文',
          actionTiming: V2ActionTiming.today,
        ),
        V2FocusItem(
          id: 'future-case',
          studentId: 'real-student',
          title: '未来处理',
          summary: '未来事项不应该挤进今日。',
          nextStep: '下周复查',
          dueLabel: '9 月 20 日',
          subject: '语文',
          actionTiming: V2ActionTiming.future,
        ),
        V2FocusItem(
          id: 'fact-only-case',
          studentId: 'real-student',
          title: '仅记录事实',
          summary: '没有 Action 的新记录不是今日任务。',
          nextStep: '待安排下一步',
          dueLabel: '待安排',
          subject: '语文',
        ),
      ],
      timeline: const [],
    );

    await tester.pumpWidget(app(data));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('今日'));
    await tester.pumpAndSettle();

    expect(find.text('9 月 12 日 · 周六'), findsOneWidget);
    expect(find.text('今天处理'), findsOneWidget);
    expect(find.text('未来处理'), findsNothing);
    expect(find.text('仅记录事实'), findsNothing);
  });

'''
path.write_text(text.replace(insert_marker, extra_tests + insert_marker, 1), encoding="utf-8")

print("V2 release semantics patch applied")
