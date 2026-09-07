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

management_page = Path(
    "lib/features/organization_management/presentation/organization_management_page.dart"
)
replace_once(
    management_page,
    "import '../../../app/theme/app_spacing.dart';\n",
    "import '../../../app/theme/app_motion.dart';\n"
    "import '../../../app/theme/app_spacing.dart';\n",
)

management_areas = Path(
    "lib/features/organization_management/presentation/organization_management_areas.dart"
)
old_switch = """        const SizedBox(height: AppSpacing.lg),
        switch (_selectedArea) {
          _ManagementArea.people => _buildPeopleArea(
            activeScopes: activeScopes,
            endedScopes: endedScopes,
            latestEndedScopeIds: latestEndedScopeIds,
          ),
          _ManagementArea.students => _buildStudentsArea(
            activeAssignments: activeAssignments,
            endedAssignments: endedAssignments,
          ),
          _ManagementArea.settings => _buildSettingsArea(),
        },
"""
new_switch = """        const SizedBox(height: AppSpacing.lg),
        AnimatedSwitcher(
          duration: AppMotion.effectiveDuration(context),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: KeyedSubtree(
            key: ValueKey<_ManagementArea>(_selectedArea),
            child: switch (_selectedArea) {
              _ManagementArea.people => _buildPeopleArea(
                activeScopes: activeScopes,
                endedScopes: endedScopes,
                latestEndedScopeIds: latestEndedScopeIds,
              ),
              _ManagementArea.students => _buildStudentsArea(
                activeAssignments: activeAssignments,
                endedAssignments: endedAssignments,
              ),
              _ManagementArea.settings => _buildSettingsArea(),
            },
          ),
        ),
"""
replace_once(management_areas, old_switch, new_switch)

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
