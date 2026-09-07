from pathlib import Path


def replace_once(path: Path, old: str, new: str) -> None:
    text = path.read_text()
    count = text.count(old)
    assert count == 1, f"{path}: expected 1 match, found {count}"
    path.write_text(text.replace(old, new, 1))


motion = Path("lib/app/theme/app_motion.dart")
motion.write_text(
    """import 'package:flutter/material.dart';

abstract final class AppMotion {
  static const Duration quick = Duration(milliseconds: 120);
  static const Duration standard = Duration(milliseconds: 180);

  static Duration effectiveDuration(
    BuildContext context, [
    Duration duration = standard,
  ]) {
    final mediaQuery = MediaQuery.maybeOf(context);
    return mediaQuery?.disableAnimations == true ? Duration.zero : duration;
  }
}
"""
)

workspace = Path(
    "lib/features/teacher_workspace/presentation/teacher_workspace_page.dart"
)
replace_once(
    workspace,
    "import '../../../app/theme/app_spacing.dart';\n",
    "import '../../../app/theme/app_motion.dart';\n"
    "import '../../../app/theme/app_spacing.dart';\n",
)
text = workspace.read_text()
today = text.index("          title: '今日',")
actions = text.index("          actions: [\n", today)
case_type = text.index("            if (workspace.canManageCaseTypes", actions)
record = text.index("            FilledButton.icon(\n", case_type)
removed = text[case_type:record]
assert "label: const Text('问题类型')" in removed
text = text[:case_type] + text[record:]
for state_name in (
    "_showAllPendingVerification",
    "_showAllFutureActions",
    "_showAllUndatedActions",
):
    old = f"                  child: Text({state_name} ? '收起' : '查看全部'),"
    new = f"""                  child: AnimatedSwitcher(
                    duration: AppMotion.effectiveDuration(
                      context,
                      AppMotion.quick,
                    ),
                    child: Text(
                      {state_name} ? '收起' : '查看全部',
                      key: ValueKey<bool>({state_name}),
                    ),
                  ),"""
    count = text.count(old)
    assert count == 1, f"{workspace}: toggle {state_name} count={count}"
    text = text.replace(old, new, 1)
workspace.write_text(text)

student_dialog = Path(
    "lib/features/organization_management/presentation/organization_student_setup_dialog.dart"
)
replace_once(
    student_dialog,
    "import '../../../app/theme/app_spacing.dart';\n",
    "import '../../../app/theme/app_motion.dart';\n"
    "import '../../../app/theme/app_spacing.dart';\n",
)
text = student_dialog.read_text()
optional_start = "                if (_showOptionalDetails) ...[\n"
error_start = "                if (_errorMessage != null) ...[\n"
start = text.index(optional_start)
end = text.index(error_start, start)
old_optional = text[start:end]
closing = "                ],\n"
assert old_optional.endswith(closing)
body = old_optional[len(optional_start) : -len(closing)]
new_optional = f"""                AnimatedSize(
                  duration: AppMotion.effectiveDuration(context),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: _showOptionalDetails
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
{body}                          ],
                        )
                      : const SizedBox.shrink(),
                ),
"""
text = text[:start] + new_optional + text[end:]
old_button = """          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('添加学生'),
"""
new_button = """          child: AnimatedSwitcher(
            duration: AppMotion.effectiveDuration(context, AppMotion.quick),
            child: _busy
                ? const SizedBox(
                    key: ValueKey<String>('student-setup-saving'),
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    '添加学生',
                    key: ValueKey<String>('student-setup-ready'),
                  ),
          ),
"""
assert text.count(old_button) == 1
text = text.replace(old_button, new_button, 1)
student_dialog.write_text(text)

workspace_test = Path("test/features/teacher_workspace_test.dart")
old_test = """  testWidgets('shows custom type settings to an organization manager', (
    tester,
  ) async {
    final customType = WorkspaceCaseType(
      id: 'case-type-1',
      displayName: '审题策略',
      baseType: LearningCaseType.examStrategy,
      status: 'active',
      sortOrder: 0,
      version: 1,
    );
    final repository = _FakeLearningRepository(
      _fixtureWorkspace(
        caseTypes: [...WorkspaceCaseType.builtInTypes, customType],
        canManageCaseTypes: true,
      ),
    );
    await _pumpWorkspace(tester, repository);

    await tester.tap(find.widgetWithText(OutlinedButton, '问题类型'));
    await tester.pumpAndSettle();

    expect(find.text('可用于新记录'), findsOneWidget);
    expect(find.text('审题策略'), findsOneWidget);
    expect(find.textContaining('系统类型始终保留。自定义类型只负责分类'), findsOneWidget);
  });
"""
new_test = """  testWidgets('keeps configuration actions out of Today for managers', (
    tester,
  ) async {
    final repository = _FakeLearningRepository(
      _fixtureWorkspace(canManageCaseTypes: true),
    );
    await _pumpWorkspace(tester, repository);

    expect(find.text('今日'), findsWidgets);
    expect(find.widgetWithText(FilledButton, '记录问题'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, '问题类型'), findsNothing);
  });
"""
replace_once(workspace_test, old_test, new_test)
